import 'dart:convert';

import '../../core/japanese_text.dart';
import '../../models/kana.dart';
import '../../models/kanji.dart';
import '../../models/word.dart';
import '../../services/dictionary_data_source.dart';
import '../packs/pack_manager.dart';

class LocalDictionaryDataSource implements DictionaryDataSource {
  LocalDictionaryDataSource(this._packs);

  final PackManager _packs;

  Future<void> _ready() => _packs.ensureReady();

  String _localeSchema(String language) {
    if (!_packs.hasCore) return 'main';
    final wanted = 'loc_${language.replaceAll('-', '_')}';
    if (_packs.localeSchemas.contains(wanted)) return wanted;
    return _packs.localeSchemas.contains('loc_en') ? 'loc_en' : wanted;
  }

  @override
  Future<SearchResults> search(
    String q, {
    String lang = 'en',
    int limit = 25,
  }) async {
    await _ready();
    final query = q.trim();
    if (query.isEmpty) return SearchResults.empty();
    final converted = isJapanese(query) ? null : romajiToHiragana(query);
    final ids = converted != null || isJapanese(query)
        ? await _surfaceIds(converted ?? query, limit)
        : await _glossIds(query, lang, limit);
    final words = <WordEntry>[];
    for (final id in ids) {
      words.add(await _word(id, details: false, language: lang));
    }
    return SearchResults(words: words, names: await _names(query, lang));
  }

  Future<List<int>> _surfaceIds(String query, int limit) async {
    final ids = <int>[];
    final seen = <int>{};
    for (final pattern in [query, '$query%', '%$query%']) {
      final rows = await _packs.db.select(
        'SELECT word_id FROM word_forms WHERE text LIKE ? '
        'ORDER BY is_common DESC, ord LIMIT ?',
        [pattern, limit * 4],
      );
      for (final row in rows) {
        final id = row['word_id'] as int;
        if (seen.add(id)) ids.add(id);
        if (ids.length == limit) return ids;
      }
    }
    return ids;
  }

  Future<List<int>> _glossIds(String query, String language, int limit) async {
    final ids = <int>[];
    final seen = <int>{};
    final schema = _localeSchema(language);
    final languages = language == 'en' ? ['en'] : [language, 'en'];
    for (final pattern in [query, '$query%', '%$query%']) {
      final rows = await _packs.db.select(
        'SELECT word_id FROM $schema.glosses '
        'WHERE language IN (${List.filled(languages.length, '?').join(',')}) '
        'AND text LIKE ? COLLATE NOCASE ORDER BY word_rank, word_common DESC LIMIT ?',
        [...languages, pattern, limit * 6],
      );
      for (final row in rows) {
        final id = row['word_id'] as int;
        if (seen.add(id)) ids.add(id);
        if (ids.length == limit) return ids;
      }
    }
    return ids;
  }

  Future<List<NameItem>> _names(String query, String language) async {
    if (!_packs.installed.any((pack) => pack.id == 'names')) return const [];
    final rows = await _packs.db.select(
      'SELECT id, kanji, reading, name_types FROM nm.names '
      'WHERE kanji LIKE ? OR reading LIKE ? LIMIT 12',
      ['%$query%', '%$query%'],
    );
    final result = <NameItem>[];
    for (final row in rows) {
      final translations = await _packs.db.select(
        'SELECT text FROM nm.name_translations WHERE name_id = ? '
        'AND language IN (?, ?) ORDER BY language = ? DESC, ord',
        [row['id'], language, 'en', language],
      );
      result.add(
        NameItem(
          kanji: row['kanji'] as String? ?? '',
          reading: row['reading'] as String? ?? '',
          translations: [
            for (final value in translations) value['text'] as String,
          ],
          types: _strings(row['name_types']),
        ),
      );
    }
    return result;
  }

  @override
  Future<WordEntry> word(int id) async {
    await _ready();
    return _word(id, details: true);
  }

