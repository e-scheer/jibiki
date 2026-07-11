import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/models/enums.dart';
import 'package:jibiki/models/study.dart';
import 'package:jibiki/models/word.dart';

void main() {
  group('AppMode', () {
    test('parses and flags behave', () {
      expect(AppMode.fromString('learning'), AppMode.learning);
      expect(AppMode.fromString(null), AppMode.middle);
      expect(AppMode.learning.showsReviewFirst, isTrue);
      expect(AppMode.dictionary.showsDueBadge, isFalse);
    });
  });

  group('WordEntry.fromJson', () {
    test('assembles forms, senses and language-filtered glosses', () {
      final w = WordEntry.fromJson({
        'id': 1,
        'is_common': true,
        'jlpt': 5,
        'headword': '食べる',
        'primary_reading': 'たべる',
        'kanji': [
          {'text': '食べる', 'is_common': true}
        ],
        'readings': [
          {'text': 'たべる', 'is_common': true}
        ],
        'senses': [
          {
            'pos': ['v1', 'vt'],
            'glosses': [
              {'language': 'en', 'text': 'to eat'},
              {'language': 'fr', 'text': 'manger'},
            ],
          }
        ],
      });
      expect(w.headword, '食べる');
      expect(w.summaryGloss('fr'), 'manger');
      expect(w.summaryGloss('en'), 'to eat');
      // Unknown language falls back to English.
      expect(w.summaryGloss('de'), 'to eat');
    });
  });

  group('StudyCard.fromJson', () {
    test('resolves the embedded kana item and front/back', () {
      final c = StudyCard.fromJson({
        'id': 7,
        'item_type': 'kana',
        'item_ref': 'く',
        'state': 0,
        'due': '2026-07-05T12:00:00Z',
        'reps': 0,
        'lapses': 0,
        'item': {'char': 'く', 'romaji': 'ku', 'script': 'hiragana', 'kind': 'gojuon'},
      });
      expect(c.itemType, ItemType.kana);
      expect(c.front, 'く');
      expect(c.meaning('en'), 'ku');
      expect(c.isNew, isTrue);
    });
  });
}
