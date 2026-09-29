import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/models/kanji.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/views/widgets/kanjialive_radical_section.dart';

void main() {
  for (final width in [390.0, 1024.0]) {
    testWidgets('source radical renders on width $width without private glyphs',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final kanji = KanjiEntry.fromJson({
        'literal': '一',
        'metadata': {
          'kanjialive': {
            'radical': {
              'literal': '',
              'source_literal': '\ue731',
              'glyph_available': false,
              'reading': 'のかんむり',
              'meaning': 'diagonal sweeping stroke',
              'meaning_language': 'en',
              'position': 'かんむり',
            }
          }
        }
      });
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
            body: SingleChildScrollView(
                child: KanjiAliveRadicalSection(kanji: kanji))),
      ));
      expect(find.text('Radical selon Kanji alive'), findsOneWidget);
      expect(find.text('のかんむり'), findsOneWidget);
      expect(find.text('\ue731'), findsNothing);
      expect(find.text('Kanji alive · CC BY 4.0'), findsOneWidget);
      expect(
          find.text('Contenu en anglais · traduction française indisponible'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
