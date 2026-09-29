import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/infrastructure/local/local_dictionary_data_source.dart';
import 'package:jibiki/infrastructure/packs/pack_manager.dart';
import 'package:jibiki/infrastructure/packs/pack_manifest.dart';
import 'package:jibiki/repositories/dictionary_repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tmp;
  late PackManager packs;
  late LocalDictionaryDataSource dictionary;
  late DictionaryRepository repository;
  var language = 'en';
  var glossLanguage = 'fr';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('jibiki-locales-');
    language = 'en';
    glossLanguage = 'fr';
    final files = <String, List<int>>{};
    final infos = <String, Map<String, dynamic>>{};
    for (final id in [
      'dict-base',
      'dict-core',
      'dict-locale-fr',
      'examples-en',
      'examples-fr'
    ]) {
      final db = sqlite3.open('${tmp.path}/$id.db');
      db.execute(_schema);
      db.execute('INSERT INTO meta VALUES (?, ?)', ['pack_id', id]);
      db.execute("INSERT INTO meta VALUES ('schema_version', '2')");
      db.execute(_core);
      if (id == 'dict-base') db.execute(_english);
      if (id == 'dict-base' || id == 'dict-locale-fr') db.execute(_french);
      if (id != 'dict-base') {
        db.execute('ALTER TABLE words ADD canonical_word_id INTEGER');
        db.execute(
            "INSERT INTO words(id, is_common, jlpt, freq_rank, headword, primary_reading, canonical_word_id) VALUES (4, 1, 5, 1, 'かな', 'かな', 1)");
        db.execute("INSERT INTO word_forms VALUES (4, 'かな', 1, 1, 0, '')");
        db.execute(
            'CREATE TABLE kana_word_examples(kana TEXT, word_id INTEGER, reading TEXT, ord INTEGER, provenance TEXT)');
        db.execute('INSERT INTO kana_word_examples VALUES (?, ?, ?, ?, ?)',
            ['は', 1, 'かな', 0, '{"source":"fixture"}']);
        db.execute("ALTER TABLE words ADD provenance TEXT DEFAULT '{}'");
        db.execute("ALTER TABLE word_forms ADD metadata TEXT DEFAULT '{}'");
        db.execute("ALTER TABLE senses ADD metadata TEXT DEFAULT '{}'");
        db.execute("ALTER TABLE glosses ADD metadata TEXT DEFAULT '{}'");
        db.execute('UPDATE words SET provenance = ?', ['{"source":"fixture"}']);
        db.execute('UPDATE word_forms SET metadata = ?', ['{"no_kanji":true}']);
        db.execute('UPDATE senses SET metadata = ?',
            ['{"restricted_readings":["かな"]}']);
        db.execute('UPDATE glosses SET metadata = ?', ['{"type":"literal"}']);
        db.execute(
            "INSERT INTO words(id, is_common, headword, primary_reading, provenance) VALUES (5, 1, 'かな', 'かな', ?)",
            ['{"source_status":"upstream_not_in_snapshot"}']);
        db.execute(
            "INSERT INTO word_forms(word_id,text,kind,is_common,ord,pitch) VALUES (5,'かな',1,1,0,'')");
        db.execute(
            "INSERT INTO words(id,is_common,headword,primary_reading,provenance) VALUES(6,1,'かな','かな',?)",
            ['{"source_status":"legacy_merged_entry"}']);
        db.execute(
            "INSERT INTO word_forms(word_id,text,kind,is_common,ord,pitch) VALUES (6,'かな',1,1,0,'')");
      }
      if (id.startsWith('examples-')) {
        final lang = id.substring('examples-'.length);
        db.execute("INSERT INTO examples VALUES (1, 'かな test')");
        db.execute(
            'CREATE TABLE example_sense_links(example_id INTEGER, word_id INTEGER)');
        db.execute('INSERT INTO example_sense_links VALUES (1, 1)');
        db.execute("ALTER TABLE examples ADD source_key TEXT");
        db.execute("ALTER TABLE examples ADD provenance TEXT DEFAULT '{}'");
        db.execute('UPDATE examples SET source_key = ?, provenance = ?',
            ['fixture:1', '{"source":"fixture"}']);
        db.execute(
            "INSERT INTO examples(id, japanese) VALUES (2, 'かな unlinked substring')");
        db.execute('INSERT INTO example_translations VALUES (1, ?, ?)',
            [lang, '$lang sentence']);
        db.execute('INSERT INTO example_translations VALUES (2, ?, ?)',
            [lang, '$lang unlinked']);
      }
      db.dispose();
      final raw = File('${tmp.path}/$id.db').readAsBytesSync();
      final gz = gzip.encode(raw);
      files['$id.db.gz'] = gz;
      infos[id] = {
        'id': id,
        'version': 'test-1',
        'schema_version': 2,
        'file': '$id.db.gz',
        'bytes': gz.length,
        'installed_bytes': raw.length,
        'sha256': sha256.convert(gz).toString(),
        'sha256_db': sha256.convert(raw).toString(),
        'languages': id.endsWith('-fr') ? ['fr'] : ['en'],
        'requires': id == 'dict-locale-fr'
            ? [
                {'id': 'dict-core', 'version': 'test-1'}
              ]
            : [],
      };
    }
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(
          requestOptions: options,
          data: Uint8List.fromList(files[options.uri.pathSegments.last]!)));
    }));
    packs = PackManager(
        root: () async => Directory('${tmp.path}/installed'),
        dio: dio,
        loadAsset: (key) async => ByteData.sublistView(Uint8List.fromList(
            key.endsWith('.json')
                ? utf8.encode(jsonEncode(infos['dict-base']))
                : files['dict-base.db.gz']!)));
    packs.available = PacksManifest.fromJson(
        {'schema': packsManifestSchema, 'packs': infos.values.toList()});
    await packs.ensureReady();
    expect(packs.lastError, isNull);
    dictionary = LocalDictionaryDataSource(packs,
        language: () => language, glossLanguage: () => glossLanguage);
    repository = DictionaryRepository(dictionary,
        cacheRevision: () => (packs.revision, language, glossLanguage));
  });

  tearDown(() async {
    await packs.close();
    await tmp.delete(recursive: true);
  });

  test('Latin glosses remain searchable when their spelling is valid romaji',
      () async {
    expect((await dictionary.search('gare', lang: 'fr')).words.single.id, 1);
    expect((await dictionary.search('%', lang: 'fr')).words, isEmpty);
    expect((await dictionary.search('_', lang: 'fr')).words, isEmpty);
  });

  test('a full romaji result page cannot crowd out a matching Latin gloss',
      () async {
    expect(
        (await dictionary.search('kana', lang: 'fr', limit: 2))
            .words
            .map((w) => w.id),
        [1, 3]);
  });

  test(
      'radical browsing finds both canonical components and source radical glyphs',
      () async {
    expect((await dictionary.kanjiList(contains: '亻')).single.literal, '休');
    expect((await dictionary.kanjiList(contains: '⺅')).single.literal, '休');
    expect(await dictionary.kanjiList(contains: '氵'), isEmpty);
  });

  test(
      'locale install retains compatible base fallback and deduplicates senses',
      () async {
    await packs.download('dict-locale-fr');
    expect(packs.glossSchemas, ['loc_fr', 'base']);
    expect((await dictionary.search('station', lang: 'fr')).words.single.id, 1);
    final word = await dictionary.word(1);
    expect(word.senses.single.glosses.map((g) => '${g.language}:${g.text}'),
        unorderedEquals(['fr:gare', 'en:station']));
    expect(word.senses.single.misc, ['uk']);
    expect(word.senses.single.field, ['ling']);
    expect(word.provenance['source'], 'fixture');
    expect(word.readings.single.metadata['no_kanji'], isTrue);
    expect(word.senses.single.metadata['restricted_readings'], ['かな']);
    expect(word.senses.single.glosses.first.metadata['type'], 'literal');
    expect(word.senses.single.notes.map((n) => '${n.language}:${n.text}'),
        unorderedEquals(['fr:French note', 'en:English note']));
  });

  test('kana explanations and examples select one locale and caches invalidate',
      () async {
    final english = await repository.kanaDetail('は');
    expect(english.originNote, 'English origin');
    expect(english.usageLanguage, 'en');
    expect(english.usageExamples.single.translation, 'English example');
    language = 'fr';
    final french = await repository.kanaDetail('は');
    expect(french.originNote, 'French origin');
    expect(french.originLanguage, 'fr');
    expect(french.usageLabel, 'French role');
    expect(french.usageExamples.single.language, 'fr');
    expect(french.usageExamples.single.translation, 'French example');
    await packs.download('dict-locale-fr');
    final updated = await repository.kanaDetail('は');
    expect(identical(french, updated), isFalse);
    expect(updated.usageExamples, hasLength(1));
    expect(updated.wordExamples.single.wordId, 1);
    expect(updated.wordExamples.single.headword, 'かな');
    expect(updated.wordExamples.single.reading, 'かな');
    expect(updated.wordExamples.single.glosses.map((g) => g.language),
        contains('fr'));
    expect(updated.wordExamples.single.provenance['source'], 'fixture');
    language = 'de';
    final fallback = await repository.kanaDetail('は');
    expect(fallback.originLanguage, 'en');
    expect(fallback.usageLanguage, 'en');
    expect(fallback.usageExamples.single.language, 'en');
  });

  test('example packs merge by sentence with explicit translation languages',
      () async {
    await packs.download('examples-en');
    await packs.download('examples-fr');
    final word = await dictionary.word(1);
    expect(word.examples, hasLength(1));
    expect(word.examples.single.language, 'fr');
    expect(word.examples.single.translation, 'fr sentence');
    expect(word.examples.single.translationFor('en'), 'en sentence');
    expect(word.examples.single.translations, hasLength(2));
    expect(word.examples.single.provenance['source'], 'fixture');
  });

  test('legacy packs without example links never guess word associations',
      () async {
    final word = await dictionary.word(1);
    expect(word.provenance, isEmpty);
    expect(word.senses.single.metadata, isEmpty);
    expect(word.examples, isEmpty);
  });

  test('legacy word IDs resolve canonical content without duplicate discovery',
      () async {
    await packs.download('dict-locale-fr');
    final alias = await dictionary.word(4);
    expect(alias.id, 4);
    expect(alias.canonicalId, 1);
    expect(alias.senses.single.glossesFor('fr'), ['gare']);
    expect((await dictionary.words(common: true)).map((w) => w.id), [1]);
    expect((await dictionary.search('かな')).words.map((w) => w.id),
        isNot(contains(4)));
    expect((await dictionary.search('かな')).words.map((w) => w.id),
        isNot(contains(5)));
    final historical = await dictionary.word(5);
    expect(historical.id, 5);
    expect(historical.provenance['source_status'], 'upstream_not_in_snapshot');
    expect((await dictionary.search('かな')).words.map((w) => w.id),
        isNot(contains(6)));
    expect((await dictionary.word(6)).provenance['source_status'],
        'legacy_merged_entry');
  });

  test(
      'dependency deletion is blocked after restart without an online manifest',
      () async {
    await packs.download('dict-locale-fr');
    await packs.close();
    packs.available = null;
    await packs.ensureReady();
    await expectLater(packs.delete('dict-core'), throwsStateError);
    expect(packs.ready, isTrue);
  });
}

