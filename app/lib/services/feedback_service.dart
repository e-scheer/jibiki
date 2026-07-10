import '../core/api_client.dart';
import '../core/api_config.dart';

class FeedbackService {
  FeedbackService(this._api);

  final ApiClient _api;

  Future<void> send({
    required String kind,
    required String message,
    String email = '',
    Map<String, dynamic> context = const {},
  }) =>
      _api.post(ApiConfig.feedback, data: {
        'kind': kind,
        'message': message,
        if (email.isNotEmpty) 'email': email,
        'context': context,
      });

  /// Flag a dictionary entry as wrong or incomplete. Requires a signed-in
  /// session (the endpoint rejects anonymous callers).
  Future<void> reportContent({
    required String itemType,
    required String itemRef,
    required String reason,
    String message = '',
    Map<String, dynamic> context = const {},
  }) =>
      _api.post(ApiConfig.contentReport, data: {
        'item_type': itemType,
        'item_ref': itemRef,
        'reason': reason,
        if (message.isNotEmpty) 'message': message,
        'context': context,
      });
}
