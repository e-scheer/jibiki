import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/api_config.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient(super.session);

  final List<({String method, String path, Object? data, Object? headers})>
      calls = [];

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, Object?>? headers,
  }) async {
    calls.add((method: 'GET', path: path, data: query, headers: headers));
    return const {};
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    calls.add((method: 'POST', path: path, data: data, headers: null));
    return const {};
  }

  @override
  Future<Response<dynamic>> postRaw(
    String path, {
    Object? data,
    Set<int> acceptedStatusCodes = const {},
  }) async {
    calls.add((
      method: 'POST',
      path: path,
      data: data,
      headers: acceptedStatusCodes,
    ));
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 401,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('auth recovery uses the allauth app-client wire contract', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final api = _RecordingApiClient(SessionStore(preferences));
    final service = AuthService(api);

    await service.inspectEmailVerificationKey('email-key');
    await service.verifyEmail('email-key');
    await service.requestPasswordReset('learner@example.com');
    await service.inspectPasswordResetKey('reset-key');
    await service.resetPassword('reset-key', 'new-password');

    expect(api.calls, hasLength(5));
    expect(api.calls[0].method, 'GET');
    expect(api.calls[0].path, ApiConfig.authVerifyEmail);
    expect(api.calls[0].headers, {
      'X-Email-Verification-Key': 'email-key',
    });

    expect(api.calls[1].method, 'POST');
    expect(api.calls[1].path, ApiConfig.authVerifyEmail);
    expect(api.calls[1].data, {'key': 'email-key'});
    expect(api.calls[1].headers, {401});

    expect(api.calls[2].method, 'POST');
    expect(api.calls[2].path, ApiConfig.authRequestPasswordReset);
    expect(api.calls[2].data, {'email': 'learner@example.com'});

    expect(api.calls[3].method, 'GET');
    expect(api.calls[3].path, ApiConfig.authResetPassword);
    expect(api.calls[3].headers, {
      'X-Password-Reset-Key': 'reset-key',
    });

    expect(api.calls[4].method, 'POST');
    expect(api.calls[4].path, ApiConfig.authResetPassword);
    expect(api.calls[4].data, {
      'key': 'reset-key',
      'password': 'new-password',
    });
    expect(api.calls[4].headers, {401});
  });
}
