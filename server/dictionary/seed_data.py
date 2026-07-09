"""Curated, bundled demo dataset - small enough to commit, rich enough to exercise
every screen offline (the DEEP_SEARCH stage-1 "seed bundled data, no upload infra"
rule). The full EDRDG data loads over the top of this via the import_* commands.

Nothing here is request-path; it is read once by `manage.py seed_demo`.
"""

from __future__ import annotations

# ── Kana ──────────────────────────────────────────────────────────────────────
# (romaji, hiragana, katakana, row, kind). kind: gojuon | dakuten | handakuten.
KANA: list[tuple[str, str, str, str, str]] = [
    # gojūon
    ("a", "あ", "ア", "a", "gojuon"),
    ("i", "い", "イ", "a", "gojuon"),
    ("u", "う", "ウ", "a", "gojuon"),
    ("e", "え", "エ", "a", "gojuon"),
    ("o", "お", "オ", "a", "gojuon"),
    ("ka", "か", "カ", "k", "gojuon"),
    ("ki", "き", "キ", "k", "gojuon"),
    ("ku", "く", "ク", "k", "gojuon"),
    ("ke", "け", "ケ", "k", "gojuon"),
    ("ko", "こ", "コ", "k", "gojuon"),
    ("sa", "さ", "サ", "s", "gojuon"),
    ("shi", "し", "シ", "s", "gojuon"),
    ("su", "す", "ス", "s", "gojuon"),
    ("se", "せ", "セ", "s", "gojuon"),
    ("so", "そ", "ソ", "s", "gojuon"),
    ("ta", "た", "タ", "t", "gojuon"),
    ("chi", "ち", "チ", "t", "gojuon"),
    ("tsu", "つ", "ツ", "t", "gojuon"),
    ("te", "て", "テ", "t", "gojuon"),
    ("to", "と", "ト", "t", "gojuon"),
    ("na", "な", "ナ", "n", "gojuon"),
    ("ni", "に", "ニ", "n", "gojuon"),
    ("nu", "ぬ", "ヌ", "n", "gojuon"),
    ("ne", "ね", "ネ", "n", "gojuon"),
    ("no", "の", "ノ", "n", "gojuon"),
    ("ha", "は", "ハ", "h", "gojuon"),
    ("hi", "ひ", "ヒ", "h", "gojuon"),
    ("fu", "ふ", "フ", "h", "gojuon"),
    ("he", "へ", "ヘ", "h", "gojuon"),
    ("ho", "ほ", "ホ", "h", "gojuon"),
    ("ma", "ま", "マ", "m", "gojuon"),
    ("mi", "み", "ミ", "m", "gojuon"),
    ("mu", "む", "ム", "m", "gojuon"),
    ("me", "め", "メ", "m", "gojuon"),
    ("mo", "も", "モ", "m", "gojuon"),
    ("ya", "や", "ヤ", "y", "gojuon"),
    ("yu", "ゆ", "ユ", "y", "gojuon"),
    ("yo", "よ", "ヨ", "y", "gojuon"),
    ("ra", "ら", "ラ", "r", "gojuon"),
    ("ri", "り", "リ", "r", "gojuon"),
    ("ru", "る", "ル", "r", "gojuon"),
    ("re", "れ", "レ", "r", "gojuon"),
    ("ro", "ろ", "ロ", "r", "gojuon"),
    ("wa", "わ", "ワ", "w", "gojuon"),
    ("wo", "を", "ヲ", "w", "gojuon"),
    ("n", "ん", "ン", "n", "gojuon"),
    # dakuten
    ("ga", "が", "ガ", "g", "dakuten"),
    ("gi", "ぎ", "ギ", "g", "dakuten"),
    ("gu", "ぐ", "グ", "g", "dakuten"),
    ("ge", "げ", "ゲ", "g", "dakuten"),
    ("go", "ご", "ゴ", "g", "dakuten"),
    ("za", "ざ", "ザ", "z", "dakuten"),
    ("ji", "じ", "ジ", "z", "dakuten"),
    ("zu", "ず", "ズ", "z", "dakuten"),
    ("ze", "ぜ", "ゼ", "z", "dakuten"),
    ("zo", "ぞ", "ゾ", "z", "dakuten"),
    ("da", "だ", "ダ", "d", "dakuten"),
    ("di", "ぢ", "ヂ", "d", "dakuten"),
    ("du", "づ", "ヅ", "d", "dakuten"),
    ("de", "で", "デ", "d", "dakuten"),
    ("do", "ど", "ド", "d", "dakuten"),
    ("ba", "ば", "バ", "b", "dakuten"),
    ("bi", "び", "ビ", "b", "dakuten"),
    ("bu", "ぶ", "ブ", "b", "dakuten"),
    ("be", "べ", "ベ", "b", "dakuten"),
    ("bo", "ぼ", "ボ", "b", "dakuten"),
    # handakuten
    ("pa", "ぱ", "パ", "p", "handakuten"),
    ("pi", "ぴ", "ピ", "p", "handakuten"),
    ("pu", "ぷ", "プ", "p", "handakuten"),
    ("pe", "ぺ", "ペ", "p", "handakuten"),
    ("po", "ぽ", "ポ", "p", "handakuten"),
]

