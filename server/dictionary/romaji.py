"""Hepburn transliteration kept in parity with app/lib/core/japanese_text.dart."""

import re

ROMAJI_KANA = {
    "kya": "きゃ",
    "kyu": "きゅ",
    "kyo": "きょ",
    "gya": "ぎゃ",
    "gyu": "ぎゅ",
    "gyo": "ぎょ",
    "sha": "しゃ",
    "shu": "しゅ",
    "sho": "しょ",
    "shi": "し",
    "ja": "じゃ",
    "ju": "じゅ",
    "jo": "じょ",
    "ji": "じ",
    "jya": "じゃ",
    "jyu": "じゅ",
    "jyo": "じょ",
    "cha": "ちゃ",
    "chu": "ちゅ",
    "cho": "ちょ",
    "chi": "ち",
    "nya": "にゃ",
    "nyu": "にゅ",
    "nyo": "にょ",
    "hya": "ひゃ",
    "hyu": "ひゅ",
    "hyo": "ひょ",
    "bya": "びゃ",
    "byu": "びゅ",
    "byo": "びょ",
    "pya": "ぴゃ",
    "pyu": "ぴゅ",
    "pyo": "ぴょ",
    "mya": "みゃ",
    "myu": "みゅ",
    "myo": "みょ",
    "rya": "りゃ",
    "ryu": "りゅ",
    "ryo": "りょ",
    "tsu": "つ",
    "fu": "ふ",
    "a": "あ",
    "i": "い",
    "u": "う",
    "e": "え",
    "o": "お",
    "ka": "か",
    "ki": "き",
    "ku": "く",
    "ke": "け",
    "ko": "こ",
    "ga": "が",
    "gi": "ぎ",
    "gu": "ぐ",
    "ge": "げ",
    "go": "ご",
    "sa": "さ",
    "si": "し",
    "su": "す",
    "se": "せ",
    "so": "そ",
    "za": "ざ",
    "zi": "じ",
    "zu": "ず",
    "ze": "ぜ",
    "zo": "ぞ",
    "ta": "た",
    "ti": "ち",
    "tu": "つ",
    "te": "て",
    "to": "と",
    "da": "だ",
    "di": "ぢ",
    "du": "づ",
    "de": "で",
    "do": "ど",
    "na": "な",
    "ni": "に",
    "nu": "ぬ",
    "ne": "ね",
    "no": "の",
    "ha": "は",
    "hi": "ひ",
    "he": "へ",
    "ho": "ほ",
    "ba": "ば",
    "bi": "び",
    "bu": "ぶ",
    "be": "べ",
    "bo": "ぼ",
    "pa": "ぱ",
    "pi": "ぴ",
    "pu": "ぷ",
    "pe": "ぺ",
    "po": "ぽ",
    "ma": "ま",
    "mi": "み",
    "mu": "む",
    "me": "め",
    "mo": "も",
    "ya": "や",
    "yu": "ゆ",
    "yo": "よ",
    "ra": "ら",
    "ri": "り",
    "ru": "る",
    "re": "れ",
    "ro": "ろ",
    "wa": "わ",
    "wo": "を",
    "n'": "ん",
    "n": "ん",
}


def romaji_to_hiragana(value: str) -> str | None:
    text = value.strip().lower()
    if not text or not re.fullmatch(r"[a-z']+", text):
        return None
    result, index = [], 0
    while index < len(text):
        if (
            index + 1 < len(text)
            and text[index] == text[index + 1]
            and text[index] != "n"
            and text[index] not in "aeiou"
        ):
            result.append("っ")
            index += 1
            continue
        for size in (3, 2, 1):
            if index + size > len(text):
                continue
            kana = ROMAJI_KANA.get(text[index : index + size])
            if kana is not None:
                result.append(kana)
                index += size
                break
        else:
            return None
    return "".join(result)
