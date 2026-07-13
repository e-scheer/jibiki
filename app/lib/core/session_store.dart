import 'package:shared_preferences/shared_preferences.dart';

/// Persists the allauth session token + the last onboarding decision so the app
/// can decide, on launch, whether to show auth / onboarding / home without a
/// network round-trip. (Use flutter_secure_storage in production for the token.)
class SessionStore {
  SessionStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kToken = 'session_token';
  static const _kOnboarded = 'onboarded';
  static const _kCachedUser = 'cached_user';
  static const _kLocalOnly = 'local_only';
  static const _kLocalProfile = 'local_profile';
  static const _kThemePalette = 'theme_palette';
  static const _kThemeMode = 'theme_mode';
  static const _kTelemetryConsent = 'telemetry_consent';
  static const _kTelemetryAnalyticsConsent = 'telemetry_analytics_consent';
  static const _kTelemetryDiagnosticsConsent = 'telemetry_diagnostics_consent';
  static const _kTelemetryInstallId = 'telemetry_install_id';

  static Future<SessionStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SessionStore(prefs);
  }

  String? get token => _prefs.getString(_kToken);
  bool get hasToken => (token ?? '').isNotEmpty;

  Future<void> setToken(String? value) async {
    if (value == null || value.isEmpty) {
      await _prefs.remove(_kToken);
    } else {
      await _prefs.setString(_kToken, value);
    }
  }

  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;
  Future<void> setOnboarded(bool value) => _prefs.setBool(_kOnboarded, value);

  /// The last /auth/me payload, so a signed-in user still gets past the
  /// router when the server is unreachable at cold start.
  String? get cachedUser => _prefs.getString(_kCachedUser);
  Future<void> setCachedUser(String? json) async {
    if (json == null) {
      await _prefs.remove(_kCachedUser);
    } else {
      await _prefs.setString(_kCachedUser, json);
    }
  }

  /// "Continue without account": the paid app is fully usable with no login;
  /// study state lives locally until (if ever) an account is created.
  bool get localOnly => _prefs.getBool(_kLocalOnly) ?? false;
  Future<void> setLocalOnly(bool value) => _prefs.setBool(_kLocalOnly, value);

  /// Local-only users still pick a mode/mnemonic language at onboarding -
  /// persisted here instead of a server profile.
  String? get localProfile => _prefs.getString(_kLocalProfile);
  Future<void> setLocalProfile(String json) =>
      _prefs.setString(_kLocalProfile, json);

  /// Visual palettes are a device preference, like an editor theme. Keeping this
  /// outside the account profile makes a theme change instant and available to
  /// local-only users too.
  String get themePalette => _prefs.getString(_kThemePalette) ?? 'neopop';
  Future<void> setThemePalette(String value) =>
      _prefs.setString(_kThemePalette, value);
  String get themeMode => _prefs.getString(_kThemeMode) ?? 'system';
  Future<void> setThemeMode(String value) =>
      _prefs.setString(_kThemeMode, value);

  /// Diagnostics and product analytics are opt-in. A null value means the user
  /// has not made a choice yet, so every telemetry provider stays disabled.
  bool? get telemetryAnalyticsConsent =>
      _prefs.getBool(_kTelemetryAnalyticsConsent) ??
      _prefs.getBool(_kTelemetryConsent);
  bool? get telemetryDiagnosticsConsent =>
      _prefs.getBool(_kTelemetryDiagnosticsConsent) ??
      _prefs.getBool(_kTelemetryConsent);
  Future<void> setTelemetryConsent({
    required bool analytics,
    required bool diagnostics,
  }) async {
    await _prefs.setBool(_kTelemetryAnalyticsConsent, analytics);
    await _prefs.setBool(_kTelemetryDiagnosticsConsent, diagnostics);
    await _prefs.remove(_kTelemetryConsent);
  }

  /// Pseudonymous installation identifier created only after consent. It is
  /// removed when consent is revoked and never contains an account identifier.
  String? get telemetryInstallId => _prefs.getString(_kTelemetryInstallId);
  Future<void> setTelemetryInstallId(String? value) async {
    if (value == null || value.isEmpty) {
      await _prefs.remove(_kTelemetryInstallId);
    } else {
      await _prefs.setString(_kTelemetryInstallId, value);
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_kToken);
    await _prefs.remove(_kCachedUser);
  }
}