# ── Kana writing origins (man'yōgana) ──────────────────────────────────────────
# Every kana descends from a man'yōgana kanji used purely for its *sound*. Each
# hiragana is a whole-kanji cursive (草書) simplification; each katakana is a
# *fragment* taken from one. This is the standard derivation table.
#   romaji → (hiragana source kanji, katakana source kanji)
KANA_ORIGINS: dict[str, tuple[str, str]] = {
    "a": ("安", "阿"), "i": ("以", "伊"), "u": ("宇", "宇"), "e": ("衣", "江"), "o": ("於", "於"),
    "ka": ("加", "加"), "ki": ("幾", "幾"), "ku": ("久", "久"), "ke": ("計", "介"), "ko": ("己", "己"),
    "sa": ("左", "散"), "shi": ("之", "之"), "su": ("寸", "須"), "se": ("世", "世"), "so": ("曽", "曽"),
    "ta": ("太", "多"), "chi": ("知", "千"), "tsu": ("川", "川"), "te": ("天", "天"), "to": ("止", "止"),
    "na": ("奈", "奈"), "ni": ("仁", "二"), "nu": ("奴", "奴"), "ne": ("祢", "祢"), "no": ("乃", "乃"),
    "ha": ("波", "八"), "hi": ("比", "比"), "fu": ("不", "不"), "he": ("部", "部"), "ho": ("保", "保"),
    "ma": ("末", "万"), "mi": ("美", "三"), "mu": ("武", "牟"), "me": ("女", "女"), "mo": ("毛", "毛"),
    "ya": ("也", "也"), "yu": ("由", "由"), "yo": ("与", "与"),
    "ra": ("良", "良"), "ri": ("利", "利"), "ru": ("留", "流"), "re": ("礼", "礼"), "ro": ("呂", "呂"),
    "wa": ("和", "和"), "wo": ("遠", "乎"), "n": ("无", "尓"),
}

# A voiced (dakuten ゛) or half-voiced (handakuten ゜) kana is not derived from its
# own kanji - it is a base gojūon kana wearing a diacritic. Map each to its base.
_DAKUTEN_BASE: dict[str, str] = {
    "ga": "ka", "gi": "ki", "gu": "ku", "ge": "ke", "go": "ko",
    "za": "sa", "ji": "shi", "zu": "su", "ze": "se", "zo": "so",
    "da": "ta", "di": "chi", "du": "tsu", "de": "te", "do": "to",
    "ba": "ha", "bi": "hi", "bu": "fu", "be": "he", "bo": "ho",
    "pa": "ha", "pi": "hi", "pu": "fu", "pe": "he", "po": "ho",
}

# romaji → (hiragana char, katakana char) - for pointing a dakuten kana at its base.
_KANA_CHARS: dict[str, tuple[str, str]] = {
    romaji: (hira, kata) for romaji, hira, kata, _row, _kind in KANA
}


def kana_origin(romaji: str, script: str, kind: str) -> tuple[str, str]:
    """(origin_char, origin_note) for one kana.

    Gojūon kana point at their man'yōgana source kanji; dakuten/handakuten kana
    point at the base gojūon kana they are built from, with a note about the mark.
    Returns ("", "") when the sound isn't in the table (e.g. yōon).
    """
    is_hira = script == "hiragana"

    if kind == "gojuon":
        src = KANA_ORIGINS.get(romaji)
        if not src:
            return ("", "")
        origin = src[0] if is_hira else src[1]
        if is_hira:
            note = f"Cursive simplification of the man'yōgana kanji {origin}, borrowed for its sound."
        else:
            note = f"Taken from a fragment of the man'yōgana kanji {origin}, borrowed for its sound."
        return (origin, note)

    base = _DAKUTEN_BASE.get(romaji)
    if not base or base not in _KANA_CHARS:
        return ("", "")
    base_char = _KANA_CHARS[base][0 if is_hira else 1]
    if kind == "handakuten":
        note = f"{base_char} with the handakuten mark (゜) - the “p” form of {base_char}."
    else:
        note = f"{base_char} with the dakuten mark (゛) - the voiced form of {base_char}."
    return (base_char, note)


# ── Kana grammatical role (particles) ──────────────────────────────────────────
# Most kana are purely phonetic, but a handful pull double duty as grammar - the
# particles (助詞) and a couple of special glyphs. This is what gives a kana a
# *job in a sentence* beyond its sound. Written in hiragana, so only the hiragana
# member of a pair carries it. romaji → (short role label, one-line explanation).
KANA_USAGE: dict[str, tuple[str, str]] = {
    "ha": ("Topic particle", "Marks the topic - “as for …”. Written は, but read wa when it's the particle."),
    "ga": ("Subject particle", "Marks the grammatical subject; between clauses it also means “but”."),
    "wo": ("Object particle", "Marks the direct object of a verb. Only ever a particle, and read o."),
    "ni": ("Particle", "Points to a destination, a time, or an indirect object - “to, at, in, on”."),
    "he": ("Direction particle", "Marks the direction of movement - “to, toward”. Read e as the particle."),
    "de": ("Particle", "Marks where an action happens or the means used - “at, by, with”."),
    "to": ("Particle", "Joins nouns as a full “and”, means “with”, and marks quotations."),
    "no": ("Possessive particle", "Links nouns - “’s / of” - and can turn a whole clause into a noun."),
    "mo": ("Particle", "“Also, too, even” - replaces は or が to add “as well”."),
    "ya": ("Particle", "Lists nouns loosely - “… and … (among others)”."),
    "ka": ("Question particle", "At a sentence's end it makes a question; between nouns it means “or”."),
    "wa": ("Sentence-final particle", "Soft emphasis at a sentence's end, common in feminine speech."),
    "ne": ("Sentence-final particle", "Seeks agreement - “…, right? / isn't it?”."),
    "yo": ("Sentence-final particle", "Adds emphasis or new information - “… you know!”."),
    "na": ("Sentence-final particle", "Emphasis or a soft prohibition; also links na-adjectives."),
    "sa": ("Sentence-final particle", "Casual filler - “y’know, well …”."),
    "zo": ("Sentence-final particle", "Strong, assertive emphasis (blunt, masculine)."),
    "ze": ("Sentence-final particle", "Casual emphasis (masculine)."),
    "n": ("Moraic nasal", "The one kana that never begins a word; also a casual squeeze of の (…んです)."),
}


