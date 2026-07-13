import 'dart:async';

import '../core/telemetry.dart';
import '../repositories/auth_repository.dart';
import 'base_view_model.dart';

enum AuthRecoveryLinkState { unchecked, checking, ready, unavailable, complete }

/// Drives the public allauth email verification and password recovery links.
class AuthRecoveryViewModel extends BaseViewModel {
  AuthRecoveryViewModel(this._auth);

  final AuthRepository _auth;
  AuthRecoveryLinkState _linkState = AuthRecoveryLinkState.unchecked;
  bool _requestSent = false;

  AuthRecoveryLinkState get linkState => _linkState;
  bool get requestSent => _requestSent;

  Future<void> inspectEmailLink(String key) =>
      _inspectLink(key, _auth.inspectEmailVerificationKey);

  Future<void> inspectPasswordLink(String key) =>
      _inspectLink(key, _auth.inspectPasswordResetKey);

  Future<bool> verifyEmail(String key) async {
    final result = await runGuarded(() async {
      await _auth.verifyEmail(key);
      return true;
    });
    if (result == true) {
      _linkState = AuthRecoveryLinkState.complete;
      notifyListeners();
    }
    unawaited(Telemetry.instance.logEvent(
      TelemetryEvent.emailVerificationResult,
      parameters: {'result': result == true ? 'success' : 'failure'},
    ));
    return result == true;
  }

  Future<bool> requestPasswordReset(String email) async {
    final result = await runGuarded(() async {
      await _auth.requestPasswordReset(email.trim());
      return true;
    });
    if (result == true) {
      _requestSent = true;
      notifyListeners();
    }
    unawaited(Telemetry.instance.logEvent(
      TelemetryEvent.passwordResetRequested,
      parameters: {'result': result == true ? 'success' : 'failure'},
    ));
    return result == true;
  }

  Future<bool> resetPassword(String key, String password) async {
    final result = await runGuarded(() async {
      await _auth.resetPassword(key, password);
      return true;
    });
    if (result == true) {
      _linkState = AuthRecoveryLinkState.complete;
      notifyListeners();
    }
    unawaited(Telemetry.instance.logEvent(
      TelemetryEvent.passwordResetResult,
      parameters: {'result': result == true ? 'success' : 'failure'},
    ));
    return result == true;
  }

  Future<void> _inspectLink(
    String key,
    Future<void> Function(String key) inspect,
  ) async {
    if (key.isEmpty) {
      _linkState = AuthRecoveryLinkState.unavailable;
      notifyListeners();
      return;
    }
    _linkState = AuthRecoveryLinkState.checking;
    notifyListeners();
    final result = await runGuarded(() async {
      await inspect(key);
      return true;
    });
    _linkState = result == true
        ? AuthRecoveryLinkState.ready
        : AuthRecoveryLinkState.unavailable;
    notifyListeners();
  }
}
