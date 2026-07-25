/// Login while a live session token is already stored: allauth headless
/// answers 409 Conflict. The repository must enter the account with the
/// stored token instead of surfacing a dead-end error.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/api_exception.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/models/user.dart';
import 'package:jibiki/repositories/auth_repository.dart';
import 'package:jibiki/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ConflictAuthService extends AuthService {
  _ConflictAuthService(super.api);

  int loginCalls = 0;
  int meCalls = 0;

  @override
  Future<String> login(String email, String password) async {
    loginCalls++;
    throw ApiException('Conflict', statusCode: 409);
  }

  @override
  Future<AppUser> me() async {
    meCalls++;
    return AppUser.fromJson({'id': 1, 'email': 'test@jibiki.dev'});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SessionStore> store(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SessionStore(await SharedPreferences.getInstance());
  }

  test('409 with a stored token resolves to the signed-in account', () async {
    final session = await store({'session_token': 'live-token'});
    final auth = _ConflictAuthService(ApiClient(session));
    final repo = AuthRepository(auth, session);

    final user = await repo.login('test@jibiki.dev', 'whatever');
    expect(user.email, 'test@jibiki.dev');
    expect(auth.meCalls, 1);
    expect(session.localOnly, isFalse);
  });

  test('409 without a stored token stays an error', () async {
    final session = await store({});
    final auth = _ConflictAuthService(ApiClient(session));
    final repo = AuthRepository(auth, session);

    await expectLater(
      repo.login('test@jibiki.dev', 'whatever'),
      throwsA(isA<ApiException>()),
    );
    expect(auth.meCalls, 0);
  });
}
