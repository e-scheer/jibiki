import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/infrastructure/packs/pack_manager.dart';
import 'package:jibiki/models/enums.dart';
import 'package:jibiki/models/kana.dart';
import 'package:jibiki/models/kanji.dart';
import 'package:jibiki/repositories/auth_repository.dart';
import 'package:jibiki/repositories/dictionary_repository.dart';
import 'package:jibiki/repositories/study_repository.dart';
import 'package:jibiki/services/auth_service.dart';
import 'package:jibiki/services/dictionary_service.dart';
import 'package:jibiki/services/study_service.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/viewmodels/app_state.dart';
import 'package:jibiki/viewmodels/onboarding_viewmodel.dart';
import 'package:jibiki/views/onboarding/onboarding_view.dart';
import 'package:jibiki/views/widgets/neo_pop.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingStudyRepository extends StudyRepository {
  _RecordingStudyRepository(StudyService service) : super(service, service);

  List<({ItemType type, String ref})> lastItems = const [];
  bool? lastKnown;
  Completer<Map<String, dynamic>>? pendingBulkAdd;
  final bulkAddStarted = Completer<void>();

  @override
  Future<Map<String, dynamic>> bulkAdd(
    List<({ItemType type, String ref})> items, {
    bool known = false,
  }) {
    lastItems = List.of(items);
    lastKnown = known;
    if (!bulkAddStarted.isCompleted) bulkAddStarted.complete();
    return pendingBulkAdd?.future ??
        Future.value(<String, dynamic>{'created': items.length});
  }
}

class _FakeDictionaryRepository extends DictionaryRepository {
  // The superclass parameter is private to its library, so it cannot be a
  // super-formal parameter here.
  // ignore: use_super_parameters
  _FakeDictionaryRepository(
    DictionaryService service, {
    this.kanaEntries = const [],
    this.jlptEntries = const {},
  }) : super(service);

  final List<KanaEntry> kanaEntries;
  final Map<int, List<KanjiEntry>> jlptEntries;
  final List<int> requestedJlptLevels = [];
  final List<int> requestedLimits = [];

  @override
  Future<List<KanaEntry>> kana() async => kanaEntries;

  @override
  Future<List<KanjiEntry>> kanjiList({
    int? jlpt,
    int? grade,
    String? contains,
    int limit = 120,
    int offset = 0,
  }) async {
    requestedJlptLevels.add(jlpt!);
    requestedLimits.add(limit);
    return jlptEntries[jlpt] ?? const [];
  }
}

class _Harness {
  const _Harness({
    required this.app,
    required this.study,
    required this.dictionary,
    required this.vm,
  });

  final AppState app;
  final _RecordingStudyRepository study;
  final _FakeDictionaryRepository dictionary;
  final OnboardingViewModel vm;
}

KanaEntry _kana(String char, String script, int order) => KanaEntry(
      char: char,
      romaji: char,
      script: script,
      kind: 'gojuon',
      row: 'a',
      order: order,
    );

KanjiEntry _kanji(String literal, int jlpt) => KanjiEntry(
      literal: literal,
      grade: null,
      strokeCount: 1,
      jlpt: jlpt,
      freqRank: null,
      onReadings: const [],
      kunReadings: const [],
      nanori: const [],
      components: const [],
      meanings: const [],
    );

