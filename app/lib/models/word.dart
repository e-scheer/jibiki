import 'kanji.dart';

class WordFormItem {
  WordFormItem({required this.text, required this.isCommon, this.pitch = ''});
  final String text;
  final bool isCommon;
  final String pitch; // pitch-accent pattern, e.g. "0" or "0,2" (empty if unknown)

  factory WordFormItem.fromJson(Map<String, dynamic> j) => WordFormItem(
        text: j['text'] as String? ?? '',
        isCommon: j['is_common'] as bool? ?? false,
        pitch: j['pitch'] as String? ?? '',
      );
}

class ExampleItem {
  ExampleItem({required this.japanese, required this.english});
  final String japanese;
  final String english;

  factory ExampleItem.fromJson(Map<String, dynamic> j) =>
      ExampleItem(japanese: j['japanese'] as String? ?? '', english: j['english'] as String? ?? '');
}

/// A JMnedict proper name (place, surname, company, …) returned alongside a search.
class NameItem {
  NameItem({required this.kanji, required this.reading, required this.translations, required this.types});
  final String kanji;
  final String reading;
  final List<String> translations;
  final List<String> types;

  String get display => kanji.isNotEmpty ? kanji : reading;

  factory NameItem.fromJson(Map<String, dynamic> j) => NameItem(
        kanji: j['kanji'] as String? ?? '',
        reading: j['reading'] as String? ?? '',
        translations: ((j['translations'] as List?) ?? const []).map((e) => e.toString()).toList(),
        types: ((j['name_types'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
}

/// A search response: ranked words + a small set of matching proper names.
class SearchResults {
  SearchResults({required this.words, required this.names});
  final List<WordEntry> words;
  final List<NameItem> names;

  static SearchResults empty() => SearchResults(words: const [], names: const []);
}

class GlossItem {
  GlossItem({required this.lang, required this.text});
  final String lang;
  final String text;

  factory GlossItem.fromJson(Map<String, dynamic> j) =>
      GlossItem(lang: j['lang'] as String? ?? 'en', text: j['text'] as String? ?? '');
}

class Sense {
  Sense({required this.pos, required this.glosses});
  final List<String> pos;
  final List<GlossItem> glosses;

  factory Sense.fromJson(Map<String, dynamic> j) => Sense(
        pos: ((j['pos'] as List?) ?? const []).map((e) => e.toString()).toList(),
        glosses: ((j['glosses'] as List?) ?? const [])
            .map((e) => GlossItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  /// Glosses in the requested language, falling back to English then to all.
  List<String> glossesFor(String lang) {
    final wanted = glosses.where((g) => g.lang == lang).map((g) => g.text).toList();
    if (wanted.isNotEmpty) return wanted;
    final en = glosses.where((g) => g.lang == 'en').map((g) => g.text).toList();
    return en.isNotEmpty ? en : glosses.map((g) => g.text).toList();
  }
}

class WordEntry {
  WordEntry({
    required this.id,
    required this.isCommon,
    required this.jlpt,
    required this.headword,
    required this.primaryReading,
    required this.kanji,
    required this.readings,
    required this.senses,
    this.kanjiBreakdown = const [],
    this.examples = const [],
  });

  final int id;
  final bool isCommon;
  final int? jlpt;
  final String headword;
  final String primaryReading;
  final List<WordFormItem> kanji;
  final List<WordFormItem> readings;
  final List<Sense> senses;
  final List<KanjiEntry> kanjiBreakdown;
  final List<ExampleItem> examples;

  /// A compact one-line meaning for list rows and card backs.
  String summaryGloss(String lang) {
    for (final s in senses) {
      final g = s.glossesFor(lang);
      if (g.isNotEmpty) return g.take(3).join('; ');
    }
    return '';
  }

  factory WordEntry.fromJson(Map<String, dynamic> j) => WordEntry(
        id: (j['id'] as num).toInt(),
        isCommon: j['is_common'] as bool? ?? false,
        jlpt: (j['jlpt'] as num?)?.toInt(),
        headword: j['headword'] as String? ?? '',
        primaryReading: j['primary_reading'] as String? ?? '',
        kanji: ((j['kanji'] as List?) ?? const [])
            .map((e) => WordFormItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        readings: ((j['readings'] as List?) ?? const [])
            .map((e) => WordFormItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        senses: ((j['senses'] as List?) ?? const [])
            .map((e) => Sense.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        kanjiBreakdown: ((j['kanji_breakdown'] as List?) ?? const [])
            .map((e) => KanjiEntry.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        examples: ((j['examples'] as List?) ?? const [])
            .map((e) => ExampleItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
