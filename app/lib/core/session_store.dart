import 'package:shared_preferences/shared_preferences.dart';

/// Persists the allauth session token + the last onboarding decision so the app
/// can decide, on launch, whether to show auth / onboarding / home without a
/// network round-trip. (Use flutter_secure_storage in production for the token.)
class SessionStore {
  SessionStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kToken = 'session_token';
  static const _kOnboarded = 'onboarded';

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

  Future<void> clear() async {
    await _prefs.remove(_kToken);
  }
}