// Deliberately artificial text fixtures. Every string has an explicit locale;
// these test records are never shipped as educational content.
const _schema = '''
CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE words(id INTEGER PRIMARY KEY, is_common INTEGER, jlpt INTEGER, freq_rank INTEGER, headword TEXT, primary_reading TEXT);
CREATE TABLE word_forms(word_id INTEGER, text TEXT, kind INTEGER, is_common INTEGER, ord INTEGER, pitch TEXT);
CREATE TABLE senses(id INTEGER PRIMARY KEY, word_id INTEGER, ord INTEGER, pos TEXT, misc TEXT, field TEXT);
CREATE TABLE glosses(sense_id INTEGER, word_id INTEGER, language TEXT, ord INTEGER, text TEXT, word_rank INTEGER, word_common INTEGER);
CREATE TABLE sense_notes(sense_id INTEGER, language TEXT, text TEXT);
CREATE TABLE kanji(literal TEXT PRIMARY KEY, stroke_count INTEGER, freq_rank INTEGER, components TEXT, metadata TEXT);
CREATE TABLE kanji_components(kanji TEXT, component TEXT);
CREATE TABLE kanji_meanings(kanji TEXT, language TEXT, text TEXT);
CREATE TABLE kanji_explanations(kanji TEXT, language TEXT, origin TEXT);
CREATE TABLE kana(char TEXT PRIMARY KEY, romaji TEXT, script TEXT, kind TEXT, row TEXT, ord INTEGER, origin TEXT);
CREATE TABLE kana_explanations(kana TEXT, language TEXT, origin_note TEXT);
CREATE TABLE kana_usages(id INTEGER PRIMARY KEY, kana TEXT);
CREATE TABLE kana_usage_translations(usage_id INTEGER, language TEXT, label TEXT, explanation TEXT);
CREATE TABLE kana_usage_examples(id INTEGER PRIMARY KEY, usage_id INTEGER, ord INTEGER, before_text TEXT, particle TEXT, after_text TEXT, pronunciation TEXT);
CREATE TABLE kana_usage_example_translations(example_id INTEGER, language TEXT, text TEXT);
CREATE TABLE examples(id INTEGER PRIMARY KEY, japanese TEXT);
CREATE TABLE example_translations(example_id INTEGER, language TEXT, text TEXT);
''';
const _core = '''
INSERT INTO words VALUES (1, 1, 5, 1, 'かな', 'かな');
INSERT INTO words VALUES (2, 0, NULL, 2, 'かなか', 'かなか');
INSERT INTO words VALUES (3, 0, NULL, 3, 'ふ', 'ふ');
INSERT INTO word_forms VALUES (1, 'かな', 1, 1, 0, '');
INSERT INTO word_forms VALUES (2, 'かなか', 1, 0, 0, '');
INSERT INTO word_forms VALUES (3, 'ふ', 1, 0, 0, '');
INSERT INTO senses VALUES (1, 1, 0, '["n"]', '["uk"]', '["ling"]');
INSERT INTO senses VALUES (3, 3, 0, '[]', '[]', '[]');
INSERT INTO kanji VALUES ('休', 6, 1, '["亻","木"]', '{"kanjialive":{"radical":{"literal":"⺅"}}}');
INSERT INTO kanji_components VALUES ('休', '亻');
INSERT INTO kana VALUES ('は', 'ha', 'hiragana', 'gojuon', 'h', 1, '波');
INSERT INTO kana_usages VALUES (1, 'は');
INSERT INTO kana_usage_examples VALUES (1, 1, 0, 'A', 'は', 'B', 'wa');
''';
const _english = '''
INSERT INTO glosses VALUES (1, 1, 'en', 0, 'station', 1, 1);
INSERT INTO sense_notes VALUES (1, 'en', 'English note');
INSERT INTO kana_explanations VALUES ('は', 'en', 'English origin');
INSERT INTO kana_usage_translations VALUES (1, 'en', 'English role', 'English usage');
INSERT INTO kana_usage_example_translations VALUES (1, 'en', 'English example');
''';
const _french = '''
INSERT INTO glosses VALUES (1, 1, 'fr', 0, 'gare', 1, 1);
INSERT INTO glosses VALUES (3, 3, 'fr', 0, 'kana', 3, 0);
INSERT INTO sense_notes VALUES (1, 'fr', 'French note');
INSERT INTO kana_explanations VALUES ('は', 'fr', 'French origin');
INSERT INTO kana_usage_translations VALUES (1, 'fr', 'French role', 'French usage');
INSERT INTO kana_usage_example_translations VALUES (1, 'fr', 'French example');
''';
