/// The onboarding-selectable spectrum (DEEP_SEARCH feature 3). Drives home layout,
/// review prominence and notification defaults, a single flag, not three apps.
enum AppMode {
  dictionary,
  middle,
  learning;

  static AppMode fromString(String? v) => switch (v) {
        'dictionary' => AppMode.dictionary,
        'learning' => AppMode.learning,
        _ => AppMode.middle,
      };

  String get wire => name;

  String get label => switch (this) {
        AppMode.dictionary => 'Dictionary',
        AppMode.middle => 'Balanced',
        AppMode.learning => 'Learning',
      };

  String get blurb => switch (this) {
        AppMode.dictionary =>
          'Search-first. No review nagging, notifications off. Add words to study only when you choose.',
        AppMode.middle =>
          'A dictionary that quietly tracks what is due, with gentle reminders and one-tap add-to-study.',
        AppMode.learning =>
          'The review queue is home. Daily goals, streaks and progress front and centre.',
      };

  bool get showsReviewFirst => this == AppMode.learning;
  bool get showsDueBadge => this != AppMode.dictionary;
}

/// FSRS four-button rating scale.
enum Rating {
  again(1, 'Again'),
  hard(2, 'Hard'),
  good(3, 'Good'),
  easy(4, 'Easy');

  const Rating(this.value, this.label);
  final int value;
  final String label;
}

/// The three study-item kinds a card can point at.
enum ItemType {
  word,
  kanji,
  kana;

  static ItemType fromString(String v) => switch (v) {
        'kanji' => ItemType.kanji,
        'kana' => ItemType.kana,
        _ => ItemType.word,
      };

  String get wire => name;
}

enum MnemonicKind { kana, kanji }

/// How a study session is played.
enum StudyMode {
  swipe,
  quiz;

  static StudyMode fromString(String? v) => v == 'quiz' ? StudyMode.quiz : StudyMode.swipe;
  String get wire => name;
  String get label => this == StudyMode.quiz ? 'Quiz' : 'Swipe';
}