def kana_usage(romaji: str, script: str) -> tuple[str, str]:
    """(role_label, explanation) for a kana's job in a sentence, or ("", "").

    Particles are written in hiragana, so only the hiragana member of a pair
    carries a role; its katakana twin stays purely phonetic.
    """
    if script != "hiragana":
        return ("", "")
    return KANA_USAGE.get(romaji, ("", ""))


def _ex(before: str, particle: str, after: str, romaji: str, en: str) -> dict:
    return {"before": before, "particle": particle, "after": after, "romaji": romaji, "en": en}


# Two curated textbook sentences per grammatical kana, showing the particle at
# work. The particle sits in its own segment so the app can highlight it in
# place; romaji spells the particle as *pronounced* (は→wa, を→o, へ→e).
KANA_USAGE_EXAMPLES: dict[str, list[dict]] = {
    "ha": [
        _ex("私", "は", "学生です。", "Watashi wa gakusei desu.", "I am a student."),
        _ex("今日", "は", "暑いです。", "Kyō wa atsui desu.", "It's hot today."),
    ],
    "ga": [
        _ex("猫", "が", "います。", "Neko ga imasu.", "There is a cat."),
        _ex("雨", "が", "降っています。", "Ame ga futte imasu.", "It is raining."),
    ],
    "wo": [
        _ex("水", "を", "飲みます。", "Mizu o nomimasu.", "I drink water."),
        _ex("本", "を", "読みます。", "Hon o yomimasu.", "I read a book."),
    ],
    "ni": [
        _ex("学校", "に", "行きます。", "Gakkō ni ikimasu.", "I go to school."),
        _ex("七時", "に", "起きます。", "Shichiji ni okimasu.", "I get up at seven."),
    ],
    "he": [
        _ex("日本", "へ", "行きます。", "Nihon e ikimasu.", "I'm going to Japan."),
        _ex("家", "へ", "帰ります。", "Ie e kaerimasu.", "I'm heading home."),
    ],
    "de": [
        _ex("図書館", "で", "勉強します。", "Toshokan de benkyō shimasu.", "I study at the library."),
        _ex("バス", "で", "行きます。", "Basu de ikimasu.", "I go by bus."),
    ],
    "to": [
        _ex("パン", "と", "牛乳を買います。", "Pan to gyūnyū o kaimasu.", "I buy bread and milk."),
        _ex("友達", "と", "話します。", "Tomodachi to hanashimasu.", "I talk with a friend."),
    ],
    "no": [
        _ex("私", "の", "本です。", "Watashi no hon desu.", "It's my book."),
        _ex("日本", "の", "音楽が好きです。", "Nihon no ongaku ga suki desu.", "I like Japanese music."),
    ],
    "mo": [
        _ex("私", "も", "行きます。", "Watashi mo ikimasu.", "I'm going too."),
        _ex("彼", "も", "学生です。", "Kare mo gakusei desu.", "He is a student too."),
    ],
    "ya": [
        _ex("本", "や", "ペンがあります。", "Hon ya pen ga arimasu.", "There are books, pens, and so on."),
        _ex("りんご", "や", "みかんを買いました。", "Ringo ya mikan o kaimashita.", "I bought apples, mandarins, and such."),
    ],
    "ka": [
        _ex("これは何です", "か", "。", "Kore wa nan desu ka.", "What is this?"),
        _ex("犬", "か", "猫を飼いたいです。", "Inu ka neko o kaitai desu.", "I want to get a dog or a cat."),
    ],
    "wa": [
        _ex("きれいだ", "わ", "。", "Kirei da wa.", "How pretty!"),
        _ex("私も行く", "わ", "。", "Watashi mo iku wa.", "I'll go too."),
    ],
    "ne": [
        _ex("いい天気です", "ね", "。", "Ii tenki desu ne.", "Nice weather, isn't it?"),
        _ex("おいしいです", "ね", "。", "Oishii desu ne.", "This is delicious, isn't it?"),
    ],
    "yo": [
        _ex("おいしいです", "よ", "。", "Oishii desu yo.", "It's delicious, I tell you!"),
        _ex("もう八時です", "よ", "。", "Mō hachiji desu yo.", "It's already eight o'clock!"),
    ],
    "na": [
        _ex("行く", "な", "。", "Iku na.", "Don't go!"),
        _ex("静か", "な", "町です。", "Shizuka na machi desu.", "It's a quiet town."),
    ],
    "sa": [
        _ex("まあ、いい", "さ", "。", "Mā, ii sa.", "Well, it's fine."),
        _ex("それは", "さ", "、難しいよ。", "Sore wa sa, muzukashii yo.", "That, y'know, is difficult."),
    ],
    "zo": [
        _ex("行く", "ぞ", "！", "Iku zo!", "Here we go!"),
        _ex("頑張る", "ぞ", "！", "Ganbaru zo!", "I'm going to give it my all!"),
    ],
    "ze": [
        _ex("行こう", "ぜ", "！", "Ikō ze!", "Let's go!"),
        _ex("やる", "ぜ", "！", "Yaru ze!", "I'll do it!"),
    ],
    "n": [
        _ex("どうした", "ん", "ですか。", "Dō shita n desu ka.", "What's the matter?"),
        _ex("分からない", "ん", "です。", "Wakaranai n desu.", "The thing is, I don't understand."),
    ],
}


