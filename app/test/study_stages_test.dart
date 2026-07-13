import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/models/enums.dart';
import 'package:jibiki/models/kanji.dart';
import 'package:jibiki/models/study.dart';
import 'package:jibiki/repositories/study_repository.dart';
import 'package:jibiki/services/study_service.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/viewmodels/review_viewmodel.dart';
import 'package:jibiki/views/study/listen_stage.dart';
import 'package:jibiki/views/study/match_stage.dart';
import 'package:jibiki/views/study/quiz_stage.dart';
import 'package:jibiki/views/study/study_feedback.dart';
import 'package:jibiki/views/study/swipe_stage.dart';
import 'package:jibiki/views/widgets/pressable.dart';
import 'package:jibiki/views/widgets/vertical_overflow_cue.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A kanji card with one English meaning and a kun reading, so both the swipe
/// answer block and the quiz distractors have real content to render.
StudyCard _kanji(int id, String literal, String meaning, String kun) =>
    StudyCard(
      id: id,
      itemType: ItemType.kanji,
      itemRef: literal,
      state: 2,
      due: DateTime(2020),
      reps: 1,
      lapses: 0,
      kanji: KanjiEntry(
        literal: literal,
        grade: 1,
        strokeCount: 4,
        jlpt: 5,
        freqRank: null,
        onReadings: const [],
        kunReadings: [kun],
        nanori: const [],
        components: const [],
        meanings: [
          {'language': 'en', 'text': meaning},
        ],
      ),
    );

class _FakeStudyRepo extends StudyRepository {
  _FakeStudyRepo(StudyService service, {required this.pool})
      : super(service, service);
  final List<StudyCard> pool;

  @override
  Future<StudyQueue> queue({int? newLimit}) async => StudyQueue(
        due: pool,
        newCards: const [],
        counts: {'new_available': pool.length},
      );

  @override
  Future<StudyCard> review(int cardId, Rating rating,
          {int durationMs = 0}) async =>
      pool.firstWhere((c) => c.id == cardId);
}

