/// Lifecycle of the on-device content packs: install the bundled base pack,
/// download/update/delete the optional full packs (resumable, sha256-verified,
/// atomically swapped), and keep the single [DictDb] connection opened on the
/// right topology.
///
/// Topology rule: `dict-core` installed → it is the main database and every
/// other installed pack is ATTACHed (gloss packs as `g_<lang>`, names as `nm`,
/// examples as `ex`, mnemonic packs as `mn_<lang>`); otherwise the bundled
/// base (self-contained core+gloss) is the main. The base is superseded but
/// never deleted - deleting the full packs falls back to it instantly.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/api_config.dart';
import '../../core/db/dict_db.dart';
import 'pack_manifest.dart';

const String basePackId = 'dict-base';
const String corePackId = 'dict-core';

/// ATTACH schema name for a pack id; null for packs that become `main`.
String? schemaForPack(String id) {
  if (id == basePackId || id == corePackId) return null;
  if (id.startsWith('dict-gloss-')) return 'g_${id.substring('dict-gloss-'.length)}';
  if (id == 'names') return 'nm';
  if (id == 'examples') return 'ex';
  if (id.startsWith('mnemonics-')) return 'mn_${id.substring('mnemonics-'.length)}';
  return null;
}

class PackProgress {
  const PackProgress({required this.received, required this.total, required this.phase});

  final int received;
  final int total;

  /// downloading | verifying | installing
  final String phase;

  double get fraction => total <= 0 ? 0 : received / total;
}

class PackManager extends ChangeNotifier {
  PackManager({
    required Future<Directory> Function() root,
    required Dio dio,
    required Future<ByteData> Function(String key) loadAsset,
  })  : _resolveRoot = root,
        _dio = dio,
        _loadAsset = loadAsset;

  /// Resolves the packs directory (…/Application Support/packs) - deferred so
  /// the manager can be constructed synchronously in the composition root;
  /// tests point it at a temp dir.
  final Future<Directory> Function() _resolveRoot;
  late Directory root;
  final Dio _dio;
  final Future<ByteData> Function(String key) _loadAsset;

  PackRegistry _registry = PackRegistry();
  DictDb? _db;
  PacksManifest? _available;
  final Map<String, PackProgress> progress = {};
  final Map<String, CancelToken> _cancels = {};
  Object? _lastError;

  bool get ready => _db != null;
  Object? get lastError => _lastError;

  /// The open pack database. Only valid once [ready].
  DictDb get db => _db!;

  /// The database, waiting for [ensureReady] to finish if it is still running
  /// (first launch inflates the bundled pack). Throws if bootstrap failed.
  Future<DictDb> whenReady() {
    if (ready) return Future.value(db);
    if (_lastError != null) return Future.error(_lastError!);
    final completer = Completer<DictDb>();
    void check() {
      if (ready) {
        removeListener(check);
        completer.complete(db);
      } else if (_lastError != null) {
        removeListener(check);
        completer.completeError(_lastError!);
      }
    }

    addListener(check);
    return completer.future;
  }

  Iterable<InstalledPack> get installed => _registry.installed.values;
  bool isInstalled(String id) => _registry.installed.containsKey(id);
  bool get hasCore => isInstalled(corePackId);
  PacksManifest? get available => _available;
  DateTime? get lastUpdateCheck => _registry.lastUpdateCheck;

  /// Where the data-source must read gloss rows from: attached gloss schemas
  /// when the full dictionary is installed, else `main` (the base pack carries
  /// its own glosses table). Falls back to the base attached as `b` when a
  /// core is installed without any gloss pack yet.
  List<String> get glossSchemas {
    if (!hasCore) return const ['main'];
    final schemas = [
      for (final p in _registry.installed.values)
        if (p.id.startsWith('dict-gloss-')) schemaForPack(p.id)!,
    ];
    return schemas.isEmpty ? const ['b'] : schemas;
  }

  /// Attached mnemonic-pack schemas (mn_en, …).
  List<String> get mnemonicSchemas => [
        for (final p in _registry.installed.values)
          if (p.id.startsWith('mnemonics-')) schemaForPack(p.id)!,
      ];

  bool get hasNames => isInstalled('names');
  bool get hasExamples => isInstalled('examples');

  String _path(String fileName) => '${root.path}/$fileName';
  File _registryFile() => File(_path('registry.json'));
  Directory get _tmp => Directory(_path('tmp'));

