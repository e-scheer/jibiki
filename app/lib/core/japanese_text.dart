/// Japanese text helpers - the Dart side of server/dictionary/search.py
/// (`is_japanese`, `kanji_in`) plus a romaji→hiragana transliterator the
/// server never had: offline search can answer "tabemono" like a native
/// Japanese query instead of a gloss lookup.
library;

// Unicode blocks that mark a query as Japanese input (same as the server).
const int _hiraganaLo = 0x3040, _hiraganaHi = 0x309F;
const int _katakanaLo = 0x30A0, _katakanaHi = 0x30FF;
const int _cjkLo = 0x4E00, _cjkHi = 0x9FFF;

bool isJapanese(String text) {
  for (final cp in text.runes) {
    if ((cp >= _hiraganaLo && cp <= _hiraganaHi) ||
        (cp >= _katakanaLo && cp <= _katakanaHi) ||
        (cp >= _cjkLo && cp <= _cjkHi)) {
      return true;
    }
  }
  return false;
}

/// The distinct CJK characters in a string, in order - a word's constituent
/// kanji for the detail breakdown.
List<String> kanjiIn(String text) {
  final out = <String>[];
  final seen = <int>{};
  for (final cp in text.runes) {
    if (cp >= _cjkLo && cp <= _cjkHi && seen.add(cp)) {
      out.add(String.fromCharCode(cp));
    }
  }
  return out;
}

/// Hepburn romaji → hiragana, or null when the input isn't fully
/// transliterable (then it's treated as a gloss query). Longest-match table
/// driven; handles sokuon (doubled consonants → っ), yōon (kya…), and the
/// bare-`n` ambiguity by trying `n`+vowel digraphs before ん.
String? romajiToHiragana(String input) {
  final s = input.trim().toLowerCase();
  if (s.isEmpty || !RegExp(r"^[a-z']+$").hasMatch(s)) return null;

  final out = StringBuffer();
  var i = 0;
  while (i < s.length) {
    // Doubled consonant (except n) = sokuon.
    if (i + 1 < s.length &&
        s[i] == s[i + 1] &&
        s[i] != 'n' &&
        !'aeiou'.contains(s[i])) {
      out.write('っ');
      i++;
      continue;
    }
    var matched = false;
    for (var len = 3; len >= 1; len--) {
      if (i + len > s.length) continue;
      final kana = _romajiKana[s.substring(i, i + len)];
      if (kana != null) {
        out.write(kana);
        i += len;
        matched = true;
        break;
      }
    }
    if (!matched) return null;
  }
  return out.toString();
}

const Map<String, String> _romajiKana = {
  // yōon and digraphs first in spirit - lookup is longest-match.
  'kya': 'きゃ', 'kyu': 'きゅ', 'kyo': 'きょ',
  'gya': 'ぎゃ', 'gyu': 'ぎゅ', 'gyo': 'ぎょ',
  'sha': 'しゃ', 'shu': 'しゅ', 'sho': 'しょ', 'shi': 'し',
  'ja': 'じゃ', 'ju': 'じゅ', 'jo': 'じょ', 'ji': 'じ',
  'jya': 'じゃ', 'jyu': 'じゅ', 'jyo': 'じょ',
  'cha': 'ちゃ', 'chu': 'ちゅ', 'cho': 'ちょ', 'chi': 'ち',
  'nya': 'にゃ', 'nyu': 'にゅ', 'nyo': 'にょ',
  'hya': 'ひゃ', 'hyu': 'ひゅ', 'hyo': 'ひょ',
  'bya': 'びゃ', 'byu': 'びゅ', 'byo': 'びょ',
  'pya': 'ぴゃ', 'pyu': 'ぴゅ', 'pyo': 'ぴょ',
  'mya': 'みゃ', 'myu': 'みゅ', 'myo': 'みょ',
  'rya': 'りゃ', 'ryu': 'りゅ', 'ryo': 'りょ',
  'tsu': 'つ', 'fu': 'ふ',
  'a': 'あ', 'i': 'い', 'u': 'う', 'e': 'え', 'o': 'お',
  'ka': 'か', 'ki': 'き', 'ku': 'く', 'ke': 'け', 'ko': 'こ',
  'ga': 'が', 'gi': 'ぎ', 'gu': 'ぐ', 'ge': 'げ', 'go': 'ご',
  'sa': 'さ', 'si': 'し', 'su': 'す', 'se': 'せ', 'so': 'そ',
  'za': 'ざ', 'zi': 'じ', 'zu': 'ず', 'ze': 'ぜ', 'zo': 'ぞ',
  'ta': 'た', 'ti': 'ち', 'tu': 'つ', 'te': 'て', 'to': 'と',
  'da': 'だ', 'di': 'ぢ', 'du': 'づ', 'de': 'で', 'do': 'ど',
  'na': 'な', 'ni': 'に', 'nu': 'ぬ', 'ne': 'ね', 'no': 'の',
  'ha': 'は', 'hi': 'ひ', 'he': 'へ', 'ho': 'ほ',
  'ba': 'ば', 'bi': 'び', 'bu': 'ぶ', 'be': 'べ', 'bo': 'ぼ',
  'pa': 'ぱ', 'pi': 'ぴ', 'pu': 'ぷ', 'pe': 'ぺ', 'po': 'ぽ',
  'ma': 'ま', 'mi': 'み', 'mu': 'む', 'me': 'め', 'mo': 'も',
  'ya': 'や', 'yu': 'ゆ', 'yo': 'よ',
  'ra': 'ら', 'ri': 'り', 'ru': 'る', 're': 'れ', 'ro': 'ろ',
  'wa': 'わ', 'wo': 'を',
  "n'": 'ん', 'n': 'ん',
};
