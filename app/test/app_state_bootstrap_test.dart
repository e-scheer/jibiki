import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/api_exception.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/models/user.dart';
import 'package:jibiki/repositories/auth_repository.dart';
import 'package:jibiki/services/auth_service.dart';
import 'package:jibiki/viewmodels/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An AuthRepository whose session presence + `me()` outcome we drive by hand.
class _FakeAuth extends AuthRepository {
  _FakeAuth(super.auth, super.session);
  bool sessionPresent = true;
  bool loggedOut = false;
  Completer<AppUser>? meCall;

  @override
  bool get hasSession => sessionPresent;

  @override
  Future<AppUser> me() => (meCall = Completer<AppUser>()).future;

  @override
  Future<void> logout() async {
    loggedOut = true;
    sessionPresent = false;
  }
}

Future<_FakeAuth> _repo() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final session = SessionStore(prefs);
  return _FakeAuth(AuthService(ApiClient(session)), session);
}

void main() {
  test('a retry visibly re-enters "connecting" and keeps the session when unreachable', () async {
    final repo = await _repo();
    final app = AppState(repo);

    final first = app.bootstrap();
    expect(app.bootstrapping, isTrue, reason: 'flips to connecting up front');
    expect(app.bootstrapError, isNull);

    repo.meCall!.completeError(ApiException('Network is unreachable'));
    await first;

    expect(app.bootstrapping, isFalse);
    expect(app.bootstrapError, 'Network is unreachable');
    expect(app.status, AuthStatus.unknown, reason: 'session kept, stays on splash');
    expect(repo.loggedOut, isFalse, reason: 'never log out a valid session on a network blip');

    // The fix: tapping "Try again" clears the error and re-enters connecting —
    // a visible change even though it will fail again with the same message.
    final retry = app.bootstrap();
    expect(app.bootstrapping, isTrue);
    expect(app.bootstrapError, isNull);

    repo.meCall!.completeError(ApiException('Network is unreachable'));
    await retry;
    expect(app.bootstrapping, isFalse);
    expect(app.bootstrapError, 'Network is unreachable');
  });

  test('a 401 during bootstrap clears the session and routes to login', () async {
    final repo = await _repo();
    final app = AppState(repo);

    final f = app.bootstrap();
    repo.meCall!.completeError(ApiException('Unauthorized', statusCode: 401));
    await f;

    expect(repo.loggedOut, isTrue);
    expect(app.status, AuthStatus.unauthenticated);
    expect(app.bootstrapError, isNull);
    expect(app.bootstrapping, isFalse);
  });

  test('no stored session goes straight to unauthenticated with no connecting state', () async {
    final repo = await _repo()
      ..sessionPresent = false;
    final app = AppState(repo);

    await app.bootstrap();
    expect(app.status, AuthStatus.unauthenticated);
    expect(app.bootstrapping, isFalse);
    expect(app.bootstrapError, isNull);
  });
}
