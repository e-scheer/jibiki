import 'enums.dart';
import 'kana.dart';
import 'kanji.dart';
import 'word.dart';

/// A study card + its embedded dictionary item, so the review UI can render the
/// front/back with no extra fetch.
class StudyCard {
  StudyCard({
    required this.id,
    required this.itemType,
    required this.itemRef,
    required this.state,
    required this.due,
    required this.reps,
    required this.lapses,
    this.word,
    this.kanji,
    this.kana,
    this.sourceSentence = '',
    this.sourceUrl = '',
    this.sourceTitle = '',
    this.sourceMedia = '',
  });

  final int id;
  final ItemType itemType;
  final String itemRef;
  final int state; // 0 new, 1 learning, 2 review, 3 relearning
  final DateTime due;
  final int reps;
  final int lapses;

  final WordEntry? word;
  final KanjiEntry? kanji;
  final KanaEntry? kana;
  final String sourceSentence;
  final String sourceUrl;
  final String sourceTitle;
  final String sourceMedia;

  bool get isNew => state == 0;

  /// The prompt shown on the front of the card.
  String get front => switch (itemType) {
        ItemType.word => word?.headword ?? itemRef,
        ItemType.kanji => kanji?.literal ?? itemRef,
        ItemType.kana => kana?.char ?? itemRef,
      };

  /// The reading revealed on the back (empty for kana, where romaji is the answer).
  String get reading => switch (itemType) {
        ItemType.word => word?.primaryReading ?? '',
        ItemType.kanji =>
          [...?kanji?.kunReadings, ...?kanji?.onReadings].take(3).join('  '),
        ItemType.kana => kana?.romaji ?? '',
      };

  String meaning(String lang) => switch (itemType) {
        ItemType.word => word?.summaryGloss(lang) ?? '',
        ItemType.kanji =>
          (kanji?.meaningsFor(lang) ?? const []).take(3).join('; '),
        ItemType.kana => kana?.romaji ?? '',
      };

  factory StudyCard.fromJson(Map<String, dynamic> j) {
    final type = ItemType.fromString(j['item_type'] as String? ?? 'word');
    final item = (j['item'] as Map?)?.cast<String, dynamic>();
    return StudyCard(
      id: (j['id'] as num).toInt(),
      itemType: type,
      itemRef: j['item_ref'] as String? ?? '',
      state: (j['state'] as num?)?.toInt() ?? 0,
      due: DateTime.tryParse(j['due'] as String? ?? '') ?? DateTime.now(),
      reps: (j['reps'] as num?)?.toInt() ?? 0,
      lapses: (j['lapses'] as num?)?.toInt() ?? 0,
      word: type == ItemType.word && item != null
          ? WordEntry.fromJson(item)
          : null,
      kanji: type == ItemType.kanji && item != null
          ? KanjiEntry.fromJson(item)
          : null,
      kana: type == ItemType.kana && item != null
          ? KanaEntry.fromJson(item)
          : null,
      sourceSentence: j['source_sentence'] as String? ?? '',
      sourceUrl: j['source_url'] as String? ?? '',
      sourceTitle: j['source_title'] as String? ?? '',
      sourceMedia: j['source_media'] as String? ?? '',
    );
  }
}

class StudyStats {
  StudyStats({
    required this.dueNow,
    required this.newRemaining,
    required this.reviewsToday,
    required this.streak,
    required this.totalCards,
    required this.byState,
  });

  final int dueNow;
  final int newRemaining;
  final int reviewsToday;
  final int streak;
  final int totalCards;
  final Map<String, int> byState;

  factory StudyStats.fromJson(Map<String, dynamic> j) => StudyStats(
        dueNow: (j['due_now'] as num?)?.toInt() ?? 0,
        newRemaining: (j['new_remaining'] as num?)?.toInt() ?? 0,
        reviewsToday: (j['reviews_today'] as num?)?.toInt() ?? 0,
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        totalCards: (j['total_cards'] as num?)?.toInt() ?? 0,
        byState: ((j['by_state'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      );

  static StudyStats empty() => StudyStats(
        dueNow: 0,
        newRemaining: 0,
        reviewsToday: 0,
        streak: 0,
        totalCards: 0,
        byState: const {},
      );
}
