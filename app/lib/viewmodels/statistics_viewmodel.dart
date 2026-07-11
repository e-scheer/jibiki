import '../models/study.dart';
import '../repositories/study_repository.dart';
import 'base_view_model.dart';

class StatisticsViewModel extends BaseViewModel {
  StatisticsViewModel(this._study);
  final StudyRepository _study;

  StudyStats _stats = StudyStats.empty();
  StudyStats get stats => _stats;

  Future<void> load() async {
    final value = await runGuarded(() => _study.stats());
    if (value != null) _stats = value;
    notifyListeners();
  }
}
