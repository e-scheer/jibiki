import 'dart:async';
import 'dart:convert';

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
  _FakeAuth(super.auth, super.session, this._session2);
  final SessionStore _session2;
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

  Future<void> saveCachedForTest(AppUser user) =>
      _session2.setCachedUser(jsonEncode(user.toJson()));
}

Future<_FakeAuth> _repo() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final session = SessionStore(prefs);
  return _FakeAuth(AuthService(ApiClient(session)), session, session);
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

    // The fix: tapping "Try again" clears the error and re-enters connecting -
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

  test('unreachable server with a cached account restores the session offline', () async {
    final repo = await _repo();
    // A previous successful /auth/me left a cached copy.
    await repo.saveCachedForTest(AppUser.fromJson(const {
      'id': 7,
      'email': 'egon@example.com',
      'profile': {'mode': 'learning', 'mnemonic_language': 'fr'},
    }));
    final app = AppState(repo);

    final f = app.bootstrap();
    repo.meCall!.completeError(ApiException('Network is unreachable'));
    await f;

    expect(app.status, AuthStatus.authenticated, reason: 'cached account gets in');
    expect(app.offline, isTrue);
    expect(app.user?.email, 'egon@example.com');
    expect(app.mode.wire, 'learning');
    expect(app.bootstrapError, isNull);
    expect(repo.loggedOut, isFalse);
  });

  test('continue without account enters the app and keeps a local profile', () async {
    final repo = await _repo()
      ..sessionPresent = false;
    final app = AppState(repo);
    await app.bootstrap();
    expect(app.canEnter, isFalse);

    await app.continueWithoutAccount();
    expect(app.canEnter, isTrue);
    expect(app.localOnly, isTrue);
    expect(app.isAuthenticated, isFalse);
    expect(app.profile, isNotNull, reason: 'settings render on a local default');

    // Profile edits persist locally, no network involved.
    await app.updateProfile({'mode': 'learning', 'new_cards_per_day': 7});
    expect(app.mode.wire, 'learning');
    expect(app.profile!.newCardsPerDay, 7);

    // The flag survives a restart.
    final again = AppState(repo);
    await again.bootstrap();
    expect(again.canEnter, isTrue);
    expect(again.profile!.newCardsPerDay, 7);
  });
}
