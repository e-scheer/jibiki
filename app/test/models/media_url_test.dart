import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_config.dart';
import 'package:jibiki/models/mnemonic.dart';
import 'package:jibiki/models/mnemonic_deck.dart';

void main() {
  group('API media URLs', () {
    test('resolves mnemonic paths with or without a leading slash', () {
      final withSlash = _mnemonic('/media/mnemonics/a.webp');
      final withoutSlash = _mnemonic('media/mnemonics/a.webp');

      expect(withSlash.imageUrl, '${ApiConfig.baseUrl}/media/mnemonics/a.webp');
      expect(withoutSlash.imageUrl, withSlash.imageUrl);
    });

    test('keeps absolute mnemonic URLs unchanged', () {
      const url = 'https://cdn.jibiki.app/mnemonics/a.webp';
      expect(_mnemonic(url).imageUrl, url);
    });

    test('resolves mnemonic deck cover paths', () {
      final deck = MnemonicDeck.fromJson({
        'id': 1,
        'cover_src': 'media/decks/cover.webp',
      });

      expect(deck.coverUrl, '${ApiConfig.baseUrl}/media/decks/cover.webp');
    });
  });
}

Mnemonic _mnemonic(String imageSrc) => Mnemonic.fromJson({
      'id': 1,
      'image_src': imageSrc,
    });
