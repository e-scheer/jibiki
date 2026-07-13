import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_exception.dart';
import 'session_store.dart';
import 'telemetry_dio_interceptor.dart';

/// Thin Dio wrapper: injects the allauth session token as `X-Session-Token` on
/// every request and normalizes failures to [ApiException]. All services talk to
/// the API through this one client.
class ApiClient {
  ApiClient(this._session)
      : _dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          // Fail promptly when the API is unreachable instead of hanging the
          // splash / a screen on the OS default (which can be minutes).
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
        )) {
    _dio.interceptors.add(TelemetryDioInterceptor());
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Accept-Language'] = _interfaceLanguage;
          final token = _session.token;
          if (token != null && token.isNotEmpty) {
            options.headers['X-Session-Token'] = token;
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final SessionStore _session;
  String _interfaceLanguage = 'en';

  void setInterfaceLanguage(String language) {
    _interfaceLanguage = language == 'fr' ? 'fr' : 'en';
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, Object?>? headers,
  }) =>
      _request(() => _dio.get(
            path,
            queryParameters: query,
            options: headers == null ? null : Options(headers: headers),
          ));

  /// A GET whose body is plain text (e.g. the Anki TSV export), not JSON.
  Future<String> getText(String path) async {
    try {
      final resp = await _dio.get<String>(
        path,
        options: Options(responseType: ResponseType.plain),
      );
      return resp.data ?? '';
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<dynamic> post(String path,
          {Object? data, Map<String, dynamic>? query}) =>
      _request(() => _dio.post(path, data: data, queryParameters: query));

  Future<dynamic> patch(String path, {Object? data}) =>
      _request(() => _dio.patch(path, data: data));

  Future<dynamic> delete(String path) => _request(() => _dio.delete(path));

  /// A raw request that also exposes response headers (used by AuthService to
  /// read the X-Session-Token echoed on signup/login).
  Future<Response<dynamic>> postRaw(
    String path, {
    Object? data,
    Set<int> acceptedStatusCodes = const {},
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        options: acceptedStatusCodes.isEmpty
            ? null
            : Options(
                validateStatus: (status) =>
                    status != null &&
                    ((status >= 200 && status < 300) ||
                        acceptedStatusCodes.contains(status)),
              ),
      );
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<dynamic> _request(Future<Response<dynamic>> Function() run) async {
    try {
      final resp = await run();
      return resp.data;
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  ApiException _map(DioException e) {
    final resp = e.response;
    final status = resp?.statusCode;
    if (resp == null) {
      return ApiException(
        _interfaceLanguage == 'fr'
            ? 'Jibiki est momentanément inaccessible. Vérifiez votre connexion puis réessayez.'
            : 'Jibiki is temporarily unreachable. Check your connection and try again.',
        statusCode: null,
      );
    }
    final data = resp.data;
    final fieldErrors = _fieldErrors(data);
    return ApiException(_message(data, status),
        statusCode: status, fieldErrors: fieldErrors);
  }

  String _message(dynamic data, int? status) {
    if (data is Map) {
      // DRF: {"detail": "..."}
      if (data['detail'] is String) return data['detail'] as String;
      // allauth headless: {"status": 400, "errors": [{"message": "..."}]}
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is Map && first['message'] is String) {
          return first['message'] as String;
        }
      }
      // DRF field errors: surface the first one.
      final fe = _fieldErrors(data);
      if (fe != null && fe.isNotEmpty) return fe.values.first.first;
    }
    if (_interfaceLanguage == 'fr') {
      return switch (status) {
        400 => 'Requête invalide.',
        401 || 403 => 'Connectez-vous pour continuer.',
        404 => 'Introuvable.',
        429 => 'Trop de requêtes, réessayez dans un instant.',
        _ => 'Une erreur est survenue (HTTP $status).',
      };
    }
    return switch (status) {
      400 => 'Invalid request.',
      401 || 403 => 'Please sign in to continue.',
      404 => 'Not found.',
      429 => 'Too many requests, slow down a moment.',
      _ => 'Something went wrong (HTTP $status).',
    };
  }

  Map<String, List<String>>? _fieldErrors(dynamic data) {
    if (data is! Map) return null;
    final out = <String, List<String>>{};
    // allauth error array carries a `param` per error.
    final errors = data['errors'];
    if (errors is List) {
      for (final e in errors) {
        if (e is Map && e['message'] is String) {
          final key = (e['param'] as String?) ?? 'detail';
          out.putIfAbsent(key, () => []).add(e['message'] as String);
        }
      }
    }
    // DRF: {"field": ["msg", ...]}
    data.forEach((key, value) {
      if (key == 'detail' || key == 'errors' || key == 'status') return;
      if (value is List) {
        out
            .putIfAbsent(key.toString(), () => [])
            .addAll(value.map((v) => v.toString()));
      } else if (value is String) {
        out.putIfAbsent(key.toString(), () => []).add(value);
      }
    });
    return out.isEmpty ? null : out;
  }
}