Future<ReviewViewModel> _vm({bool includeFifth = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final service = StudyService(ApiClient(SessionStore(prefs)));
  final repo = _FakeStudyRepo(service, pool: [
    _kanji(1, '水', 'water', 'みず'),
    _kanji(2, '火', 'fire', 'ひ'),
    _kanji(3, '木', 'tree', 'き'),
    _kanji(4, '金', 'gold', 'かね'),
    if (includeFifth) _kanji(5, '土', 'earth', 'つち'),
  ]);
  final vm = ReviewViewModel(repo);
  await vm.load();
  return vm;
}

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuizStage (multiple choice)', () {
    testWidgets('renders the prompt, lettered option chips and every choice',
        (tester) async {
      final vm = await _vm();
      await tester.pumpWidget(_host(QuizStage(vm: vm, lang: 'en')));
      await tester.pumpAndSettle();

      expect(find.text('What does this mean?'), findsOneWidget);
      // The four options, each with its lettered chip.
      for (final letter in ['A', 'B', 'C', 'D']) {
        expect(find.text(letter), findsOneWidget);
      }
      for (final meaning in ['water', 'fire', 'tree', 'gold']) {
        expect(find.text(meaning), findsOneWidget);
      }
      // Audio stays hidden until the learner commits.
      expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
    });

    testWidgets(
        'recall direction flips prompt to the meaning and options to kanji',
        (tester) async {
      final vm = await _vm();
      await tester.pumpWidget(_host(
          QuizStage(vm: vm, lang: 'en', direction: StudyDirection.recall)));
      await tester.pumpAndSettle();

      // Reversed: you see the meaning, you produce the kanji.
      expect(find.text('Which one means this?'), findsOneWidget);
      expect(find.text('water'), findsOneWidget); // the prompt (was an option)
      for (final glyph in ['水', '火', '木', '金']) {
        expect(find.text(glyph), findsOneWidget); // options are now Japanese
      }
    });

    testWidgets('locking a choice marks correct/wrong and reveals audio',
        (tester) async {
      final vm = await _vm();
      await tester.pumpWidget(_host(QuizStage(vm: vm, lang: 'en')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('fire')); // wrong (correct is 水/water)
      await tester.pump(const Duration(milliseconds: 300));

      expect(
          find.byIcon(Icons.close_rounded), findsOneWidget); // the wrong pick
      expect(find.byIcon(Icons.check_rounded),
          findsOneWidget); // the correct answer surfaced
      expect(find.byIcon(Icons.volume_up_outlined),
          findsOneWidget); // audio revealed
      // The correct card's reading surfaces as a teaching aid on a miss.
      expect(find.text('みず'), findsWidgets);

      await tester.pump(const Duration(
          milliseconds: 1600)); // fire the advance timer (wrong = 1500ms)
      await tester.pumpAndSettle();
    });

    testWidgets('a correct pick celebrates the win before advancing',
        (tester) async {
      final vm = await _vm();
      await tester.pumpWidget(_host(QuizStage(vm: vm, lang: 'en')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('water')); // correct (prompt is 水)
      await tester.pump(const Duration(milliseconds: 200));

      // The won round is signalled unmistakably while the next card is queued.
      expect(find.byType(SuccessBurst), findsOneWidget);

      await tester.pump(const Duration(
          milliseconds: 900)); // drain the advance timer (correct = 850ms)
      await tester.pumpAndSettle();
    });

    testWidgets('uses compact two-column answer cards on a phone',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final vm = await _vm();
      await tester.pumpWidget(_host(QuizStage(vm: vm, lang: 'en')));
      await tester.pumpAndSettle();

      for (final meaning in ['water', 'fire', 'tree', 'gold']) {
        final button = find.ancestor(
          of: find.text(meaning),
          matching: find.byType(Pressable),
        );
        expect(button, findsOneWidget);
        final size = tester.getSize(button);
        expect(size.width, lessThan(190));
        expect(size.height, greaterThanOrEqualTo(72));
      }
    });
  });

  group('SwipeStage (flashcard)', () {
    testWidgets(
        'shows the answer, the four graded buttons and their swipe arrows',
        (tester) async {
      final vm = await _vm();
      await tester.pumpWidget(_host(SwipeStage(vm: vm, lang: 'en')));
      await tester.pumpAndSettle();

      expect(find.text('Show answer'), findsOneWidget);

      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();

      // Answer block: reading in vermilion + meaning.
      expect(find.text('water'), findsOneWidget);
      // The four grade buttons carry both a label and their swipe-direction arrow.
      for (final label in ['Again', 'Hard', 'Good', 'Easy']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final arrow in ['←', '↓', '→', '↑']) {
        expect(find.text(arrow), findsOneWidget);
      }
    });

    testWidgets('uses the 55/45 tablet landscape review workspace',
        (tester) async {
      tester.view.physicalSize = const Size(1180, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final vm = await _vm();
      await tester.pumpWidget(_host(SwipeStage(vm: vm, lang: 'en')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();

      expect(find.text('Did you know it?'), findsOneWidget);
      expect(find.text('In context'), findsOneWidget);
      final again = find.ancestor(
        of: find.text('Again'),
        matching: find.byType(Pressable),
      );
      expect(again, findsOneWidget);
      expect(tester.getSize(again).height, 70);
    });
  });

  group('MatchStage (memory)', () {
    testWidgets('lays down face-down tiles and flips one on tap',
        (tester) async {
      final vm = await _vm();
      await tester.pumpWidget(_host(MatchStage(vm: vm, lang: 'en')));
      await tester.pumpAndSettle();

      expect(find.text('Find the pairs'), findsOneWidget);
      // 4 cards → 8 tiles, all hidden; no face content shown yet.
      expect(find.bySemanticsLabel('Hidden tile'), findsNWidgets(8));
      expect(find.text('water'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Hidden tile').first);
      await tester.pumpAndSettle();
      // One tile flipped up → seven remain hidden.
      expect(find.bySemanticsLabel('Hidden tile'), findsNWidgets(7));
    });

    testWidgets('keeps every tile above the phone safe area', (tester) async {
      tester.view.physicalSize = const Size(390, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final vm = await _vm(includeFifth: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 540),
              padding: EdgeInsets.only(bottom: 24),
              viewPadding: EdgeInsets.only(bottom: 24),
            ),
            child: Scaffold(body: MatchStage(vm: vm, lang: 'en')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hidden = find.bySemanticsLabel('Hidden tile');
      expect(hidden, findsNWidgets(10));
      expect(find.byType(VerticalOverflowCue), findsOneWidget);
      for (final element in hidden.evaluate()) {
        final tile =
            find.byElementPredicate((candidate) => candidate == element);
        expect(tester.getBottomRight(tile).dy, lessThanOrEqualTo(516));
      }
    });
  });

  group('ListenStage (assemble the reading)', () {
    testWidgets('fills cells from the tile bank and enables Check',
        (tester) async {
      final vm = await _vm();
      await tester.pumpWidget(_host(ListenStage(vm: vm, lang: 'en')));
      await tester.pumpAndSettle();

      expect(find.text('Type what you hear'), findsOneWidget);
      FilledButton check() => tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Check'));
      expect(check().onPressed, isNull); // nothing placed yet

      // 水's reading is みず: place both kana from the bank.
      await tester.tap(find.text('み'));
      await tester.pump();
      await tester.tap(find.text('ず'));
      await tester.pump();
      expect(check().onPressed, isNotNull); // both cells filled

      await tester.tap(find.widgetWithText(FilledButton, 'Check'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(check().onPressed, isNull); // locked after checking
      // A correct build wins: the celebration shows and the word's meaning is
      // now taught here, not just its spelling.
      expect(find.byType(SuccessBurst), findsOneWidget);
      expect(find.text('water'), findsOneWidget);

      await tester
          .pump(const Duration(milliseconds: 1700)); // drain the advance timer
      await tester.pumpAndSettle();
    });

    testWidgets('a wrong build shows the miss burst and the correct reading',
        (tester) async {
      final vm = await _vm();
      await tester.pumpWidget(_host(ListenStage(vm: vm, lang: 'en')));
      await tester.pumpAndSettle();

      // 水's reading is みず: place the kana in the wrong order to build ずみ.
      await tester.tap(find.text('ず'));
      await tester.pump();
      await tester.tap(find.text('み'));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Check'));
      await tester.pump(const Duration(milliseconds: 300));

      // A miss is signalled as plainly as a win, not just a quiet colour change,
      // and the correct reading + meaning are surfaced as a teaching moment.
      expect(find.byType(MissBurst), findsOneWidget);
      expect(find.byType(SuccessBurst), findsNothing);
      expect(find.text('みず'),
          findsOneWidget); // corrected reading in the result block
      expect(find.text('water'), findsOneWidget);

      await tester
          .pump(const Duration(milliseconds: 1700)); // drain the advance timer
      await tester.pumpAndSettle();
    });
  });
}
