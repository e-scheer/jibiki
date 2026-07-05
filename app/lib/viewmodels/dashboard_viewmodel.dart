import '../models/study.dart';
import '../repositories/study_repository.dart';
import 'base_view_model.dart';

class DashboardViewModel extends BaseViewModel {
  DashboardViewModel(this._study);
  final StudyRepository _study;

  StudyStats _stats = StudyStats.empty();
  StudyStats get stats => _stats;

  Future<void> load() async {
    final s = await runGuarded(() => _study.stats());
    if (s != null) _stats = s;
  }
}
