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
    this.totalReviews = 0,
    this.correctReviews = 0,
    this.studyTimeMs = 0,
    this.matureReviews = 0,
    this.matureCorrectReviews = 0,
    this.history = const [],
    this.cardsByType = const {},
    this.reviewsByRating = const {},
  });

  final int dueNow;
  final int newRemaining;
  final int reviewsToday;
  final int streak;
  final int totalCards;
  final Map<String, int> byState;
  final int totalReviews;
  final int correctReviews;
  final int studyTimeMs;
  final int matureReviews;
  final int matureCorrectReviews;
  final List<StudyStatsDay> history;
  final Map<String, int> cardsByType;
  final Map<String, int> reviewsByRating;

  double get accuracy => totalReviews == 0 ? 0 : correctReviews / totalReviews;
  double get matureRetention =>
      matureReviews == 0 ? 0 : matureCorrectReviews / matureReviews;
  int get studyMinutes => (studyTimeMs / 60000).round();

  factory StudyStats.fromJson(Map<String, dynamic> j) => StudyStats(
        dueNow: (j['due_now'] as num?)?.toInt() ?? 0,
        newRemaining: (j['new_remaining'] as num?)?.toInt() ?? 0,
        reviewsToday: (j['reviews_today'] as num?)?.toInt() ?? 0,
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        totalCards: (j['total_cards'] as num?)?.toInt() ?? 0,
        byState: ((j['by_state'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        totalReviews: (j['total_reviews'] as num?)?.toInt() ?? 0,
        correctReviews: (j['correct_reviews'] as num?)?.toInt() ?? 0,
        studyTimeMs: (j['study_time_ms'] as num?)?.toInt() ?? 0,
        matureReviews: (j['mature_reviews'] as num?)?.toInt() ?? 0,
        matureCorrectReviews:
            (j['mature_correct_reviews'] as num?)?.toInt() ?? 0,
        history: ((j['history'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => StudyStatsDay.fromJson(e.cast<String, dynamic>()))
            .toList(),
        cardsByType: ((j['cards_by_type'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        reviewsByRating: ((j['reviews_by_rating'] as Map?) ?? const {})
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

class StudyStatsDay {
  const StudyStatsDay(
      {required this.date, required this.reviews, required this.correct});

  final DateTime date;
  final int reviews;
  final int correct;

  double get accuracy => reviews == 0 ? 0 : correct / reviews;

  factory StudyStatsDay.fromJson(Map<String, dynamic> j) => StudyStatsDay(
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        reviews: (j['reviews'] as num?)?.toInt() ?? 0,
        correct: (j['correct'] as num?)?.toInt() ?? 0,
      );
}
