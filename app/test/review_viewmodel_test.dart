import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/models/enums.dart';
import 'package:jibiki/models/study.dart';
import 'package:jibiki/repositories/study_repository.dart';
import 'package:jibiki/services/study_service.dart';
import 'package:jibiki/viewmodels/review_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

StudyCard _card(int id) => StudyCard(
      id: id,
      itemType: ItemType.kana,
      itemRef: '$id',
      state: 0,
      due: DateTime(2020),
      reps: 0,
      lapses: 0,
    );

/// A repository whose queue serves a per-session batch of new cards and, when
/// asked for more (`newLimit`), the rest of the pool - mirroring the server.
class _FakeStudyRepo extends StudyRepository {
  _FakeStudyRepo(StudyService service,
      {required this.pool, required this.batch})
      : super(service, service);
  final List<StudyCard> pool;
  final int batch;
  final Set<int> reviewed = {};
  final List<({int cardId, Rating rating, int duration, String? id})> attempts =
      [];
  Future<void> Function(int cardId)? onReview;

  List<StudyCard> get _available =>
      pool.where((c) => !reviewed.contains(c.id)).toList();

  @override
  Future<StudyQueue> queue({int? newLimit}) async {
    final avail = _available;
    final take = newLimit ?? batch;
    return StudyQueue(
      due: const [],
      newCards: avail.take(take).toList(),
      counts: {'new_available': avail.length, 'new_remaining': take},
    );
  }

  @override
  Future<StudyCard> review(int cardId, Rating rating,
      {int durationMs = 0, String? clientReviewId}) async {
    attempts.add((
      cardId: cardId,
      rating: rating,
      duration: durationMs,
      id: clientReviewId
    ));
    await onReview?.call(cardId);
    reviewed.add(cardId);
    return pool.firstWhere((c) => c.id == cardId);
  }
}

Future<_FakeStudyRepo> _repo(
    {required int poolSize, required int batch}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final service = StudyService(ApiClient(SessionStore(prefs)));
  return _FakeStudyRepo(service,
      pool: [for (var i = 1; i <= poolSize; i++) _card(i)], batch: batch);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load serves one batch and flags that more new cards remain', () async {
    final vm = ReviewViewModel(await _repo(poolSize: 4, batch: 2));
    await vm.load();

    expect(vm.total, 2);
    expect(vm.hasMoreNew, isTrue);
    expect(vm.current!.id, 1);
  });

  test('studyMore appends the rest of the pool and resumes in place - no wall',
      () async {
    final vm = ReviewViewModel(await _repo(poolSize: 4, batch: 2));
    await vm.load();

    await vm.rate(Rating.good);
    await vm.rate(Rating.good);
    expect(vm.finished, isTrue); // the batch drained
    expect(vm.reviewed, 2);
    expect(vm.hasMoreNew, isTrue); // …but there's more to study

    await vm.studyMore();
    expect(vm.finished, isFalse); // session resumed
    expect(vm.total, 4);
    expect(vm.current!.id, 3); // the first not-yet-seen card
    expect(vm.hasMoreNew, isFalse); // whole pool now loaded

    await vm.rate(Rating.good);
    await vm.rate(Rating.good);
    expect(vm.finished, isTrue);
    expect(vm.reviewed, 4);
  });

  test('when the batch already covers the pool, there is nothing more',
      () async {
    final vm = ReviewViewModel(await _repo(poolSize: 2, batch: 5));
    await vm.load();

    expect(vm.total, 2);
    expect(vm.hasMoreNew, isFalse);
  });

  test('rateMany grades a whole batch and advances past it at once (Match)',
      () async {
    final vm = ReviewViewModel(await _repo(poolSize: 4, batch: 4));
    await vm.load();
    expect(vm.total, 4);

    final firstThree = vm.sessionCards.take(3).toList();
    await vm.rateMany(firstThree, Rating.good);

    expect(vm.reviewed, 3);
    expect(vm.index, 3);
    expect(vm.current!.id, 4); // resumes at the fourth card
    expect(vm.finished, isFalse);
  });

  test('listeners receive the loaded queue after the fetch completes',
      () async {
    final vm = ReviewViewModel(await _repo(poolSize: 2, batch: 2));
    final totals = <int>[];
    vm.addListener(() => totals.add(vm.total));
    await vm.load();
    expect(totals.last, 2);
  });

  test('rating waits for persistence and prevents duplicate taps', () async {
    final repo = await _repo(poolSize: 2, batch: 2);
    final save = Completer<void>();
    repo.onReview = (_) => save.future;
    final vm = ReviewViewModel(repo);
    await vm.load();
    final pending = vm.rate(Rating.good);
    expect(vm.isLoading, isTrue);
    expect(vm.index, 0);
    expect(vm.reviewed, 0);
    await vm.rate(Rating.easy);
    expect(repo.attempts, hasLength(1));
    save.complete();
    await pending;
    expect(vm.index, 1);
    expect(vm.reviewed, 1);
    expect(vm.isLoading, isFalse);
  });

  test('failed rating retains the card and retries the same event', () async {
    final repo = await _repo(poolSize: 1, batch: 1);
    repo.onReview = (_) async => throw StateError('disk or network failure');
    final vm = ReviewViewModel(repo);
    await vm.load();
    vm.reveal();
    await vm.rate(Rating.again);
    expect(vm.hasError, isTrue);
    expect(vm.finished, isFalse);
    expect(vm.answerShown, isTrue);
    expect(vm.reviewed, 0);
    repo.onReview = null;
    await vm.rate(Rating.good);
    expect(repo.attempts.last, repo.attempts.first);
    expect(repo.attempts.first.id, isNotNull);
    expect(vm.finished, isTrue);
    expect(vm.hasError, isFalse);
  });

  test('partial batch failure retries only the unpersisted suffix', () async {
    final repo = await _repo(poolSize: 3, batch: 3);
    repo.onReview = (id) async {
      if (id == 2) throw StateError('save failed');
    };
    final vm = ReviewViewModel(repo);
    await vm.load();
    final batch = vm.sessionCards;
    await vm.rateMany(batch, Rating.good);
    expect(vm.index, 1);
    expect(vm.reviewed, 1);
    expect(vm.hasError, isTrue);
    repo.onReview = null;
    await vm.rateMany(batch, Rating.good);
    expect(vm.finished, isTrue);
    expect(vm.reviewed, 3);
    expect(repo.attempts.map((a) => a.cardId), [1, 2, 2, 3]);
    expect(repo.attempts[1].id, repo.attempts[2].id);
  });

  test('batch cannot skip cards or advance beyond the session', () async {
    final repo = await _repo(poolSize: 2, batch: 2);
    final vm = ReviewViewModel(repo);
    await vm.load();
    await vm.rateMany([vm.sessionCards.last], Rating.good);
    await vm.rateMany([vm.current!, vm.current!], Rating.good);
    expect(vm.index, 0);
    expect(repo.attempts, isEmpty);
  });
}
