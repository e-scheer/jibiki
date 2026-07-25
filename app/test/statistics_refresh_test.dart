import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/models/study.dart';
import 'package:jibiki/repositories/study_repository.dart';
import 'package:jibiki/services/study_service.dart';
import 'package:jibiki/viewmodels/statistics_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InstantStudyRepository extends StudyRepository {
  _InstantStudyRepository(StudyService service) : super(service, service);

  @override
  Future<StudyStats> stats() async => StudyStats.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('refresh holds the loading state long enough to be visible', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = StudyService(ApiClient(SessionStore(prefs)));

    fakeAsync((async) {
      final vm = StatisticsViewModel(_InstantStudyRepository(service));

      var completed = false;
      vm.refresh().then((_) => completed = true);
      async.elapse(const Duration(milliseconds: 300));
      // The stats read resolves within a frame; the spinner must still be up.
      expect(vm.isLoading, isTrue);

      async.elapse(const Duration(milliseconds: 400));
      expect(completed, isTrue);
      expect(vm.isLoading, isFalse);
    });
  });

  test('load resolves immediately without the refresh floor', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = StudyService(ApiClient(SessionStore(prefs)));

    fakeAsync((async) {
      final vm = StatisticsViewModel(_InstantStudyRepository(service));

      var completed = false;
      vm.load().then((_) => completed = true);
      async.flushMicrotasks();
      expect(completed, isTrue);
      expect(vm.isLoading, isFalse);
    });
  });
}
