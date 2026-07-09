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
}
