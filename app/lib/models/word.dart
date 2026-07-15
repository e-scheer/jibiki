import 'kanji.dart';

class WordFormItem {
  WordFormItem({required this.text, required this.isCommon, this.pitch = ''});
  final String text;
  final bool isCommon;
  final String
      pitch; // pitch-accent pattern, e.g. "0" or "0,2" (empty if unknown)

  factory WordFormItem.fromJson(Map<String, dynamic> j) => WordFormItem(
        text: j['text'] as String? ?? '',
        isCommon: j['is_common'] as bool? ?? false,
        pitch: j['pitch'] as String? ?? '',
      );
}

class ExampleItem {
  ExampleItem({required this.japanese, required this.translation});
  final String japanese;
  final String translation;

  factory ExampleItem.fromJson(Map<String, dynamic> j) => ExampleItem(
      japanese: j['japanese'] as String? ?? '',
      translation: j['translation'] as String? ?? '');
}

/// A JMnedict proper name (place, surname, company, …) returned alongside a search.
class NameItem {
  NameItem(
      {required this.kanji,
      required this.reading,
      required this.translations,
      required this.types});
  final String kanji;
  final String reading;
  final List<String> translations;
  final List<String> types;

  String get display => kanji.isNotEmpty ? kanji : reading;

  factory NameItem.fromJson(Map<String, dynamic> j) => NameItem(
        kanji: j['kanji'] as String? ?? '',
        reading: j['reading'] as String? ?? '',
        translations: ((j['translations'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e['text']?.toString() ?? '')
            .where((text) => text.isNotEmpty)
            .toList(),
        types: ((j['name_types'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// A search response: ranked words + a small set of matching proper names.
class SearchResults {
  SearchResults({required this.words, required this.names});
  final List<WordEntry> words;
  final List<NameItem> names;

  static SearchResults empty() =>
      SearchResults(words: const [], names: const []);
}

class GlossItem {
  GlossItem({required this.language, required this.text});
  final String language;
  final String text;

  factory GlossItem.fromJson(Map<String, dynamic> j) => GlossItem(
      language: j['language'] as String? ?? 'en',
      text: j['text'] as String? ?? '');
}

class Sense {
  Sense({required this.pos, required this.glosses});
  final List<String> pos;
  final List<GlossItem> glosses;

  factory Sense.fromJson(Map<String, dynamic> j) => Sense(
        pos:
            ((j['pos'] as List?) ?? const []).map((e) => e.toString()).toList(),
        glosses: ((j['glosses'] as List?) ?? const [])
            .map((e) => GlossItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  List<String> exactGlossesFor(String language) => glosses
      .where((g) => g.language == language && g.text.trim().isNotEmpty)
      .map((g) => g.text)
      .toList();

  bool hasGlossFor(String language) => exactGlossesFor(language).isNotEmpty;

  /// Glosses in the requested language, falling back to English when available.
  List<String> glossesFor(String lang) {
    final wanted = exactGlossesFor(lang);
    if (wanted.isNotEmpty) return wanted;
    return exactGlossesFor('en');
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

  /// A compact one-line meaning for list rows and card backs. Prefers the
  /// resolved display language, then English, then any language that carries a
  /// definition, so a word that has a meaning never renders as a blank card.
  String summaryGloss(String lang) {
    final displayLanguage = glossLanguageFor(lang);
    for (final language in {displayLanguage, 'en'}) {
      for (final s in senses) {
        final g = s.exactGlossesFor(language);
        if (g.isNotEmpty) return g.take(3).join('; ');
      }
    }
    for (final s in senses) {
      final texts = s.glosses
          .where((g) => g.text.trim().isNotEmpty)
          .map((g) => g.text)
          .toList();
      if (texts.isNotEmpty) return texts.take(3).join('; ');
    }
    return '';
  }

  /// Meanings that have at least one definition in [lang] or its English
  /// fallback. Some JMdict records contain metadata-only sense rows; they are
  /// useful to preserve in the pack but must not render as empty numbered rows.
  List<Sense> sensesFor(String lang) {
    final displayLanguage = glossLanguageFor(lang);
    return [
      for (final sense in senses)
        if (sense.hasGlossFor(displayLanguage)) sense,
    ];
  }

  /// Select one language for the whole entry instead of falling back per sense.
  /// This prevents a partly translated entry from showing English and French in
  /// the same numbered list. If the requested language is incomplete, English
  /// wins when it covers at least as many meaningful senses.
  String glossLanguageFor(String requested) {
    final meaningful = senses
        .where((sense) => sense.glosses.any((g) => g.text.trim().isNotEmpty))
        .toList();
    if (meaningful.isEmpty || requested == 'en') return requested;
    final requestedCount =
        meaningful.where((sense) => sense.hasGlossFor(requested)).length;
    if (requestedCount == meaningful.length) return requested;
    final englishCount =
        meaningful.where((sense) => sense.hasGlossFor('en')).length;
    return englishCount >= requestedCount ? 'en' : requested;
  }

  factory WordEntry.fromJson(Map<String, dynamic> j) => WordEntry(
        id: (j['id'] as num).toInt(),
        isCommon: j['is_common'] as bool? ?? false,
        jlpt: (j['jlpt'] as num?)?.toInt(),
        headword: j['headword'] as String? ?? '',
        primaryReading: j['primary_reading'] as String? ?? '',
        kanji: ((j['kanji'] as List?) ?? const [])
            .map((e) =>
                WordFormItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        readings: ((j['readings'] as List?) ?? const [])
            .map((e) =>
                WordFormItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        senses: ((j['senses'] as List?) ?? const [])
            .map((e) => Sense.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        kanjiBreakdown: ((j['kanji_breakdown'] as List?) ?? const [])
            .map((e) => KanjiEntry.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        examples: ((j['examples'] as List?) ?? const [])
            .map(
                (e) => ExampleItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
