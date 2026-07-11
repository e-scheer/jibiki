/// The offline dictionary: every DictionaryService read, answered from the
/// installed content packs. Emits maps in the exact shape of the server
/// serializers (dictionary/serializers.py) and reuses the existing fromJson
/// factories, so models, viewmodels and views cannot tell the difference.
///
/// Search parity with server/dictionary/search.py: Japanese input matches
/// surface forms exact → prefix → substring ordered by (is_common, ord);
/// Latin input matches glosses (user language + English fallback) exact →
/// prefix → FTS-contains ordered by word frequency; tiers are deduped keeping
/// the first hit. On top, a romaji query that fully transliterates to kana
/// also runs the Japanese branch and lands above the gloss matches.
library;

import 'dart:convert';

import '../../core/db/dict_db.dart';
import '../../core/japanese_text.dart';
import '../../models/kana.dart';
import '../../models/kanji.dart';
import '../../models/word.dart';
import '../../services/dictionary_data_source.dart';
import '../packs/pack_manager.dart';

class LocalDictionaryDataSource implements DictionaryDataSource {
  LocalDictionaryDataSource(this._packs);

  final PackManager _packs;

  Future<DictDb> get _db => _packs.whenReady();

  /// Schemas holding a `glosses`/`kanji_meanings` pair, in priority order.
  List<String> get _gloss => _packs.glossSchemas;

  static String _like(String q) =>
      q.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

  // ── search ──────────────────────────────────────────────────────────────────

  @override
  Future<SearchResults> search(String q, {String lang = 'en', int limit = 25}) async {
    final query = q.trim();
    if (query.isEmpty) return SearchResults.empty();
    final db = await _db;

    List<int> ids;
    if (isJapanese(query)) {
      ids = await _japaneseWordIds(db, query, limit);
    } else {
      final kana = romajiToHiragana(query);
      ids = [
        // Romaji that reads as Japanese ranks like Japanese (jisho behavior),
        // ahead of any gloss whose text happens to contain the letters.
        if (kana != null) ...await _japaneseWordIds(db, kana, limit),
        ...await _glossWordIds(db, query, lang, limit),
      ];
      ids = _dedupe(ids, limit);
    }

    final words = await wordsByIds(db, ids);
    final names = await _names(db, query);
    return SearchResults(words: words, names: names);
  }

  Future<List<int>> _japaneseWordIds(DictDb db, String q, int limit) async {
    final ordered = <int>[];
    final tiers = [
      ('text = ?', q),
      ("text LIKE ? ESCAPE '\\'", '${_like(q)}%'),
      ("text LIKE ? ESCAPE '\\'", '%${_like(q)}%'),
    ];
    for (final (where, param) in tiers) {
      final rows = await db.select(
        'SELECT word_id FROM word_forms WHERE $where '
        'ORDER BY is_common DESC, ord LIMIT ?',
        [param, limit * 4],
      );
      ordered.addAll([for (final r in rows) r['word_id'] as int]);
    }
    return _dedupe(ordered, limit);
  }

