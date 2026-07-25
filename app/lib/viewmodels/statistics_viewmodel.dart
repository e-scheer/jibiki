import '../models/study.dart';
import '../repositories/study_repository.dart';
import 'base_view_model.dart';

class StatisticsViewModel extends BaseViewModel {
  StatisticsViewModel(this._study);
  final StudyRepository _study;

  StudyStats _stats = StudyStats.empty();
  StudyStats get stats => _stats;

  Future<void> load() => _load(minVisible: null);

  /// Explicit refresh from the header button. The stats read is usually local
  /// and resolves within a frame, so the loading state is held long enough
  /// for the button's spinner to actually be seen.
  Future<void> refresh() => _load(minVisible: const Duration(milliseconds: 600));

  Future<void> _load({required Duration? minVisible}) async {
    final value = await runGuarded(() async {
      final stats = _study.stats();
      if (minVisible == null) return stats;
      final results = await Future.wait<Object?>(
        [stats, Future<void>.delayed(minVisible)],
      );
      return results.first as StudyStats;
    });
    if (value != null) _stats = value;
    notifyListeners();
  }
}