def kana_usage_examples(romaji: str, script: str) -> list[dict]:
    """Curated particle example sentences, or [] - hiragana only, like the role."""
    if script != "hiragana":
        return []
    return KANA_USAGE_EXAMPLES.get(romaji, [])


# ── Radicals / components (RADKFILE-style) ─────────────────────────────────────
# literal → (strokes, reading, meaning)
RADICALS: dict[str, tuple[int, str, str]] = {
    "一": (1, "いち", "one"),
    "口": (3, "くち", "mouth"),
    "日": (4, "ひ", "sun / day"),
    "月": (4, "つき", "moon / month"),
    "木": (4, "き", "tree"),
    "水": (4, "みず", "water"),
    "火": (4, "ひ", "fire"),
    "人": (2, "ひと", "person"),
    "亻": (2, "にんべん", "person (radical)"),
    "山": (3, "やま", "mountain"),
    "田": (5, "た", "rice field"),
    "力": (2, "ちから", "power"),
    "女": (3, "おんな", "woman"),
    "子": (3, "こ", "child"),
    "目": (5, "め", "eye"),
    "大": (3, "だい", "big"),
    "小": (3, "しょう", "small"),
    "言": (7, "ことば", "words / speech"),
    "食": (9, "しょく", "eat / food"),
    "門": (8, "もん", "gate"),
}

