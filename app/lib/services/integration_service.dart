import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/integration.dart';

class WaniKaniService {
  WaniKaniService(this._api);
  final ApiClient _api;

  Future<WaniKaniStatus> status() async =>
      _parse(await _api.get(ApiConfig.waniKani));

  Future<WaniKaniStatus> connect(String token, String threshold) async =>
      _parse(await _api.post(ApiConfig.waniKaniConnect, data: {
        'token': token,
        'threshold': threshold,
      }));

  Future<WaniKaniStatus> sync() async =>
      _parse(await _api.post(ApiConfig.waniKaniSync));

  Future<Map<String, dynamic>> importPreview() async =>
      (await _api.post(ApiConfig.waniKaniImport) as Map)
          .cast<String, dynamic>();

  Future<void> cancel() => _api.post(ApiConfig.waniKaniCancel).then((_) {});

  Future<void> disconnect() => _api.delete(ApiConfig.waniKani).then((_) {});

  WaniKaniStatus _parse(dynamic value) =>
      WaniKaniStatus.fromJson((value as Map).cast<String, dynamic>());
}
