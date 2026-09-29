import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/models/kana.dart';
import 'package:jibiki/models/kanji.dart';
import 'package:jibiki/l10n/l10n.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/views/widgets/origin_section.dart';
import 'package:jibiki/views/widgets/speech_button.dart';

KanjiEntry _kanji(
        {String origin = '',
        String formation = '',
        String phonetic = '',
        Map<String, dynamic> provenance = const {}}) =>
    KanjiEntry.fromJson({
      'literal': '電',
      'stroke_count': 13,
      'origin': origin,
      'origin_language': 'en',
      'provenance': provenance,
      'formation': formation,
      'phonetic': phonetic,
      'meanings': const [],
    });

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('KanjiOriginSection', () {
    testWidgets('renders prose, formation badge and the 音符 phonetic callout',
        (tester) async {
      await tester.pumpWidget(_host(KanjiOriginSection(
        kanji: _kanji(
          origin: 'Phono-semantic compound: semantic 雨 + phonetic 申.',
          formation: 'phono-semantic',
          phonetic: '申',
        ),
      )));
      expect(find.text('Origin'), findsOneWidget);
      expect(
          find.textContaining('Phono-semantic'), findsWidgets); // prose + badge
      expect(find.textContaining('音符'), findsOneWidget);
      expect(find.text('申'), findsOneWidget); // the highlighted phonetic glyph
      expect(find.textContaining('Wiktionary'), findsNothing);
      expect(find.textContaining('source not documented'), findsOneWidget);
    });

    testWidgets('collapses to nothing when there is no origin', (tester) async {
      await tester.pumpWidget(_host(KanjiOriginSection(kanji: _kanji())));
      expect(find.text('Origin'), findsNothing);
    });

    testWidgets('shows no phonetic callout for a pictogram', (tester) async {
      await tester.pumpWidget(_host(KanjiOriginSection(
        kanji: _kanji(
            origin: 'Pictogram - a cloud with rain.', formation: 'pictogram'),
      )));
      expect(find.textContaining('音符'), findsNothing);
      expect(find.textContaining('Pictogram'), findsWidgets);
    });

    for (final width in [390.0, 1024.0]) {
      for (final documented in [false, true]) {
        testWidgets(
            'origin language and attribution stay accurate at $width (source=$documented)',
            (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(_host(
              Padding(
                padding: const EdgeInsets.all(16),
                child: KanjiOriginSection(
                    kanji: _kanji(
                  origin: 'Complete English origin explanation.',
                  formation: 'phono-semantic',
                  phonetic: '申',
                  provenance: documented
                      ? {
                          'wiktionary': {
                            'source_url': 'https://en.wiktionary.org/wiki/電'
                          }
                        }
                      : const {},
                )),
              ),
              locale: const Locale('fr')));
          await tester.pumpAndSettle();
          expect(find.textContaining('traduction française indisponible'),
              findsOneWidget);
          expect(find.textContaining('Phono-sémantique'), findsOneWidget);
          expect(find.text('申 suggère une lecture de ce caractère.'),
              findsOneWidget);
          expect(find.text('Complete English origin explanation.'),
              findsOneWidget);
          expect(
              find.textContaining(
                  documented ? 'Wiktionary' : 'source non documentée'),
              findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('KanaOriginSection', () {
    testWidgets('shows the source → kana derivation diagram and note',
        (tester) async {
      final kana = KanaEntry.fromJson({
        'char': 'あ',
        'romaji': 'a',
        'script': 'hiragana',
        'kind': 'gojuon',
        'origin': '安',
        'origin_note': "Cursive simplification of the man'yōgana kanji 安.",
      });
      await tester.pumpWidget(_host(KanaOriginSection(kana: kana)));
      expect(find.text('Origin'), findsOneWidget);
      expect(find.text('安'), findsOneWidget); // source glyph
      expect(find.text('あ'), findsOneWidget); // derived kana
      expect(find.textContaining('Cursive simplification'), findsOneWidget);
    });
  });

  group('KanaGrammarSection', () {
    testWidgets('shows the role badge and sentence usage for a particle',
        (tester) async {
      final ha = KanaEntry.fromJson({
        'char': 'は',
        'romaji': 'ha',
        'script': 'hiragana',
        'kind': 'gojuon',
        'usage_label': 'Topic particle',
        'usage': 'Marks the topic - read wa when it is the particle.',
      });
      await tester.pumpWidget(_host(KanaGrammarSection(kana: ha)));
      expect(find.text('In a sentence'), findsOneWidget);
      expect(find.text('Topic particle'), findsOneWidget);
      expect(find.textContaining('Marks the topic'), findsOneWidget);
    });

    testWidgets('renders example sentences with romaji, translation and audio',
        (tester) async {
      final ha = KanaEntry.fromJson({
        'char': 'は',
        'romaji': 'ha',
        'script': 'hiragana',
        'kind': 'gojuon',
        'usage_label': 'Topic particle',
        'usage': 'Marks the topic.',
        'usage_examples': [
          {
            'before': '私',
            'particle': 'は',
            'after': '学生です。',
            'pronunciation': 'Watashi wa gakusei desu.',
            'translation': 'I am a student.',
          },
          {
            'before': '今日',
            'particle': 'は',
            'after': '暑いです。',
            'pronunciation': 'Kyō wa atsui desu.',
            'translation': "It's hot today.",
          },
        ],
      });
      await tester.pumpWidget(_host(KanaGrammarSection(kana: ha)));
      expect(find.textContaining('学生です', findRichText: true), findsOneWidget);
      expect(find.text('Watashi wa gakusei desu.'), findsOneWidget);
      expect(find.text('I am a student.'), findsOneWidget);
      expect(find.text("It's hot today."), findsOneWidget);
      // one speaker per example sentence
      expect(find.byType(SpeechButton), findsNWidgets(2));
    });

    testWidgets('collapses for a purely phonetic kana', (tester) async {
      final ki = KanaEntry.fromJson({
        'char': 'き',
        'romaji': 'ki',
        'script': 'hiragana',
        'kind': 'gojuon'
      });
      await tester.pumpWidget(_host(KanaGrammarSection(kana: ki)));
      expect(find.text('In a sentence'), findsNothing);
    });
  });
}