# ── Kanji (KANJIDIC-style; JLPT N5 staples) ────────────────────────────────────
# literal → dict(on, kun, en, fr, strokes, grade, jlpt, freq, components)
KANJI: dict[str, dict] = {
    "一": dict(
        on=["イチ", "イツ"],
        kun=["ひと"],
        en=["one"],
        fr=["un"],
        strokes=1,
        grade=1,
        jlpt=5,
        freq=2,
        comp=["一"],
    ),
    "二": dict(
        on=["ニ"],
        kun=["ふた"],
        en=["two"],
        fr=["deux"],
        strokes=2,
        grade=1,
        jlpt=5,
        freq=9,
        comp=["一"],
    ),
    "三": dict(
        on=["サン"],
        kun=["み"],
        en=["three"],
        fr=["trois"],
        strokes=3,
        grade=1,
        jlpt=5,
        freq=13,
        comp=["一"],
    ),
    "四": dict(
        on=["シ"],
        kun=["よ", "よん"],
        en=["four"],
        fr=["quatre"],
        strokes=5,
        grade=1,
        jlpt=5,
        freq=33,
        comp=["口"],
    ),
    "五": dict(
        on=["ゴ"],
        kun=["いつ"],
        en=["five"],
        fr=["cinq"],
        strokes=4,
        grade=1,
        jlpt=5,
        freq=30,
        comp=["一"],
    ),
    "六": dict(
        on=["ロク"],
        kun=["む"],
        en=["six"],
        fr=["six"],
        strokes=4,
        grade=1,
        jlpt=5,
        freq=69,
        comp=[],
    ),
    "七": dict(
        on=["シチ"],
        kun=["なな"],
        en=["seven"],
        fr=["sept"],
        strokes=2,
        grade=1,
        jlpt=5,
        freq=84,
        comp=[],
    ),
    "八": dict(
        on=["ハチ"],
        kun=["や"],
        en=["eight"],
        fr=["huit"],
        strokes=2,
        grade=1,
        jlpt=5,
        freq=101,
        comp=[],
    ),
    "九": dict(
        on=["キュウ", "ク"],
        kun=["ここの"],
        en=["nine"],
        fr=["neuf"],
        strokes=2,
        grade=1,
        jlpt=5,
        freq=94,
        comp=[],
    ),
    "十": dict(
        on=["ジュウ"],
        kun=["とお"],
        en=["ten"],
        fr=["dix"],
        strokes=2,
        grade=1,
        jlpt=5,
        freq=11,
        comp=[],
    ),
    "日": dict(
        on=["ニチ", "ジツ"],
        kun=["ひ", "か"],
        en=["day", "sun"],
        fr=["jour", "soleil"],
        strokes=4,
        grade=1,
        jlpt=5,
        freq=1,
        comp=["日"],
    ),
    "月": dict(
        on=["ゲツ", "ガツ"],
        kun=["つき"],
        en=["month", "moon"],
        fr=["mois", "lune"],
        strokes=4,
        grade=1,
        jlpt=5,
        freq=23,
        comp=["月"],
    ),
    "火": dict(
        on=["カ"],
        kun=["ひ"],
        en=["fire"],
        fr=["feu"],
        strokes=4,
        grade=1,
        jlpt=5,
        freq=134,
        comp=["火"],
    ),
    "水": dict(
        on=["スイ"],
        kun=["みず"],
        en=["water"],
        fr=["eau"],
        strokes=4,
        grade=1,
        jlpt=5,
        freq=130,
        comp=["水"],
    ),
    "木": dict(
        on=["モク", "ボク"],
        kun=["き"],
        en=["tree", "wood"],
        fr=["arbre", "bois"],
        strokes=4,
        grade=1,
        jlpt=5,
        freq=317,
        comp=["木"],
    ),
    "金": dict(
        on=["キン", "コン"],
        kun=["かね"],
        en=["gold", "money"],
        fr=["or", "argent"],
        strokes=8,
        grade=1,
        jlpt=5,
        freq=25,
        comp=[],
    ),
    "土": dict(
        on=["ド", "ト"],
        kun=["つち"],
        en=["earth", "soil"],
        fr=["terre"],
        strokes=3,
        grade=1,
        jlpt=5,
        freq=181,
        comp=[],
    ),
    "人": dict(
        on=["ジン", "ニン"],
        kun=["ひと"],
        en=["person"],
        fr=["personne"],
        strokes=2,
        grade=1,
        jlpt=5,
        freq=5,
        comp=["人"],
    ),
    "山": dict(
        on=["サン"],
        kun=["やま"],
        en=["mountain"],
        fr=["montagne"],
        strokes=3,
        grade=1,
        jlpt=5,
        freq=175,
        comp=["山"],
    ),
    "川": dict(
        on=["セン"],
        kun=["かわ"],
        en=["river"],
        fr=["rivière"],
        strokes=3,
        grade=1,
        jlpt=5,
        freq=234,
        comp=[],
    ),
    "口": dict(
        on=["コウ"],
        kun=["くち"],
        en=["mouth"],
        fr=["bouche"],
        strokes=3,
        grade=1,
        jlpt=5,
        freq=340,
        comp=["口"],
    ),
    "目": dict(
        on=["モク"],
        kun=["め"],
        en=["eye"],
        fr=["œil"],
        strokes=5,
        grade=1,
        jlpt=5,
        freq=104,
        comp=["目"],
    ),
    "大": dict(
        on=["ダイ", "タイ"],
        kun=["おお"],
        en=["big", "large"],
        fr=["grand"],
        strokes=3,
        grade=1,
        jlpt=5,
        freq=7,
        comp=["大"],
    ),
    "小": dict(
        on=["ショウ"],
        kun=["ちい", "こ"],
        en=["small", "little"],
        fr=["petit"],
        strokes=3,
        grade=1,
        jlpt=5,
        freq=114,
        comp=["小"],
    ),
    "中": dict(
        on=["チュウ"],
        kun=["なか"],
        en=["middle", "inside"],
        fr=["milieu", "dedans"],
        strokes=4,
        grade=1,
        jlpt=5,
        freq=10,
        comp=["口"],
    ),
    "本": dict(
        on=["ホン"],
        kun=["もと"],
        en=["book", "origin"],
        fr=["livre", "origine"],
        strokes=5,
        grade=1,
        jlpt=5,
        freq=38,
        comp=["木", "一"],
    ),
    "田": dict(
        on=["デン"],
        kun=["た"],
        en=["rice field"],
        fr=["rizière"],
        strokes=5,
        grade=1,
        jlpt=5,
        freq=97,
        comp=["田"],
    ),
    "力": dict(
        on=["リョク", "リキ"],
        kun=["ちから"],
        en=["power", "strength"],
        fr=["force"],
        strokes=2,
        grade=1,
        jlpt=5,
        freq=145,
        comp=["力"],
    ),
    "男": dict(
        on=["ダン", "ナン"],
        kun=["おとこ"],
        en=["man", "male"],
        fr=["homme"],
        strokes=7,
        grade=1,
        jlpt=5,
        freq=249,
        comp=["田", "力"],
    ),
    "女": dict(
        on=["ジョ"],
        kun=["おんな"],
        en=["woman", "female"],
        fr=["femme"],
        strokes=3,
        grade=1,
        jlpt=5,
        freq=169,
        comp=["女"],
    ),
    "子": dict(
        on=["シ", "ス"],
        kun=["こ"],
        en=["child"],
        fr=["enfant"],
        strokes=3,
        grade=1,
        jlpt=5,
        freq=75,
        comp=["子"],
    ),
    "学": dict(
        on=["ガク"],
        kun=["まな"],
        en=["study", "learning"],
        fr=["étude", "apprendre"],
        strokes=8,
        grade=1,
        jlpt=5,
        freq=63,
        comp=["子"],
    ),
    "校": dict(
        on=["コウ"],
        kun=[],
        en=["school"],
        fr=["école"],
        strokes=10,
        grade=1,
        jlpt=5,
        freq=209,
        comp=["木"],
    ),
    "先": dict(
        on=["セン"],
        kun=["さき"],
        en=["previous", "ahead"],
        fr=["précédent", "devant"],
        strokes=6,
        grade=1,
        jlpt=5,
        freq=115,
        comp=[],
    ),
    "生": dict(
        on=["セイ", "ショウ"],
        kun=["い", "う", "なま"],
        en=["life", "birth"],
        fr=["vie", "naissance"],
        strokes=5,
        grade=1,
        jlpt=5,
        freq=29,
        comp=[],
    ),
    "食": dict(
        on=["ショク"],
        kun=["た", "く"],
        en=["eat", "food"],
        fr=["manger", "nourriture"],
        strokes=9,
        grade=2,
        jlpt=5,
        freq=380,
        comp=["食"],
    ),
    "飲": dict(
        on=["イン"],
        kun=["の"],
        en=["drink"],
        fr=["boire"],
        strokes=12,
        grade=3,
        jlpt=5,
        freq=1092,
        comp=["食"],
    ),
    "見": dict(
        on=["ケン"],
        kun=["み"],
        en=["see", "look"],
        fr=["voir", "regarder"],
        strokes=7,
        grade=1,
        jlpt=5,
        freq=22,
        comp=["目"],
    ),
    "行": dict(
        on=["コウ", "ギョウ"],
        kun=["い", "おこな"],
        en=["go", "conduct"],
        fr=["aller"],
        strokes=6,
        grade=2,
        jlpt=5,
        freq=20,
        comp=[],
    ),
    "語": dict(
        on=["ゴ"],
        kun=["かた"],
        en=["language", "word"],
        fr=["langue", "mot"],
        strokes=14,
        grade=2,
        jlpt=5,
        freq=301,
        comp=["言", "口"],
    ),
    "話": dict(
        on=["ワ"],
        kun=["はな", "はなし"],
        en=["talk", "story"],
        fr=["parler", "histoire"],
        strokes=13,
        grade=2,
        jlpt=5,
        freq=306,
        comp=["言", "口"],
    ),
    "気": dict(
        on=["キ", "ケ"],
        kun=[],
        en=["spirit", "energy"],
        fr=["esprit", "énergie"],
        strokes=6,
        grade=1,
        jlpt=5,
        freq=41,
        comp=[],
    ),
    "何": dict(
        on=["カ"],
        kun=["なに", "なん"],
        en=["what"],
        fr=["quoi", "que"],
        strokes=7,
        grade=2,
        jlpt=5,
        freq=257,
        comp=["亻", "口"],
    ),
}

