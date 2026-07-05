import '../models/enums.dart';
import 'app_state.dart';
import 'base_view_model.dart';

class OnboardingViewModel extends BaseViewModel {
  OnboardingViewModel(this._app) {
    _mode = _app.mode;
    _language = _app.mnemonicLanguage;
  }
  final AppState _app;

  late AppMode _mode;
  late String _language;

  AppMode get mode => _mode;
  String get language => _language;

  // The mnemonic languages we seed content for out of the box.
  static const languages = {'en': 'English', 'fr': 'Français'};

  void selectMode(AppMode m) {
    _mode = m;
    notifyListeners();
  }

  void selectLanguage(String code) {
    _language = code;
    notifyListeners();
  }

  Future<bool> finish() async {
    await runGuarded(() => _app.completeOnboarding(mode: _mode, mnemonicLanguage: _language));
    return !hasError;
  }
}
