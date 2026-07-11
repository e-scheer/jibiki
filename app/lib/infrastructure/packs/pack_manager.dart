import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/api_config.dart';
import '../../core/db/dict_db.dart';
import 'pack_manifest.dart';

const basePackId = 'dict-base';
const corePackId = 'dict-core';

String? schemaForPack(String id) {
  if (id.startsWith('dict-locale-')) {
    return 'loc_${id.substring('dict-locale-'.length).replaceAll('-', '_')}';
  }
  if (id.startsWith('examples-')) {
    return 'ex_${id.substring('examples-'.length).replaceAll('-', '_')}';
  }
  if (id.startsWith('mnemonics-')) {
    return 'mn_${id.substring('mnemonics-'.length).replaceAll('-', '_')}';
  }
  return switch (id) {
    'names' => 'nm',
    basePackId || corePackId => null,
    _ => null,
  };
}

class InstalledPack {
  const InstalledPack({
    required this.id,
    required this.version,
    required this.path,
    required this.installedBytes,
    required this.schemaVersion,
    this.languages = const [],
  });

  final String id;
  final String version;
  final String path;
  final int installedBytes;
  final int schemaVersion;
  final List<String> languages;

  factory InstalledPack.fromJson(Map<String, dynamic> json) => InstalledPack(
        id: json['id'] as String,
        version: json['version'] as String,
        path: json['path'] as String,
        installedBytes: (json['installed_bytes'] as num).toInt(),
        schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 0,
        languages: [
          for (final value in json['languages'] as List? ?? const []) '$value',
        ],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'path': path,
        'installed_bytes': installedBytes,
        'schema_version': schemaVersion,
        'languages': languages,
      };
}

class PackProgress {
  const PackProgress(this.received, this.total, {this.phase = 'downloading'});
  final int received;
  final int total;
  final String phase;
  double get fraction => total <= 0 ? 0 : received / total;
}

typedef PackRoot = Future<Directory> Function();
typedef AssetLoader = Future<ByteData> Function(String key);

class PackManager extends ChangeNotifier {
  PackManager({
    required PackRoot root,
    required Dio dio,
    required AssetLoader loadAsset,
  })  : _rootProvider = root,
        _dio = dio,
        _loadAsset = loadAsset;

  final PackRoot _rootProvider;
  final Dio _dio;
  final AssetLoader _loadAsset;
  final Map<String, CancelToken> _cancellations = {};

  DictDb? _database;
  DictDb get db => _database!;
  Directory? _root;
  bool ready = false;
  Object? lastError;
  PacksManifest? available;
  DateTime? lastUpdateCheck;
  final List<InstalledPack> installed = [];
  final Map<String, PackProgress> progress = {};

  bool get hasCore => isInstalled(corePackId);
  int get installedBytesTotal =>
      installed.fold(0, (total, pack) => total + pack.installedBytes);
  List<String> get localeSchemas => _schemas('loc_');
  List<String> get glossSchemas => hasCore ? localeSchemas : ['main'];
  List<String> get mnemonicSchemas => _schemas('mn_');

  List<String> _schemas(String prefix) => [
        for (final pack in installed)
          if ((schemaForPack(pack.id) ?? '').startsWith(prefix))
            schemaForPack(pack.id)!,
      ];

  bool isInstalled(String id) => installed.any((pack) => pack.id == id);

  Future<void> ensureReady() async {
    if (ready) return;
    lastError = null;
    try {
      _root = await _rootProvider();
      await _root!.create(recursive: true);
      _database ??= await DictDb.spawn();
      await _readRegistry();
      await _ensureBase();
      await _openTopology();
      ready = true;
    } catch (error) {
      ready = false;
      lastError = error;
      installed.removeWhere(
        (pack) => pack.id == basePackId && !File(pack.path).existsSync(),
      );
    }
    notifyListeners();
  }

  Future<void> _ensureBase() async {
    final bytes = await _loadAsset('assets/packs/base_manifest.json');
    final info = PackInfo.fromJson(
      jsonDecode(
        utf8.decode(
          bytes.buffer.asUint8List(
            bytes.offsetInBytes,
            bytes.lengthInBytes,
          ),
        ),
      ) as Map<String, dynamic>,
    );
    final current = _installed(info.id);
    if (current != null &&
        current.version == info.version &&
        File(current.path).existsSync()) {
      return;
    }
    final compressed = await _loadAsset('assets/packs/base.db.gz');
    final payload = compressed.buffer.asUint8List(
      compressed.offsetInBytes,
      compressed.lengthInBytes,
    );
    await _install(info, payload, filename: 'base.db');
  }

