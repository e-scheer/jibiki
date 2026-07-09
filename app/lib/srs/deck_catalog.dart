/// The smart-deck catalogue - a 1:1 port of server/srs/decks.py's CATALOG,
/// with content universes resolved against the local packs instead of the
/// Django ORM. Ids are the wire contract (deck_enroll ops replay them
/// server-side), so they must never drift from decks.py.
library;

import '../core/db/dict_db.dart';
import '../models/enums.dart';

class DeckSpec {
  const DeckSpec(this.id, this.title, this.subtitle, this.icon, this.kind,
      [this.itemType]);

  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final String kind; // content | filter
  final ItemType? itemType;

  bool get isFilter => kind == 'filter';
}

const List<DeckSpec> deckCatalog = [
  DeckSpec('hiragana', 'Hiragana', 'The full ひらがな syllabary', 'あ', 'content', ItemType.kana),
  DeckSpec('katakana', 'Katakana', 'The full カタカナ syllabary', 'ア', 'content', ItemType.kana),
  DeckSpec('kana', 'All kana', 'Hiragana + katakana', 'か', 'content', ItemType.kana),
  DeckSpec('kanji_n5', 'JLPT N5 kanji', 'The beginner kanji set', '水', 'content', ItemType.kanji),
  DeckSpec('kanji_all', 'All kanji', 'Every kanji in the dictionary', '漢', 'content', ItemType.kanji),
  DeckSpec('words_common', 'Common words', 'The everyday vocabulary', '語', 'content', ItemType.word),
  DeckSpec('words_all', 'All words', 'The whole dictionary', '本', 'content', ItemType.word),
  DeckSpec('favorites', 'Favorites', 'Everything you starred', '★', 'filter'),
  DeckSpec('struggling', 'Struggling', 'The ones you keep missing', '🔥', 'filter'),
];

DeckSpec? deckById(String id) {
  for (final d in deckCatalog) {
    if (d.id == id) return d;
  }
  return null;
}

/// The (whereClause, params) selecting a content deck's universe rows in the
/// pack database, or null for filter decks.
(String, String, List<Object?>)? _universeQuery(DeckSpec spec) => switch (spec.id) {
      'hiragana' => ('kana', "script = 'hiragana'", const []),
      'katakana' => ('kana', "script = 'katakana'", const []),
      'kana' => ('kana', '1=1', const []),
      'kanji_n5' => ('kanji', 'jlpt = 5', const []),
      'kanji_all' => ('kanji', '1=1', const []),
      'words_common' => ('words', 'is_common = 1', const []),
      'words_all' => ('words', '1=1', const []),
      _ => null,
    };

String _refColumn(String table) => switch (table) {
      'kana' => 'char',
      'kanji' => 'literal',
      _ => 'id',
    };

/// How many dictionary rows the deck spans.
Future<int> deckUniverseCount(DictDb db, DeckSpec spec) async {
  final q = _universeQuery(spec);
  if (q == null) return 0;
  final (table, where, params) = q;
  final rows = await db.select('SELECT count(*) AS n FROM $table WHERE $where', params);
  return rows.single['n'] as int;
}

/// Every item_ref in the deck's universe (server enroll caps at 20k; same
/// bound keeps a full-dictionary enroll from materializing 200k rows).
Future<List<String>> deckUniverseRefs(DictDb db, DeckSpec spec, {int limit = 20000}) async {
  final q = _universeQuery(spec);
  if (q == null) return const [];
  final (table, where, params) = q;
  final col = _refColumn(table);
  final rows = await db.select(
      'SELECT "$col" AS ref FROM $table WHERE $where LIMIT ?', [...params, limit]);
  return [for (final r in rows) '${r['ref']}'];
}

/// Which of [refs] (cards the user already has, of the deck's item type)
/// belong to this content deck. Cross-database membership: the user DB and
/// the pack DB are separate connections, so membership is resolved by
/// checking the user's own refs - always a small set - against the pack.
Future<Set<String>> deckMembership(DictDb db, DeckSpec spec, List<String> refs) async {
  final q = _universeQuery(spec);
  if (q == null || refs.isEmpty) return const {};
  final (table, where, params) = q;
  final col = _refColumn(table);
  final out = <String>{};
  for (var i = 0; i < refs.length; i += 500) {
    final chunk = refs.sublist(i, i + 500 > refs.length ? refs.length : i + 500);
    final marks = List.filled(chunk.length, '?').join(',');
    final rows = await db.select(
      'SELECT "$col" AS ref FROM $table WHERE $where AND "$col" IN ($marks)',
      [...params, ...chunk],
    );
    out.addAll([for (final r in rows) '${r['ref']}']);
  }
  return out;
}
