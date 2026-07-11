class KanjiComponent {
  KanjiComponent({required this.literal, required this.meaning, required this.reading, required this.isKanji});
  final String literal;
  final String meaning;
  final String reading;
  final bool isKanji;

  factory KanjiComponent.fromJson(Map<String, dynamic> j) => KanjiComponent(
        literal: j['literal'] as String? ?? '',
        meaning: j['meaning'] as String? ?? '',
        reading: j['reading'] as String? ?? '',
        isKanji: j['is_kanji'] as bool? ?? false,
      );
}

class KanjiEntry {
  KanjiEntry({
    required this.literal,
    required this.grade,
    required this.strokeCount,
    required this.jlpt,
    required this.freqRank,
    required this.onReadings,
    required this.kunReadings,
    required this.nanori,
    required this.components,
    required this.meanings,
    this.origin = '',
    this.formation = '',
    this.phonetic = '',
    this.componentDetails = const [],
    this.words = const [],
    this.strokePaths = const [],
    this.strokeViewbox = '0 0 109 109',
  });

  final String literal;
  final int? grade;
  final int strokeCount;
  final int? jlpt;
  final int? freqRank;
  final List<String> onReadings;
  final List<String> kunReadings;
  final List<String> nanori;
  final List<String> components;
  final List<Map<String, String>> meanings; // {language, text}
  final String origin; // Wiktionary "Glyph origin" prose (CC BY-SA); '' if unknown
  final String formation; // phono-semantic | ideogrammic | pictogram | simplified | …
  final String phonetic; // 音符: the sound-carrying component, when phono-semantic
  final List<KanjiComponent> componentDetails;
  final List<dynamic> words; // raw word json (kept light to avoid a cycle)
  final List<String> strokePaths; // KanjiVG SVG `d` strings, in stroke order
  final String strokeViewbox;

  bool get hasStrokes => strokePaths.isNotEmpty;
  bool get hasOrigin => origin.isNotEmpty;

  List<String> meaningsFor(String lang) {
    final wanted = meanings.where((m) => m['language'] == lang).map((m) => m['text'] ?? '').toList();
    if (wanted.isNotEmpty) return wanted;
    final en = meanings.where((m) => m['language'] == 'en').map((m) => m['text'] ?? '').toList();
    return en.isNotEmpty ? en : meanings.map((m) => m['text'] ?? '').toList();
  }

  static List<String> _strs(dynamic v) =>
      ((v as List?) ?? const []).map((e) => e.toString()).toList();

  factory KanjiEntry.fromJson(Map<String, dynamic> j) => KanjiEntry(
        literal: j['literal'] as String? ?? '',
        grade: (j['grade'] as num?)?.toInt(),
        strokeCount: (j['stroke_count'] as num?)?.toInt() ?? 0,
        jlpt: (j['jlpt'] as num?)?.toInt(),
        freqRank: (j['freq_rank'] as num?)?.toInt(),
        onReadings: _strs(j['on_readings']),
        kunReadings: _strs(j['kun_readings']),
        nanori: _strs(j['nanori']),
        components: _strs(j['components']),
        origin: j['origin'] as String? ?? '',
        formation: j['formation'] as String? ?? '',
        phonetic: j['phonetic'] as String? ?? '',
        meanings: ((j['meanings'] as List?) ?? const [])
            .map((e) => {
                  'language': (e as Map)['language']?.toString() ?? 'en',
                  'text': e['text']?.toString() ?? '',
                })
            .toList(),
        componentDetails: ((j['component_details'] as List?) ?? const [])
            .map((e) => KanjiComponent.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        words: (j['words'] as List?) ?? const [],
        strokePaths: _strs(j['stroke_paths']),
        strokeViewbox: j['stroke_viewbox'] as String? ?? '0 0 109 109',
      );
}
