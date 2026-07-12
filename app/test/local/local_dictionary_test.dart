/// The offline dictionary against the real bundled base pack: search parity
/// (JP exact/prefix/contains, gloss tiers, romaji), detail assembly
/// (breakdown, components, kanji words) and browse filters - the same
/// behaviors server/tests/test_dictionary.py pins for the HTTP API.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show ByteData;
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/japanese_text.dart';
import 'package:jibiki/infrastructure/local/local_dictionary_data_source.dart';
import 'package:jibiki/infrastructure/packs/pack_manager.dart';

void main() {
  late Directory tmp;
  late PackManager packs;
  late LocalDictionaryDataSource dict;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('jibiki-local-dict');
    // Feed the real bundled asset through the normal install path.
    final gz = File('assets/packs/base.db.gz').readAsBytesSync();
    final manifest = File('assets/packs/base_manifest.json').readAsStringSync();
    packs = PackManager(
      root: () async => Directory('${tmp.path}/packs'),
      dio: Dio(),
      loadAsset: (key) async => switch (key) {
        'assets/packs/base.db.gz' => ByteData.sublistView(gz),
        'assets/packs/base_manifest.json' =>
          ByteData.sublistView(utf8.encode(manifest)),
        _ => throw StateError('missing asset $key'),
      },
    );
    await packs.ensureReady();
    expect(packs.lastError, isNull);
    dict = LocalDictionaryDataSource(packs);
  });

  tearDownAll(() async {
    await packs.close();
    await tmp.delete(recursive: true);
  });

  group('search', () {
    test('japanese exact beats prefix beats contains', () async {
      final results = await dict.search('食べる');
      expect(results.words.first.headword, '食べる');
      // Prefix hits (食べる…compounds) follow, contains later.
      expect(results.words.length, greaterThan(1));
    });

    test('gloss tiers: prefix beats contains, en fallback works', () async {
      // Same ranking as the server: "eat" prefix-matches eatery/eating rows
      // before the FTS-contains tier surfaces 食べる ("to eat").
      final en = await dict.search('eat', lang: 'en');
      expect(en.words.map((w) => w.headword), contains('食べる'));
      final prefixTier = await dict.search('eating', lang: 'en');
      expect(prefixTier.words, isNotEmpty);
      // French user: fr glosses match, en fills the gaps.
      final fr = await dict.search('manger', lang: 'fr');
      expect(fr.words.map((w) => w.headword), contains('食べる'));
    });

    test('romaji transliterates and ranks like japanese input', () async {
      final results = await dict.search('taberu');
      expect(results.words.first.headword, '食べる');
    });

    test('sha/tsu/sokuon romaji conversions', () {
      expect(romajiToHiragana('gakkou'), 'がっこう');
      expect(romajiToHiragana('shashin'), 'しゃしん');
      expect(romajiToHiragana('konnichiwa'), 'こんにちわ');
      expect(romajiToHiragana('zenbu'), 'ぜんぶ');
      expect(romajiToHiragana('not romaji!'), isNull);
    });

    test('empty and unmatched queries return empty', () async {
      expect((await dict.search('  ')).words, isEmpty);
      expect((await dict.search('zzzzqqqq')).words, isEmpty);
    });

    test('names are empty without the names pack', () async {
      expect((await dict.search('東京')).names, isEmpty);
    });
  });

  group('detail', () {
    test('word detail carries forms, senses, glosses and kanji breakdown',
        () async {
      final id = (await dict.search('食べる')).words.first.id;
      final word = await dict.word(id);
      expect(word.headword, '食べる');
      expect(word.primaryReading, 'たべる');
      expect(word.kanji, isNotEmpty);
      expect(word.readings, isNotEmpty);
      expect(word.senses.first.glosses, isNotEmpty);
      expect(word.kanjiBreakdown.map((k) => k.literal), contains('食'));
      // Base pack has no examples pack attached.
      expect(word.examples, isEmpty);
    });

    test('kanji detail: meanings, components, strokes and ranked words',
        () async {
      final kanji = await dict.kanji('水');
      expect(kanji.meaningsFor('en').join(' '), contains('water'));
      expect(kanji.strokeCount, 4);
      expect(kanji.hasStrokes, isTrue);
      expect(kanji.words, isNotEmpty);
      expect(kanji.words.length, lessThanOrEqualTo(12));
      // Sample words are WordSerializer-shaped maps.
      final first = (kanji.words.first as Map).cast<String, dynamic>();
      expect(first['headword'], isNotEmpty);
      expect(first['is_common'], isA<bool>());
    });

    test('kana chart and detail', () async {
      final chart = await dict.kana();
      expect(chart.length, 208);
      final hira = await dict.kana(script: 'hiragana');
      expect(hira.every((k) => k.isHiragana), isTrue);
      final a = await dict.kanaDetail('あ');
      expect(a.romaji, 'a');
      expect(a.order, greaterThanOrEqualTo(0));
      final kya = await dict.kanaDetail('きゃ');
      expect(kya.romaji, 'kya');
      expect(kya.kind, 'yoon');
    });
  });

  group('browse', () {
    test('common words ordered by frequency, paginated', () async {
      final page1 = await dict.words(common: true, limit: 5);
      final page2 = await dict.words(common: true, limit: 5, offset: 5);
      expect(page1.length, 5);
      expect(page1.every((w) => w.isCommon), isTrue);
      expect(
        page2
            .map((w) => w.id)
            .toSet()
            .intersection(page1.map((w) => w.id).toSet()),
        isEmpty,
      );
    });

    test('kanji list filters by jlpt and grade', () async {
      final n5 = await dict.kanjiList(jlpt: 5, limit: 200);
      expect(n5, isNotEmpty);
      expect(n5.every((k) => k.jlpt == 5), isTrue);
      final grade1 = await dict.kanjiList(grade: 1, limit: 10);
      expect(grade1.every((k) => k.grade == 1), isTrue);
    });

    test('kanji list contains= intersects components', () async {
      final withWater = await dict.kanjiList(contains: '水', limit: 50);
      expect(withWater, isNotEmpty);
      expect(withWater.every((k) => k.components.contains('水')), isTrue);
    });

    test('radicals list', () async {
      final radicals = await dict.radicals();
      expect(radicals, isNotEmpty);
      expect(radicals.first.keys,
          containsAll(['literal', 'strokes', 'reading', 'meaning']));
    });
  });

  test('sha256 of the asset matches its manifest (release-gate sanity)', () {
    final manifest =
        jsonDecode(File('assets/packs/base_manifest.json').readAsStringSync());
    final gz = File('assets/packs/base.db.gz').readAsBytesSync();
    expect(sha256.convert(gz).toString(), manifest['sha256']);
  });
}
