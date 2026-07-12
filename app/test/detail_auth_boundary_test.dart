import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/models/enums.dart';
import 'package:jibiki/models/kana.dart';
import 'package:jibiki/models/kanji.dart';
import 'package:jibiki/models/study.dart';
import 'package:jibiki/models/word.dart';
import 'package:jibiki/repositories/auth_repository.dart';
import 'package:jibiki/repositories/dictionary_repository.dart';
import 'package:jibiki/repositories/study_repository.dart';
import 'package:jibiki/services/auth_service.dart';
import 'package:jibiki/services/dictionary_data_source.dart';
import 'package:jibiki/services/study_service.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/viewmodels/app_state.dart';
import 'package:jibiki/viewmodels/kanji_detail_viewmodel.dart';
import 'package:jibiki/viewmodels/word_detail_viewmodel.dart';
import 'package:jibiki/views/kana/kana_chart_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DictionarySource implements DictionaryDataSource {
  final wordEntry = WordEntry.fromJson({
    'id': 7,
    'is_common': true,
    'headword': '猫',
    'primary_reading': 'ねこ',
    'kanji': const [],
    'readings': const [],
    'senses': const [],
  });

  final kanjiEntry = KanjiEntry.fromJson({
    'literal': '日',
    'stroke_count': 4,
    'on_readings': const ['ニチ'],
    'kun_readings': const ['ひ'],
    'meanings': const [
      {'language': 'en', 'text': 'sun'},
    ],
  });

  final kanaEntry = KanaEntry.fromJson(const {
    'char': 'あ',
    'romaji': 'a',
    'script': 'hiragana',
    'kind': 'gojuon',
    'row': 'a',
    'order': 1,
  });

  @override
  Future<KanjiEntry> kanji(String literal) async => kanjiEntry;

  @override
  Future<List<KanjiEntry>> kanjiList({
    int? jlpt,
    int? grade,
    String? contains,
    int limit = 120,
    int offset = 0,
  }) async =>
      [kanjiEntry];

  @override
  Future<List<KanaEntry>> kana({String? script}) async => [kanaEntry];

  @override
  Future<KanaEntry> kanaDetail(String char) async => kanaEntry;

  @override
  Future<List<Map<String, dynamic>>> radicals() async => const [];

  @override
  Future<SearchResults> search(
    String q, {
    String lang = 'en',
    int limit = 25,
  }) async =>
      SearchResults(words: [wordEntry], names: const []);

  @override
  Future<WordEntry> word(int id) async => wordEntry;

  @override
  Future<List<WordEntry>> words({
    bool common = false,
    int? jlpt,
    int limit = 60,
    int offset = 0,
  }) async =>
      [wordEntry];
}

class _TrackingStudyRepository extends StudyRepository {
  _TrackingStudyRepository(
    StudyService service, {
    this.states = const {},
    this.failIfStatesRequested = false,
  }) : super(service, service);

  final Map<String, int> states;
  final bool failIfStatesRequested;
  int stateRequests = 0;

  @override
  Future<Map<String, int>> studyStates({ItemType? type}) async {
    stateRequests++;
    if (failIfStatesRequested) {
      throw StateError('study states must not be requested');
    }
    return states;
  }

  @override
  Future<List<StudyCard>> cards({ItemType? type}) async => const [];
}

Future<StudyService> _studyService() async {
  final prefs = await SharedPreferences.getInstance();
  return StudyService(ApiClient(SessionStore(prefs)));
}

Future<AppState> _unauthenticatedAppState() async {
  final prefs = await SharedPreferences.getInstance();
  final session = SessionStore(prefs);
  final app =
      AppState(AuthRepository(AuthService(ApiClient(session)), session));
  await app.bootstrap();
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('unauthenticated word detail keeps public content and skips study state',
      () async {
    final source = _DictionarySource();
    final study = _TrackingStudyRepository(
      await _studyService(),
      failIfStatesRequested: true,
    );
    final vm = WordDetailViewModel(
      DictionaryRepository(source),
      study,
      7,
      loadStudyState: false,
    );

    await vm.load();

    expect(vm.word?.headword, '猫');
    expect(vm.hasError, isFalse);
    expect(vm.status, 'none');
    expect(study.stateRequests, 0);
  });

  test(
      'unauthenticated kanji detail keeps public content and skips study state',
      () async {
    final source = _DictionarySource();
    final study = _TrackingStudyRepository(
      await _studyService(),
      failIfStatesRequested: true,
    );
    final vm = KanjiDetailViewModel(
      DictionaryRepository(source),
      study,
      '日',
      loadStudyState: false,
    );

    await vm.load();

    expect(vm.kanji?.literal, '日');
    expect(vm.hasError, isFalse);
    expect(vm.status, 'none');
    expect(study.stateRequests, 0);
  });

  test('authenticated detail viewmodels still resolve study status', () async {
    final source = _DictionarySource();
    final study = _TrackingStudyRepository(
      await _studyService(),
      states: const {'7': 2, '日': 1},
    );
    final word = WordDetailViewModel(
      DictionaryRepository(source),
      study,
      7,
      loadStudyState: true,
    );
    final kanji = KanjiDetailViewModel(
      DictionaryRepository(source),
      study,
      '日',
      loadStudyState: true,
    );

    await word.load();
    await kanji.load();

    expect(word.status, 'known');
    expect(kanji.status, 'learning');
    expect(study.stateRequests, 2);
  });

  testWidgets('Review due kana soft-blocks with sign-in sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final source = _DictionarySource();
    final study = _TrackingStudyRepository(await _studyService());
    final app = await _unauthenticatedAppState();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: app),
          Provider<DictionaryRepository>(
            create: (_) => DictionaryRepository(source),
          ),
          Provider<StudyRepository>.value(value: study),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const KanaChartView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review due kana'));
    await tester.pumpAndSettle();

    expect(find.text('Review your kana'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
