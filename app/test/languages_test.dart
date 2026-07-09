import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/languages.dart';

void main() {
  test('the catalog is the full ISO list, not a hand-picked subset', () {
    final all = allMnemonicLanguages;
    expect(all.length, greaterThan(100));
    // No regional variants - anchors live at the language level.
    expect(all.any((l) => l.code.contains('_')), isFalse);
    // Community languages from our research are all present.
    for (final code in ['pt', 'it', 'ko', 'zh', 'th', 'vi', 'id', 'sw', 'hu']) {
      expect(all.any((l) => l.code == code), isTrue, reason: code);
    }
  });

  test('validation only admits real ISO 639-1 codes', () {
    expect(isValidMnemonicLanguage('fr'), isTrue);
    expect(isValidMnemonicLanguage('vi'), isTrue);
    expect(isValidMnemonicLanguage('xx'), isFalse);
    expect(isValidMnemonicLanguage('en_US'), isFalse);
    expect(isValidMnemonicLanguage(''), isFalse);
  });

  test('native names render, unknown codes degrade gracefully', () {
    expect(mnemonicLanguageName('fr'), 'Français');
    expect(mnemonicLanguageName('ja'), '日本語');
    expect(mnemonicLanguageName('zz'), 'ZZ');
  });

  test('quick chips: seeded + current selection', () {
    expect(quickMnemonicLanguages('en').map((l) => l.code), ['en', 'fr']);
    expect(quickMnemonicLanguages('vi').map((l) => l.code), ['en', 'fr', 'vi']);
    expect(quickMnemonicLanguages('xx').map((l) => l.code), ['en', 'fr']);
  });
}
