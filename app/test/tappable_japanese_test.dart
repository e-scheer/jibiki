import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/views/widgets/tappable_japanese.dart';

void main() {
  group('lookupableChars', () {
    test('splits a word into its kanji and kana in order', () {
      final cs = lookupableChars('食べる');
      expect(cs.map((c) => c.char).toList(), ['食', 'べ', 'る']);
      expect(cs.first.isKanji, isTrue);
      expect(cs[1].isKanji, isFalse);
    });

    test('drops small kana, marks and non-Japanese', () {
      expect(lookupableChars('しゃ').map((c) => c.char).toList(), ['し']); // ゃ excluded
      expect(lookupableChars('コーヒー').map((c) => c.char).toList(), ['コ', 'ヒ']); // ー excluded
      expect(lookupableChars('Hello 123 !'), isEmpty);
    });

    test('dedupes repeated characters, keeping first-seen order', () {
      expect(lookupableChars('ここ').map((c) => c.char).toList(), ['こ']);
      expect(lookupableChars('日本日').map((c) => c.char).toList(), ['日', '本']);
    });
  });

  group('TappableJapanese widget', () {
    testWidgets('a plain (non-Japanese) string renders inert text', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: TappableJapanese('hello')),
      ));
      expect(find.text('hello'), findsOneWidget);
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('tapping a multi-character word opens a breakdown sheet', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Center(child: TappableJapanese('日本語'))),
      ));
      await tester.tap(find.text('日本語'));
      await tester.pumpAndSettle();
      expect(find.text('Tap a character to look it up'), findsOneWidget);
      // one tile per unique kanji
      expect(find.text('日'), findsOneWidget);
      expect(find.text('本'), findsOneWidget);
      expect(find.text('語'), findsOneWidget);
      expect(find.text('Kanji'), findsNWidgets(3));
    });

    testWidgets('a kana word breaks down into per-kana tiles', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Center(child: TappableJapanese('あい'))),
      ));
      await tester.tap(find.text('あい'));
      await tester.pumpAndSettle();
      expect(find.text('あ'), findsOneWidget);
      expect(find.text('い'), findsOneWidget);
      // With no repository in scope the romaji lookup degrades gracefully to the
      // "Kana" label rather than throwing (in the app it shows a/i etc.).
      expect(find.text('Kana'), findsNWidgets(2));
    });
  });
}
