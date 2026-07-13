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

  Future<void> inspectEmailVerificationKey(String key) async {
    await _api.get(
      ApiConfig.authVerifyEmail,
      headers: {'X-Email-Verification-Key': key},
    );
  }

  Future<void> verifyEmail(String key) async {
    // A successful confirmation returns AuthenticationResponse. When allauth
    // does not automatically sign the learner in, that response is 401 even
    // though the email mutation succeeded.
    await _api.postRaw(
      ApiConfig.authVerifyEmail,
      data: {'key': key},
      acceptedStatusCodes: const {401},
    );
  }

  Future<void> requestPasswordReset(String email) async {
    await _api.post(
      ApiConfig.authRequestPasswordReset,
      data: {'email': email},
    );
  }

  Future<void> inspectPasswordResetKey(String key) async {
    await _api.get(
      ApiConfig.authResetPassword,
      headers: {'X-Password-Reset-Key': key},
    );
  }

  Future<void> resetPassword(String key, String password) async {
    // Password reset has the same unauthenticated success response as email
    // verification when ACCOUNT_LOGIN_ON_PASSWORD_RESET is disabled.
    await _api.postRaw(
      ApiConfig.authResetPassword,
      data: {'key': key, 'password': password},
      acceptedStatusCodes: const {401},
    );
  }

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
    final token =
        (fromBody != null && fromBody.isNotEmpty) ? fromBody : fromHeader;
    if (token == null || token.isEmpty) {
      throw StateError(
          'No session token returned, email verification may be required.');
    }
    return token;
  }
}
