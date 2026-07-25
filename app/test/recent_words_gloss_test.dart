import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/models/kana.dart';
import 'package:jibiki/models/kanji.dart';
import 'package:jibiki/models/word.dart';
import 'package:jibiki/repositories/auth_repository.dart';
import 'package:jibiki/repositories/dictionary_repository.dart';
import 'package:jibiki/repositories/mnemonic_deck_repository.dart';
import 'package:jibiki/repositories/study_repository.dart';
import 'package:jibiki/services/auth_service.dart';
import 'package:jibiki/services/dictionary_data_source.dart';
import 'package:jibiki/services/mnemonic_deck_service.dart';
import 'package:jibiki/services/study_service.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/viewmodels/app_state.dart';
import 'package:jibiki/viewmodels/dashboard_viewmodel.dart';
import 'package:jibiki/views/dashboard/tablet_dashboard_view.dart';
import 'package:jibiki/views/dictionary/search_view.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The word the seeded history entry resolves to. Its gloss must appear on the
/// "Seen recently" chip next to the headword.
final _sakura = WordEntry.fromJson({
  'id': 7,
  'is_common': true,
  'headword': '桜',
  'primary_reading': 'さくら',
  'kanji': const [],
  'readings': const [],
  'senses': const [
    {
      'pos': ['n'],
      'glosses': [
        {'language': 'en', 'text': 'cherry blossom'},
        {'language': 'en', 'text': 'cherry tree'},
      ],
    },
  ],
});

/// A distinct word for the editorial panels, so the recent chip's gloss can be
/// asserted without matching the word-of-the-day card.
final _cat = WordEntry.fromJson({
  'id': 1,
  'is_common': true,
  'headword': '猫',
  'primary_reading': 'ねこ',
  'kanji': const [],
  'readings': const [],
  'senses': const [
    {
      'pos': ['n'],
      'glosses': [
        {'language': 'en', 'text': 'cat'},
      ],
    },
  ],
});

class _DictionarySource implements DictionaryDataSource {
  @override
  Future<WordEntry> word(int id) async => id == 7 ? _sakura : _cat;

  @override
  Future<List<WordEntry>> words({
    bool common = false,
    int? jlpt,
    int limit = 60,
    int offset = 0,
  }) async =>
      [_cat];

  @override
  Future<SearchResults> search(
    String q, {
    String lang = 'en',
    int limit = 25,
  }) async =>
      SearchResults(words: [_cat], names: const []);

  @override
  Future<KanjiEntry> kanji(String literal) async =>
      throw UnimplementedError();

  @override
  Future<List<KanjiEntry>> kanjiList({
    int? jlpt,
    int? grade,
    String? contains,
    int limit = 120,
    int offset = 0,
  }) async =>
      const [];

  @override
  Future<List<KanaEntry>> kana({String? script}) async => const [];

  @override
  Future<KanaEntry> kanaDetail(String char) async => throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> radicals() async => const [];
}

Future<List<SingleChildWidget>> _providers() async {
  final prefs = await SharedPreferences.getInstance();
  final session = SessionStore(prefs);
  final api = ApiClient(session);
  final app = AppState(AuthRepository(AuthService(api), session));
  await app.bootstrap();
  final study = StudyService(api);
  return [
    ChangeNotifierProvider.value(value: app),
    Provider<DictionaryRepository>(
      create: (_) => DictionaryRepository(_DictionarySource()),
    ),
    Provider<MnemonicDeckRepository>(
      create: (_) => MnemonicDeckRepository(MnemonicDeckService(api)),
    ),
    ChangeNotifierProvider(
      create: (_) => DashboardViewModel(StudyRepository(study, study)),
    ),
  ];
}

Future<void> _pumpFrames(WidgetTester tester) async {
  // The dashboard keeps looping skeleton animations alive, so pumpAndSettle
  // would never return. Pump enough fixed frames for the landing data instead.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'recent_dictionary_words_v1': jsonEncode([
        {'word_id': 7, 'viewed_at': '2026-07-17T10:00:00.000'},
      ]),
    });
  });

  Future<void> setViewSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> pumpDashboard(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: await _providers(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TabletDashboardView(onOpenDictionary: ([String q = '']) {}),
          ),
        ),
      ),
    );
    await _pumpFrames(tester);
  }

  testWidgets('wide tablet dashboard recent chip shows the translation',
      (tester) async {
    await setViewSize(tester, const Size(1280, 800));
    await pumpDashboard(tester);

    expect(find.text('桜'), findsOneWidget);
    expect(find.text('cherry blossom'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two-column tablet dashboard recent chip shows the translation',
      (tester) async {
    await setViewSize(tester, const Size(900, 800));
    await pumpDashboard(tester);

    expect(find.text('桜'), findsOneWidget);
    expect(find.text('cherry blossom'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile search landing recent chip shows the translation',
      (tester) async {
    await setViewSize(tester, const Size(400, 800));

    await tester.pumpWidget(
      MultiProvider(
        providers: await _providers(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SearchView(),
        ),
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('桜'), findsOneWidget);
    expect(find.text('cherry blossom'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
