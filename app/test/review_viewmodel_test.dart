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
  _FakeStudyRepo(StudyService service, {required this.pool, required this.batch}) : super(service, service);
  final List<StudyCard> pool;
  final int batch;
  final Set<int> reviewed = {};

  List<StudyCard> get _available => pool.where((c) => !reviewed.contains(c.id)).toList();

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
  Future<StudyCard> review(int cardId, Rating rating, {int durationMs = 0}) async {
    reviewed.add(cardId);
    return pool.firstWhere((c) => c.id == cardId);
  }
}

Future<_FakeStudyRepo> _repo({required int poolSize, required int batch}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final service = StudyService(ApiClient(SessionStore(prefs)));
  return _FakeStudyRepo(service, pool: [for (var i = 1; i <= poolSize; i++) _card(i)], batch: batch);
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

  test('studyMore appends the rest of the pool and resumes in place - no wall', () async {
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

  test('when the batch already covers the pool, there is nothing more', () async {
    final vm = ReviewViewModel(await _repo(poolSize: 2, batch: 5));
    await vm.load();

    expect(vm.total, 2);
    expect(vm.hasMoreNew, isFalse);
  });

  test('rateMany grades a whole batch and advances past it at once (Match)', () async {
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
}
