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

    test('sensesFor hides metadata-only senses without definitions', () {
      final w = WordEntry.fromJson({
        'id': 2,
        'is_common': false,
        'headword': '扉',
        'primary_reading': 'とびら',
        'kanji': const [],
        'readings': const [],
        'senses': [
          {
            'pos': ['n'],
            'glosses': const []
          },
          {
            'pos': const [],
            'glosses': [
              {'language': 'en', 'text': 'door'},
            ],
          },
        ],
      });
      expect(w.sensesFor('en'), hasLength(1));
      expect(w.sensesFor('en').single.glossesFor('en'), ['door']);
    });

    test('summaryGloss falls back to any definition rather than a blank card',
        () {
      // Requested language is English, but the word only carries a French
      // definition: show it instead of an empty subtitle.
      final frenchOnly = WordEntry.fromJson({
        'id': 4,
        'is_common': false,
        'headword': '扉',
        'primary_reading': 'とびら',
        'kanji': const [],
        'readings': const [],
        'senses': [
          {
            'pos': const [],
            'glosses': [
              {'language': 'fr', 'text': 'porte'},
            ],
          },
        ],
      });
      expect(frenchOnly.summaryGloss('en'), 'porte');

      // A word with no glosses at all still yields an empty string.
      final noGlosses = WordEntry.fromJson({
        'id': 5,
        'is_common': false,
        'headword': '扉',
        'primary_reading': 'とびら',
        'kanji': const [],
        'readings': const [],
        'senses': const [],
      });
      expect(noGlosses.summaryGloss('en'), '');
    });

    test('glossLanguageFor avoids mixing partial translations per word', () {
      final w = WordEntry.fromJson({
        'id': 3,
        'is_common': false,
        'headword': '扉',
        'primary_reading': 'とびら',
        'kanji': const [],
        'readings': const [],
        'senses': [
          {
            'pos': const [],
            'glosses': [
              {'language': 'en', 'text': 'door'},
            ],
          },
          {
            'pos': const [],
            'glosses': [
              {'language': 'fr', 'text': 'porte'},
            ],
          },
        ],
      });
      expect(w.glossLanguageFor('fr'), 'en');
      expect(w.sensesFor('fr').every((s) => s.hasGlossFor('en')), isTrue);
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
        'item': {
          'char': 'く',
          'romaji': 'ku',
          'script': 'hiragana',
          'kind': 'gojuon'
        },
      });
      expect(c.itemType, ItemType.kana);
      expect(c.front, 'く');
      expect(c.meaning('en'), 'ku');
      expect(c.isNew, isTrue);
    });
  });
}
