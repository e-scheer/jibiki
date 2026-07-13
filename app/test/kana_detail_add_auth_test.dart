import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/api_exception.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/models/enums.dart';
import 'package:jibiki/models/kana.dart';
import 'package:jibiki/models/kanji.dart';
import 'package:jibiki/models/mnemonic.dart';
import 'package:jibiki/models/study.dart';
import 'package:jibiki/models/user.dart';
import 'package:jibiki/models/word.dart';
import 'package:jibiki/repositories/auth_repository.dart';
import 'package:jibiki/repositories/dictionary_repository.dart';
import 'package:jibiki/repositories/mnemonic_repository.dart';
import 'package:jibiki/repositories/study_repository.dart';
import 'package:jibiki/services/auth_service.dart';
import 'package:jibiki/services/dictionary_data_source.dart';
import 'package:jibiki/services/mnemonic_service.dart';
import 'package:jibiki/services/study_service.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/viewmodels/app_state.dart';
import 'package:jibiki/views/kana/kana_detail_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _KanaDictionarySource implements DictionaryDataSource {
  static final hiragana = KanaEntry.fromJson(const {
    'char': 'あ',
    'romaji': 'a',
    'script': 'hiragana',
    'kind': 'gojuon',
    'row': 'a',
    'order': 1,
    'usage_label': 'Sentence helper',
    'usage': 'Shows how this kana behaves in a sentence.',
  });
  static final katakana = KanaEntry.fromJson(const {
    'char': 'ア',
    'romaji': 'a',
    'script': 'katakana',
    'kind': 'gojuon',
    'row': 'a',
    'order': 1,
  });

  @override
  Future<List<KanaEntry>> kana({String? script}) async => [hiragana, katakana]
      .where((entry) => script == null || entry.script == script)
      .toList(growable: false);

  @override
  Future<KanaEntry> kanaDetail(String char) async =>
      char == katakana.char ? katakana : hiragana;

  @override
  Future<KanjiEntry> kanji(String literal) => throw UnimplementedError();

  @override
  Future<List<KanjiEntry>> kanjiList({
    int? jlpt,
    int? grade,
    String? contains,
    int limit = 120,
    int offset = 0,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> radicals() => throw UnimplementedError();

  @override
  Future<SearchResults> search(
    String q, {
    String lang = 'en',
    int limit = 25,
  }) =>
      throw UnimplementedError();

  @override
  Future<WordEntry> word(int id) => throw UnimplementedError();

  @override
  Future<List<WordEntry>> words({
    bool common = false,
    int? jlpt,
    int limit = 60,
    int offset = 0,
  }) =>
      throw UnimplementedError();
}

class _EmptyMnemonicRepository extends MnemonicRepository {
  _EmptyMnemonicRepository(super.service);

  @override
  Future<List<Mnemonic>> list({
    required String character,
    required String language,
    String kind = 'kana',
  }) async =>
      const [];
}

class _TrackingStudyRepository extends StudyRepository {
  _TrackingStudyRepository(
    StudyService service, {
    this.addError,
    this.readError,
  }) : super(service, service);

  final Object? addError;
  final Object? readError;
  int addCalls = 0;

  @override
  Future<StudyCard> addCard(
    ItemType type,
    String ref, {
    String sourceSentence = '',
    String sourceUrl = '',
    String sourceTitle = '',
    String sourceMedia = '',
  }) async {
    addCalls++;
    if (addError case final error?) throw error;
    return StudyCard(
      id: addCalls,
      itemType: type,
      itemRef: ref,
      state: 0,
      due: DateTime.now(),
      reps: 0,
      lapses: 0,
    );
  }

  @override
  Future<List<StudyCard>> cards({ItemType? type}) {
    if (readError case final error?) return Future.error(error);
    return Future.value(const []);
  }

  @override
  Future<Map<String, int>> studyStates({ItemType? type}) {
    if (readError case final error?) return Future.error(error);
    return Future.value(const {});
  }
}

class _AuthRepository extends AuthRepository {
  _AuthRepository(
    super.auth,
    super.session, {
    required this.sessionPresent,
  });

  final bool sessionPresent;

  @override
  bool get hasSession => sessionPresent;

  @override
  Future<AppUser> me() async => AppUser.fromJson(const {
        'id': 7,
        'email': 'expired@example.com',
        'profile': {
          'mode': 'learning',
          'mnemonic_language': 'en',
          'interface_language': 'en',
        },
      });
}

typedef _Dependencies = ({
  AppState app,
  DictionaryRepository dictionary,
  MnemonicRepository mnemonics,
  _TrackingStudyRepository study,
});

Future<_Dependencies> _dependencies({
  required bool authenticated,
  Object? addError,
  Object? studyReadError,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final session = SessionStore(prefs);
  final api = ApiClient(session);
  final app = AppState(
    _AuthRepository(
      AuthService(api),
      session,
      sessionPresent: authenticated,
    ),
  );
  await app.bootstrap();
  final studyService = StudyService(api);
  return (
    app: app,
    dictionary: DictionaryRepository(_KanaDictionarySource()),
    mnemonics: _EmptyMnemonicRepository(MnemonicService(api)),
    study: _TrackingStudyRepository(
      studyService,
      addError: addError,
      readError: studyReadError,
    ),
  );
}

Future<void> _pumpBothPane(
  WidgetTester tester,
  _Dependencies dependencies,
) async {
  await tester.binding.setSurfaceSize(const Size(1180, 820));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: dependencies.app),
        Provider<DictionaryRepository>.value(value: dependencies.dictionary),
        Provider<MnemonicRepository>.value(value: dependencies.mnemonics),
        Provider<StudyRepository>.value(value: dependencies.study),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: KanaDetailPane(char: 'あ', showBoth: true),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpMobileDetail(
  WidgetTester tester,
  _Dependencies dependencies,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: dependencies.app),
        Provider<DictionaryRepository>.value(value: dependencies.dictionary),
        Provider<MnemonicRepository>.value(value: dependencies.mnemonics),
        Provider<StudyRepository>.value(value: dependencies.study),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const KanaDetailView(char: 'あ'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .clearAllTestValues();
  });

  testWidgets(
    'embedded tablet detail keeps the kana grammar usage section',
    (tester) async {
      final dependencies = await _dependencies(authenticated: true);
      await _pumpBothPane(tester, dependencies);

      expect(find.text('In a sentence'), findsOneWidget);
      expect(find.text('Sentence helper'), findsOneWidget);
      expect(
        find.text('Shows how this kana behaves in a sentence.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'parallel study failures stay contained inside the kana detail',
    (tester) async {
      final dependencies = await _dependencies(
        authenticated: true,
        studyReadError: ApiException('Forbidden', statusCode: 403),
      );
      await _pumpBothPane(tester, dependencies);

      expect(find.text('Hiragana gesture · あ'), findsOneWidget);
      expect(find.text('Katakana gesture · ア'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unauthenticated Both tablet add opens the auth sheet without calling study',
    (tester) async {
      final dependencies = await _dependencies(authenticated: false);
      await _pumpBothPane(tester, dependencies);

      await tester.tap(find.bySemanticsLabel('Add both forms'));
      await tester.pumpAndSettle();

      expect(dependencies.study.addCalls, 0);
      expect(find.text('Save both kana forms'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.textContaining('__AUTH_REQUIRED__'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expired authenticated session turns addCard 401 into the auth sheet',
    (tester) async {
      final dependencies = await _dependencies(
        authenticated: true,
        addError: ApiException('Unauthorized', statusCode: 401),
      );
      await _pumpBothPane(tester, dependencies);

      await tester.tap(find.bySemanticsLabel('Add both forms'));
      await tester.pumpAndSettle();

      expect(dependencies.study.addCalls, 1);
      expect(find.text('Save both kana forms'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.textContaining('__AUTH_REQUIRED__'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unauthenticated mobile add uses the same auth sheet boundary',
    (tester) async {
      final dependencies = await _dependencies(authenticated: false);
      await _pumpMobileDetail(tester, dependencies);

      await tester.tap(find.bySemanticsLabel('Add to study'));
      await tester.pumpAndSettle();

      expect(dependencies.study.addCalls, 0);
      expect(find.text('Save this kana'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.textContaining('__AUTH_REQUIRED__'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
