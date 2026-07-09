import 'dart:convert';

import '../core/session_store.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

/// Coordinates the token lifecycle with the account/profile calls, so ViewModels
/// never touch the SessionStore or the wire directly. Every successful account
/// fetch is cached so a cold start with the server unreachable can restore the
/// signed-in state instead of blocking on the network.
class AuthRepository {
  AuthRepository(this._auth, this._session);

  final AuthService _auth;
  final SessionStore _session;

  bool get hasSession => _session.hasToken;
  bool get onboarded => _session.onboarded;
  Future<void> setOnboarded(bool v) => _session.setOnboarded(v);

  bool get localOnly => _session.localOnly;
  Future<void> setLocalOnly(bool v) => _session.setLocalOnly(v);

  AppUser? get cachedUser {
    final raw = _session.cachedUser;
    if (raw == null) return null;
    try {
      return AppUser.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  UserProfile? get localProfile {
    final raw = _session.localProfile;
    if (raw == null) return null;
    try {
      return UserProfile.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLocalProfile(UserProfile profile) =>
      _session.setLocalProfile(jsonEncode(profile.toJson()));

  Future<AppUser> signup(String email, String password) async {
    final token = await _auth.signup(email, password);
    await _session.setToken(token);
    await _session.setLocalOnly(false); // account-link: sync uploads history
    return _cache(await _auth.me());
  }

  Future<AppUser> login(String email, String password) async {
    final token = await _auth.login(email, password);
    await _session.setToken(token);
    await _session.setLocalOnly(false);
    return _cache(await _auth.me());
  }

  Future<AppUser> me() async => _cache(await _auth.me());

  Future<AppUser> updateProfile(Map<String, dynamic> patch) async =>
      _cache(await _auth.updateProfile(patch));

  Future<AppUser> _cache(AppUser user) async {
    await _session.setCachedUser(jsonEncode(user.toJson()));
    return user;
  }

  Future<void> logout() async {
    await _auth.logout();
    await _session.clear();
    await _session.setLocalOnly(false);
  }
}
