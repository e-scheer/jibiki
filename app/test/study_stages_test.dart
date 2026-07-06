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
import 'package:jibiki/views/study/quiz_stage.dart';
import 'package:jibiki/views/study/swipe_stage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A kanji card with one English meaning and a kun reading, so both the swipe
/// answer block and the quiz distractors have real content to render.
StudyCard _kanji(int id, String literal, String meaning, String kun) => StudyCard(
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
          {'lang': 'en', 'text': meaning},
        ],
      ),
    );

class _FakeStudyRepo extends StudyRepository {
  _FakeStudyRepo(super.service, {required this.pool});
  final List<StudyCard> pool;

  @override
  Future<StudyQueue> queue({int? newLimit}) async => StudyQueue(
        due: pool,
        newCards: const [],
        counts: {'new_available': pool.length},
      );

  @override
  Future<StudyCard> review(int cardId, Rating rating, {int durationMs = 0}) async =>
      pool.firstWhere((c) => c.id == cardId);
}

Future<ReviewViewModel> _vm() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final service = StudyService(ApiClient(SessionStore(prefs)));
  final repo = _FakeStudyRepo(service, pool: [
    _kanji(1, '水', 'water', 'みず'),
    _kanji(2, '火', 'fire', 'ひ'),
    _kanji(3, '木', 'tree', 'き'),
    _kanji(4, '金', 'gold', 'かね'),
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
    testWidgets('renders the prompt, lettered option chips and every choice', (tester) async {
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

    testWidgets('locking a choice marks correct/wrong and reveals audio', (tester) async {
      final vm = await _vm();
      await tester.pumpWidget(_host(QuizStage(vm: vm, lang: 'en')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('fire')); // wrong (correct is 水/water)
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.close_rounded), findsOneWidget); // the wrong pick
      expect(find.byIcon(Icons.check_rounded), findsOneWidget); // the correct answer surfaced
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget); // audio revealed
      // The correct card's reading surfaces as a teaching aid on a miss.
      expect(find.text('みず'), findsWidgets);

      await tester.pump(const Duration(milliseconds: 1600)); // fire the advance timer (wrong = 1500ms)
      await tester.pumpAndSettle();
    });
  });

  group('SwipeStage (flashcard)', () {
    testWidgets('shows the answer, the four graded buttons and their swipe arrows', (tester) async {
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
  });
}