# ── Words (JMdict-style entries) ───────────────────────────────────────────────
# Each: dict(kanji=[(text, common)], kana=[(text, common)], common, jlpt,
#            senses=[dict(pos=[...], en=[...], fr=[...])])
WORDS: list[dict] = [
    dict(
        kanji=[("日本", True)],
        kana=[("にほん", True), ("にっぽん", False)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["n"], en=["Japan"], fr=["Japon"])],
    ),
    dict(
        kanji=[("日本語", True)],
        kana=[("にほんご", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["n"], en=["Japanese (language)"], fr=["japonais (langue)"])],
    ),
    dict(
        kanji=[("学生", True)],
        kana=[("がくせい", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["n"], en=["student"], fr=["étudiant", "élève"])],
    ),
    dict(
        kanji=[("先生", True)],
        kana=[("せんせい", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["n"], en=["teacher", "master", "doctor"], fr=["professeur", "maître"])],
    ),
    dict(
        kanji=[("学校", True)],
        kana=[("がっこう", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["n"], en=["school"], fr=["école"])],
    ),
    dict(
        kanji=[("食べる", True)],
        kana=[("たべる", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["v1", "vt"], en=["to eat"], fr=["manger"])],
    ),
    dict(
        kanji=[("飲む", True)],
        kana=[("のむ", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["v5m", "vt"], en=["to drink", "to swallow"], fr=["boire", "avaler"])],
    ),
    dict(
        kanji=[("見る", True)],
        kana=[("みる", True)],
        common=True,
        jlpt=5,
        senses=[
            dict(pos=["v1", "vt"], en=["to see", "to look", "to watch"], fr=["voir", "regarder"])
        ],
    ),
    dict(
        kanji=[("行く", True)],
        kana=[("いく", True), ("ゆく", False)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["v5k-s", "vi"], en=["to go"], fr=["aller"])],
    ),
    dict(
        kanji=[("来る", True)],
        kana=[("くる", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["vk", "vi"], en=["to come"], fr=["venir"])],
    ),
    dict(
        kanji=[("話す", True)],
        kana=[("はなす", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["v5s", "vt"], en=["to speak", "to talk"], fr=["parler", "discuter"])],
    ),
    dict(
        kanji=[("聞く", True)],
        kana=[("きく", True)],
        common=True,
        jlpt=5,
        senses=[
            dict(
                pos=["v5k", "vt"],
                en=["to hear", "to listen", "to ask"],
                fr=["entendre", "écouter", "demander"],
            )
        ],
    ),
    dict(
        kanji=[("大きい", True)],
        kana=[("おおきい", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["adj-i"], en=["big", "large"], fr=["grand", "gros"])],
    ),
    dict(
        kanji=[("小さい", True)],
        kana=[("ちいさい", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["adj-i"], en=["small", "little"], fr=["petit"])],
    ),
    dict(
        kanji=[("水", True)],
        kana=[("みず", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["n"], en=["water"], fr=["eau"])],
    ),
    dict(
        kanji=[("火", True)],
        kana=[("ひ", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["n"], en=["fire", "flame"], fr=["feu", "flamme"])],
    ),
    dict(
        kanji=[("山", True)],
        kana=[("やま", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["n"], en=["mountain"], fr=["montagne"])],
    ),
    dict(
        kanji=[("川", True)],
        kana=[("かわ", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["n"], en=["river", "stream"], fr=["rivière", "fleuve"])],
    ),
    dict(
        kanji=[("人", True)],
        kana=[("ひと", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["n"], en=["person", "human"], fr=["personne", "être humain"])],
    ),
    dict(
        kanji=[("男", True)],
        kana=[("おとこ", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["n"], en=["man", "male"], fr=["homme"])],
    ),
    dict(
        kanji=[("女", True)],
        kana=[("おんな", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["n"], en=["woman", "female"], fr=["femme"])],
    ),
    dict(
        kanji=[("子供", True)],
        kana=[("こども", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["n"], en=["child", "children"], fr=["enfant"])],
    ),
    dict(
        kanji=[("本", True)],
        kana=[("ほん", True)],
        common=True,
        jlpt=5,
        senses=[
            dict(pos=["n"], en=["book"], fr=["livre"]),
            dict(
                pos=["n-suf", "ctr"],
                en=["counter for long cylindrical things"],
                fr=["compteur pour objets longs"],
            ),
        ],
    ),
    dict(
        kanji=[("元気", True)],
        kana=[("げんき", True)],
        common=True,
        jlpt=5,
        senses=[
            dict(
                pos=["adj-na", "n"],
                en=["healthy", "energetic", "fine"],
                fr=["en forme", "énergique"],
            )
        ],
    ),
    dict(
        kanji=[],
        kana=[("こんにちは", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["int"], en=["hello", "good afternoon"], fr=["bonjour"])],
    ),
    dict(
        kanji=[],
        kana=[("ありがとう", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["int"], en=["thank you"], fr=["merci"])],
    ),
    dict(
        kanji=[],
        kana=[("すし", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["n"], en=["sushi"], fr=["sushi"])],
    ),
    dict(
        kanji=[("猫", False)],
        kana=[("ねこ", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["n"], en=["cat"], fr=["chat"])],
    ),
    dict(
        kanji=[("犬", True)],
        kana=[("いぬ", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["n"], en=["dog"], fr=["chien"])],
    ),
    dict(
        kanji=[("何", True)],
        kana=[("なに", True), ("なん", True)],
        common=True,
        jlpt=5,
        senses=[dict(pos=["pn"], en=["what"], fr=["quoi", "que"])],
    ),
]