  Future<WordEntry> _word(
    int id, {
    required bool details,
    String language = 'en',
  }) async {
    final rows = await _packs.db.select('SELECT * FROM words WHERE id = ?', [
      id,
    ]);
    if (rows.isEmpty) throw StateError('Unknown word $id');
    final row = rows.single;
    final forms = await _packs.db.select(
      'SELECT text, kind, is_common, pitch FROM word_forms WHERE word_id = ? ORDER BY kind, ord',
      [id],
    );
    final senses = <Sense>[];
    final senseRows = await _packs.db.select(
      'SELECT id, pos FROM senses WHERE word_id = ? ORDER BY ord',
      [id],
    );
    final schemas = _packs.glossSchemas;
    for (final sense in senseRows) {
      final glosses = <GlossItem>[];
      for (final schema in schemas) {
        final values = await _packs.db.select(
          'SELECT language, text FROM $schema.glosses WHERE sense_id = ? ORDER BY ord',
          [sense['id']],
        );
        glosses.addAll(
          values.map(
            (value) => GlossItem(
              language: value['language'] as String,
              text: value['text'] as String,
            ),
          ),
        );
      }
      senses.add(Sense(pos: _strings(sense['pos']), glosses: glosses));
    }
    final breakdown = details
        ? [
            for (final literal in kanjiIn(row['headword'] as String))
              await _kanji(literal, false),
          ]
        : const <KanjiEntry>[];
    final examples = <ExampleItem>[];
    if (details) {
      for (final pack in _packs.installed.where(
        (value) => value.id.startsWith('examples-'),
      )) {
        final schema = schemaForPack(pack.id)!;
        final values = await _packs.db.select(
          'SELECT e.japanese, t.text FROM $schema.examples e '
          'JOIN $schema.example_translations t ON t.example_id = e.id '
          'WHERE e.japanese LIKE ? LIMIT 6',
          ['%${row['headword']}%'],
        );
        examples.addAll(
          values.map(
            (value) => ExampleItem(
              japanese: value['japanese'] as String,
              translation: value['text'] as String,
            ),
          ),
        );
      }
    }
    return WordEntry(
      id: id,
      isCommon: (row['is_common'] as int? ?? 0) != 0,
      jlpt: row['jlpt'] as int?,
      headword: row['headword'] as String,
      primaryReading: row['primary_reading'] as String,
      kanji: [
        for (final form in forms.where((value) => value['kind'] == 0))
          _form(form),
      ],
      readings: [
        for (final form in forms.where((value) => value['kind'] == 1))
          _form(form),
      ],
      senses: senses,
      kanjiBreakdown: breakdown,
      examples: examples,
    );
  }

  WordFormItem _form(Map<String, Object?> row) => WordFormItem(
    text: row['text'] as String,
    isCommon: (row['is_common'] as int? ?? 0) != 0,
    pitch: row['pitch'] as String? ?? '',
  );

  @override
  Future<KanjiEntry> kanji(String literal) async {
    await _ready();
    return _kanji(literal, true);
  }

  Future<KanjiEntry> _kanji(String literal, bool details) async {
    final rows = await _packs.db.select(
      'SELECT * FROM kanji WHERE literal = ?',
      [literal],
    );
    if (rows.isEmpty) throw StateError('Unknown kanji $literal');
    final row = rows.single;
    final meanings = await _meanings('kanji_meanings', 'kanji', literal);
    final components = _strings(row['components']);
    final componentDetails = <KanjiComponent>[];
    if (details) {
      for (final component in components) {
        final kanjiRows = await _packs.db.select(
          'SELECT literal FROM kanji WHERE literal = ?',
          [component],
        );
        final values = kanjiRows.isNotEmpty
            ? await _meanings('kanji_meanings', 'kanji', component)
            : await _meanings('radical_meanings', 'radical', component);
        final radical = kanjiRows.isEmpty
            ? await _packs.db.select(
                'SELECT reading FROM radicals WHERE literal = ?',
                [component],
              )
            : const <Map<String, Object?>>[];
        componentDetails.add(
          KanjiComponent(
            literal: component,
            meaning: values.isEmpty ? '' : values.first['text']!,
            reading: radical.isEmpty
                ? ''
                : radical.first['reading'] as String? ?? '',
            isKanji: kanjiRows.isNotEmpty,
          ),
        );
      }
    }
    final sampleWords = <dynamic>[];
    if (details) {
      final links = await _packs.db.select(
        'SELECT word_id FROM kanji_words WHERE kanji = ? ORDER BY rank LIMIT 12',
        [literal],
      );
      for (final link in links) {
        sampleWords.add(
          _wordMap(await _word(link['word_id'] as int, details: false)),
        );
      }
    }
    var origin = '';
    for (final schema in _packs.glossSchemas) {
      final values = await _packs.db.select(
        'SELECT origin FROM $schema.kanji_explanations WHERE kanji = ? '
        'ORDER BY language = ? DESC LIMIT 1',
        [literal, 'en'],
      );
      if (values.isNotEmpty) origin = values.first['origin'] as String;
    }
    return KanjiEntry(
      literal: literal,
      grade: row['grade'] as int?,
      strokeCount: row['stroke_count'] as int? ?? 0,
      jlpt: row['jlpt'] as int?,
      freqRank: row['freq_rank'] as int?,
      onReadings: _strings(row['on_readings']),
      kunReadings: _strings(row['kun_readings']),
      nanori: _strings(row['nanori']),
      components: components,
      meanings: meanings,
      origin: origin,
      formation: row['formation'] as String? ?? '',
      phonetic: row['phonetic'] as String? ?? '',
      componentDetails: componentDetails,
      words: sampleWords,
      strokePaths: _strings(row['stroke_paths']),
      strokeViewbox: row['stroke_viewbox'] as String? ?? '0 0 109 109',
    );
  }

  Future<List<Map<String, String>>> _meanings(
    String table,
    String key,
    String value,
  ) async {
    final result = <Map<String, String>>[];
    for (final schema in _packs.glossSchemas) {
      final rows = await _packs.db.select(
        'SELECT language, text FROM $schema.$table WHERE $key = ?',
        [value],
      );
      result.addAll(
        rows.map(
          (row) => {
            'language': row['language'] as String,
            'text': row['text'] as String,
          },
        ),
      );
    }
    return result;
  }

