import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../core/telemetry.dart';

/// Shared ViewModel plumbing: a loading flag, a last-error message, and a guarded
/// runner that handles expected API failures and reports unexpected failures.
abstract class BaseViewModel extends ChangeNotifier {
  bool _loading = false;
  String? _error;
  bool _disposed = false;

  bool get isLoading => _loading;
  String? get error => _error;
  bool get hasError => _error != null;

  void clearError() {
    _error = null;
    _safeNotify();
  }

  @protected
  void setError(String? message) {
    _error = message;
    _safeNotify();
  }

  @protected
  Future<T?> runGuarded<T>(Future<T> Function() action,
      {bool silent = false}) async {
    if (_loading && !silent) return null;
    if (!silent) {
      _loading = true;
      _error = null;
      _safeNotify();
    }
    try {
      return await action();
    } on ApiException catch (e) {
      _error = e.isUnauthorized ? authRequiredErrorMessage : e.message;
      return null;
    } catch (error, stackTrace) {
      if (error is DioException && error.type == DioExceptionType.cancel) {
        return null;
      }
      _error = 'Something went wrong. Please try again.';
      unawaited(Telemetry.instance.recordError(
        error,
        stackTrace,
        mechanism: 'view_model',
        context: {'view_model': runtimeType.toString()},
      ));
      return null;
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
