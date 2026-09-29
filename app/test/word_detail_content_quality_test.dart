import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/l10n/l10n.dart';
import 'package:jibiki/models/word.dart';
import 'package:jibiki/repositories/auth_repository.dart';
import 'package:jibiki/repositories/dictionary_repository.dart';
import 'package:jibiki/repositories/study_repository.dart';
import 'package:jibiki/services/auth_service.dart';
import 'package:jibiki/services/dictionary_data_source.dart';
import 'package:jibiki/services/study_service.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/viewmodels/app_state.dart';
import 'package:jibiki/views/dictionary/word_detail_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FrenchGuest extends AppState {
  _FrenchGuest(super.auth);
  @override
  String get mnemonicLanguage => 'fr';
  @override
  bool get canStudy => false;
}

class _Source implements DictionaryDataSource {
  _Source({this.withOrigin = false, this.historical = false});
  final bool withOrigin;
  final bool historical;
  @override
  Future<WordEntry> word(int id) async => WordEntry.fromJson({
        'id': id,
        'headword': 'かな',
        'primary_reading': 'かな',
        'provenance': {
          if (historical) 'source_status': 'upstream_not_in_snapshot'
        },
        'kanji_breakdown': [
          {
            'literal': '日',
            'meanings': [
              {'language': 'en', 'text': 'sun'}
            ],
            'origin': withOrigin
                ? 'Documented English origin, shown completely.'
                : '',
            'origin_language': withOrigin ? 'en' : '',
          },
        ],
        'readings': [
          {'text': 'かな', 'pitch': ''},
          {'text': 'べつ', 'pitch': '99'},
        ],
        'senses': [
          for (var i = 1; i <= 6; i++)
            {
              'order': i,
              'glosses': [
                {'language': 'fr', 'text': 'sens complet $i'}
              ],
              if (i == 5) ...{
                'notes': [
                  {
                    'language': 'fr',
                    'text': 'Note française du cinquième sens'
                  },
                  {'language': 'en', 'text': 'Unselected English note'}
                ],
                'misc': ['colloquial'],
                'field': ['linguistics'],
                'metadata': {
                  'restricted_readings': ['かな'],
                  'restricted_kanji': ['仮名']
                },
              },
            }
        ],
        'examples': [
          {
            'japanese': 'これは二十文字で切られずに最後まで表示される例文です。',
            'translation': 'Old English default',
            'language': 'en',
            'translations': [
              {'language': 'fr', 'text': 'Première traduction française'},
              {'language': 'en', 'text': 'Old English default'}
            ]
          },
          {
            'japanese': '最後の例文。',
            'translation': 'Second English example',
            'language': 'en'
          },
        ],
      });
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final (width, withOrigin, historical) in [
    (390.0, false, false),
    (1024.0, false, false),
    (1024.0, true, false),
    (390.0, false, true),
  ]) {
    testWidgets(
        'all senses, notes and full examples remain accessible at $width (origin=$withOrigin historical=$historical)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = SessionStore(prefs);
      final api = ApiClient(session);
      final app = _FrenchGuest(AuthRepository(AuthService(api), session));
      final study = StudyService(api);
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: app),
            Provider(
                create: (_) => DictionaryRepository(
                    _Source(withOrigin: withOrigin, historical: historical))),
            Provider(create: (_) => StudyRepository(study, study)),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: width < 600
                ? const WordDetailView(wordId: 1)
                : const Scaffold(body: WordDetailPane(wordId: 1)),
          )));
      await tester.pumpAndSettle();
      if (historical) {
        expect(find.textContaining('Cette entrée historique'), findsOneWidget);
      }
      expect(find.textContaining('pitch 99'), findsNothing);
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('sens complet 6'), 250,
          scrollable: scrollable);
      expect(find.text('sens complet 6'), findsOneWidget);
      expect(find.text('Note française du cinquième sens'), findsOneWidget);
      expect(find.textContaining('Avec ces lectures'), findsOneWidget);
      expect(find.textContaining('Avec ces graphies'), findsOneWidget);
      expect(find.text('Unselected English note'), findsNothing);
      if (width > 600) {
        final memory = find.text(withOrigin
            ? 'Documented English origin, shown completely.'
            : 'Stratégie d’étude suggérée');
        await tester.scrollUntilVisible(memory, 250, scrollable: scrollable);
        expect(memory, findsOneWidget);
        expect(find.text('D’après le dictionnaire'), findsNothing);
        if (withOrigin) {
          expect(find.textContaining('traduction française indisponible'),
              findsOneWidget);
        }
      }
      await tester.scrollUntilVisible(find.text('Second English example'), 250,
          scrollable: scrollable);
      expect(find.text('Second English example'), findsOneWidget);
      expect(find.text('Première traduction française'), findsOneWidget);
      expect(find.text('Old English default'), findsNothing);
      expect(find.textContaining('Langue du contenu'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });
  }
}
