import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/japanese_text.dart';
import 'package:jibiki/views/widgets/tappable_japanese.dart';

void main() {
  for (final literal in ['㐀', '𠮷', '﨑', '丽']) {
    test('rare CJK character $literal remains searchable and lookupable', () {
      expect(isJapanese(literal), isTrue);
      expect(kanjiIn('a$literal$literalかな'), [literal]);
      expect(lookupableChars(literal), [(char: literal, isKanji: true)]);
    });
  }
  test('CJK detection does not mistake emoji or Latin input for kanji', () {
    expect(isJapanese('café🙂'), isFalse);
    expect(kanjiIn('café🙂かな'), isEmpty);
  });
}
