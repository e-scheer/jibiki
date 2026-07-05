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

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get onboarded => _auth.onboarded;

  AppMode get mode => _user?.profile.mode ?? AppMode.middle;
  String get mnemonicLanguage => _user?.profile.mnemonicLanguage ?? 'en';
  UserProfile? get profile => _user?.profile;

  /// Called once at launch to resolve the start destination.
  Future<void> bootstrap() async {
    if (!_auth.hasSession) {
      _set(AuthStatus.unauthenticated, null);
      return;
    }
    try {
      final user = await _auth.me();
      _set(AuthStatus.authenticated, user);
    } on ApiException {
      await _auth.logout();
      _set(AuthStatus.unauthenticated, null);
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
