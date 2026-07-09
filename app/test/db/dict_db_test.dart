/// Opens the real bundled base pack through the isolate-backed DictDb and
/// exercises the queries the local data source will rely on - counts, ranked
/// FTS gloss search, JP prefix search, and the quoted kana."row" column.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/db/dict_db.dart';

void main() {
  late Directory tmp;
  late DictDb db;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('jibiki-dictdb-test');
    final raw = File('${tmp.path}/base.db');
    await File('assets/packs/base.db.gz')
        .openRead()
        .transform(gzip.decoder)
        .pipe(raw.openWrite());
    db = await DictDb.spawn();
    await db.open(raw.path);
  });

  tearDownAll(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  test('base pack carries the expected content', () async {
    final counts = await db.select(
      'SELECT (SELECT count(*) FROM words) AS words, '
      '(SELECT count(*) FROM kanji) AS kanji, '
      '(SELECT count(*) FROM kana) AS kana, '
      '(SELECT count(*) FROM radicals) AS radicals',
    );
    expect(counts.single['words'], greaterThan(20000));
    expect(counts.single['kanji'], greaterThan(2000));
    expect(counts.single['kana'], 142);
    expect(counts.single['radicals'], greaterThan(0));
  });

  test('FTS gloss search ranks 食べる first for "eat"', () async {
    final rows = await db.select(
      'SELECT w.headword FROM gloss_fts f '
      'JOIN glosses g ON g.id = f.rowid '
      'JOIN words w ON w.id = g.word_id '
      "WHERE gloss_fts MATCH '\"eat\"*' AND g.lang = 'en' "
      'ORDER BY g.word_rank LIMIT 3',
    );
    expect(rows.first['headword'], '食べる');
  });

  test('JP prefix search over word forms', () async {
    final rows = await db.select(
      "SELECT DISTINCT word_id FROM word_forms WHERE text LIKE ?||'%' "
      'ORDER BY is_common DESC LIMIT 10',
      ['食べ'],
    );
    expect(rows, isNotEmpty);
  });

  test('kana table reads with the quoted "row" keyword column', () async {
    final rows = await db.select(
      'SELECT char, romaji, "row" FROM kana WHERE script = ? ORDER BY ord LIMIT 1',
      ['hiragana'],
    );
    expect(rows.single['char'], 'あ');
    expect(rows.single['romaji'], 'a');
  });

  test('errors surface as exceptions, connection survives', () async {
    await expectLater(db.select('SELECT * FROM nope'), throwsStateError);
    final ok = await db.select('SELECT 1 AS one');
    expect(ok.single['one'], 1);
  });
}
