/// One curated sentence showing a grammatical kana at work. The particle is
/// kept as its own segment so the UI can highlight it inside the sentence.
class KanaUsageExample {
  KanaUsageExample({
    required this.before,
    required this.particle,
    required this.after,
    required this.romaji,
    required this.en,
  });

  final String before;
  final String particle;
  final String after;
  final String romaji; // particle spelled as pronounced (は→wa, を→o, へ→e)
  final String en;

  String get sentence => '$before$particle$after';

  factory KanaUsageExample.fromJson(Map<String, dynamic> j) => KanaUsageExample(
        before: j['before'] as String? ?? '',
        particle: j['particle'] as String? ?? '',
        after: j['after'] as String? ?? '',
        romaji: j['romaji'] as String? ?? '',
        en: j['en'] as String? ?? '',
      );
}

class KanaEntry {
  KanaEntry({
    required this.char,
    required this.romaji,
    required this.script,
    required this.kind,
    required this.row,
    required this.order,
    this.origin = '',
    this.originNote = '',
    this.usageLabel = '',
    this.usage = '',
    this.usageExamples = const [],
  });

  final String char;
  final String romaji;
  final String script; // hiragana | katakana
  final String kind; // gojuon | dakuten | handakuten | yoon
  final String row; // a,k,s,...
  final int order;
  final String origin; // the man'yōgana kanji (or base kana) this glyph came from
  final String originNote; // one-line "how it got this shape" story
  final String usageLabel; // short grammatical role, e.g. "Topic particle"; '' if none
  final String usage; // one-line "job in a sentence" for the particle kana
  final List<KanaUsageExample> usageExamples; // curated sentences showing that job

  bool get isHiragana => script == 'hiragana';
  bool get hasOrigin => origin.isNotEmpty;
  bool get hasUsage => usage.isNotEmpty;
  // Gojūon kana descend from a kanji; dakuten/handakuten from a base kana.
  bool get originIsKanji => kind == 'gojuon';

  factory KanaEntry.fromJson(Map<String, dynamic> j) => KanaEntry(
        char: j['char'] as String? ?? '',
        romaji: j['romaji'] as String? ?? '',
        script: j['script'] as String? ?? 'hiragana',
        kind: j['kind'] as String? ?? 'gojuon',
        row: j['row'] as String? ?? '',
        order: (j['order'] as num?)?.toInt() ?? 0,
        origin: j['origin'] as String? ?? '',
        originNote: j['origin_note'] as String? ?? '',
        usageLabel: j['usage_label'] as String? ?? '',
        usage: j['usage'] as String? ?? '',
        usageExamples: (j['usage_examples'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(KanaUsageExample.fromJson)
            .toList(),
      );
}
