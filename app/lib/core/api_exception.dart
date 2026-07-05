/// A normalized API error the UI can render, mapped from Dio failures.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors});

  final String message;
  final int? statusCode;

  /// Field → messages, extracted from DRF / allauth validation error bodies.
  final Map<String, List<String>>? fieldErrors;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}
