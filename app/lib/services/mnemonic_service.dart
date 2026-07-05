import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/mnemonic.dart';

class MnemonicService {
  MnemonicService(this._api);
  final ApiClient _api;

  Future<List<Mnemonic>> list({
    required String character,
    required String language,
    String kind = 'kana',
  }) async {
    final data = await _api.get(
      ApiConfig.mnemonics,
      query: {'character': character, 'language': language, 'kind': kind},
    );
    final results = (data as Map)['results'] as List? ?? const [];
    return results.map((e) => Mnemonic.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<Mnemonic> create({
    required String character,
    required String kind,
    required String language,
    required String story,
    List<int>? imageBytes,
    String? imageFilename,
  }) async {
    final Object body;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      // Bytes (not a file path) so image_picker works identically on web + mobile.
      body = FormData.fromMap({
        'character': character,
        'kind': kind,
        'language': language,
        'story': story,
        'image': MultipartFile.fromBytes(imageBytes, filename: imageFilename ?? 'mnemonic.jpg'),
      });
    } else {
      body = {'character': character, 'kind': kind, 'language': language, 'story': story};
    }
    final data = await _api.post(ApiConfig.mnemonicCreate, data: body);
    return Mnemonic.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Returns the new (score, myVote).
  Future<(int, int)> vote(int id, int value) async {
    final data = await _api.post(ApiConfig.mnemonicVote(id), data: {'value': value});
    final m = data as Map;
    return ((m['score'] as num).toInt(), (m['my_vote'] as num).toInt());
  }

  /// Toggle the 🔖 bookmark; returns the new saved state.
  Future<bool> save(int id) async {
    final data = await _api.post(ApiConfig.mnemonicSave(id));
    return (data as Map)['saved'] as bool? ?? false;
  }

  Future<List<Mnemonic>> saved() => _listPlain(ApiConfig.mnemonicsSaved);

  /// The signed-in user's own contributions (all statuses), powers the deck
  /// builder's "pick from your drawings" picker.
  Future<List<Mnemonic>> mine() => _listPlain(ApiConfig.mnemonicsMine);

  Future<List<Mnemonic>> _listPlain(String path) async {
    final data = await _api.get(path);
    return (data as List)
        .map((e) => Mnemonic.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> report(int id, String reason, {String detail = ''}) =>
      _api.post(ApiConfig.mnemonicReport(id), data: {'reason': reason, 'detail': detail});
}