# ── Seed kana mnemonics (language-segmented; DEEP_SEARCH feature 6) ─────────────
# (char, language, story). Concrete, vivid, sound-cued - English AND French, which
# key off different words for the same kana (the localization moat).
KANA_MNEMONICS: list[tuple[str, str, str]] = [
    ("く", "en", "く is a bird's beak opening to say 'coo' - a cuckoo goes 'ku-ku'."),
    ("く", "fr", "く est un bec d'oiseau qui s'ouvre : le coucou fait « cou-cou » → ku."),
    ("し", "en", "し is a fish-hook swooping down: you 'sheee' as it hooks a fish."),
    ("し", "fr", "し est un hameçon qui plonge - « chiii », il attrape le poisson (shi)."),
    ("つ", "en", "つ is a wave curling - a tsunami ('tsu') builds and curls over."),
    ("つ", "fr", "つ est une vague qui s'enroule : le tsunami (tsu) déferle."),
    ("さ", "en", "さ looks like a person doing a cartwheel - 'sah!' they land."),
    ("さ", "fr", "さ ressemble à un cerf-volant (sa) qui monte dans le ciel."),
    ("お", "en", "お is a person kicking a ball - 'oh!' as it flies off the foot."),
    ("お", "fr", "お : quelqu'un donne un coup de pied - « oh ! » le ballon part."),
    ("あ", "en", "あ has an 'A' hidden in it - the antenna of the letter A."),
    ("あ", "fr", "あ cache un « A » - l'antenne de la lettre A pour le son a."),
    ("ま", "en", "ま is mama's face with two eyes - 'ma-ma'."),
    ("ま", "fr", "ま est le visage de maman avec deux yeux - « ma-man »."),
    ("ね", "en", "ね has a cat's tail curling - a cat says 'nyah' ('ne')."),
    ("ね", "fr", "ね : la queue d'un chat qui s'enroule - le chat fait « nyé » (ne)."),
    ("ん", "en", "ん is the tail-end 'n' hum - like the last stroke of a signature."),
    ("ん", "fr", "ん est le « n » final que l'on fredonne, comme un trait de signature."),
    ("す", "en", "す is a swirl of noodles on a fork - you 'slurp' ('su')."),
    ("す", "fr", "す est un tourbillon de nouilles - on aspire « sou » (su)."),
]

