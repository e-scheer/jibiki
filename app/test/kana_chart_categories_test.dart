import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/models/enums.dart';
import 'package:jibiki/models/kana.dart';
import 'package:jibiki/models/kanji.dart';
import 'package:jibiki/models/mnemonic.dart';
import 'package:jibiki/models/study.dart';
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
import 'package:jibiki/views/kana/kana_cell.dart';
import 'package:jibiki/views/kana/kana_chart_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _KanaDictionarySource implements DictionaryDataSource {
  static final entries = <KanaEntry>[
    _entry('あ', 'a', 'hiragana', 'gojuon', 'a', 1),
    _entry('ア', 'a', 'katakana', 'gojuon', 'a', 1),
    _entry('が', 'ga', 'hiragana', 'dakuten', 'g', 2),
    _entry('ガ', 'ga', 'katakana', 'dakuten', 'g', 2),
    _entry('ぱ', 'pa', 'hiragana', 'handakuten', 'p', 3),
    _entry('パ', 'pa', 'katakana', 'handakuten', 'p', 3),
    _entry('きゃ', 'kya', 'hiragana', 'yoon', 'ky', 4),
    _entry('キャ', 'kya', 'katakana', 'yoon', 'ky', 4),
  ];

  static KanaEntry _entry(
    String char,
    String romaji,
    String script,
    String kind,
    String row,
    int order,
  ) =>
      KanaEntry(
        char: char,
        romaji: romaji,
        script: script,
        kind: kind,
        row: row,
        order: order,
      );

  @override
  Future<List<KanaEntry>> kana({String? script}) async => entries
      .where((entry) => script == null || entry.script == script)
      .toList(growable: false);

  @override
  Future<KanaEntry> kanaDetail(String char) async =>
      entries.singleWhere((entry) => entry.char == char);

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

class _EmptyStudyRepository extends StudyRepository {
  _EmptyStudyRepository(StudyService service) : super(service, service);

  @override
  Future<List<StudyCard>> cards({ItemType? type}) async => const [];

  @override
  Future<Map<String, int>> studyStates({ItemType? type}) async => const {};
}

Future<Widget> _app() async {
  final prefs = await SharedPreferences.getInstance();
  final session = SessionStore(prefs);
  final api = ApiClient(session);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppState>.value(
        value: AppState(AuthRepository(AuthService(api), session)),
      ),
      Provider<DictionaryRepository>(
        create: (_) => DictionaryRepository(_KanaDictionarySource()),
      ),
      Provider<MnemonicRepository>(
        create: (_) => _EmptyMnemonicRepository(MnemonicService(api)),
      ),
      Provider<StudyRepository>(
        create: (_) => _EmptyStudyRepository(StudyService(api)),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const KanaChartView(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'expanded chart keeps every category visible and preserves Both pairs',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(await _app());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final label in ['Basic', 'Dakuten', 'Handakuten', 'Yōon']) {
        final control = find.text(label);
        expect(control, findsOneWidget);
        expect(tester.getRect(control).bottom, lessThan(250));
      }

      Future<void> selectSingle({
        required String category,
        required String char,
        required String romaji,
      }) async {
        await tester.tap(find.text(category));
        await tester.pumpAndSettle();

        final cell = tester.widget<KanaCell>(find.byType(KanaCell));
        expect(cell.entries.map((entry) => entry.char), [char]);
        expect(cell.entries.single.romaji, romaji);
        expect(cell.focused, isTrue);
        expect(find.text(char), findsWidgets);
        expect(tester.takeException(), isNull);
      }

      await selectSingle(category: 'Dakuten', char: 'が', romaji: 'ga');
      await selectSingle(category: 'Handakuten', char: 'ぱ', romaji: 'pa');
      await selectSingle(category: 'Yōon', char: 'きゃ', romaji: 'kya');

      await tester.tap(find.text('Both'));
      await tester.pumpAndSettle();

      Future<void> selectPair({
        required String category,
        required String hiragana,
        required String katakana,
        required String romaji,
      }) async {
        await tester.tap(find.text(category));
        await tester.pumpAndSettle();

        final cell = tester.widget<KanaCell>(find.byType(KanaCell));
        expect(
          cell.entries.map((entry) => entry.char),
          [hiragana, katakana],
        );
        expect(cell.entries.map((entry) => entry.romaji).toSet(), {romaji});
        expect(cell.focused, isTrue);
        expect(find.text(hiragana), findsWidgets);
        expect(find.text(katakana), findsWidgets);
        expect(find.text('Hiragana + Katakana'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      await selectPair(
        category: 'Dakuten',
        hiragana: 'が',
        katakana: 'ガ',
        romaji: 'ga',
      );
      await selectPair(
        category: 'Handakuten',
        hiragana: 'ぱ',
        katakana: 'パ',
        romaji: 'pa',
      );
      await selectPair(
        category: 'Yōon',
        hiragana: 'きゃ',
        katakana: 'キャ',
        romaji: 'kya',
      );

      expect(tester.takeException(), isNull);
    },
  );
}
