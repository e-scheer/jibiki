import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/user.dart';

/// Talks to allauth headless (app client) for auth flows, and to the domain
/// profile endpoint for jibiki-specific settings. Returns the session token;
/// persistence is the caller's job (AuthRepository → SessionStore).
class AuthService {
  AuthService(this._api);
  final ApiClient _api;

  Future<String> signup(String email, String password) =>
      _tokenFrom(ApiConfig.authSignup, {'email': email, 'password': password});

  Future<String> login(String email, String password) =>
      _tokenFrom(ApiConfig.authLogin, {'email': email, 'password': password});

  Future<AppUser> me() async {
    final data = await _api.get(ApiConfig.me);
    return AppUser.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<AppUser> updateProfile(Map<String, dynamic> patch) async {
    final data = await _api.patch(ApiConfig.me, data: patch);
    return AppUser.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> logout() async {
    // allauth headless logs out by DELETE-ing the session; ignore the response.
    try {
      await _api.delete(ApiConfig.authSession);
    } catch (_) {
      // Even if the server call fails, the client drops the token regardless.
    }
  }

  Future<String> _tokenFrom(String path, Map<String, dynamic> body) async {
    final resp = await _api.postRaw(path, data: body);
    final data = resp.data;
    final meta = (data is Map ? data['meta'] : null) as Map?;
    final fromBody = meta?['session_token'] as String?;
    final fromHeader = resp.headers.value('x-session-token');
    final token = (fromBody != null && fromBody.isNotEmpty) ? fromBody : fromHeader;
    if (token == null || token.isEmpty) {
      throw StateError('No session token returned, email verification may be required.');
    }
    return token;
  }
}
