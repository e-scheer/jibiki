import '../models/mnemonic.dart';
import '../services/mnemonic_service.dart';

class MnemonicRepository {
  MnemonicRepository(this._service);
  final MnemonicService _service;

  Future<List<Mnemonic>> list({
    required String character,
    required String language,
    String kind = 'kana',
  }) =>
      _service.list(character: character, language: language, kind: kind);

  Future<Mnemonic> create({
    required String character,
    required String kind,
    required String language,
    required String story,
    List<int>? imageBytes,
    String? imageFilename,
  }) =>
      _service.create(
        character: character,
        kind: kind,
        language: language,
        story: story,
        imageBytes: imageBytes,
        imageFilename: imageFilename,
      );

  Future<(int, int)> vote(int id, int value) => _service.vote(id, value);
  Future<bool> save(int id) => _service.save(id);
  Future<List<Mnemonic>> saved() => _service.saved();
  Future<List<Mnemonic>> mine() => _service.mine();
  Future<void> report(int id, String reason, {String detail = ''}) =>
      _service.report(id, reason, detail: detail);
}
