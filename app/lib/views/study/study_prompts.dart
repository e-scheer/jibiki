import '../../models/enums.dart';
import '../../models/study.dart';

/// Shared prompt/answer derivations for the study games, so Quiz, Match and
/// Listen all phrase a card the same way.

/// The short answer text shown as a card's "meaning": romaji for kana, the first
/// meaning for a kanji, the first gloss for a word.
String answerLabel(StudyCard c, String lang) => switch (c.itemType) {
      ItemType.kana => c.kana?.romaji ?? '',
      ItemType.kanji => _firstMeaning(c, lang),
      ItemType.word => (c.word?.summaryGloss(lang) ?? '').split(';').first.trim(),
    };

/// The quiz prompt (the big text you answer from): the Japanese glyph for
/// recognize, the meaning for recall (see [StudyDirection]).
String quizPrompt(StudyCard c, String lang, StudyDirection dir) =>
    dir.isRecall ? answerLabel(c, lang) : c.front;

/// The correct quiz option: the meaning for recognize, the Japanese for recall.
String quizAnswer(StudyCard c, String lang, StudyDirection dir) =>
    dir.isRecall ? c.front : answerLabel(c, lang);

/// The question line above the prompt, phrased for the direction being tested.
String quizQuestion(ItemType t, StudyDirection dir) {
  if (dir.isRecall) {
    return t == ItemType.kana ? 'Which kana reads like this?' : 'Which one means this?';
  }
  return t == ItemType.kana ? 'How do you read this?' : 'What does this mean?';
}

/// Whether the quiz prompt text is Japanese (glyph) rather than Latin (a
/// meaning), so the widget picks the right font.
bool quizPromptIsJapanese(StudyDirection dir) => !dir.isRecall;

String _firstMeaning(StudyCard c, String lang) {
  final m = c.kanji?.meaningsFor(lang) ?? const [];
  return m.isNotEmpty ? m.first : '';
}

/// The kana string the Listen game asks you to rebuild: a word's reading, a
/// kanji's first reading (okurigana dots stripped), or the kana glyph itself.
String listenTarget(StudyCard c) => switch (c.itemType) {
      ItemType.word => (c.word?.primaryReading.isNotEmpty ?? false) ? c.word!.primaryReading : c.front,
      ItemType.kanji => _kanjiReading(c),
      ItemType.kana => c.front,
    };

String _kanjiReading(StudyCard c) {
  final k = c.kanji;
  if (k == null) return c.front;
  final raw = k.kunReadings.isNotEmpty
      ? k.kunReadings.first
      : (k.onReadings.isNotEmpty ? k.onReadings.first : c.front);
  return raw.replaceAll(RegExp(r'[.\-]'), '');
}

/// What to read aloud for a card: the reading for a word, the glyph for kana/kanji.
String speechText(StudyCard c) => switch (c.itemType) {
      ItemType.word => c.reading.isNotEmpty ? c.reading : c.front,
      _ => c.front,
    };
