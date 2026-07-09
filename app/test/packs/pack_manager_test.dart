/// PackManager lifecycle against a synthetic tiny pack: install-from-asset,
/// version-gated reinstall, registry persistence, topology, and delete rules.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/data/packs/pack_manager.dart';
import 'package:jibiki/data/packs/pack_manifest.dart';
import 'package:sqlite3/sqlite3.dart' as sq;

void main() {
  late Directory tmp;
  late Map<String, List<int>> assets;

  PackManager manager() => PackManager(
        root: () async => Directory('${tmp.path}/packs'),
        dio: Dio(), // never reached in these tests
        loadAsset: (key) async {
          final bytes = assets[key];
          if (bytes == null) throw StateError('missing asset $key');
          return ByteData.sublistView(Uint8List.fromList(bytes));
        },
      );

  /// A minimal but schema-plausible base pack: enough for topology to open.
  List<int> buildTinyPack() {
    final dbFile = '${tmp.path}/tiny.db';
    final db = sq.sqlite3.open(dbFile);
    db.execute('''
      CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
      CREATE TABLE kana("char" TEXT PRIMARY KEY, romaji TEXT, script TEXT,
        kind TEXT, "row" TEXT, ord INTEGER);
      INSERT INTO meta VALUES ('pack_id', 'dict-base');
      INSERT INTO kana VALUES ('あ', 'a', 'hiragana', 'gojuon', 'a', 1);
    ''');
    db.dispose();
    return File(dbFile).readAsBytesSync();
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('jibiki-packs-test');
    final raw = buildTinyPack();
    final gz = gzip.encode(raw);
    assets = {
      'assets/packs/base.db.gz': gz,
      'assets/packs/base_manifest.json': utf8.encode(jsonEncode({
        'id': 'dict-base',
        'kind': 'sqlite',
        'schema_version': 1,
        'version': '2026.07.09',
        'dataset_rev': 1,
        'file': 'base.db.gz',
        'bytes': gz.length,
        'installed_bytes': raw.length,
        'sha256': sha256.convert(gz).toString(),
        'sha256_db': sha256.convert(raw).toString(),
      })),
    };
  });

  tearDown(() => tmp.delete(recursive: true));

  test('ensureReady installs the bundled base and opens it', () async {
    final packs = manager();
    await packs.ensureReady();
    expect(packs.lastError, isNull);
    expect(packs.ready, isTrue);
    expect(packs.isInstalled(basePackId), isTrue);
    expect(packs.hasCore, isFalse);
    expect(packs.glossSchemas, ['main']);

    final row = await packs.db.select('SELECT romaji FROM kana WHERE "char" = ?', ['あ']);
    expect(row.single['romaji'], 'a');
  });

  test('registry survives a restart; same version is not reinstalled', () async {
    final first = manager();
    await first.ensureReady();
    final installedAt = await File('${tmp.path}/packs/base.db').lastModified();

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final second = manager();
    await second.ensureReady();
    expect(second.isInstalled(basePackId), isTrue);
    // Untouched file - ensureBase saw the same version in the registry.
    expect(await File('${tmp.path}/packs/base.db').lastModified(), installedAt);
  });

  test('a corrupted asset fails safe: not ready, error surfaced', () async {
    assets['assets/packs/base.db.gz'] =
        gzip.encode(utf8.encode('not a database at all'));
    final packs = manager();
    await packs.ensureReady();
    expect(packs.ready, isFalse);
    expect(packs.lastError, isNotNull);
    expect(packs.isInstalled(basePackId), isFalse);
  });

  test('the bundled base cannot be deleted', () async {
    final packs = manager();
    await packs.ensureReady();
    await expectLater(packs.delete(basePackId), throwsStateError);
  });

  test('schema names are stable identifiers', () {
    expect(schemaForPack('dict-gloss-fr'), 'g_fr');
    expect(schemaForPack('dict-gloss-en'), 'g_en');
    expect(schemaForPack('names'), 'nm');
    expect(schemaForPack('examples'), 'ex');
    expect(schemaForPack('mnemonics-en'), 'mn_en');
    expect(schemaForPack('dict-core'), isNull);
    expect(schemaForPack('dict-base'), isNull);
  });

  test('manifest v2 parses', () {
    final manifest = PacksManifest.fromJson({
      'schema': 'jibiki-packs/2',
      'packs': [
        {
          'id': 'dict-gloss-fr',
          'version': '2026.07.09',
          'schema_version': 1,
          'dataset_rev': 1,
          'file': 'dict-gloss-fr-2026.07.09.db.gz',
          'bytes': 1,
          'installed_bytes': 2,
          'sha256': 'x',
          'sha256_db': 'y',
          'languages': ['fr'],
          'requires': [
            {'id': 'dict-core', 'version': '2026.07.09'},
          ],
          'title': {'en': 'French dictionary', 'fr': 'Dictionnaire français'},
        },
      ],
    });
    final pack = manifest.byId('dict-gloss-fr')!;
    expect(pack.requires.single.id, 'dict-core');
    expect(pack.languages, ['fr']);
    expect(manifest.byId('absent'), isNull);
  });
}
