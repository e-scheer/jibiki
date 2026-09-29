import 'dart:convert';

import '../../core/japanese_text.dart';
import '../../models/kana.dart';
import '../../models/kanji.dart';
import '../../models/word.dart';
import '../../services/dictionary_data_source.dart';
import '../packs/pack_manager.dart';

class LocalDictionaryDataSource implements DictionaryDataSource {
  LocalDictionaryDataSource(this._packs,
      {String Function()? language, String Function()? glossLanguage})
      : _language = language ?? _english,
        _glossLanguage = glossLanguage ?? language ?? _english;

  final PackManager _packs;
  final String Function() _language;
  final String Function() _glossLanguage;
  int _schemaRevision = -1;
  bool _hasCanonicalWords = false;
  bool _hasWordProvenance = false;
  bool _hasKanjiMetadata = false;
  static String _english() => 'en';

  Future<void> _ready() async {
    await _packs.ensureReady();
    if (!_packs.ready) {
      throw StateError('Dictionary packs unavailable: ${_packs.lastError}');
    }
    if (_schemaRevision != _packs.revision) {
      final columns = await _packs.db.select('PRAGMA main.table_info(words)');
      _hasCanonicalWords =
          columns.any((column) => column['name'] == 'canonical_word_id');
      _hasWordProvenance =
          columns.any((column) => column['name'] == 'provenance');
      final kanjiColumns =
          await _packs.db.select('PRAGMA main.table_info(kanji)');
      _hasKanjiMetadata =
          kanjiColumns.any((column) => column['name'] == 'metadata');
      _schemaRevision = _packs.revision;
    }
  }

  static String _like(String query) => query
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  String _currentSource(String prefix) => _hasWordProvenance
      ? 'COALESCE(json_extract(${prefix}provenance, '
          r"'$.source_status'), '') NOT IN ('upstream_not_in_snapshot', 'legacy_merged_entry')"
      : '1 = 1';

  @override
  Future<SearchResults> search(
    String q, {
    String lang = 'en',
    int limit = 25,
  }) async {
    await _ready();
    final query = q.trim();
    if (query.isEmpty || limit <= 0) return SearchResults.empty();
    limit = limit.clamp(1, 100);
    final converted = isJapanese(query) ? null : romajiToHiragana(query);
    final surface = converted != null || isJapanese(query)
        ? await _surfaceIds(converted ?? query, limit)
        : const <int>[];
    // Latin words can also be valid romaji (e.g. French "gare" or "ou").
    // Interleave both ranked lists so a full surface page cannot hide meanings.
    final gloss = !isJapanese(query)
        ? await _glossIds(query, lang, limit)
        : const <int>[];
    final merged = <int>{};
    for (var i = 0; i < limit; i++) {
      if (i < surface.length) merged.add(surface[i]);
      if (i < gloss.length) merged.add(gloss[i]);
    }
    final ids = merged.take(limit);
    final words = <WordEntry>[];
    for (final id in ids) {
      words.add(await _word(id, details: false, language: lang));
    }
    return SearchResults(words: words, names: await _names(query, lang));
  }

