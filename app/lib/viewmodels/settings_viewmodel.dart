import '../models/enums.dart';
import '../repositories/study_repository.dart';
import 'app_state.dart';
import 'base_view_model.dart';

/// Every setting is a profile patch through AppState, so a change here ripples to
/// the nav layout, mnemonic language and SRS behaviour app-wide. Data actions
/// (Anki export, FSRS optimization) go through the study repository.
class SettingsViewModel extends BaseViewModel {
  SettingsViewModel(this._app, this._study);
  final AppState _app;
  final StudyRepository _study;

  Future<void> setMode(AppMode mode) => _patch({'mode': mode.wire});
  Future<void> setMnemonicLanguage(String code) =>
      _patch({'mnemonic_language': code});
  Future<void> setInterfaceLanguage(String code) =>
      _patch({'interface_language': code});
  Future<void> setNewCardsPerDay(int n) => _patch({'new_cards_per_day': n});
  Future<void> setDesiredRetention(double r) =>
      _patch({'desired_retention': r});
  Future<void> setNotifications(bool on) =>
      _patch({'notifications_enabled': on});

  Future<void> _patch(Map<String, dynamic> patch) =>
      runGuarded(() => _app.updateProfile(patch));

  Future<void> logout() => runGuarded(() => _app.logout());

  Future<String?> exportDeck() => runGuarded(() => _study.exportTsv());
  Future<Map<String, dynamic>?> optimizeStatus() =>
      runGuarded(() => _study.optimizeStatus(), silent: true);
  Future<Map<String, dynamic>?> runOptimize() =>
      runGuarded(() => _study.runOptimize());
}
