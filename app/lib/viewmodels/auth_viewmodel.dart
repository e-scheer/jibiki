import 'dart:async';

import '../core/telemetry.dart';
import 'app_state.dart';
import 'base_view_model.dart';

/// Backs the login / register forms. Delegates the actual session mutation to
/// AppState, wrapping it with loading + error surfacing.
class AuthViewModel extends BaseViewModel {
  AuthViewModel(this._app);
  final AppState _app;

  Future<bool> login(String email, String password) async {
    await runGuarded(() => _app.login(email.trim(), password));
    if (!hasError) {
      unawaited(Telemetry.instance.logEvent(
        'login',
        parameters: {'method': 'password'},
      ));
    }
    unawaited(Telemetry.instance.logEvent('login_result', parameters: {
      'result': hasError ? 'failure' : 'success',
      'method': 'password',
    }));
    return !hasError;
  }

  Future<bool> register(String email, String password) async {
    await runGuarded(() => _app.signup(email.trim(), password));
    if (!hasError) {
      unawaited(Telemetry.instance.logEvent(
        'sign_up',
        parameters: {'method': 'password'},
      ));
    }
    unawaited(Telemetry.instance.logEvent('sign_up_result', parameters: {
      'result': hasError ? 'failure' : 'success',
      'method': 'password',
    }));
    return !hasError;
  }
}
