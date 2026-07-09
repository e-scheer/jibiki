/// Offline & storage presentation state + onboarding pack offers, against a
/// PackManager with the tiny synthetic base installed and no server manifest
/// (the offline-first-launch worst case).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/data/packs/pack_manager.dart';
import 'package:jibiki/viewmodels/storage_viewmodel.dart';
import 'package:sqlite3/sqlite3.dart' as sq;

void main() {
  late Directory tmp;
  late PackManager packs;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('jibiki-storage-vm');
    final dbFile = '${tmp.path}/tiny.db';
    final db = sq.sqlite3.open(dbFile);
    db.execute("CREATE TABLE kana(\"char\" TEXT PRIMARY KEY); INSERT INTO kana VALUES ('あ');");
    db.dispose();
    final raw = File(dbFile).readAsBytesSync();
    final gz = gzip.encode(raw);
    packs = PackManager(
      root: () async => Directory('${tmp.path}/packs'),
      dio: Dio(), // unreachable server: checkUpdates will fail
      loadAsset: (key) async => switch (key) {
        'assets/packs/base.db.gz' => ByteData.sublistView(Uint8List.fromList(gz)),
        'assets/packs/base_manifest.json' =>
          ByteData.sublistView(Uint8List.fromList(utf8.encode(jsonEncode({
            'id': 'dict-base',
            'version': '1',
            'file': 'base.db.gz',
            'bytes': gz.length,
            'installed_bytes': raw.length,
            'sha256': sha256.convert(gz).toString(),
            'sha256_db': sha256.convert(raw).toString(),
          })))),
        _ => throw StateError('missing asset $key'),
      },
    );
    await packs.ensureReady();
  });

  tearDown(() => tmp.delete(recursive: true));

  test('rows show the installed base even with no server manifest', () {
    final vm = StorageViewModel(packs, null);
    final rows = vm.rows;
    expect(rows, hasLength(1));
    expect(rows.single.id, basePackId);
    expect(rows.single.isInstalled, isTrue);
    expect(rows.single.canDelete, isFalse);
    expect(vm.installedBytesTotal, greaterThan(0));
  });

  test('checkUpdates against an unreachable server fails soft', () async {
    final vm = StorageViewModel(packs, null);
    await vm.checkUpdates();
    expect(vm.updateError, isNotNull);
    expect(vm.checking, isFalse);
    // The screen still renders the installed state.
    expect(vm.rows, isNotEmpty);
  });

  test('human sizes read like a store listing', () {
    expect(StorageViewModel.humanSize(0), '-');
    expect(StorageViewModel.humanSize(900), '1 KB');
    expect(StorageViewModel.humanSize(10 * 1024 * 1024), '10.0 MB');
    expect(StorageViewModel.humanSize(200 * 1024 * 1024), '200 MB');
  });
}
