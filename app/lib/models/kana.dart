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
      );
}