  Future<List<int>> _glossWordIds(DictDb db, String q, String lang, int limit) async {
    final langs = lang == 'en' ? ['en'] : [lang, 'en'];
    final inLangs = 'lang IN (${List.filled(langs.length, '?').join(',')})';
    final ordered = <int>[];
    for (var tier = 0; tier < 3; tier++) {
      for (final schema in _gloss) {
        final rows = switch (tier) {
          0 => await db.select(
              'SELECT word_id FROM $schema.glosses '
              'WHERE text = ? COLLATE NOCASE AND $inLangs '
              'ORDER BY word_rank LIMIT ?',
              [q, ...langs, limit * 6],
            ),
          1 => await db.select(
              "SELECT word_id FROM $schema.glosses "
              "WHERE text LIKE ? ESCAPE '\\' AND $inLangs "
              'ORDER BY word_rank LIMIT ?',
              ['${_like(q)}%', ...langs, limit * 6],
            ),
          // Contains: FTS5 token-prefix over the gloss text. Better than a
          // %LIKE% ("eat" hits "to eat", not "theater") and index-backed.
          _ => await db.select(
              'SELECT word_id FROM $schema.glosses '
              'WHERE id IN (SELECT rowid FROM $schema.gloss_fts WHERE gloss_fts MATCH ?) '
              'AND $inLangs ORDER BY word_rank LIMIT ?',
              ['"${q.replaceAll('"', '""')}"*', ...langs, limit * 6],
            ),
        };
        ordered.addAll([for (final r in rows) r['word_id'] as int]);
      }
    }
    return _dedupe(ordered, limit);
  }

  static List<int> _dedupe(List<int> ids, int limit) {
    final seen = <int>{};
    final out = <int>[];
    for (final id in ids) {
      if (seen.add(id)) {
        out.add(id);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  /// Proper names, when the JMnedict pack is installed. Exact then prefix -
  /// offline drops the server's full substring scan over 740k rows.
  Future<List<NameItem>> _names(DictDb db, String q) async {
    if (!_packs.hasNames) return const [];
    final rows = await db.select(
      'SELECT kanji, reading, translations, name_types FROM ('
      'SELECT *, 0 AS tier FROM nm.names WHERE kanji = ? OR reading = ? '
      'UNION ALL '
      "SELECT *, 1 AS tier FROM nm.names WHERE (kanji LIKE ? ESCAPE '\\' OR reading LIKE ? ESCAPE '\\') "
      'AND kanji != ? AND reading != ?'
      ') ORDER BY tier LIMIT 12',
      [q, q, '${_like(q)}%', '${_like(q)}%', q, q],
    );
    return [
      for (final r in rows)
        NameItem.fromJson({
          'kanji': r['kanji'],
          'reading': r['reading'],
          'translations': jsonDecode(r['translations'] as String? ?? '[]'),
          'name_types': jsonDecode(r['name_types'] as String? ?? '[]'),
        }),
    ];
  }

  // ── word hydration (shared by search, browse, detail, kanji words) ──────────

  /// Batch-assemble WordSerializer-shaped entries, preserving [ids] order.
  /// Public: the study card assembler reuses it to join local cards to their
  /// dictionary items.
  Future<List<WordEntry>> wordsByIds(DictDb db, List<int> ids) async {
    final maps = await wordMapsByIds(db, ids);
    return [for (final m in maps) WordEntry.fromJson(m)];
  }

  Future<List<Map<String, dynamic>>> wordMapsByIds(DictDb db, List<int> ids) async {
    if (ids.isEmpty) return const [];
    final marks = List.filled(ids.length, '?').join(',');
    final words = await db.select('SELECT * FROM words WHERE id IN ($marks)', ids);
    final forms = await db.select(
        'SELECT * FROM word_forms WHERE word_id IN ($marks) ORDER BY ord', ids);
    final senses = await db.select(
        'SELECT * FROM senses WHERE word_id IN ($marks) ORDER BY word_id, ord', ids);
    final senseIds = [for (final s in senses) s['id'] as int];
    final glosses = <Map<String, Object?>>[];
    if (senseIds.isNotEmpty) {
      final senseMarks = List.filled(senseIds.length, '?').join(',');
      for (final schema in _gloss) {
        glosses.addAll(await db.select(
          'SELECT sense_id, lang, text, ord FROM $schema.glosses '
          'WHERE sense_id IN ($senseMarks) ORDER BY ord',
          senseIds,
        ));
      }
    }

    final glossesBySense = <int, List<Map<String, Object?>>>{};
    for (final g in glosses) {
      glossesBySense.putIfAbsent(g['sense_id'] as int, () => []).add(g);
    }
    final formsByWord = <int, List<Map<String, Object?>>>{};
    for (final f in forms) {
      formsByWord.putIfAbsent(f['word_id'] as int, () => []).add(f);
    }
    final sensesByWord = <int, List<Map<String, Object?>>>{};
    for (final s in senses) {
      sensesByWord.putIfAbsent(s['word_id'] as int, () => []).add(s);
    }

    final byId = {
      for (final w in words)
        w['id'] as int: _wordMap(w, formsByWord, sensesByWord, glossesBySense),
    };
    return [for (final id in ids) byId[id]].whereType<Map<String, dynamic>>().toList();
  }

  Map<String, dynamic> _wordMap(
    Map<String, Object?> w,
    Map<int, List<Map<String, Object?>>> formsByWord,
    Map<int, List<Map<String, Object?>>> sensesByWord,
    Map<int, List<Map<String, Object?>>> glossesBySense,
  ) {
    final id = w['id'] as int;
    List<Map<String, dynamic>> forms(int kind) => [
          for (final f in formsByWord[id] ?? const <Map<String, Object?>>[])
            if (f['kind'] == kind)
              {
                'text': f['text'],
                'is_common': f['is_common'] == 1,
                'pitch': f['pitch'],
              },
        ];
    return {
      'id': id,
      'seq': w['seq'],
      'is_common': w['is_common'] == 1,
      'jlpt': w['jlpt'],
      'freq_rank': w['freq_rank'],
      'headword': w['headword'],
      'primary_reading': w['primary_reading'],
      'kanji': forms(0),
      'readings': forms(1),
      'senses': [
        for (final s in sensesByWord[id] ?? const <Map<String, Object?>>[])
          {
            'order': s['ord'],
            'pos': jsonDecode(s['pos'] as String? ?? '[]'),
            'misc': jsonDecode(s['misc'] as String? ?? '[]'),
            'field': jsonDecode(s['field'] as String? ?? '[]'),
            'info': s['info'],
            'glosses': [
              for (final g in glossesBySense[s['id'] as int] ?? const <Map<String, Object?>>[])
                {'lang': g['lang'], 'text': g['text']},
            ],
          },
      ],
    };
  }

  // ── details ─────────────────────────────────────────────────────────────────

  @override
  Future<WordEntry> word(int id) async {
    final db = await _db;
    final maps = await wordMapsByIds(db, [id]);
    if (maps.isEmpty) throw StateError('word $id not in the installed packs');
    final map = maps.single;

    final chars = kanjiIn(map['headword'] as String);
    map['kanji_breakdown'] = await kanjiMapsByLiterals(db, chars);

    if (_packs.hasExamples) {
      final rows = await db.select(
        "SELECT japanese, english FROM ex.examples WHERE japanese LIKE ? ESCAPE '\\' LIMIT 6",
        ['%${_like(map['headword'] as String)}%'],
      );
      map['examples'] = [for (final r in rows) Map<String, dynamic>.from(r)];
    }
    return WordEntry.fromJson(map);
  }

  /// KanjiSerializer-shaped maps for [literals], in order (missing skipped).
  Future<List<Map<String, dynamic>>> kanjiMapsByLiterals(DictDb db, List<String> literals) async {
    if (literals.isEmpty) return const [];
    final marks = List.filled(literals.length, '?').join(',');
    final rows =
        await db.select('SELECT * FROM kanji WHERE literal IN ($marks)', literals);
    final meanings = <String, List<Map<String, Object?>>>{};
    for (final schema in _gloss) {
      final ms = await db.select(
        'SELECT kanji, lang, text FROM $schema.kanji_meanings '
        'WHERE kanji IN ($marks) ORDER BY ord',
        literals,
      );
      for (final m in ms) {
        meanings.putIfAbsent(m['kanji'] as String, () => []).add(m);
      }
    }
    final byLit = {
      for (final r in rows) r['literal'] as String: _kanjiMap(r, meanings[r['literal']]),
    };
    return [for (final l in literals) byLit[l]].whereType<Map<String, dynamic>>().toList();
  }

  Map<String, dynamic> _kanjiMap(Map<String, Object?> r, List<Map<String, Object?>>? meanings) => {
        'literal': r['literal'],
        'grade': r['grade'],
        'stroke_count': r['stroke_count'],
        'jlpt': r['jlpt'],
        'freq_rank': r['freq_rank'],
        'radical_number': r['radical_number'],
        'on_readings': jsonDecode(r['on_readings'] as String? ?? '[]'),
        'kun_readings': jsonDecode(r['kun_readings'] as String? ?? '[]'),
        'nanori': jsonDecode(r['nanori'] as String? ?? '[]'),
        'components': jsonDecode(r['components'] as String? ?? '[]'),
        'meanings': [
          for (final m in meanings ?? const <Map<String, Object?>>[])
            {'lang': m['lang'], 'text': m['text']},
        ],
      };

  @override
  Future<KanjiEntry> kanji(String literal) async {
    final db = await _db;
    final maps = await kanjiMapsByLiterals(db, [literal]);
    if (maps.isEmpty) throw StateError('kanji $literal not in the installed packs');
    final map = maps.single;

    final row =
        (await db.select('SELECT * FROM kanji WHERE literal = ?', [literal])).single;
    map['origin'] = row['origin'];
    map['formation'] = row['formation'];
    map['phonetic'] = row['phonetic'];
    map['stroke_paths'] = jsonDecode(row['stroke_paths'] as String? ?? '[]');
    map['stroke_viewbox'] = row['stroke_viewbox'];

    // Component labels: a component is itself a kanji (first meaning) or a
    // radical row - mirrors KanjiDetailSerializer.get_component_details.
    final components = (map['components'] as List).cast<String>();
    final details = <Map<String, dynamic>>[];
    if (components.isNotEmpty) {
      final compMaps = await kanjiMapsByLiterals(db, components);
      final compByLit = {for (final c in compMaps) c['literal'] as String: c};
      final marks = List.filled(components.length, '?').join(',');
      final radicals = await db.select(
          'SELECT * FROM radicals WHERE literal IN ($marks)', components);
      final radByLit = {for (final r in radicals) r['literal'] as String: r};
      for (final lit in components) {
        final comp = compByLit[lit];
        if (comp != null) {
          final ms = (comp['meanings'] as List).cast<Map>();
          details.add({
            'literal': lit,
            'meaning': ms.isEmpty ? '' : ms.first['text'],
            'is_kanji': true,
          });
          continue;
        }
        final rad = radByLit[lit];
        details.add({
          'literal': lit,
          'meaning': rad?['meaning'] ?? '',
          'reading': rad?['reading'] ?? '',
          'is_kanji': false,
        });
      }
    }
    map['component_details'] = details;

    final wordRows = await db.select(
      'SELECT word_id FROM kanji_words WHERE kanji = ? ORDER BY rank LIMIT 12',
      [literal],
    );
    map['words'] = await wordMapsByIds(db, [for (final r in wordRows) r['word_id'] as int]);
    return KanjiEntry.fromJson(map);
  }

  // ── browse ──────────────────────────────────────────────────────────────────

  @override
  Future<List<WordEntry>> words({
    bool common = false,
    int? jlpt,
    int limit = 60,
    int offset = 0,
  }) async {
    final db = await _db;
    final where = <String>[if (common) 'is_common = 1', if (jlpt != null) 'jlpt = ?'];
    final rows = await db.select(
      'SELECT id FROM words '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      // Postgres sorts NULLs last on ASC; SQLite sorts them first - match it.
      'ORDER BY (freq_rank IS NULL), freq_rank, id LIMIT ? OFFSET ?',
      [if (jlpt != null) jlpt, limit, offset],
    );
    return wordsByIds(db, [for (final r in rows) r['id'] as int]);
  }

  @override
  Future<List<KanjiEntry>> kanjiList({
    int? jlpt,
    int? grade,
    String? contains,
    int limit = 120,
    int offset = 0,
  }) async {
    final db = await _db;
    final where = <String>[if (jlpt != null) 'jlpt = ?', if (grade != null) 'grade = ?'];
    final params = <Object?>[if (jlpt != null) jlpt, if (grade != null) grade];
    // Radical-grid lookup: kanji whose component set includes EVERY requested
    // character (INTERSECT over the exploded kanji_components rows).
    if (contains != null && contains.isNotEmpty) {
      final chars = [for (final cp in contains.runes) String.fromCharCode(cp)];
      final intersect = List.filled(
        chars.length,
        'SELECT kanji FROM kanji_components WHERE component = ?',
      ).join(' INTERSECT ');
      where.add('literal IN ($intersect)');
      params.addAll(chars);
    }
    final rows = await db.select(
      'SELECT literal FROM kanji '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      // Kanji.Meta.ordering = [freq_rank, stroke_count, literal], NULLs last.
      'ORDER BY (freq_rank IS NULL), freq_rank, stroke_count, literal LIMIT ? OFFSET ?',
      [...params, limit, offset],
    );
    final maps = await kanjiMapsByLiterals(db, [for (final r in rows) r['literal'] as String]);
    return [for (final m in maps) KanjiEntry.fromJson(m)];
  }

  @override
  Future<List<Map<String, dynamic>>> radicals() async {
    final db = await _db;
    final rows =
        await db.select('SELECT * FROM radicals ORDER BY strokes, literal');
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  @override
  Future<List<KanaEntry>> kana({String? script}) async {
    final db = await _db;
    final rows = await db.select(
      'SELECT * FROM kana ${script != null ? 'WHERE script = ?' : ''} '
      'ORDER BY script, ord',
      [if (script != null) script],
    );
    return [for (final r in rows) KanaEntry.fromJson(_kanaMap(r))];
  }

  @override
  Future<KanaEntry> kanaDetail(String char) async {
    final db = await _db;
    final rows = await db.select('SELECT * FROM kana WHERE char = ?', [char]);
    if (rows.isEmpty) throw StateError('kana $char not in the installed packs');
    return KanaEntry.fromJson(_kanaMap(rows.single));
  }

  /// KanaSerializer-shaped maps for [chars], in order (missing skipped).
  /// Public for the study card assembler.
  Future<List<Map<String, dynamic>>> kanaMapsByChars(DictDb db, List<String> chars) async {
    if (chars.isEmpty) return const [];
    final marks = List.filled(chars.length, '?').join(',');
    final rows = await db.select('SELECT * FROM kana WHERE char IN ($marks)', chars);
    final byChar = {for (final r in rows) r['char'] as String: _kanaMap(r)};
    return [for (final c in chars) byChar[c]].whereType<Map<String, dynamic>>().toList();
  }

  Map<String, dynamic> _kanaMap(Map<String, Object?> r) => {
        'char': r['char'],
        'romaji': r['romaji'],
        'script': r['script'],
        'kind': r['kind'],
        'row': r['row'],
        'order': r['ord'],
        'origin': r['origin'],
        'origin_note': r['origin_note'],
        'usage_label': r['usage_label'],
        'usage': r['usage'],
        'usage_examples': jsonDecode(r['usage_examples'] as String? ?? '[]'),
      };
}
