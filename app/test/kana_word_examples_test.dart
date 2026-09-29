import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jibiki/models/kana.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/views/widgets/kana_word_examples.dart';

void main() {
  for (final width in [390.0, 1024.0]) {
    testWidgets('lexical examples link to canonical words at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final kana = KanaEntry.fromJson({
        'char': 'い',
        'word_examples': [
          {
            'word_id': 42,
            'headword': '犬',
            'reading': 'いぬ',
            'glosses': [
              {'language': 'en', 'text': 'dog'}
            ],
            'provenance': {'review_status': 'structural_match'},
          }
        ]
      });
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, state) => Scaffold(
                body: SingleChildScrollView(
                    child: KanaWordExamplesSection(kana: kana)))),
        GoRoute(
            path: '/word/:id',
            builder: (_, state) =>
                Scaffold(body: Text('word ${state.pathParameters['id']}'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Mots contenant い'), findsOneWidget);
      expect(find.text('いぬ'), findsOneWidget);
      expect(
          find.text('Contenu en anglais · traduction française indisponible'),
          findsOneWidget);
      expect(
          find.text(
              'Lecture concordante avec JMdict · relecture non documentée'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('いぬ'));
      await tester.pumpAndSettle();
      expect(find.text('word 42'), findsOneWidget);
    });
  }
}
