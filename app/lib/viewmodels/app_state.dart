import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../core/entitlements.dart';
import '../core/languages.dart';
import '../core/telemetry.dart';
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
  bool _offline = false;
  bool _localOnly = false;
  UserProfile? _localProfile;

  AuthStatus get status => _status;
  AppUser? get user => _user;

  /// The session was restored from cache because the server was unreachable -
  /// everything local works; sync catches up when the network returns.
  bool get offline => _offline;

  /// "Continue without account": fully local study, no sync. Flipped off the
  /// moment the user signs up/in (their history uploads on first sync).
  bool get localOnly => _localOnly;

  /// Whether the router may enter the app shell.
  bool get canEnter => isAuthenticated || _localOnly;

  /// Set when cold-start bootstrap couldn't reach the server (not an auth
  /// failure). The session is kept intact and the splash offers a retry, instead
  /// of silently dumping a signed-in user at the login screen.
  String? get bootstrapError => _bootstrapError;

  /// True while a (re)connect attempt is in flight - so the splash's "Try again"
  /// gives immediate feedback instead of looking inert when it fails again.
  bool get bootstrapping => _bootstrapping;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get onboarded => _auth.onboarded;

  /// The user's tier (server-set; mirror only - the API enforces it). All
  /// gates resolve to full access while the app is a one-shot purchase.
  Entitlements get entitlements =>
      Entitlements.of(_user?.profile, localOnly: _localOnly);

  AppMode get mode => profile?.mode ?? AppMode.middle;
  String get mnemonicLanguage => profile?.mnemonicLanguage ?? fallbackLanguage;
  String get interfaceLanguage => profile?.interfaceLanguage ?? 'en';
  UserProfile? get profile =>
      _user?.profile ?? (_localOnly ? _localProfile ?? _defaultProfile : null);

  static final UserProfile _defaultProfile = UserProfile.fromJson(const {});

  // The last study game the user played, remembered across decks within a run so
  // switching games sticks instead of snapping back to Swipe each session.
  StudyMode _studyMode = StudyMode.swipe;
  StudyMode get studyMode => _studyMode;
  void setStudyMode(StudyMode m) {
    if (_studyMode == m) return;
    _studyMode = m;
    notifyListeners();
  }

  /// Called once at launch (and on "Try again") to resolve the start destination.
  Future<void> bootstrap() async {
    if (!_auth.hasSession) {
      if (_auth.localOnly) {
        _localOnly = true;
        _localProfile = _auth.localProfile;
      }
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
      _offline = false;
      _set(AuthStatus.authenticated, user);
    } on ApiException catch (e) {
      _bootstrapping = false;
      if (e.isUnauthorized) {
        // The session really is invalid - clear it and go to login.
        await _auth.logout();
        _set(AuthStatus.unauthenticated, null);
      } else {
        // Server unreachable / network down. A previously-cached account gets
        // straight in - dictionary and study are fully local, sync will catch
        // up. Only a never-cached session (first run) stays on the splash
        // retry, because we know nothing about the user yet.
        final cached = _auth.cachedUser;
        if (cached != null) {
          _offline = true;
          _set(AuthStatus.authenticated, cached);
        } else {
          _bootstrapError = e.message;
          notifyListeners();
        }
      }
    }
  }

  /// Enter the app without an account (paid app: everything works locally).
  Future<void> continueWithoutAccount() async {
    await _auth.setLocalOnly(true);
    _localOnly = true;
    _localProfile = _auth.localProfile;
    notifyListeners();
    unawaited(Telemetry.instance.logEvent('guest_continue'));
  }

  Future<void> signup(String email, String password) async {
    final user = await _auth.signup(email, password);
    _localOnly = false;
    _offline = false;
    _set(AuthStatus.authenticated, user);
  }

  Future<void> login(String email, String password) async {
    final user = await _auth.login(email, password);
    _localOnly = false;
    _offline = false;
    _set(AuthStatus.authenticated, user);
  }

  Future<void> logout() async {
    await _auth.logout();
    // Clear any stuck cold-start error so the splash never lingers after we've
    // dropped the session and handed off to the login screen.
    _bootstrapError = null;
    _bootstrapping = false;
    _localOnly = false;
    _offline = false;
    _set(AuthStatus.unauthenticated, null);
  }

  /// Persist a profile patch (mode / mnemonic language / SRS knobs) and refresh
  /// the cached user so the whole app reacts (nav layout, mnemonic language, …).
  /// Without an account the patch lands in the local profile instead.
  Future<void> updateProfile(Map<String, dynamic> patch) async {
    if (_localOnly && !isAuthenticated) {
      final merged = UserProfile.fromJson({
        ...(profile ?? _defaultProfile).toJson(),
        ...patch,
      });
      await _auth.saveLocalProfile(merged);
      _localProfile = merged;
      notifyListeners();
      return;
    }
    final user = await _auth.updateProfile(patch);
    _user = user;
    notifyListeners();
  }

  Future<void> completeOnboarding(
      {required AppMode mode, required String mnemonicLanguage}) async {
    await updateProfile(
        {'mode': mode.wire, 'mnemonic_language': mnemonicLanguage});
    await _auth.setOnboarded(true);
    notifyListeners();
  }

  void _set(AuthStatus status, AppUser? user) {
    _status = status;
    _user = user;
    notifyListeners();
  }
}
