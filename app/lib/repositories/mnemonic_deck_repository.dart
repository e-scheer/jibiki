import '../models/mnemonic_deck.dart';
import '../services/mnemonic_deck_service.dart';

class MnemonicDeckRepository {
  MnemonicDeckRepository(this._service);
  final MnemonicDeckService _service;

  Future<List<MnemonicDeck>> list({String? language, String? kind, bool mine = false}) =>
      _service.list(language: language, kind: kind, mine: mine);

  Future<MnemonicDeck> detail(int id) => _service.detail(id);

  Future<MnemonicDeck> create({
    required String title,
    String description = '',
    required String language,
    required String kind,
    required List<int> mnemonicIds,
    bool publish = false,
  }) =>
      _service.create(
        title: title,
        description: description,
        language: language,
        kind: kind,
        mnemonicIds: mnemonicIds,
        publish: publish,
      );

  Future<String> publish(int id) => _service.publish(id);
  Future<(int, int)> vote(int id, int value) => _service.vote(id, value);
  Future<int> enroll(int id) => _service.enroll(id);
}
