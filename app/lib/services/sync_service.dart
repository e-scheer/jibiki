import '../core/api_client.dart';
import '../core/api_config.dart';

/// The /study/sync wire call: upload one outbox page, receive the delta.
class SyncService {
  SyncService(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> sync({
    String? lastSyncedAt,
    String mode = 'sync',
    List<Map<String, dynamic>> reviews = const [],
    List<Map<String, dynamic>> ops = const [],
  }) async {
    final data = await _api.post(ApiConfig.studySync, data: {
      'last_synced_at': lastSyncedAt,
      'mode': mode,
      'reviews': reviews,
      'ops': ops,
    });
    return (data as Map).cast<String, dynamic>();
  }
}