  Future<List<int>> _surfaceIds(String query, int limit) async {
    final ids = <int>[];
    final seen = <int>{};
    final escaped = _like(query);
    for (final pattern in [escaped, '$escaped%', '%$escaped%']) {
      final rows = await _packs.db.select(
        "SELECT DISTINCT f.word_id FROM word_forms f JOIN words w ON w.id = f.word_id WHERE f.text LIKE ? ESCAPE '\\' "
        '${_hasCanonicalWords ? 'AND w.canonical_word_id IS NULL ' : ''}'
        'AND ${_currentSource('w.')} '
        'ORDER BY f.is_common DESC, f.ord, f.word_id LIMIT ?',
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
    final languages = language == 'en' ? ['en'] : [language, 'en'];
    final escaped = _like(query);
    // JMdict English verbs conventionally begin with "to". An exact
    // infinitive is more useful than a loose prefix or substring match.
    for (final (pattern, selectedLanguages) in [
      (escaped, languages),
      ('to $escaped', ['en']),
      ('$escaped%', languages),
      ('%$escaped%', languages),
    ]) {
      final candidates = <Map<String, Object?>>[];
      for (final schema in _packs.glossSchemas) {
        final rows = await _packs.db.select(
          'SELECT DISTINCT word_id, word_rank, word_common FROM $schema.glosses '
          'WHERE language IN (${List.filled(selectedLanguages.length, '?').join(',')}) '
          "AND text LIKE ? ESCAPE '\\' COLLATE NOCASE "
          'AND EXISTS (SELECT 1 FROM main.words w WHERE w.id = word_id '
          '${_hasCanonicalWords ? 'AND w.canonical_word_id IS NULL ' : ''}'
          'AND ${_currentSource('w.')}) '
          'ORDER BY word_rank, word_common DESC, word_id LIMIT ?',
          [...selectedLanguages, pattern, limit * 6],
        );
        candidates.addAll(rows);
      }
      candidates.sort((a, b) {
        final rank = (a['word_rank'] as int).compareTo(b['word_rank'] as int);
        if (rank != 0) return rank;
        final common =
            (b['word_common'] as int).compareTo(a['word_common'] as int);
        return common != 0
            ? common
            : (a['word_id'] as int).compareTo(b['word_id'] as int);
      });
      for (final row in candidates) {
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
      'SELECT * FROM nm.names '
      "WHERE kanji LIKE ? ESCAPE '\\' OR reading LIKE ? ESCAPE '\\' "
      'ORDER BY id LIMIT 12',
      ['%${_like(query)}%', '%${_like(query)}%'],
    );
    final result = <NameItem>[];
    for (final row in rows) {
      final translations = await _packs.db.select(
        'SELECT language, text FROM nm.name_translations WHERE name_id = ? ORDER BY language, ord',
        [row['id']],
      );
      result.add(
        NameItem(
          kanji: row['kanji'] as String? ?? '',
          reading: row['reading'] as String? ?? '',
          translations: [
            for (final value in _localized(translations, language))
              value['text'] as String,
          ],
          translationItems: [
            for (final value in translations)
              GlossItem(
                  language: value['language'] as String,
                  text: value['text'] as String)
          ],
          translationLanguage: _localized(translations, language)
                  .firstOrNull?['language'] as String? ??
              '',
          types: _strings(row['name_types']),
          metadata: _object(row['metadata']),
          provenance: _object(row['provenance']),
        ),
      );
    }
    return result;
  }

  @override
  Future<WordEntry> word(int id) async {
    await _ready();
    return _word(id, details: true, language: _glossLanguage());
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
    var row = rows.single;
    var contentId = id;
    final visited = <int>{id};
    while (row['canonical_word_id'] != null) {
      contentId = row['canonical_word_id'] as int;
      if (!visited.add(contentId)) throw StateError('Circular word alias $id');
      final targets = await _packs.db
          .select('SELECT * FROM words WHERE id = ?', [contentId]);
      if (targets.isEmpty) {
        throw StateError('Unknown canonical word $contentId');
      }
      row = targets.single;
    }
    final forms = await _packs.db.select(
      'SELECT * FROM word_forms WHERE word_id = ? ORDER BY kind, ord',
      [contentId],
    );
    final senses = <Sense>[];
    final senseRows = await _packs.db.select(
      'SELECT * FROM senses WHERE word_id = ? ORDER BY ord',
      [contentId],
    );
    final schemas = _packs.glossSchemas;
    for (final sense in senseRows) {
      final glosses = <GlossItem>[];
      final notes = <GlossItem>[];
      final seenGlosses = <(String, String)>{};
      final seenNotes = <(String, String)>{};
      for (final schema in schemas) {
        final values = await _packs.db.select(
          'SELECT * FROM $schema.glosses WHERE sense_id = ? AND word_id = ? ORDER BY ord',
          [sense['id'], contentId],
        );
        glosses.addAll(
          values
              .where((v) => seenGlosses
                  .add((v['language'] as String, v['text'] as String)))
              .map(
                (value) => GlossItem(
                  language: value['language'] as String,
                  text: value['text'] as String,
                  metadata: _object(value['metadata']),
                ),
              ),
        );
        final noteRows = await _packs.db.select(
            'SELECT language, text FROM $schema.sense_notes WHERE sense_id = ?',
            [sense['id']]);
        notes.addAll(noteRows
            .where((v) =>
                seenNotes.add((v['language'] as String, v['text'] as String)))
            .map((v) => GlossItem(
                language: v['language'] as String, text: v['text'] as String)));
      }
      senses.add(Sense(
          order: sense['ord'] as int,
          pos: _strings(sense['pos']),
          misc: _strings(sense['misc']),
          field: _strings(sense['field']),
          metadata: _object(sense['metadata']),
          notes: notes,
          glosses: glosses));
    }
    final breakdown = details
        ? await _breakdown(row['headword'] as String)
        : const <KanjiEntry>[];
    final examples = <ExampleItem>[];
    if (details) {
      final translationsBySentence =
          <String, Map<(String, String), GlossItem>>{};
      final sentenceRows = <String, Map<String, Object?>>{};
      for (final schema in _packs.exampleSchemas) {
        // Older schema-2 packs remain readable, but have no reliable word links.
        // Never infer that a substring is an example of this word or sense.
        final linkTable = await _packs.db.select(
            "SELECT name FROM $schema.sqlite_master WHERE type = 'table' AND name = 'example_sense_links'");
        if (linkTable.isEmpty) continue;
        final values = await _packs.db.select(
          'SELECT e.*, t.language, t.text FROM $schema.examples e '
          'JOIN $schema.example_translations t ON t.example_id = e.id '
          'WHERE EXISTS (SELECT 1 FROM $schema.example_sense_links l '
          'WHERE l.example_id = e.id AND l.word_id = ?) AND t.language IN (?, ?) '
          'ORDER BY e.id, t.language LIMIT 12',
          [contentId, language, 'en'],
        );
        for (final value in values) {
          final item = GlossItem(
              language: value['language'] as String,
              text: value['text'] as String);
          final key = value['source_key'] as String? ?? 'id:${value['id']}';
          sentenceRows[key] = value;
          translationsBySentence.putIfAbsent(
              key, () => {})[(item.language, item.text)] = item;
        }
      }
      for (final entry in translationsBySentence.entries.take(6)) {
        final values = entry.value.values.toList();
        final selected =
            values.where((v) => v.language == language).firstOrNull ??
                values.where((v) => v.language == 'en').firstOrNull;
        if (selected == null) continue;
        examples.add(ExampleItem(
            japanese: sentenceRows[entry.key]!['japanese'] as String,
            translation: selected.text,
            language: selected.language,
            translations: values,
            provenance: _object(sentenceRows[entry.key]!['provenance'])));
      }
    }
    return WordEntry(
      id: id,
      canonicalId: contentId == id ? null : contentId,
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
      provenance: _object(row['provenance']),
    );
  }

  WordFormItem _form(Map<String, Object?> row) => WordFormItem(
        text: row['text'] as String,
        isCommon: (row['is_common'] as int? ?? 0) != 0,
        pitch: row['pitch'] as String? ?? '',
        metadata: _object(row['metadata']),
      );

  Future<List<KanjiEntry>> _breakdown(String headword) async {
    final literals = kanjiIn(headword);
    if (literals.isEmpty) return const [];
    final rows = await _packs.db.select(
        'SELECT literal FROM kanji WHERE literal IN (${List.filled(literals.length, '?').join(',')})',
        literals);
    final available = {for (final row in rows) row['literal']};
    return [
      for (final literal in literals)
        if (available.contains(literal)) await _kanji(literal, false)
    ];
  }

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
            meaning: _localized(values, _language()).firstOrNull?['text']
                    as String? ??
                '',
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
    final origins = <Map<String, Object?>>[];
    for (final schema in _packs.glossSchemas) {
      final values = await _packs.db.select(
        'SELECT language, origin FROM $schema.kanji_explanations WHERE kanji = ?',
        [literal],
      );
      origins.addAll(values);
    }
    final explanation = _localized(origins, _language()).firstOrNull;
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
      origin: explanation?['origin'] as String? ?? '',
      originLanguage: explanation?['language'] as String? ?? '',
      formation: row['formation'] as String? ?? '',
      phonetic: row['phonetic'] as String? ?? '',
      componentDetails: componentDetails,
      words: sampleWords,
      strokePaths: _strings(row['stroke_paths']),
      strokeViewbox: row['stroke_viewbox'] as String? ?? '0 0 109 109',
      metadata: _object(row['metadata']),
      provenance: _object(row['provenance']),
    );
  }

  Future<List<Map<String, String>>> _meanings(
    String table,
    String key,
    String value,
  ) async {
    final result = <Map<String, String>>[];
    final seen = <(String, String)>{};
    for (final schema in _packs.glossSchemas) {
      final rows = await _packs.db.select(
        'SELECT language, text FROM $schema.$table WHERE $key = ?',
        [value],
      );
      result.addAll(
        rows
            .where(
                (r) => seen.add((r['language'] as String, r['text'] as String)))
            .map(
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
        'canonical_id': word.canonicalId,
        'headword': word.headword,
        'primary_reading': word.primaryReading,
        'is_common': word.isCommon,
        'jlpt': word.jlpt,
        'senses': [
          for (final sense in word.senses)
            {
              'order': sense.order,
              'pos': sense.pos,
              'misc': sense.misc,
              'field': sense.field,
              'notes': [
                for (final note in sense.notes)
                  {'language': note.language, 'text': note.text}
              ],
              'glosses': [
                for (final gloss in sense.glosses)
                  {'language': gloss.language, 'text': gloss.text}
              ],
            }
        ],
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
    if (_hasCanonicalWords) clauses.add('canonical_word_id IS NULL');
    clauses.add(_currentSource(''));
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
        '(EXISTS (SELECT 1 FROM kanji_components kc '
        'WHERE kc.kanji = kanji.literal AND kc.component = ?)'
        '${_hasKanjiMetadata ? r" OR json_extract(kanji.metadata, '$.kanjialive.radical.literal') = ?" : ''})',
      );
      params.add(contains);
      if (_hasKanjiMetadata) params.add(contains);
    }
    final rows = await _packs.db.select(
      'SELECT literal FROM kanji ${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'} '
      'ORDER BY freq_rank IS NULL, freq_rank, stroke_count, literal LIMIT ? OFFSET ?',
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
        'provenance': _object(row['provenance']),
        'meaning': _localized(meanings, _language()).firstOrNull?['text'] ?? '',
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
    final explanations = <Map<String, Object?>>[];
    final roles = <Map<String, Object?>>[];
    final examples = <KanaUsageExample>[];
    for (final schema in _packs.glossSchemas) {
      final explanation = await _packs.db.select(
        'SELECT language, origin_note FROM $schema.kana_explanations WHERE kana = ?',
        [char],
      );
      explanations.addAll(explanation);
      final role = await _packs.db.select(
        'SELECT u.id, t.language, t.label, t.explanation FROM kana_usages u '
        'JOIN $schema.kana_usage_translations t ON t.usage_id = u.id WHERE u.kana = ?',
        [char],
      );
      roles.addAll(role);
    }
    final explanation = _localized(explanations, _language()).firstOrNull;
    final role = _localized(roles, _language()).firstOrNull;
    final seenExamples = <(String, String, String, String)>{};
    if (role != null) {
      for (final schema in _packs.glossSchemas) {
        final values = await _packs.db.select(
          'SELECT e.before_text, e.particle, e.after_text, e.pronunciation, t.language, t.text '
          'FROM kana_usage_examples e JOIN $schema.kana_usage_example_translations t '
          'ON t.example_id = e.id WHERE e.usage_id = ? AND t.language = ? ORDER BY e.ord',
          [role['id'], role['language']],
        );
        examples.addAll(
          values
              .where((v) => seenExamples.add((
                    v['before_text'] as String,
                    v['particle'] as String,
                    v['after_text'] as String,
                    v['text'] as String
                  )))
              .map(
                (value) => KanaUsageExample(
                  before: value['before_text'] as String,
                  particle: value['particle'] as String,
                  after: value['after_text'] as String,
                  pronunciation: value['pronunciation'] as String,
                  translation: value['text'] as String,
                  language: value['language'] as String,
                ),
              ),
        );
      }
    }
    final wordExamples = <KanaWordExample>[];
    final lexicalTable = await _packs.db.select(
        "SELECT name FROM main.sqlite_master WHERE type = 'table' AND name = 'kana_word_examples'");
    if (lexicalTable.isNotEmpty) {
      final links = await _packs.db.select(
          'SELECT * FROM kana_word_examples WHERE kana = ? ORDER BY ord, word_id',
          [char]);
      for (final link in links) {
        final word = await _word(link['word_id'] as int, details: false);
        wordExamples.add(KanaWordExample(
          wordId: word.id,
          headword: word.headword,
          reading: link['reading'] as String,
          glosses: [
            for (final sense in word.sensesFor(_language()))
              for (final gloss in sense.glosses)
                if (gloss.language == word.glossLanguageFor(_language())) gloss
          ],
          provenance: _object(link['provenance']),
        ));
      }
    }
    return KanaEntry(
      char: char,
      romaji: row['romaji'] as String,
      script: row['script'] as String,
      kind: row['kind'] as String,
      row: row['row'] as String? ?? '',
      order: row['ord'] as int? ?? 0,
      origin: row['origin'] as String? ?? '',
      originNote: explanation?['origin_note'] as String? ?? '',
      originLanguage: explanation?['language'] as String? ?? '',
      usageLabel: role?['label'] as String? ?? '',
      usage: role?['explanation'] as String? ?? '',
      usageLanguage: role?['language'] as String? ?? '',
      usageExamples: examples,
      wordExamples: wordExamples,
    );
  }

  List<String> _strings(Object? value) {
    if (value == null) return const [];
    final decoded = value is String ? jsonDecode(value) : value;
    return [for (final item in decoded as List) '$item'];
  }

  Map<String, dynamic> _object(Object? value) {
    if (value == null) return const {};
    final decoded = value is String ? jsonDecode(value) : value;
    return (decoded as Map).cast<String, dynamic>();
  }

  List<Map<String, Object?>> _localized(
      List<Map<String, Object?>> rows, String language) {
    final exact = rows.where((r) => r['language'] == language).toList();
    if (exact.isNotEmpty) return exact;
    return rows.where((r) => r['language'] == 'en').toList();
  }
}
