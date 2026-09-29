import 'kanji.dart';

class WordFormItem {
  WordFormItem(
      {required this.text,
      required this.isCommon,
      this.pitch = '',
      this.metadata = const {}});
  final String text;
  final bool isCommon;
  final Map<String, dynamic> metadata;
  final String
      pitch; // pitch-accent pattern, e.g. "0" or "0,2" (empty if unknown)

  factory WordFormItem.fromJson(Map<String, dynamic> j) => WordFormItem(
        text: j['text'] as String? ?? '',
        isCommon: j['is_common'] as bool? ?? false,
        pitch: j['pitch'] as String? ?? '',
        metadata: (j['metadata'] as Map? ?? const {}).cast<String, dynamic>(),
      );
}

class ExampleItem {
  ExampleItem(
      {required this.japanese,
      required this.translation,
      this.language = '',
      this.translations = const [],
      this.provenance = const {}});
  final String japanese;
  final String translation;
  final String language;
  final List<GlossItem> translations;
  final Map<String, dynamic> provenance;

  String translationFor(String requested) {
    for (final language in {requested, 'en'}) {
      for (final value in translations) {
        if (value.language == language) return value.text;
      }
    }
    return translations.isEmpty ? translation : '';
  }

  factory ExampleItem.fromJson(Map<String, dynamic> j) => ExampleItem(
          japanese: j['japanese'] as String? ?? '',
          translation: j['translation'] as String? ?? '',
          language: j['language'] as String? ?? '',
          provenance:
              (j['provenance'] as Map? ?? const {}).cast<String, dynamic>(),
          translations: [
            for (final value in j['translations'] as List? ?? const [])
              GlossItem.fromJson((value as Map).cast<String, dynamic>())
          ]);
}

/// A JMnedict proper name (place, surname, company, …) returned alongside a search.
class NameItem {
  NameItem(
      {required this.kanji,
      required this.reading,
      required this.translations,
      required this.types,
      this.translationItems = const [],
      this.translationLanguage = '',
      this.metadata = const {},
      this.provenance = const {}});
  final String kanji;
  final String reading;
  final List<String> translations;
  final List<String> types;
  final List<GlossItem> translationItems;
  final String translationLanguage;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> provenance;

  String get display => kanji.isNotEmpty ? kanji : reading;

  factory NameItem.fromJson(Map<String, dynamic> j, {String? language}) {
    final items = [
      for (final value in j['translations'] as List? ?? const [])
        GlossItem.fromJson((value as Map).cast<String, dynamic>())
    ];
    final requested = language ?? j['language'] as String? ?? 'en';
    final chosen =
        items.any((item) => item.language == requested) ? requested : 'en';
    return NameItem(
      kanji: j['kanji'] as String? ?? '',
      reading: j['reading'] as String? ?? '',
      metadata: (j['metadata'] as Map? ?? const {}).cast<String, dynamic>(),
      provenance: (j['provenance'] as Map? ?? const {}).cast<String, dynamic>(),
      translations: [
        for (final item in items)
          if (item.language == chosen && item.text.isNotEmpty) item.text
      ],
      translationItems: items,
      translationLanguage: chosen,
      types: ((j['name_types'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
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
  GlossItem(
      {required this.language, required this.text, this.metadata = const {}});
  final String language;
  final String text;
  final Map<String, dynamic> metadata;

  factory GlossItem.fromJson(Map<String, dynamic> j) => GlossItem(
      language: j['language'] as String? ?? 'en',
      metadata: (j['metadata'] as Map? ?? const {}).cast<String, dynamic>(),
      text: j['text'] as String? ?? '');
}

class Sense {
  Sense(
      {required this.pos,
      required this.glosses,
      this.order = 0,
      this.misc = const [],
      this.field = const [],
      this.notes = const [],
      this.metadata = const {}});
  final List<String> pos;
  final List<GlossItem> glosses;
  final int order;
  final List<String> misc;
  final List<String> field;
  final List<GlossItem> notes;
  final Map<String, dynamic> metadata;

  factory Sense.fromJson(Map<String, dynamic> j) => Sense(
        order: (j['order'] as num?)?.toInt() ?? 0,
        metadata: (j['metadata'] as Map? ?? const {}).cast<String, dynamic>(),
        misc: [for (final value in j['misc'] as List? ?? const []) '$value'],
        field: [for (final value in j['field'] as List? ?? const []) '$value'],
        notes: [
          for (final value in j['notes'] as List? ?? const [])
            GlossItem.fromJson((value as Map).cast<String, dynamic>())
        ],
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
    this.provenance = const {},
    this.canonicalId,
  });

  final int id;
  final int? canonicalId;
  final bool isCommon;
  final int? jlpt;
  final String headword;
  final String primaryReading;
  final List<WordFormItem> kanji;
  final List<WordFormItem> readings;
  final List<Sense> senses;
  final List<KanjiEntry> kanjiBreakdown;
  final List<ExampleItem> examples;
  final Map<String, dynamic> provenance;

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
  /// JMdict can have separate sense rows in different languages. A difference
  /// in their number does not prove a translation is incomplete.
  String glossLanguageFor(String requested) {
    if (senses.any((sense) => sense.hasGlossFor(requested))) return requested;
    if (senses.any((sense) => sense.hasGlossFor('en'))) return 'en';
    return requested;
  }

  factory WordEntry.fromJson(Map<String, dynamic> j) => WordEntry(
        id: (j['id'] as num).toInt(),
        canonicalId: (j['canonical_id'] as num?)?.toInt(),
        provenance:
            (j['provenance'] as Map? ?? const {}).cast<String, dynamic>(),
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