# Full default pack: one sound-cued story per gojūon syllable, EN + FR. Keyed by
# romaji and applied to BOTH the hiragana and katakana character (the mnemonic
# rides on the shared sound). Real illustrations, when contributed, replace the
# glyph; until then this is the built-in text pack everyone gets.
KANA_STORIES: dict[str, dict[str, str]] = {
    "a": {
        "en": "あ hides a capital 'A' - its antenna cues the 'ah' sound.",
        "fr": "あ cache un grand « A » - son antenne donne le son « a ».",
    },
    "i": {
        "en": "い is two reeds standing side by side - 'ee'.",
        "fr": "い, deux roseaux dressés côte à côte - « i ».",
    },
    "u": {
        "en": "う is a face in profile going 'oooh'.",
        "fr": "う, un profil de visage qui fait « ou ».",
    },
    "e": {
        "en": "え is an exotic, energetic bird - 'eh!'.",
        "fr": "え, un oiseau exotique plein d'énergie - « é ».",
    },
    "o": {
        "en": "お is someone kicking a ball - 'oh!' as it flies off.",
        "fr": "お, un coup de pied - « oh ! » le ballon part.",
    },
    "ka": {
        "en": "か is a karate chop cutting the air - 'ka!'.",
        "fr": "か, un coup de karaté qui fend l'air - « ka ! ».",
    },
    "ki": {"en": "き is a key on a ring - 'kee'.", "fr": "き, une clé sur un anneau - « ki »."},
    "ku": {
        "en": "く is a bird's beak opening to say 'coo' - a cuckoo goes 'ku-ku'.",
        "fr": "く est un bec d'oiseau : le coucou fait « cou-cou » → ku.",
    },
    "ke": {
        "en": "け is a keg tipping over - 'keh'.",
        "fr": "け, un tonnelet (keg) qui bascule - « ké ».",
    },
    "ko": {
        "en": "こ are two short cords lying down - 'ko'.",
        "fr": "こ, deux petites cordes posées - « ko ».",
    },
    "sa": {
        "en": "さ is a kite catching the wind and rising - 'sah'.",
        "fr": "さ, un cerf-volant qui monte dans le ciel - « sa ».",
    },
    "shi": {
        "en": "し is a fish-hook swooping down - you 'sheee' as it hooks a fish.",
        "fr": "し est un hameçon qui plonge - « chiii », il attrape le poisson.",
    },
    "su": {
        "en": "す is a swirl of noodles on a fork - you 'slurp' ('su').",
        "fr": "す est un tourbillon de nouilles - on aspire « sou ».",
    },
    "se": {
        "en": "せ is a mouth with the tongue out saying 'seh'.",
        "fr": "せ, une bouche tirant la langue - « sé ».",
    },
    "so": {
        "en": "そ zig-zags like a line of sewing thread - 'so'.",
        "fr": "そ, un fil de couture en zig-zag - « so ».",
    },
    "ta": {
        "en": "た is a hammer nailing a board - 'tah!'.",
        "fr": "た, un marteau qui plante un clou - « ta ! ».",
    },
    "chi": {
        "en": "ち is a cheerleader bending back - 'chee'.",
        "fr": "ち, un petit chien qui frétille - « tchi ».",
    },
    "tsu": {
        "en": "つ is a wave curling - a tsunami ('tsu') builds and breaks.",
        "fr": "つ est une vague qui s'enroule : le tsunami (tsu) déferle.",
    },
    "te": {
        "en": "て is a hand / a table seen side-on - 'teh'.",
        "fr": "て, une table (te) vue de profil - « té ».",
    },
    "to": {
        "en": "と is a toe with a thorn stuck in it - 'toh!'.",
        "fr": "と, un orteil avec une épine - « to ! ».",
    },
    "na": {
        "en": "な is a knot tied in a rope - 'nah'.",
        "fr": "な, un nœud dans une corde - « na ».",
    },
    "ni": {"en": "に is a knee bending - 'nee'.", "fr": "に, un genou qui plie - « ni »."},
    "nu": {
        "en": "ぬ is a bowl of noodles twirled up - 'noo'.",
        "fr": "ぬ, un bol de nouilles enroulées - « nou ».",
    },
    "ne": {
        "en": "ね has a cat's tail curling - a cat says 'nyah' ('ne').",
        "fr": "ね : la queue d'un chat qui s'enroule - « né ».",
    },
    "no": {
        "en": "の is a swirling no-entry sign - 'no'.",
        "fr": "の, un panneau « sens interdit » qui tourbillonne - « no ».",
    },
    "ha": {
        "en": "は is a person doubled over laughing 'ha-ha'.",
        "fr": "は, quelqu'un plié de rire « ha-ha ».",
    },
    "hi": {"en": "ひ is a wide grinning smile - 'hee'.", "fr": "ひ, un grand sourire - « hi »."},
    "fu": {
        "en": "ふ is Mount Fuji seen from afar - 'fu'.",
        "fr": "ふ, le mont Fuji au loin - « fou ».",
    },
    "he": {
        "en": "へ is a mountain slope you climb - 'heh'.",
        "fr": "へ, une pente de montagne - « hé ».",
    },
    "ho": {
        "en": "ほ is a sail hoisted on a mast - 'hoh'.",
        "fr": "ほ, une voile hissée sur un mât - « ho ».",
    },
    "ma": {
        "en": "ま is mama's face with two eyes - 'ma-ma'.",
        "fr": "ま est le visage de maman avec deux yeux - « ma ».",
    },
    "mi": {
        "en": "み looks like '21' and hums the note 'mi'.",
        "fr": "み, comme un « 21 » qui chante la note « mi ».",
    },
    "mu": {"en": "む is a cow mooing - 'muu'.", "fr": "む, une vache qui meugle - « mou »."},
    "me": {
        "en": "め is an eye ('me' means eye in Japanese) - 'meh'.",
        "fr": "め, un œil (me = œil en japonais) - « mé ».",
    },
    "mo": {
        "en": "も is a fishing hook baited with worms - 'mo'.",
        "fr": "も, un hameçon appâté de vers - « mo ».",
    },
    "ya": {
        "en": "や is a yak with two horns - 'yah'.",
        "fr": "や, un yak avec deux cornes - « ya ».",
    },
    "yu": {
        "en": "ゆ is a looped fish swimming - 'yoo'.",
        "fr": "ゆ, un poisson en boucle - « you ».",
    },
    "yo": {
        "en": "よ is a person in a yoga pose - 'yoh'.",
        "fr": "よ, une posture de yoga - « yo ».",
    },
    "ra": {"en": "ら is a rabbit sitting up - 'rah'.", "fr": "ら, un lapin assis - « ra »."},
    "ri": {
        "en": "り is a unicorn's horn ('ri'... uni-corn) - 'ree'.",
        "fr": "り est une licorne (li-corne) - « ri ».",
    },
    "ru": {
        "en": "る is a loop in a winding route - 'roo'.",
        "fr": "る, une boucle sur une route sinueuse - « rou ».",
    },
    "re": {
        "en": "れ is a runner leaning forward - 'reh'.",
        "fr": "れ, un coureur penché en avant - « ré ».",
    },
    "ro": {"en": "ろ is a road spiralling - 'roh'.", "fr": "ろ, une route en spirale - « ro »."},
    "wa": {
        "en": "わ is a swan gliding on water - 'wah'.",
        "fr": "わ, un cygne qui glisse sur l'eau - « wa ».",
    },
    "wo": {
        "en": "を is a person throwing an object away - 'woh'.",
        "fr": "を, quelqu'un qui lance un objet - « wo ».",
    },
    "n": {
        "en": "ん is the final hum 'n' - like the last flick of a signature.",
        "fr": "ん est le « n » que l'on fredonne en fin de mot, comme un trait de signature.",
    },
}