  /// Bootstrap: load the registry, install/refresh the bundled base pack and
  /// open the topology. Never throws - a failure leaves [ready] false with
  /// [lastError] set, and the caller's HTTP paths keep working.
  Future<void> ensureReady() async {
    try {
      root = await _resolveRoot();
      await root.create(recursive: true);
      await _loadRegistry();
      await _ensureBase();
      await _reopen();
      _lastError = null;
    } catch (e) {
      _lastError = e;
    }
    notifyListeners();
  }

  Future<void> _loadRegistry() async {
    final file = _registryFile();
    if (await file.exists()) {
      _registry = PackRegistry.fromJson(
        (jsonDecode(await file.readAsString()) as Map).cast<String, dynamic>(),
      );
    }
  }

  Future<void> _saveRegistry() =>
      _registryFile().writeAsString(jsonEncode(_registry.toJson()));

  /// Install (or refresh after an app update) the base pack shipped in the
  /// binary. ~30 MB inflate, once per app version - runs behind the splash.
  Future<void> _ensureBase() async {
    final manifestBytes = await _loadAsset('assets/packs/base_manifest.json');
    final info = PackInfo.fromJson(
      (jsonDecode(utf8.decode(manifestBytes.buffer.asUint8List())) as Map)
          .cast<String, dynamic>(),
    );
    final current = _registry.installed[info.id];
    if (current != null && current.version == info.version) return;

    final gz = await _loadAsset('assets/packs/base.db.gz');
    await _tmp.create(recursive: true);
    final tmpDb = File('${_tmp.path}/base.db');
    await _gunzipVerified(
      Stream<List<int>>.value(gz.buffer.asUint8List()),
      tmpDb,
      info.sha256Db,
    );
    await _install(info, tmpDb, 'base.db');
  }