  Future<void> _install(
    PackInfo info,
    List<int> compressed, {
    String? filename,
  }) async {
    if (info.sha256.isNotEmpty &&
        sha256.convert(compressed).toString() != info.sha256) {
      throw StateError('Checksum mismatch for ${info.id}');
    }
    final raw = gzip.decode(compressed);
    if (info.sha256Db.isNotEmpty &&
        sha256.convert(raw).toString() != info.sha256Db) {
      throw StateError('Database checksum mismatch for ${info.id}');
    }
    final path = '${_root!.path}/${filename ?? '${info.id}.db'}';
    final temporary = File('$path.part');
    await temporary.writeAsBytes(raw, flush: true);
    final probe = await DictDb.spawn();
    try {
      try {
        await probe.open(temporary.path);
        await probe.select('PRAGMA schema_version');
        final rows = await probe.select('SELECT key, value FROM meta');
        final metadata = <String, String>{
          for (final row in rows) '${row['key']}': '${row['value']}',
        };
        if (metadata['pack_id'] != info.id) {
          throw StateError('Pack identity mismatch for ${info.id}');
        }
        if (info.schemaVersion > 0 &&
            metadata['schema_version'] != '${info.schemaVersion}') {
          throw StateError('Pack schema mismatch for ${info.id}');
        }
      } finally {
        await probe.close();
      }
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
    final target = File(path);
    if (await target.exists()) await target.delete();
    await temporary.rename(path);
    installed.removeWhere((pack) => pack.id == info.id);
    installed.add(
      InstalledPack(
        id: info.id,
        version: info.version,
        path: path,
        installedBytes: raw.length,
        schemaVersion: info.schemaVersion,
        languages: info.languages,
      ),
    );
    await _writeRegistry();
  }

  Future<PacksManifest> checkUpdates({bool force = false}) async {
    if (!force && available != null) return available!;
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConfig.packsManifest,
    );
    available = PacksManifest.fromJson(response.data!);
    lastUpdateCheck = DateTime.now();
    notifyListeners();
    return available!;
  }

  Future<void> download(String id) => _download(id, <String>{});

  Future<void> _download(String id, Set<String> resolving) async {
    await ensureReady();
    final manifest = available ?? await checkUpdates();
    final info = manifest.byId(id);
    if (info == null) throw StateError('Unknown pack $id');
    final current = _installed(id);
    if (current != null &&
        current.version == info.version &&
        File(current.path).existsSync()) {
      return;
    }
    if (!resolving.add(id)) {
      throw StateError('Circular pack dependency involving $id');
    }
    for (final dependency in info.requires) {
      final installedDependency = _installed(dependency.id);
      if (installedDependency == null ||
          installedDependency.version != dependency.version) {
        await _download(dependency.id, resolving);
      }
    }
    final token = CancelToken();
    _cancellations[id] = token;
    progress[id] = PackProgress(0, info.bytes);
    notifyListeners();
    try {
      final response = await _dio.get<List<int>>(
        ApiConfig.packFile(info.file),
        options: Options(responseType: ResponseType.bytes),
        cancelToken: token,
        onReceiveProgress: (received, total) {
          progress[id] = PackProgress(received, total > 0 ? total : info.bytes);
          notifyListeners();
        },
      );
      await _install(info, response.data!);
      await _openTopology();
    } finally {
      resolving.remove(id);
      _cancellations.remove(id);
      progress.remove(id);
      notifyListeners();
    }
  }

  void cancelDownload(String id) => _cancellations[id]?.cancel();

  Future<void> delete(String id) async {
    if (id == basePackId) {
      throw StateError('The bundled base pack cannot be deleted.');
    }
    final dependants = installed.where((pack) {
      final info = available?.byId(pack.id);
      return info?.requires.any((requirement) => requirement.id == id) ?? false;
    }).toList();
    if (dependants.isNotEmpty) {
      throw StateError('$id is required by ${dependants.first.id}.');
    }
    final pack = _installed(id);
    if (pack == null) return;
    final file = File(pack.path);
    if (await file.exists()) await file.delete();
    installed.removeWhere((value) => value.id == id);
    await _writeRegistry();
    await _openTopology();
    notifyListeners();
  }

  InstalledPack? _installed(String id) {
    for (final pack in installed) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  Future<void> _openTopology() async {
    final main = _installed(corePackId) ?? _installed(basePackId);
    if (main == null) throw StateError('No dictionary core is installed.');
    final attached = <String, String>{};
    for (final pack in installed) {
      final schema = schemaForPack(pack.id);
      if (schema != null) attached[schema] = pack.path;
    }
    await db.open(main.path, attach: attached);
  }

  File get _registry => File('${_root!.path}/registry.json');

  Future<void> _readRegistry() async {
    installed.clear();
    if (!await _registry.exists()) return;
    final values = jsonDecode(await _registry.readAsString()) as List;
    installed.addAll(
      values.map(
        (value) =>
            InstalledPack.fromJson((value as Map).cast<String, dynamic>()),
      ),
    );
    installed.removeWhere((pack) => !File(pack.path).existsSync());
  }

  Future<void> _writeRegistry() => _registry.writeAsString(
        jsonEncode([for (final pack in installed) pack.toJson()]),
        flush: true,
      );

  Future<void> close() async {
    final database = _database;
    _database = null;
    ready = false;
    if (database != null) await database.close();
  }
}
