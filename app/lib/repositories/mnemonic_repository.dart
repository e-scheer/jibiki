import 'dart:typed_data';

import '../data/packs/pack_manager.dart';
import '../models/mnemonic.dart';
import '../services/mnemonic_service.dart';

/// Community mnemonics ride the network (they're UGC, images disk-cache once
/// seen); when the feed is unreachable and a seed-mnemonic pack is installed,
/// [list] falls back to it so the visual layer never goes blank offline.
class MnemonicRepository {
  MnemonicRepository(this._service, {PackManager? packs}) : _packs = packs;

  final MnemonicService _service;
  final PackManager? _packs;

  Future<List<Mnemonic>> list({
    required String character,
    required String language,
    String kind = 'kana',
  }) async {
    try {
      return await _service.list(character: character, language: language, kind: kind);
    } catch (_) {
      final offline =
          await _fromPack(character: character, language: language, kind: kind);
      if (offline.isEmpty) rethrow;
      return offline;
    }
  }

  Future<List<Mnemonic>> _fromPack({
    required String character,
    required String language,
    required String kind,
  }) async {
    final packs = _packs;
    final schema = 'mn_$language';
    if (packs == null || !packs.ready || !packs.mnemonicSchemas.contains(schema)) {
      return const [];
    }
    final rows = await packs.db.select(
      'SELECT id, kind, character, language, story, score, image, image_w, image_h '
      'FROM $schema.mnemonics WHERE kind = ? AND character = ? ORDER BY score DESC',
      [kind, character],
    );
    return [
      for (final r in rows)
        Mnemonic(
          id: r['id'] as int,
          character: r['character'] as String? ?? character,
          kind: r['kind'] as String? ?? kind,
          language: r['language'] as String? ?? language,
          story: r['story'] as String? ?? '',
          imageSrc: '',
          imageBytes: r['image'] as Uint8List?,
          imageWidth: r['image_w'] as int? ?? 0,
          imageHeight: r['image_h'] as int? ?? 0,
          authorName: 'jibiki',
          isSeed: true,
          status: 'visible',
          score: r['score'] as int? ?? 0,
          myVote: 0,
          saved: false,
        ),
    ];
  }

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
