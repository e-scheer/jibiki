import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/mnemonic_deck.dart';

/// Talks to the community-deck endpoints (browse / mine / detail / create /
/// publish / like / enroll).
class MnemonicDeckService {
  MnemonicDeckService(this._api);
  final ApiClient _api;

  Future<List<MnemonicDeck>> list({String? language, String? kind, bool mine = false}) async {
    final data = await _api.get(ApiConfig.mnemonicDecks, query: {
      if (mine) 'mine': '1',
      if (language != null) 'language': language,
      if (kind != null) 'kind': kind,
    });
    final results = (data as Map)['results'] as List? ?? const [];
    return results
        .map((e) => MnemonicDeck.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<MnemonicDeck> detail(int id) async {
    final data = await _api.get(ApiConfig.mnemonicDeck(id));
    return MnemonicDeck.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<MnemonicDeck> create({
    required String title,
    String description = '',
    required String language,
    required String kind,
    required List<int> mnemonicIds,
    bool publish = false,
  }) async {
    final data = await _api.post(ApiConfig.mnemonicDeckCreate, data: {
      'title': title,
      'description': description,
      'language': language,
      'kind': kind,
      'mnemonic_ids': mnemonicIds,
      'publish': publish,
    });
    return MnemonicDeck.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Returns the deck's new status (visible | pending).
  Future<String> publish(int id) async {
    final data = await _api.post(ApiConfig.mnemonicDeckPublish(id));
    return (data as Map)['status'] as String? ?? 'pending';
  }

  /// Returns the new (score, myVote).
  Future<(int, int)> vote(int id, int value) async {
    final data = await _api.post(ApiConfig.mnemonicDeckVote(id), data: {'value': value});
    final m = data as Map;
    return ((m['score'] as num).toInt(), (m['my_vote'] as num).toInt());
  }

  /// Study a community deck; returns how many cards were enrolled.
  Future<int> enroll(int id) async {
    final data = await _api.post(ApiConfig.mnemonicDeckEnroll(id));
    return (data as Map)['enrolled'] as int? ?? 0;
  }
}
