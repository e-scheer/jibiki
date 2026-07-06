import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

/// The one global ViewModel: who is signed in, their profile/mode, and the
/// bootstrap status the router redirects on. Feature ViewModels stay per-screen;
/// this holds only cross-cutting session state.
class AppState extends ChangeNotifier {
  AppState(this._auth);
  final AuthRepository _auth;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  String? _bootstrapError;
  bool _bootstrapping = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;

  /// Set when cold-start bootstrap couldn't reach the server (not an auth
  /// failure). The session is kept intact and the splash offers a retry, instead
  /// of silently dumping a signed-in user at the login screen.
  String? get bootstrapError => _bootstrapError;

  /// True while a (re)connect attempt is in flight — so the splash's "Try again"
  /// gives immediate feedback instead of looking inert when it fails again.
  bool get bootstrapping => _bootstrapping;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get onboarded => _auth.onboarded;

  AppMode get mode => _user?.profile.mode ?? AppMode.middle;
  String get mnemonicLanguage => _user?.profile.mnemonicLanguage ?? 'en';
  UserProfile? get profile => _user?.profile;

  /// Called once at launch (and on "Try again") to resolve the start destination.
  Future<void> bootstrap() async {
    if (!_auth.hasSession) {
      _set(AuthStatus.unauthenticated, null);
      return;
    }
    // Flip into the loading state up front so a retry visibly re-enters
    // "connecting…" even when it will fail again with the same message.
    _bootstrapping = true;
    _bootstrapError = null;
    notifyListeners();
    try {
      final user = await _auth.me();
      _bootstrapping = false;
      _set(AuthStatus.authenticated, user);
    } on ApiException catch (e) {
      _bootstrapping = false;
      if (e.isUnauthorized) {
        // The session really is invalid — clear it and go to login.
        await _auth.logout();
        _set(AuthStatus.unauthenticated, null);
      } else {
        // Server unreachable / network down: keep the session, stay on the
        // splash, and let the user retry. Never log a valid session out because
        // the API was momentarily down.
        _bootstrapError = e.message;
        notifyListeners();
      }
    }
  }

  Future<void> signup(String email, String password) async {
    final user = await _auth.signup(email, password);
    _set(AuthStatus.authenticated, user);
  }

  Future<void> login(String email, String password) async {
    final user = await _auth.login(email, password);
    _set(AuthStatus.authenticated, user);
  }

  Future<void> logout() async {
    await _auth.logout();
    // Clear any stuck cold-start error so the splash never lingers after we've
    // dropped the session and handed off to the login screen.
    _bootstrapError = null;
    _bootstrapping = false;
    _set(AuthStatus.unauthenticated, null);
  }

  /// Persist a profile patch (mode / mnemonic language / SRS knobs) and refresh
  /// the cached user so the whole app reacts (nav layout, mnemonic language, …).
  Future<void> updateProfile(Map<String, dynamic> patch) async {
    final user = await _auth.updateProfile(patch);
    _user = user;
    notifyListeners();
  }

  Future<void> completeOnboarding({required AppMode mode, required String mnemonicLanguage}) async {
    await updateProfile({'mode': mode.wire, 'mnemonic_language': mnemonicLanguage});
    await _auth.setOnboarded(true);
    notifyListeners();
  }

  void _set(AuthStatus status, AppUser? user) {
    _status = status;
    _user = user;
    notifyListeners();
  }
}
