import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/db/user_db.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failed upgrade rolls back all schema changes and can be retried',
      () async {
    final tmp = await Directory.systemTemp.createTemp('jibiki-db-upgrade-');
    final path = '${tmp.path}/user.db';
    try {
      // A legacy v1 database with a conflicting table forces the later v3
      // migration to fail after the v2 ALTER TABLE statements have run.
      final legacy = sqlite3.open(path);
      legacy.execute('CREATE TABLE cards (item_ref TEXT PRIMARY KEY)');
      legacy.execute("INSERT INTO cards VALUES ('あ')");
      legacy.execute('CREATE TABLE collection_cards (preserved TEXT)');
      legacy.execute('PRAGMA user_version = 1');
      legacy.dispose();

      await expectLater(UserDb.open(path), throwsStateError);

      final unchanged = sqlite3.open(path);
      expect(unchanged.select('PRAGMA user_version').single.values.single, 1);
      expect(unchanged.select('PRAGMA table_info(cards)').map((r) => r['name']),
          ['item_ref']);
      expect(unchanged.select('SELECT item_ref FROM cards').single['item_ref'],
          'あ');
      expect(
          unchanged.select(
              "SELECT name FROM sqlite_master WHERE name = 'booster_grants'"),
          isEmpty);
      unchanged.execute('DROP TABLE collection_cards');
      unchanged.dispose();

      final upgraded = await UserDb.open(path);
      expect(
          (await upgraded.select('PRAGMA user_version')).single['user_version'],
          3);
      expect(
          (await upgraded.select('SELECT item_ref, source_title FROM cards'))
              .single,
          {'item_ref': 'あ', 'source_title': ''});
      await upgraded.close();
    } finally {
      await tmp.delete(recursive: true);
    }
  });
}
