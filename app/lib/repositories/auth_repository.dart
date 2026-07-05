import '../core/session_store.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

/// Coordinates the token lifecycle with the account/profile calls, so ViewModels
/// never touch the SessionStore or the wire directly.
class AuthRepository {
  AuthRepository(this._auth, this._session);

  final AuthService _auth;
  final SessionStore _session;

  bool get hasSession => _session.hasToken;
  bool get onboarded => _session.onboarded;
  Future<void> setOnboarded(bool v) => _session.setOnboarded(v);

  Future<AppUser> signup(String email, String password) async {
    final token = await _auth.signup(email, password);
    await _session.setToken(token);
    return _auth.me();
  }

  Future<AppUser> login(String email, String password) async {
    final token = await _auth.login(email, password);
    await _session.setToken(token);
    return _auth.me();
  }

  Future<AppUser> me() => _auth.me();

  Future<AppUser> updateProfile(Map<String, dynamic> patch) => _auth.updateProfile(patch);

  Future<void> logout() async {
    await _auth.logout();
    await _session.clear();
  }
}