  Map<String, dynamic> _wordMap(WordEntry word) => {
    'id': word.id,
    'headword': word.headword,
    'primary_reading': word.primaryReading,
    'is_common': word.isCommon,
  };

  @override
  Future<List<WordEntry>> words({
    bool common = false,
    int? jlpt,
    int limit = 60,
    int offset = 0,
  }) async {
    await _ready();
    final clauses = <String>[];
    final params = <Object?>[];
    if (common) clauses.add('is_common = 1');
    if (jlpt != null) {
      clauses.add('jlpt = ?');
      params.add(jlpt);
    }
    final rows = await _packs.db.select(
      'SELECT id FROM words ${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'} '
      'ORDER BY freq_rank IS NULL, freq_rank, id LIMIT ? OFFSET ?',
      [...params, limit, offset],
    );
    return [
      for (final row in rows) await _word(row['id'] as int, details: false),
    ];
  }

  @override
  Future<List<KanjiEntry>> kanjiList({
    int? jlpt,
    int? grade,
    String? contains,
    int limit = 120,
    int offset = 0,
  }) async {
    await _ready();
    final clauses = <String>[];
    final params = <Object?>[];
    if (jlpt != null) {
      clauses.add('jlpt = ?');
      params.add(jlpt);
    }
    if (grade != null) {
      clauses.add('grade = ?');
      params.add(grade);
    }
    if (contains != null) {
      clauses.add(
        'EXISTS (SELECT 1 FROM kanji_components kc '
        'WHERE kc.kanji = kanji.literal AND kc.component = ?)',
      );
      params.add(contains);
    }
    final rows = await _packs.db.select(
      'SELECT literal FROM kanji ${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'} '
      'ORDER BY freq_rank IS NULL, freq_rank, stroke_count LIMIT ? OFFSET ?',
      [...params, limit, offset],
    );
    return [
      for (final row in rows) await _kanji(row['literal'] as String, false),
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> radicals() async {
    await _ready();
    final rows = await _packs.db.select(
      'SELECT * FROM radicals ORDER BY strokes, literal',
    );
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final meanings = await _meanings(
        'radical_meanings',
        'radical',
        row['literal'] as String,
      );
      result.add({
        ...row,
        'meaning': meanings.isEmpty ? '' : meanings.first['text'],
        'meanings': meanings,
      });
    }
    return result;
  }

  @override
  Future<List<KanaEntry>> kana({String? script}) async {
    await _ready();
    final rows = await _packs.db.select(
      'SELECT char FROM kana ${script == null ? '' : 'WHERE script = ?'} ORDER BY script, ord',
      [if (script != null) script],
    );
    return [for (final row in rows) await kanaDetail(row['char'] as String)];
  }

  @override
  Future<KanaEntry> kanaDetail(String char) async {
    await _ready();
    final rows = await _packs.db.select('SELECT * FROM kana WHERE char = ?', [
      char,
    ]);
    if (rows.isEmpty) throw StateError('Unknown kana $char');
    final row = rows.single;
    var originNote = '';
    var usageLabel = '';
    var usage = '';
    final examples = <KanaUsageExample>[];
    for (final schema in _packs.glossSchemas) {
      final explanation = await _packs.db.select(
        'SELECT origin_note FROM $schema.kana_explanations WHERE kana = ? LIMIT 1',
        [char],
      );
      if (explanation.isNotEmpty) {
        originNote = explanation.first['origin_note'] as String;
      }
      final role = await _packs.db.select(
        'SELECT u.id, t.label, t.explanation FROM kana_usages u '
        'JOIN $schema.kana_usage_translations t ON t.usage_id = u.id WHERE u.kana = ? LIMIT 1',
        [char],
      );
      if (role.isEmpty) continue;
      usageLabel = role.first['label'] as String;
      usage = role.first['explanation'] as String;
      final values = await _packs.db.select(
        'SELECT e.before_text, e.particle, e.after_text, e.pronunciation, t.text '
        'FROM kana_usage_examples e JOIN $schema.kana_usage_example_translations t '
        'ON t.example_id = e.id WHERE e.usage_id = ? ORDER BY e.ord',
        [role.first['id']],
      );
      examples.addAll(
        values.map(
          (value) => KanaUsageExample(
            before: value['before_text'] as String,
            particle: value['particle'] as String,
            after: value['after_text'] as String,
            pronunciation: value['pronunciation'] as String,
            translation: value['text'] as String,
          ),
        ),
      );
    }
    return KanaEntry(
      char: char,
      romaji: row['romaji'] as String,
      script: row['script'] as String,
      kind: row['kind'] as String,
      row: row['row'] as String? ?? '',
      order: row['ord'] as int? ?? 0,
      origin: row['origin'] as String? ?? '',
      originNote: originNote,
      usageLabel: usageLabel,
      usage: usage,
      usageExamples: examples,
    );
  }

  List<String> _strings(Object? value) {
    if (value == null) return const [];
    final decoded = value is String ? jsonDecode(value) : value;
    return [for (final item in decoded as List) '$item'];
  }
}
