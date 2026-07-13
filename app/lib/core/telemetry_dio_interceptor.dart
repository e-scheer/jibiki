import 'dart:async';

import 'package:dio/dio.dart';

import 'telemetry.dart';

class TelemetryDioInterceptor extends Interceptor {
  TelemetryDioInterceptor({Telemetry? telemetry})
      : _telemetry = telemetry ?? Telemetry.instance;

  static const requestIdHeader = 'X-Request-ID';
  static const _traceKey = 'jibiki.telemetry.trace';
  static const _requestIdKey = 'jibiki.telemetry.request_id';

  final Telemetry _telemetry;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = options.headers[requestIdHeader]?.toString() ??
        _telemetry.createRequestId();
    options.headers[requestIdHeader] = requestId;
    options.extra[_requestIdKey] = requestId;
    options.extra[_traceKey] = _telemetry.startRequestTrace(
      method: options.method,
      path: options.path,
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final trace = response.requestOptions.extra[_traceKey];
    if (trace is TelemetryRequestTrace) {
      unawaited(trace.finish(
        outcome: 'success',
        statusCode: response.statusCode,
      ));
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    final trace = options.extra[_traceKey];
    if (trace is TelemetryRequestTrace) {
      unawaited(trace.finish(
        outcome: err.type == DioExceptionType.cancel ? 'cancelled' : 'error',
        statusCode: err.response?.statusCode,
      ));
    }

    final status = err.response?.statusCode;
    if (status != null && status >= 500) {
      unawaited(_telemetry.recordError(
        err.error ?? err,
        err.stackTrace,
        mechanism: 'api_server_error',
        context: {
          'method': options.method,
          'route': Telemetry.normalizeHttpPath(options.path),
          'status': status,
          'request_id': options.extra[_requestIdKey]?.toString(),
        },
      ));
    }
    handler.next(err);
  }
}