Future<_Harness> _harness({
  List<KanaEntry> kana = const [],
  Map<int, List<KanjiEntry>> jlpt = const {},
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final session = SessionStore(prefs);
  final api = ApiClient(session);
  final app = AppState(AuthRepository(AuthService(api), session));
  await app.bootstrap();
  await app.continueWithoutAccount();

  final study = _RecordingStudyRepository(StudyService(api));
  final dictionary = _FakeDictionaryRepository(
    DictionaryService(api),
    kanaEntries: kana,
    jlptEntries: jlpt,
  );
  return _Harness(
    app: app,
    study: study,
    dictionary: dictionary,
    vm: OnboardingViewModel(app, null, study, dictionary),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final canonicalKana = [
    _kana('あ', 'hiragana', 1),
    _kana('が', 'hiragana', 2),
    _kana('ア', 'katakana', 3),
    _kana('ガ', 'katakana', 4),
  ];

  for (final testCase in [
    (
      placement: OnboardingPlacement.hiragana,
      expected: const {'あ', 'が'},
    ),
    (
      placement: OnboardingPlacement.katakana,
      expected: const {'ア', 'ガ'},
    ),
    (
      placement: OnboardingPlacement.allKana,
      expected: const {'あ', 'が', 'ア', 'ガ'},
    ),
  ]) {
    test('${testCase.placement.name} uses the canonical dictionary syllabary',
        () async {
      final h = await _harness(kana: canonicalKana);
      h.vm.selectPlacement(testCase.placement);

      expect(await h.vm.finish(), isTrue);
      expect(h.study.lastKnown, isTrue);
      expect(
        h.study.lastItems.map((item) => item.ref).toSet(),
        testCase.expected,
      );
      expect(
        h.study.lastItems.every((item) => item.type == ItemType.kana),
        isTrue,
      );
    });
  }

  test('JLPT placement is cumulative and reads canonical repository levels',
      () async {
    final h = await _harness(jlpt: {
      5: [_kanji('日', 5)],
      4: [_kanji('本', 4)],
      3: [_kanji('語', 3), _kanji('日', 3)],
    });
    h.vm.selectPlacement(OnboardingPlacement.jlpt3);

    expect(await h.vm.finish(), isTrue);
    expect(h.dictionary.requestedJlptLevels, [5, 4, 3]);
    expect(h.dictionary.requestedLimits, everyElement(1500));
    expect(
      h.study.lastItems.map((item) => item.ref).toSet(),
      {'日', '本', '語'},
    );
    expect(
      h.study.lastItems.every((item) => item.type == ItemType.kanji),
      isTrue,
    );
  });

  test('specific characters deduplicate and ignore unsupported text', () async {
    final h = await _harness();
    h.vm.selectPlacement(OnboardingPlacement.specific);
    expect(h.vm.canContinuePlacement, isFalse);

    h.vm.setKnownCharacters('日本日 abc あ!');
    expect(h.vm.specificCharacterCount, 3);
    expect(h.vm.canContinuePlacement, isTrue);
    expect(await h.vm.finish(), isTrue);
    expect(
      h.study.lastItems.toSet(),
      {
        (type: ItemType.kanji, ref: '日'),
        (type: ItemType.kanji, ref: '本'),
        (type: ItemType.kana, ref: 'あ'),
      },
    );
  });

  test('every onboarding mutation is locked while finish is running', () async {
    final h = await _harness();
    await h.vm.goToPlacementStep();
    h.vm.selectPlacement(OnboardingPlacement.specific);
    h.vm.setKnownCharacters('日');
    final offer = PackOffer(id: 'test', title: 'Test', blurb: 'Test');
    h.study.pendingBulkAdd = Completer<Map<String, dynamic>>();

    final finishing = h.vm.finish();
    await h.study.bulkAddStarted.future;
    expect(h.vm.isLoading, isTrue);

    h.vm.selectMode(AppMode.learning);
    h.vm.selectLanguage('fr');
    h.vm.selectPlacement(OnboardingPlacement.fresh);
    h.vm.setKnownCharacters('本');
    h.vm.toggleOffer(offer, true);
    h.vm.backToProfileStep();
    await h.vm.goToDataStep();

    expect(h.vm.mode, AppMode.middle);
    expect(h.vm.language, 'en');
    expect(h.vm.placement, OnboardingPlacement.specific);
    expect(h.vm.knownCharacters, '日');
    expect(offer.selected, isFalse);
    expect(h.vm.step, 1);
    expect(await h.vm.finish(), isFalse, reason: 'reentrant finish is blocked');

    h.study.pendingBulkAdd!.complete({'created': 1});
    expect(await finishing, isTrue);
    expect(h.vm.isLoading, isFalse);
  });

  test('an unavailable canonical level stays on onboarding with a useful error',
      () async {
    final h = await _harness();
    h.vm.selectPlacement(OnboardingPlacement.jlpt5);

    expect(await h.vm.finish(), isFalse);
    expect(h.vm.hasError, isTrue);
    expect(
      h.vm.error,
      'We could not load this level. Check your connection and try again.',
    );
    expect(h.app.onboarded, isFalse);
  });

  testWidgets('mode and placement cards use exact equal grid heights',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final h = await _harness(kana: canonicalKana);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: h.app),
          Provider<PackManager?>.value(value: null),
          Provider<StudyRepository>.value(value: h.study),
          Provider<DictionaryRepository>.value(value: h.dictionary),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const OnboardingView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Size cardSize(String label) => tester.getSize(
          find
              .ancestor(of: find.text(label), matching: find.byType(NeoCard))
              .first,
        );

    final modeHeights = [
      for (final label in ['Dictionary', 'Balanced', 'Learning'])
        cardSize(label).height,
    ];
    expect(modeHeights.toSet(), {204.0});

    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final placementHeights = [
      for (final label in [
        'Start fresh',
        'I know specific characters',
        'Hiragana',
        'Katakana',
        'All kana',
        'JLPT N5',
        'JLPT N4',
        'JLPT N3',
        'JLPT N2',
        'JLPT N1',
      ])
        cardSize(label).height,
    ];
    expect(placementHeights.toSet(), {168.0});
  });
}
