import '../models/enums.dart';
import '../models/study.dart';
import '../repositories/study_repository.dart';
import 'base_view_model.dart';

class DashboardViewModel extends BaseViewModel {
  DashboardViewModel(this._study);
  final StudyRepository _study;

  StudyStats _stats = StudyStats.empty();
  StudyStats get stats => _stats;

  List<int> _forecast = List<int>.filled(7, 0);
  List<int> get forecast => _forecast;
  bool _forecastLoading = true;
  bool get forecastLoading => _forecastLoading;

  Map<ItemType, int> _dueByType = const {};
  Map<ItemType, int> get dueByType => _dueByType;

  Future<void> load() async {
    _forecastLoading = true;
    final cardsFuture = _study.cards().catchError((_) => <StudyCard>[]);
    final stats = await runGuarded(_study.stats);
    if (stats != null) {
      _stats = stats;
      if (hasListeners) notifyListeners();
    }

    final cards = await cardsFuture;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final forecast = List<int>.filled(7, 0);
    final dueByType = <ItemType, int>{};

    for (final card in cards) {
      if (card.isNew) continue;
      final due = card.due.toLocal();
      if (!due.isAfter(now)) {
        dueByType.update(card.itemType, (value) => value + 1,
            ifAbsent: () => 1);
      }
      final dueDay = DateTime(due.year, due.month, due.day);
      final days = dueDay.difference(today).inDays;
      if (days >= 1 && days <= 7) forecast[days - 1]++;
    }

    _forecast = forecast;
    _dueByType = dueByType;
    _forecastLoading = false;
    if (hasListeners) notifyListeners();
  }
}