  /// Streaming gunzip → [out], verifying the inflated sha256.
  Future<void> _gunzipVerified(
      Stream<List<int>> gzStream, File out, String expectedSha) async {
    final sink = out.openWrite();
    final hash = _Sha256();
    try {
      await for (final chunk in gzStream.transform(gzip.decoder)) {
        hash.add(chunk);
        sink.add(chunk);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (hash.hex() != expectedSha) {
      await out.delete();
      throw StateError('pack corrupted: sha256 mismatch after inflate');
    }
  }

  /// Atomic swap into place + registry update. Reopens the topology.
  Future<void> _install(PackInfo info, File inflated, String fileName) async {
    await inflated.rename(_path(fileName));
    _registry.installed[info.id] = InstalledPack(
      id: info.id,
      version: info.version,
      schemaVersion: info.schemaVersion,
      datasetRev: info.datasetRev,
      installedBytes: info.installedBytes,
      fileName: fileName,
    );
    await _saveRegistry();
    await _reopen();
    notifyListeners();
  }

  Future<void> _reopen() async {
    final core = _registry.installed[corePackId];
    final base = _registry.installed[basePackId];
    final main = core ?? base;
    if (main == null) {
      // Nothing installed (base asset failed?) - leave not-ready.
      return;
    }
    final attach = <String, String>{};
    for (final pack in _registry.installed.values) {
      if (pack.id == main.id) continue;
      final schema = schemaForPack(pack.id);
      if (schema != null) attach[schema] = _path(pack.fileName);
    }
    // Core without any gloss pack: attach the base as `b` so searches keep a
    // gloss source until the language pack lands.
    if (core != null &&
        base != null &&
        !_registry.installed.keys.any((id) => id.startsWith('dict-gloss-'))) {
      attach['b'] = _path(base.fileName);
    }
    final db = _db ?? await DictDb.spawn();
    await db.open(_path(main.fileName), attach: attach);
    _db = db;
  }

  /// Fetch the server manifest (throttled to daily unless [force]).
  Future<PacksManifest?> checkUpdates({bool force = false}) async {
    final last = _registry.lastUpdateCheck;
    if (!force &&
        _available != null &&
        last != null &&
        DateTime.now().difference(last) < const Duration(hours: 24)) {
      return _available;
    }
    final resp = await _dio.get<Map<String, dynamic>>(ApiConfig.packsManifest);
    _available = PacksManifest.fromJson(resp.data!);
    _registry.lastUpdateCheck = DateTime.now();
    await _saveRegistry();
    notifyListeners();
    return _available;
  }

  bool updateAvailable(String id) {
    final local = _registry.installed[id];
    final remote = _available?.byId(id);
    return local != null && remote != null && remote.version != local.version;
  }

  /// Download and install a pack (and its dependencies first). Resumable: a
  /// partial `.part.gz` continues with a Range request on the next attempt.
  Future<void> download(String id) async {
    final manifest = _available ?? await checkUpdates(force: true);
    final info = manifest?.byId(id);
    if (info == null) throw StateError('unknown pack: $id');

    for (final dep in info.requires) {
      final have = _registry.installed[dep.id];
      if (have == null || have.version != dep.version) {
        await download(dep.id);
      }
    }

    await _tmp.create(recursive: true);
    final part = File('${_tmp.path}/$id.part.gz');
    final cancel = CancelToken();
    _cancels[id] = cancel;
    try {
      await _downloadPart(info, part, cancel);

      progress[id] = PackProgress(received: info.bytes, total: info.bytes, phase: 'verifying');
      notifyListeners();
      if (await _sha256OfFile(part) != info.sha256) {
        await part.delete();
        throw StateError('download corrupted: sha256 mismatch');
      }

      progress[id] =
          PackProgress(received: info.bytes, total: info.bytes, phase: 'installing');
      notifyListeners();
      final tmpDb = File('${_tmp.path}/$id.db');
      await _gunzipVerified(part.openRead(), tmpDb, info.sha256Db);
      await part.delete();
      await _install(info, tmpDb, '$id.db');
    } finally {
      _cancels.remove(id);
      progress.remove(id);
      notifyListeners();
    }
  }

  Future<void> _downloadPart(PackInfo info, File part, CancelToken cancel) async {
    var offset = await part.exists() ? await part.length() : 0;
    if (offset >= info.bytes && info.bytes > 0) return; // fully downloaded earlier
    final resp = await _dio.get<ResponseBody>(
      ApiConfig.packFile(info.file),
      options: Options(
        responseType: ResponseType.stream,
        headers: {if (offset > 0) 'range': 'bytes=$offset-'},
        // 200 (full body) is fine when the server ignores the range.
        validateStatus: (code) => code == 200 || code == 206,
      ),
      cancelToken: cancel,
    );
    if (resp.statusCode == 200 && offset > 0) {
      // Server sent the whole file - start over.
      await part.writeAsBytes(const []);
      offset = 0;
    }
    final sink = part.openWrite(mode: FileMode.append);
    try {
      await for (final chunk in resp.data!.stream) {
        sink.add(chunk);
        offset += chunk.length;
        progress[info.id] =
            PackProgress(received: offset, total: info.bytes, phase: 'downloading');
        notifyListeners();
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  void cancelDownload(String id) => _cancels[id]?.cancel();

  /// Remove an installed pack. Refuses while another installed pack depends
  /// on it (delete the dependents first - the UI cascades explicitly).
  Future<void> delete(String id) async {
    if (id == basePackId) throw StateError('the bundled base pack cannot be deleted');
    final pack = _registry.installed[id];
    if (pack == null) return;
    final dependents = [
      for (final p in _registry.installed.values)
        if (_available?.byId(p.id)?.requires.any((d) => d.id == id) ??
            (id == corePackId && p.id.startsWith('dict-gloss-')))
          p.id,
    ];
    if (dependents.isNotEmpty) {
      throw StateError('installed packs depend on $id: ${dependents.join(', ')}');
    }
    _registry.installed.remove(id);
    await _saveRegistry();
    await _reopen();
    final file = File(_path(pack.fileName));
    if (await file.exists()) await file.delete();
    notifyListeners();
  }

  /// Total bytes the packs occupy on disk (for the storage screen).
  int get installedBytesTotal =>
      installed.fold(0, (sum, p) => sum + p.installedBytes);

  Future<String> _sha256OfFile(File file) async {
    final hash = _Sha256();
    await for (final chunk in file.openRead()) {
      hash.add(chunk);
    }
    return hash.hex();
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }
}

/// Incremental sha256 (crypto's chunked conversion, minus the ceremony).
class _Sha256 {
  final _digest = <Digest>[];
  late final ByteConversionSink _sink;

  _Sha256() {
    _sink = sha256.startChunkedConversion(
      ChunkedConversionSink<Digest>.withCallback((digests) => _digest.addAll(digests)),
    );
  }

  void add(List<int> chunk) => _sink.add(chunk);

  String hex() {
    _sink.close();
    return _digest.single.toString();
  }
}
