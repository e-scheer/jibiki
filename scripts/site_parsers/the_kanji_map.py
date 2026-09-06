"""Parser for thekanjimap.com mirrored snapshots.

The Kanji Map is a Next.js app whose pages render client side: stripping the
script tags out of a mirrored page leaves 53 characters of chrome (a logo, the
site name and a theme toggle). Everything of value, the decomposition graph,
the readings, the compound words and the Kanji Alive mnemonic hint, lives in
the React flight payload that the page pushes into ``self.__next_f``.

The first-generation parser regexed the escaped payload field by field over the
whole document. Every page embeds a complete ``kanjialiveData`` plus
``jishoData`` record for every neighbour in the graph (14 records on the 下
page, 333 on the 氵 page), so a first-match ``re.search`` for a key the
requested kanji does not carry silently returned a neighbour's value. That
fabricated grade on 79 of 140 records, taught_in on 67, frequency_rank on 66
and jlpt_level on 65, and it merged the decompositions of every graph node into
one ``parts`` list (下 got 18 components instead of its own three).

This module instead reassembles the flight payload from the ``script`` nodes,
JSON-decodes it once, and reads every field from the requested character's own
``props`` object. Nothing may originate in ``graphData`` except the graph
itself. Two upstream datasets are merged in that object and they disagree on
notation, so each emitted value records which upstream it came from:

* ``kanjialiveData`` (Kanji Alive): romaji readings, a one word meaning, the
  mnemonic hint, stroke timings and media, curated example words with audio.
  Frequently ``null`` (197 of 250 sampled pages) or reduced to a radical-only
  stub on component pages.
* ``jishoData`` (KANJIDIC / JMdict via jisho.org): the authoritative reading
  lists in KANJIDIC notation (``さ.げる``, ``こ-``, ``-ごころ``), the gloss
  list, JLPT level, school grade band, newspaper frequency rank, the radical,
  the decomposition ``parts`` and the reading-scoped compound words.

Licensing: the Kanji Alive mnemonic hint and its curated example words are
authored third-party prose, so they are declared as authored fields and their
provenance marks them ``ship: "reference-only"``. They exist as local
reference for an authoring pass, never as shipped content.

Where the two upstreams are malformed rather than merely different, the flaw is
recorded instead of forwarded. Kanji Alive stores 42 radical glyphs as
private-use codepoints of its own webfont, which render as tofu anywhere else,
and writes ``"n/a"`` where it has no romaji reading. The two radical blocks do
not always name the same radical, and jisho.org shifts its own field layout for
a kana-only example headword, putting the English gloss in the ``reading`` key.
"""

from __future__ import annotations

import html
import json
import re
import unicodedata
import urllib.parse
from typing import Any, NamedTuple

from lxml.html import HtmlElement

from site_parsers.common import (
    TextSpan,
    build_provenance_map,
    is_japanese_char,
    normalize_jlpt,
    normalize_text,
    parse_document,
    parse_int,
    rich_text,
    split_english_glosses,
    text_or_none,
    unique_list,
)

SITE_ID = "the_kanji_map"

EXTRACTABLE = frozenset({"kanji"})

# Basenames that share the single-path-segment shape of a kanji url. The old
# infer_page_type called /manifest.json a kanji page and only the caller's
# content-type filter kept it out of the extract. The crawl log also holds
# mangled variants such as ``/favicon.ico\`` and ``/favicon.ico?favicon...=``,
# so the extension test below backs up the explicit list.
ASSET_BASENAMES = frozenset(
    {
        "favicon.ico",
        "manifest.json",
        "apple-touch-icon.png",
        "apple-touch-icon-precomposed.png",
        "robots.txt",
        "sitemap.xml",
        "sw.js",
        "opensearch.xml",
    }
)

_ASSET_EXTENSION = re.compile(r"\.[A-Za-z0-9]{2,5}[\\/]?$")

# Marker the flight payload uses for the props object of the kanji page.
PROPS_ANCHOR = '{"requestedId"'

_PUSH_CALL = re.compile(r"self\.__next_f\.push\(\[\s*1\s*,")

# Kanji Alive ships UI instructions inside mn_hint. Half of all occurrences are
# a "please view the animation" string, so ingesting mn_hint verbatim would feed
# navigation chrome to an authoring pass as if it were a mnemonic. The verb and
# the noun both vary across the corpus ("Please see the movie in the radical
# fields above." on 力), so both are matched as alternatives rather than
# literally.
_HINT_BOILERPLATE = re.compile(
    r"^\s*please (?:view|see|watch|look at) the (?:radical )?"
    r"(?:animation|animations|movie|movies|video|videos|clip)[^;.]*[.;]?",
    re.IGNORECASE,
)
# Tokens Kanji Alive writes when a field has no content. "na" belongs here for a
# whole mn_hint value but never for a romaji reading, where na is a real
# syllable, so the two sets are kept apart deliberately.
_HINT_PLACEHOLDERS = frozenset(
    {"n/a", "na", "n.a.", "-", "?", "none", "no hint", "no hints", "no mnemonic"}
)
_ROMAJI_PLACEHOLDERS = frozenset({"n/a", "n.a", "n.a.", "n-a", "-", "?", "none", "no reading"})
_HINT_STROKE_DESCRIPTION = re.compile(
    r"^(?:one|two|three|four|five|six|seven|eight|nine|ten) lines?\.?$", re.IGNORECASE
)
# Inline Kanji Alive radical indices, e.g. "on a podium [176] in the west."
_HINT_KANJI_REF = re.compile(r"\[(\d{1,4})\]")

# Radical-index annotations that jisho.org appends to the gloss list. They are
# metadata about the Kangxi table, not a meaning of the character. The index is
# written half a dozen ways in the corpus: "(no. 85)", "radical 122",
# "rad. no. 90", "radical number 140", "death radical (n. 78)". A trailing
# number is required, so an ordinary gloss that merely contains the word
# "radical" is never lifted.
_RADICAL_ORDINAL = r"(?:no\.|n\.|nr\.?|number)?"
_RADICAL_INDEX_LABEL = re.compile(
    r"^(?:.*\b)?(?:radical|rad\.)(?:\s+variant)?\s*"
    rf"(?:\(\s*{_RADICAL_ORDINAL}\s*\d+\s*\)|{_RADICAL_ORDINAL}\s*\d+)$",
    re.IGNORECASE,
)
_RADICAL_VARIANT_LABEL = re.compile(
    rf"^variant of (?:radical|rad\.)\s*{_RADICAL_ORDINAL}\s*\d+$", re.IGNORECASE
)
# The trailing index expression on its own. Lifting the whole gloss out of
# ``meanings`` threw away the descriptive radical name in front of it, which on
# component pages was the only meaning the page carried: 丿 was left with no
# meaning at all and 刂 lost "standing sword". Only this tail is metadata.
_RADICAL_INDEX_TAIL = re.compile(
    rf"\s*(?:\(\s*{_RADICAL_ORDINAL}\s*(?P<paren>\d+)\s*\)|{_RADICAL_ORDINAL}\s*(?P<bare>\d+))\s*$",
    re.IGNORECASE,
)
# Words that carry no meaning once the index is removed. "radical number 9" and
# "variant of radical 146" reduce to nothing, so those pages genuinely have no
# meaning to recover, while "katakana no radical" and "standing sword radical" do.
_RADICAL_NAME_STOPWORDS = frozenset(
    {
        "radical", "radicals", "rad", "rad.", "variant", "variants", "form", "forms",
        "of", "the", "a", "an", "is", "are", "1st", "2nd", "3rd", "first", "second",
        "third", "or", "and",
    }
)

# Full-width parenthesised reading in a Kanji Alive example, e.g. 地下鉄（ちかてつ）.
_EXAMPLE_SURFACE = re.compile(r"^(?P<surface>[^（(]+)[（(](?P<reading>[^）)]*)[）)]\s*$")
# jisho.org wraps a kana-only headword in lenticular brackets and then shifts its
# own field layout: 【アイゴ】 arrives with the English gloss in ``reading`` and an
# empty ``meaning``. Unwrapped and re-aligned rather than stored as a Japanese
# reading holding English prose.
_EXAMPLE_KANA_HEADWORD = re.compile(r"^【\s*(?P<kana>[^】]+?)\s*】$")

# Private Use Area planes. Kanji Alive stores many radical glyphs as codepoints
# of its own webfont, which render as tofu anywhere else, so they are not shipped
# as if they were the Kangxi character.
PRIVATE_USE_RANGES = ((0xE000, 0xF8FF), (0xF0000, 0xFFFFD), (0x100000, 0x10FFFD))
# Kangxi Radicals block. NFKC maps every codepoint in it onto the standard
# unified ideograph for that radical, which is the notation jishoData.radical
# uses, so and only so are the two upstreams directly comparable.
KANGXI_RADICALS_BLOCK = (0x2F00, 0x2FDF)

RADICAL_GLYPH_AGREE = "agree"
RADICAL_GLYPH_CONFLICT = "conflict"
RADICAL_GLYPH_UNVERIFIED = "unverified"

KANA_RANGES = ((0x3040, 0x309F), (0x30A0, 0x30FF), (0x31F0, 0x31FF), (0xFF66, 0xFF9F))
RARE_RANGES = (
    (0x3400, 0x4DBF),  # CJK extension A
    (0x20000, 0x2A6DF),  # extension B
    (0x2A700, 0x2EBEF),  # extensions C..F
    (0x2F800, 0x2FA1F),  # compatibility supplement
    (0x31C0, 0x31EF),  # CJK strokes
)

ENTRY_KIND_KANJI = "kanji"
ENTRY_KIND_RADICAL = "radical_component"
ENTRY_KIND_KANA = "kana_component"
ENTRY_KIND_RARE = "rare_kanji"


class UnexpectedMarkup(ValueError):
    """Raised when a page does not match the shape this parser was written for.

    Never caught locally. The caller records the failure, which is the whole
    point: the previous ``except Exception: return {}`` turned real breakage
    into thousands of confident-looking empty records.
    """


# --- url routing --------------------------------------------------------------


def _path_segments(url: str) -> list[str]:
    split = urllib.parse.urlsplit(url)
    path = urllib.parse.unquote(split.path or "/")
    return [segment for segment in path.split("/") if segment]


def infer_page_type(url: str) -> str:
    segments = _path_segments(url)
    if not segments:
        return "home"
    if len(segments) > 1:
        return "other"
    segment = segments[0]
    if segment.lower().rstrip("\\/") in ASSET_BASENAMES or _ASSET_EXTENSION.search(segment):
        return "asset"
    if segment.lower() == "about":
        return "about"
    if len(segment) == 1:
        return "kanji"
    return "other"


def dedupe_key(url: str, page_type: str) -> str:
    """Identity of the entity, ignoring query strings and percent-encoding.

    The site emits ``<link rel="canonical" href="http://localhost:3000/...">``
    on every page, so canonical is unusable as an identity and the url path is
    the only honest key.
    """
    segments = _path_segments(url)
    if page_type == "kanji" and segments:
        return f"kanji:{segments[0]}"
    if not segments:
        return "home"
    return f"{page_type}:{'/'.join(segments)}"


# --- flight payload -----------------------------------------------------------


def _iter_flight_chunks(tree: HtmlElement) -> list[str]:
    """Decode every ``self.__next_f.push([1, "..."])`` string literal in order.

    Read from the script nodes rather than from the raw file, and decoded with
    ``json.JSONDecoder.raw_decode`` rather than a regex, because the payload
    contains escaped quotes: 93 of 140 audited snapshots carry ``\\"`` inside a
    string, and the old ``(.*?)\\"`` idiom truncated those values mid sentence
    (早 came out as ``Rising very 十 (orig. \\``).
    """
    decoder = json.JSONDecoder()
    chunks: list[str] = []
    for script in tree.iter("script"):
        body = script.text
        if not body or "self.__next_f" not in body:
            continue
        for call in _PUSH_CALL.finditer(body):
            index = call.end()
            while index < len(body) and body[index] in " \t\r\n":
                index += 1
            if index >= len(body) or body[index] != '"':
                continue
            value, _end = decoder.raw_decode(body, index)
            if isinstance(value, str):
                chunks.append(value)
    return chunks


def load_props(tree: HtmlElement) -> dict[str, Any] | None:
    """The kanji page props object, or None when the payload is absent."""
    payload = "".join(_iter_flight_chunks(tree))
    if not payload:
        return None
    anchor = payload.find(PROPS_ANCHOR)
    if anchor < 0:
        return None
    props, _end = json.JSONDecoder().raw_decode(payload, anchor)
    if not isinstance(props, dict):
        raise UnexpectedMarkup("flight payload props anchor did not decode to an object")
    return props


def is_shell(tree: HtmlElement, url: str) -> bool:
    """True when the mirrored file is not the requested kanji page.

    The rendered DOM is identical on every page of this site, so the only
    honest test is whether the flight payload carries the requested
    character's props. A payload-free file is an app shell that needs
    refetching, not a kanji with no data.
    """
    try:
        props = load_props(tree)
    except (ValueError, json.JSONDecodeError):
        return True
    if props is None:
        return True
    if not props.get("requestedId"):
        return True
    kanji_info = props.get("kanjiInfo")
    if not isinstance(kanji_info, dict):
        return True
    jisho = kanji_info.get("jishoData")
    kanjialive = kanji_info.get("kanjialiveData")
    if jisho is None and not kanjialive:
        # Neither upstream returned anything: a soft 404 for a character the
        # site has no record of.
        return True
    return False


# --- small helpers ------------------------------------------------------------


def _clean_scalar(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return str(value)
    text = normalize_text(str(value))
    return text or None


def _as_dict(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _as_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def _codepoint_in(value: str, ranges: tuple[tuple[int, int], ...]) -> bool:
    if len(value) != 1:
        return False
    code = ord(value)
    return any(low <= code <= high for low, high in ranges)


def _is_private_use(value: str | None) -> bool:
    if not value:
        return False
    return any(
        low <= ord(char) <= high for char in value for low, high in PRIVATE_USE_RANGES
    )


def _is_japanese_text(value: str | None) -> bool:
    """True when the string is Japanese rather than English prose."""
    if not value:
        return False
    return all(is_japanese_char(char) or char.isspace() for char in value)


# --- meanings -----------------------------------------------------------------


class MeaningSplit(NamedTuple):
    """Result of splitting a jisho gloss blob."""

    glosses: list[str]
    index_label: str | None
    index: int | None
    index_name: str | None
    index_name_is_only_meaning: bool


def _radical_index_parts(gloss: str) -> tuple[int | None, str | None]:
    """Split a radical-index gloss into its index number and its name.

    ``"standing sword radical (no. 18)"`` yields ``(18, "standing sword
    radical")``, ``"radical number 9"`` yields ``(9, None)`` because nothing
    descriptive is left once the index is removed.
    """
    tail = _RADICAL_INDEX_TAIL.search(gloss)
    if tail is None:
        return None, None
    index = parse_int(tail.group("paren") or tail.group("bare"))
    name = gloss[: tail.start()].strip().strip(",").strip()
    core = [
        word
        for word in re.split(r"[\s,]+", name.lower())
        if word.strip(".,;:") and word.strip(",;:") not in _RADICAL_NAME_STOPWORDS
    ]
    return index, (name if core and name else None)


def split_meanings(blob: Any) -> MeaningSplit:
    """Split a jisho gloss blob, separating the radical-index annotation.

    ``"water, water radical (no. 85)"`` yields ``["water"]`` plus the label
    ``"water radical (no. 85)"``. 27 of 140 audited records stored that
    annotation as if it were a meaning of the character.

    The index is metadata about the Kangxi table, but the name in front of it is
    not: on a component page it is usually the only description the page carries.
    So the number is parsed out as ``index``, the name is kept as ``index_name``,
    and when the gloss list holds nothing else that name becomes the meaning
    rather than leaving ``meanings`` empty and ``meaning_primary`` null.
    """
    text = _clean_scalar(blob)
    if not text:
        return MeaningSplit([], None, None, None, False)
    label: str | None = None
    index: int | None = None
    index_name: str | None = None
    glosses: list[str] = []
    for gloss in split_english_glosses(text):
        if _RADICAL_INDEX_LABEL.match(gloss) or _RADICAL_VARIANT_LABEL.match(gloss):
            label = gloss if label is None else f"{label}, {gloss}"
            gloss_index, gloss_name = _radical_index_parts(gloss)
            if index is None:
                index = gloss_index
            if index_name is None:
                index_name = gloss_name
            continue
        glosses.append(gloss)
    meanings = unique_list(glosses)
    name_is_only_meaning = not meanings and bool(index_name)
    if name_is_only_meaning:
        meanings = [index_name]
    return MeaningSplit(meanings, label, index, index_name, name_is_only_meaning)


# --- readings -----------------------------------------------------------------


def normalize_reading(raw: str) -> dict[str, Any] | None:
    """Explode one KANJIDIC reading into its parts, keeping the raw form.

    KANJIDIC marks the okurigana boundary with ``.`` and affix use with ``-``:
    ``さ.げる`` is stem さ plus okurigana げる, ``こ-`` is a prefix form and
    ``-ごころ`` a suffix form. The old parser ran these through a comma splitter
    that erased both markers and invented a bare ``ちい`` next to ``ちいさい``.
    """
    text = normalize_text(raw)
    if not text:
        return None
    affixes: list[str] = []
    if text.startswith("-"):
        affixes.append("suffix")
        text = text[1:]
    if text.endswith("-"):
        affixes.append("prefix")
        text = text[:-1]
    if not text:
        return None
    stem: str | None = None
    okurigana: str | None = None
    if "." in text:
        stem, okurigana = text.split(".", 1)
        stem = stem or None
        okurigana = okurigana or None
    return {
        "raw": normalize_text(raw),
        "reading": text.replace(".", ""),
        "stem": stem,
        "okurigana": okurigana,
        "affix": "-".join(affixes) if affixes else None,
    }


def normalize_readings(values: Any) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    seen: set[str] = set()
    for value in _as_list(values):
        if not isinstance(value, str):
            continue
        entry = normalize_reading(value)
        if entry is None or entry["raw"] in seen:
            continue
        seen.add(entry["raw"])
        out.append(entry)
    return out


def _romaji_list(value: Any) -> tuple[list[str], list[str]]:
    """Split a Kanji Alive romaji reading string into readings and placeholders.

    Kanji Alive writes ``"n/a"`` in the romaji field of a kanji whose reading list
    it has not transliterated. Emitting that as a reading contradicted the
    KANJIDIC reading list next to it (予 had ``kun_readings_romaji == ["n/a"]``
    beside ``あらかじ.め``), so placeholders are separated out and reported rather
    than shipped. ``na`` is deliberately not treated as a placeholder here: it is
    a real romaji syllable, as on 並 and 亡.
    """
    text = _clean_scalar(value)
    if not text:
        return [], []
    readings: list[str] = []
    placeholders: list[str] = []
    for part in re.split(r"[,、]\s*", text):
        token = part.strip()
        if not token:
            continue
        if token.lower().rstrip(".") in _ROMAJI_PLACEHOLDERS or token.lower() in _ROMAJI_PLACEHOLDERS:
            placeholders.append(token)
            continue
        readings.append(token)
    return unique_list(readings), unique_list(placeholders)


def _romaji_readings(*candidates: Any) -> tuple[list[str], list[str]]:
    """First candidate that yields readings, with the placeholders it dropped."""
    dropped: list[str] = []
    for candidate in candidates:
        readings, placeholders = _romaji_list(candidate)
        dropped.extend(placeholders)
        if readings:
            return readings, unique_list(dropped)
    return [], unique_list(dropped)


# --- mnemonic hint ------------------------------------------------------------


def _hint_class_roles() -> dict[str, str]:
    return {"note": "etymology_note"}


def parse_mnemonic_hint(raw: Any) -> dict[str, Any]:
    """Classify and structure a Kanji Alive ``mn_hint`` value.

    Returns the hint as a :class:`RichText` payload so the embedded
    ``<span class='note'>`` etymological aside stays distinguishable from the
    mnemonic story instead of being flattened into one sentence, plus the
    inline ``[NN]`` Kanji Alive indices as an explicit list.
    """
    text = raw if isinstance(raw, str) else None
    result: dict[str, Any] = {
        "raw": text,
        "kind": "absent",
        "hint": None,
        "etymology_notes": [],
        "kanji_refs": [],
        "boilerplate_prefix_removed": False,
    }
    if not text or not text.strip():
        return result

    stripped = text.strip()
    if stripped.lower().rstrip(".") in _HINT_PLACEHOLDERS:
        result["kind"] = "placeholder"
        return result
    if _HINT_STROKE_DESCRIPTION.match(stripped):
        result["kind"] = "stroke_description"
        return result

    boilerplate = _HINT_BOILERPLATE.match(stripped)
    if boilerplate:
        remainder = stripped[boilerplate.end() :].strip()
        if not remainder:
            result["kind"] = "ui_boilerplate"
            return result
        # Hybrid form: "Please view the radical animation on the left;
        # pointing at the nose to indicate the self." Only the continuation is
        # a mnemonic.
        stripped = remainder[0].upper() + remainder[1:]
        result["boilerplate_prefix_removed"] = True

    fragment = parse_document(f"<div>{stripped}</div>")
    rich = rich_text(fragment, title_roles={}, class_roles=_hint_class_roles())
    if not rich.text:
        result["kind"] = "placeholder"
        return result

    refs: list[int] = []
    for match in _HINT_KANJI_REF.finditer(rich.text):
        refs.append(int(match.group(1)))
        rich.spans.append(
            TextSpan(
                text=match.group(0),
                role="kanjialive_ref",
                start=match.start(),
                end=match.end(),
            )
        )
    rich.spans.sort(key=lambda span: (span.start, span.end))

    result["kind"] = "authored"
    result["hint"] = rich.to_json()
    result["etymology_notes"] = rich.roles("etymology_note")
    result["kanji_refs"] = unique_list(refs)
    return result


# --- example words ------------------------------------------------------------


def parse_kanjialive_examples(kanjialive: dict[str, Any]) -> list[dict[str, Any]]:
    """Curated Kanji Alive compound words with per-example audio.

    ``japanese`` is a surface form with the reading in full-width parentheses,
    and a leading ``*`` marks an irregular or jukujikun reading. The marker is
    lifted into a boolean so no stray asterisk reaches an authoring pass, and
    the signal is not lost either.
    """
    out: list[dict[str, Any]] = []
    for item in _as_list(kanjialive.get("examples")):
        entry = _as_dict(item)
        japanese = _clean_scalar(entry.get("japanese"))
        if not japanese:
            continue
        irregular = japanese.startswith("*")
        if irregular:
            japanese = japanese[1:].strip()
        match = _EXAMPLE_SURFACE.match(japanese)
        if match:
            surface = normalize_text(match.group("surface"))
            reading = normalize_text(match.group("reading")) or None
        else:
            surface = japanese
            reading = None
        gloss = _clean_scalar(_as_dict(entry.get("meaning")).get("english"))
        audio = _as_dict(entry.get("audio"))
        out.append(
            {
                "surface": surface,
                "reading": reading,
                "gloss": gloss,
                "glosses": split_english_glosses(gloss),
                "irregular": irregular,
                "audio_mp3": _clean_scalar(audio.get("mp3")),
                "audio_ogg": _clean_scalar(audio.get("ogg")),
                "audio_aac": _clean_scalar(audio.get("aac")),
                "audio_opus": _clean_scalar(audio.get("opus")),
            }
        )
    return out


def _unescaped(value: Any) -> str | None:
    """Cleaned scalar with HTML entities resolved.

    jisho.org double-escapes a few gloss strings, so ``substitutes for
    &quot;ga&quot;`` arrives entity-encoded and must not be shipped that way.
    """
    text = _clean_scalar(value)
    if text is None:
        return None
    return normalize_text(html.unescape(text)) or None


def parse_jisho_examples(values: Any, reading_type: str) -> list[dict[str, Any]]:
    """Reading-scoped compound words: which compound demonstrates which reading.

    A kana-only headword arrives in a different shape: jisho wraps it in
    lenticular brackets (``【アイゴ】``), puts the English gloss in ``reading`` and
    leaves ``meaning`` empty. Copying the three keys verbatim stored English prose
    in a Japanese reading field and lost the gloss on 114 entries, so that shape is
    detected and re-aligned, with ``kana_headword`` recording which entries it was.
    """
    out: list[dict[str, Any]] = []
    for item in _as_list(values):
        entry = _as_dict(item)
        surface = _unescaped(entry.get("example"))
        if not surface:
            continue
        reading = _unescaped(entry.get("reading"))
        gloss = _unescaped(entry.get("meaning"))
        bracketed = _EXAMPLE_KANA_HEADWORD.match(surface)
        kana_headword = False
        if bracketed:
            kana = normalize_text(bracketed.group("kana")) or None
            kana_headword = kana is not None
            if kana:
                surface = kana
                if not gloss and reading and not _is_japanese_text(reading):
                    # The upstream shifted its fields: what sits in `reading` is
                    # the gloss, and the reading of a kana headword is the
                    # headword itself.
                    gloss = reading
                    reading = kana
        out.append(
            {
                "surface": surface,
                "reading": reading,
                "reading_type": reading_type,
                "kana_headword": kana_headword,
                "gloss": gloss,
                "glosses": split_english_glosses(gloss),
            }
        )
    return out


# --- radical ------------------------------------------------------------------


def _radical_glyph_agreement(
    symbol: str | None,
    forms: list[str],
    kangxi: str | None,
    private_use: bool,
    kanjialive_present: bool,
) -> tuple[str | None, str | None]:
    """Whether the two upstreams name the same radical, and how sure that is.

    The two blocks are merged into one object, so a consumer reading ``symbol``
    next to the Kanji Alive ``name_ja`` has to be told when they describe
    different radicals: on 問 jisho says 口 while Kanji Alive says 門 / もんがまえ.

    A verdict is only claimed when the two notations are commensurable. NFKC maps
    the Kangxi Radicals block onto the same unified ideographs jisho uses, so
    those compare exactly. A CJK-Radicals-Supplement glyph (⺅), a private-use
    glyph or a variant ideograph such as 𠆢 has no canonical unified equivalent,
    and 𠆢 really is a form of 人 even though no mapping says so, so those stay
    ``unverified`` instead of being asserted either way.
    """
    if private_use:
        return RADICAL_GLYPH_UNVERIFIED, "kanjialive_glyph_is_private_use"
    if not kanjialive_present:
        # Only jisho described a radical here, so there is no second notation to
        # reconcile and no verdict to state. 5274 of 6529 radical blocks.
        return None, None
    if not kangxi and not symbol:
        return None, None
    if not kangxi:
        return RADICAL_GLYPH_UNVERIFIED, "kanjialive_block_has_no_glyph"
    if not symbol:
        return RADICAL_GLYPH_UNVERIFIED, "jisho_block_has_no_symbol"
    normalized = unicodedata.normalize("NFKC", kangxi)
    known = {unicodedata.normalize("NFKC", symbol)}
    known.update(unicodedata.normalize("NFKC", form) for form in forms)
    if normalized in known:
        return RADICAL_GLYPH_AGREE, "kanjialive_glyph_matches_jisho_symbol_or_form"
    if _codepoint_in(kangxi, (KANGXI_RADICALS_BLOCK,)):
        return RADICAL_GLYPH_CONFLICT, "kanjialive_kangxi_glyph_names_another_radical"
    return RADICAL_GLYPH_UNVERIFIED, "kanjialive_glyph_has_no_canonical_equivalent"


def merge_radical(jisho: dict[str, Any], kanjialive: dict[str, Any]) -> dict[str, Any] | None:
    """Merge the jisho and Kanji Alive radical blocks, tagging each source.

    Emits None when the requested character has no radical block at all. The
    old whole-document regex inherited a neighbour's radical on 7 of 140
    records (コ was given 火 / "fire" from the 炊 node).

    Two upstream defects are handled rather than passed through. Kanji Alive
    stores 42 distinct radical glyphs as codepoints of its own webfont
    (``U+E723`` for the 口 hand form), which render as tofu everywhere else, so a
    private-use glyph is not emitted as ``kangxi_character`` and the flag records
    that one was present. And the two blocks do not always name the same radical,
    so ``glyph_agreement`` states whether they were reconciled.
    """
    jisho_radical = _as_dict(jisho.get("radical"))
    ka_radical = _as_dict(kanjialive.get("radical"))
    ka_name = _as_dict(ka_radical.get("name"))
    ka_position = _as_dict(ka_radical.get("position"))
    ka_meaning = _as_dict(ka_radical.get("meaning"))

    symbol = _clean_scalar(jisho_radical.get("symbol"))
    forms = unique_list(
        form for form in _as_list(jisho_radical.get("forms")) if isinstance(form, str)
    )
    kangxi_raw = _clean_scalar(ka_radical.get("character"))
    kangxi_private_use = _is_private_use(kangxi_raw)
    kangxi = None if kangxi_private_use else kangxi_raw
    kanjialive_present = bool(ka_radical) or any(
        kanjialive.get(key) is not None
        for key in ("rad_meaning", "rad_name_ja", "rad_name", "rad_stroke", "rad_order")
    )
    agreement, agreement_reason = _radical_glyph_agreement(
        symbol, forms, kangxi, kangxi_private_use, kanjialive_present
    )

    payload = {
        "symbol": symbol,
        "forms": forms,
        "meaning": _clean_scalar(jisho_radical.get("meaning")),
        "kangxi_character": kangxi,
        "kangxi_character_private_use": kangxi_private_use,
        "glyph_agreement": agreement,
        "glyph_agreement_reason": agreement_reason,
        "meaning_kanjialive": _clean_scalar(ka_meaning.get("english"))
        or _clean_scalar(kanjialive.get("rad_meaning")),
        "name_ja": _clean_scalar(ka_name.get("hiragana")) or _clean_scalar(kanjialive.get("rad_name_ja")),
        "name_romaji": _clean_scalar(ka_name.get("romaji")) or _clean_scalar(kanjialive.get("rad_name")),
        "stroke_count": parse_int(ka_radical.get("strokes"))
        if ka_radical.get("strokes") is not None
        else parse_int(kanjialive.get("rad_stroke")),
        "position_ja": _clean_scalar(ka_position.get("hiragana"))
        or _clean_scalar(kanjialive.get("rad_position_ja")),
        "position_romaji": _clean_scalar(ka_position.get("romaji"))
        or _clean_scalar(kanjialive.get("rad_position")),
        "order": parse_int(kanjialive.get("rad_order")),
        "image_uri": _clean_scalar(ka_radical.get("image")),
        "animation_frames": [
            frame for frame in _as_list(ka_radical.get("animation")) if isinstance(frame, str)
        ],
        "sources": {
            "symbol": "jisho" if jisho_radical.get("symbol") else None,
            "meaning": "jisho" if jisho_radical.get("meaning") else None,
            "forms": "jisho" if jisho_radical.get("forms") else None,
            "kangxi_character": "kanjialive" if kangxi else None,
            "meaning_kanjialive": "kanjialive"
            if (ka_meaning.get("english") or kanjialive.get("rad_meaning"))
            else None,
            "name": "kanjialive" if (ka_name or kanjialive.get("rad_name_ja")) else None,
            "position": "kanjialive"
            if (ka_position.get("romaji") or kanjialive.get("rad_position"))
            else None,
            "stroke_count": "kanjialive"
            if (ka_radical.get("strokes") is not None or kanjialive.get("rad_stroke") is not None)
            else None,
            "media": "kanjialive" if (ka_radical.get("image") or ka_radical.get("animation")) else None,
        },
    }
    if not any(
        payload[key]
        for key in (
            "symbol",
            "forms",
            "meaning",
            "kangxi_character",
            "meaning_kanjialive",
            "name_ja",
            "name_romaji",
        )
    ):
        return None
    return payload


# --- graph --------------------------------------------------------------------


def parse_graph(props: dict[str, Any], character: str) -> dict[str, Any]:
    """Explicit parent/child edges with node labels, split into two closures.

    The graph is a multi-level tree, not a one-hop star: on the 混 page the
    edges are 氵 -> 混 and 昆 -> 混 for the direct components, plus 水 -> 氵,
    日 -> 昆 and 比 -> 昆 one level deeper. Emitting only the direct parents
    would throw away the depth that is the whole point of this site, and
    emitting a flat edge list would make every consumer re-derive it.

    So the edge list is kept whole and partitioned into ``decomposition``, the
    upward closure from the requested character with a depth per node, and
    ``usage``, the downward closure. ``components`` and ``used_in`` are the
    depth-1 slices of each.

    ``graphData.withOutLinks`` is the superset. ``graphData.noOutLinks`` holds
    flight back-references (``"$8:props:...:withOutLinks:links:0"``) rather
    than data, so it is a labelled subset and is deliberately not re-expanded.
    """
    graph_data = _as_dict(props.get("graphData"))
    variant = "withOutLinks"
    block = _as_dict(graph_data.get(variant))
    if not block:
        raise UnexpectedMarkup("graphData.withOutLinks missing from flight payload")

    labels: dict[str, dict[str, Any]] = {}
    for node in _as_list(block.get("nodes")):
        entry = _as_dict(node)
        node_id = entry.get("id")
        if not isinstance(node_id, str) or not node_id:
            continue
        data = _as_dict(entry.get("data"))
        jisho = _as_dict(data.get("jishoData"))
        split = split_meanings(jisho.get("meaning"))
        labels[node_id] = {
            "character": node_id,
            "meaning": _clean_scalar(jisho.get("meaning")),
            "meanings": split.glosses,
            "stroke_count": parse_int(jisho.get("strokeCount")),
        }

    edges: list[dict[str, str]] = []
    for link in _as_list(block.get("links")):
        entry = _as_dict(link)
        source = entry.get("source")
        target = entry.get("target")
        if not isinstance(source, str) or not isinstance(target, str):
            continue
        edges.append({"source": source, "target": target})

    def label_for(node_id: str, depth: int) -> dict[str, Any]:
        label = labels.get(
            node_id,
            {"character": node_id, "meaning": None, "meanings": [], "stroke_count": None},
        )
        return {**label, "depth": depth}

    parents: dict[str, list[str]] = {}
    children: dict[str, list[str]] = {}
    for edge in edges:
        parents.setdefault(edge["target"], []).append(edge["source"])
        children.setdefault(edge["source"], []).append(edge["target"])

    def closure(adjacency: dict[str, list[str]]) -> list[dict[str, Any]]:
        seen = {character}
        frontier = [character]
        depth = 0
        out: list[dict[str, Any]] = []
        while frontier:
            depth += 1
            next_frontier: list[str] = []
            for node_id in frontier:
                for neighbour in adjacency.get(node_id, []):
                    if neighbour in seen:
                        continue
                    seen.add(neighbour)
                    next_frontier.append(neighbour)
                    out.append(label_for(neighbour, depth))
            frontier = next_frontier
        return out

    decomposition = closure(parents)
    usage = closure(children)
    reached = {entry["character"] for entry in decomposition} | {
        entry["character"] for entry in usage
    }
    reached.add(character)
    detached = [
        edge
        for edge in edges
        if edge["source"] not in reached or edge["target"] not in reached
    ]

    return {
        "graph_variant": variant,
        "node_count": len(labels),
        "edge_count": len(edges),
        "edges": edges,
        "decomposition": decomposition,
        "usage": usage,
        "components": [entry for entry in decomposition if entry["depth"] == 1],
        "used_in": [entry for entry in usage if entry["depth"] == 1],
        "detached_edge_count": len(detached),
        "nodes": list(labels.values()),
    }


# --- entry kind ---------------------------------------------------------------


def classify_entry(
    character: str,
    jisho: dict[str, Any],
    kanjialive: dict[str, Any] | None,
    radical_index_label: str | None,
    navigable_radical_ids: list[Any],
) -> str:
    """Distinguish a learner kanji from a component, a kana or a rare glyph.

    Needed because every url on this site has the same single-segment shape, so
    氵, 彐 and 刂 were typed exactly like 下 and inherited fabricated grade and
    JLPT values.

    Radical-list membership alone is not enough to demote a character: 小 and 心
    are both Kangxi radicals and grade 1 jouyou kanji, and both appear in
    ``navigableRadicalIds``. Learner-level data therefore wins over every
    radical signal, and the raw nav-list membership is emitted separately as
    ``is_navigable_radical`` instead of being folded into the kind.
    """
    if _codepoint_in(character, KANA_RANGES):
        return ENTRY_KIND_KANA
    has_learner_data = any(
        jisho.get(key) for key in ("jlptLevel", "taughtIn", "newspaperFrequencyRank")
    )
    kanjialive_dict = kanjialive if isinstance(kanjialive, dict) else {}
    has_kanji_level_kanjialive = any(
        kanjialive_dict.get(key) is not None for key in ("grade", "kstroke", "kanji")
    )
    if not (has_learner_data or has_kanji_level_kanjialive):
        radical_evidence = (
            character in navigable_radical_ids
            or (bool(kanjialive_dict) and set(kanjialive_dict) == {"radical"})
            or bool(radical_index_label)
        )
        if radical_evidence:
            return ENTRY_KIND_RADICAL
    if _codepoint_in(character, RARE_RANGES):
        return ENTRY_KIND_RARE
    return ENTRY_KIND_KANJI


# --- provenance ---------------------------------------------------------------

FACTUAL_FIELDS = (
    "character",
    "canonical_character",
    "variant_aliases",
    "entry_kind",
    "is_navigable_radical",
    "meanings",
    "meaning_primary",
    "meaning_jisho",
    "radical_index_label",
    "radical_index",
    "radical_index_name",
    "stroke_count",
    "stroke_count_jisho",
    "stroke_count_kanjialive",
    "grade",
    "jlpt_level",
    "taught_in",
    "frequency_rank",
    "on_readings",
    "kun_readings",
    "on_readings_romaji",
    "kun_readings_romaji",
    "nanori",
    "radical",
    "parts",
    "parts_lists_self",
    "parts_without_direct_edge",
    "parts_not_in_graph",
    "graph_variant",
    "node_count",
    "edge_count",
    "edges",
    "decomposition",
    "usage",
    "components",
    "used_in",
    "detached_edge_count",
    "nodes",
    "example_words_on",
    "example_words_kun",
    "stroke_order",
    "textbooks",
    "kanjialive_lesson",
    "references",
    "kanjialive_id",
    "kanjialive_name",
    "jisho_uri",
    "upstreams",
    "source_url",
    "parse_notes",
)

# Authored third-party prose. Kanji Alive writes the mnemonic hints and curates
# the example words with their English glosses and audio, so both stay
# reference-only and never reach the app.
AUTHORED_FIELDS = (
    "mnemonic_hint",
    "mnemonic_hint_raw",
    "mnemonic_hint_kind",
    "mnemonic_hint_group",
    "mnemonic_etymology_notes",
    "mnemonic_kanji_refs",
    "meaning_kanjialive",
    "example_words_kanjialive",
)


# --- parse --------------------------------------------------------------------


def parse(tree: HtmlElement, url: str, page_type: str) -> dict[str, Any]:
    if page_type != "kanji":
        raise UnexpectedMarkup(f"page_type {page_type!r} is not extractable for {SITE_ID}")

    props = load_props(tree)
    if props is None:
        raise UnexpectedMarkup("flight payload with a kanji props object not found")

    character = _clean_scalar(props.get("requestedId"))
    if not character:
        raise UnexpectedMarkup("flight payload carries no requestedId")

    segments = _path_segments(url)
    if segments and segments[0] != character:
        raise UnexpectedMarkup(
            f"requestedId {character!r} does not match url segment {segments[0]!r}"
        )

    kanji_info = _as_dict(props.get("kanjiInfo"))
    if not kanji_info:
        raise UnexpectedMarkup("flight payload carries no kanjiInfo")
    info_id = _clean_scalar(kanji_info.get("id"))
    if info_id and info_id != character:
        raise UnexpectedMarkup(f"kanjiInfo.id {info_id!r} does not match requestedId {character!r}")

    kanjialive_raw = kanji_info.get("kanjialiveData")
    kanjialive = _as_dict(kanjialive_raw)
    jisho = _as_dict(kanji_info.get("jishoData"))
    ka_kanji = _as_dict(kanjialive.get("kanji"))

    parse_notes: list[str] = [
        "Fields read from the requested character's own props object in the "
        "Next.js flight payload. No value may originate in graphData.",
        "graphData.noOutLinks holds flight back-references rather than data, so "
        "only the withOutLinks superset is expanded.",
    ]

    split = split_meanings(jisho.get("meaning"))
    meanings = split.glosses
    radical_index_label = split.index_label
    if split.index_name_is_only_meaning:
        parse_notes.append(
            "The jisho gloss list held nothing but the Kangxi index annotation, so "
            f"the radical name {split.index_name!r} is the only meaning available."
        )
    meaning_kanjialive = _clean_scalar(kanjialive.get("meaning")) or _clean_scalar(
        _as_dict(ka_kanji.get("meaning")).get("english")
    )

    stroke_count_kanjialive = parse_int(kanjialive.get("kstroke"))
    stroke_count_jisho = parse_int(jisho.get("strokeCount"))
    if (
        stroke_count_kanjialive is not None
        and stroke_count_jisho is not None
        and stroke_count_kanjialive != stroke_count_jisho
    ):
        # The two upstreams agreed on all 170 sampled pages that carry both, so
        # a disagreement is worth surfacing rather than silently resolving.
        parse_notes.append(
            f"stroke count disagreement: kanjialive {stroke_count_kanjialive}, "
            f"jisho {stroke_count_jisho}; kanjialive wins in stroke_count."
        )

    on_readings = normalize_readings(jisho.get("onyomi"))
    kun_readings = normalize_readings(jisho.get("kunyomi"))

    hint = parse_mnemonic_hint(kanjialive.get("mn_hint"))
    if hint["kind"] in {"ui_boilerplate", "placeholder", "stroke_description"}:
        parse_notes.append(
            f"kanjialiveData.mn_hint is not a mnemonic on this page (kind={hint['kind']}), "
            "so mnemonic_hint is null."
        )
    if hint["boilerplate_prefix_removed"]:
        parse_notes.append(
            "A 'Please view the animation' UI prefix was removed from mn_hint; only the "
            "authored continuation is kept."
        )

    graph = parse_graph(props, character)
    listed_parts = unique_list(
        part for part in _as_list(jisho.get("parts")) if isinstance(part, str)
    )
    # jishoData.parts lists the character itself on 245 pages (西 -> ["西"]). A
    # character is not one of its own components, and leaving it in put it in
    # parts_without_direct_edge as if the graph were missing an edge, so it is
    # removed and the upstream quirk is recorded as a flag instead.
    parts_lists_self = character in listed_parts
    parts = [part for part in listed_parts if part != character]
    if parts_lists_self:
        parse_notes.append(
            f"jishoData.parts listed the character itself ({character}); dropped from "
            "parts, since a character is not its own component."
        )
    # jishoData.parts and the graph edges describe the decomposition at
    # different granularities: parts are the atomic glyphs jisho lists, while
    # the graph decomposes one level at a time. For 混 the parts are 日, 比 and
    # 汁 while the direct components are 氵 and 昆. Recording both differences
    # explicitly keeps the two fields from silently disagreeing.
    component_chars = {entry["character"] for entry in graph["components"]}
    graph_chars = {entry["character"] for entry in graph["nodes"]}
    parts_without_direct_edge = [part for part in parts if part not in component_chars]
    parts_not_in_graph = [part for part in parts if part not in graph_chars]
    if parts_not_in_graph:
        parse_notes.append(
            "jishoData.parts lists components absent from the graph entirely: "
            + ", ".join(parts_not_in_graph)
        )

    strokes = _as_dict(ka_kanji.get("strokes"))
    video = _as_dict(ka_kanji.get("video"))
    stroke_order = {
        "svg_uri": _clean_scalar(jisho.get("strokeOrderSvgUri")),
        "diagram_uri": _clean_scalar(jisho.get("strokeOrderDiagramUri")),
        "gif_uri": _clean_scalar(jisho.get("strokeOrderGifUri")),
        "per_stroke_images": [
            image for image in _as_list(strokes.get("images")) if isinstance(image, str)
        ],
        "timings": [
            timing for timing in _as_list(strokes.get("timings")) if isinstance(timing, (int, float))
        ],
        "video_mp4": _clean_scalar(video.get("mp4")),
        "video_webm": _clean_scalar(video.get("webm")),
        "poster": _clean_scalar(video.get("poster")),
        # props.strokeAnimation is null on every mirrored page: the vector path
        # data the app draws is fetched client side and is genuinely not in the
        # mirror, so it must come from another source (KanjiVG) rather than be
        # assumed missed here.
        "stroke_animation_available": props.get("strokeAnimation") is not None,
    }

    radical = merge_radical(jisho, kanjialive)
    if radical:
        if radical["glyph_agreement"] == RADICAL_GLYPH_CONFLICT:
            parse_notes.append(
                "radical conflict: jishoData.radical is "
                f"{radical['symbol']} ({radical['meaning']}) but kanjialiveData.radical is "
                f"{radical['kangxi_character']} ({radical['meaning_kanjialive']}), so the "
                "kanjialive name, position and stroke count describe a different radical "
                "than radical.symbol."
            )
        elif (
            radical["glyph_agreement"] == RADICAL_GLYPH_UNVERIFIED
            and radical["symbol"]
            and radical["glyph_agreement_reason"] == "kanjialive_glyph_has_no_canonical_equivalent"
        ):
            parse_notes.append(
                "The two radical blocks could not be reconciled "
                f"(reason={radical['glyph_agreement_reason']}), so radical.symbol and the "
                "kanjialive naming fields are not asserted to describe the same radical."
            )
        if radical["kangxi_character_private_use"]:
            parse_notes.append(
                "kanjialiveData.radical.character is a private-use codepoint of the Kanji "
                "Alive webfont, which renders as tofu anywhere else, so kangxi_character "
                "is null."
            )

    on_readings_romaji, on_romaji_placeholders = _romaji_readings(
        _as_dict(ka_kanji.get("onyomi")).get("romaji"), kanjialive.get("onyomi")
    )
    kun_readings_romaji, kun_romaji_placeholders = _romaji_readings(
        _as_dict(ka_kanji.get("kunyomi")).get("romaji"), kanjialive.get("kunyomi")
    )
    for field_name, placeholders in (
        ("on_readings_romaji", on_romaji_placeholders),
        ("kun_readings_romaji", kun_romaji_placeholders),
    ):
        if placeholders:
            parse_notes.append(
                f"kanjialive wrote the placeholder {', '.join(placeholders)} where the romaji "
                f"readings belong, so it is not emitted in {field_name}."
            )

    textbooks, kanjialive_lesson = _textbooks(kanjialive)

    navigable = [
        value for value in _as_list(props.get("navigableRadicalIds")) if isinstance(value, str)
    ]
    entry_kind = classify_entry(character, jisho, kanjialive_raw, radical_index_label, navigable)

    title_character = _title_character(tree)
    if title_character and title_character != character:
        parse_notes.append(
            f"Document title character {title_character!r} differs from the payload character."
        )

    record: dict[str, Any] = {
        "character": character,
        "canonical_character": _clean_scalar(props.get("canonicalId")),
        "variant_aliases": unique_list(
            alias
            for alias in _as_list(_as_dict(props.get("variantInfo")).get("aliases"))
            if isinstance(alias, str)
        ),
        "entry_kind": entry_kind,
        # Membership of the site's own 253-entry radical navigation list. Kept
        # as a flag rather than copied wholesale: the list is identical nav
        # chrome on all 6602 pages.
        "is_navigable_radical": character in navigable,
        "meanings": meanings,
        "meaning_primary": meanings[0] if meanings else None,
        "meaning_jisho": _clean_scalar(jisho.get("meaning")),
        "meaning_kanjialive": meaning_kanjialive,
        "radical_index_label": radical_index_label,
        # The Kangxi table index, and the descriptive radical name jisho writes in
        # front of it, kept apart from the raw label so neither is lost when the
        # gloss list holds nothing else.
        "radical_index": split.index,
        "radical_index_name": split.index_name,
        "stroke_count": stroke_count_kanjialive
        if stroke_count_kanjialive is not None
        else stroke_count_jisho,
        "stroke_count_kanjialive": stroke_count_kanjialive,
        "stroke_count_jisho": stroke_count_jisho,
        "grade": parse_int(kanjialive.get("grade")) if kanjialive.get("grade") is not None else None,
        "jlpt_level": normalize_jlpt(jisho.get("jlptLevel")) if jisho.get("jlptLevel") else None,
        "taught_in": _clean_scalar(jisho.get("taughtIn")),
        "frequency_rank": parse_int(jisho.get("newspaperFrequencyRank"))
        if jisho.get("newspaperFrequencyRank") is not None
        else None,
        "on_readings": on_readings,
        "kun_readings": kun_readings,
        "on_readings_romaji": on_readings_romaji,
        "kun_readings_romaji": kun_readings_romaji,
        # KANJIDIC nanori is absent from this site entirely (0 occurrences over
        # 900 sampled pages). Recorded explicitly as a source coverage gap.
        "nanori": None,
        "radical": radical,
        "parts": parts,
        "parts_lists_self": parts_lists_self,
        "parts_without_direct_edge": parts_without_direct_edge,
        "parts_not_in_graph": parts_not_in_graph,
        **graph,
        "mnemonic_hint": hint["hint"],
        "mnemonic_hint_raw": hint["raw"],
        "mnemonic_hint_kind": hint["kind"],
        "mnemonic_hint_group": parse_int(kanjialive.get("hint_group"))
        if kanjialive.get("hint_group") is not None
        else None,
        "mnemonic_etymology_notes": hint["etymology_notes"],
        "mnemonic_kanji_refs": hint["kanji_refs"],
        "example_words_kanjialive": parse_kanjialive_examples(kanjialive),
        "example_words_on": parse_jisho_examples(jisho.get("onyomiExamples"), "on"),
        "example_words_kun": parse_jisho_examples(jisho.get("kunyomiExamples"), "kun"),
        "stroke_order": stroke_order,
        "textbooks": textbooks,
        # Kanji Alive files its own lesson number in the textbook list under the
        # key "lesson". It is a curriculum index, not a book, so it is emitted on
        # its own rather than mixed into a bibliography.
        "kanjialive_lesson": kanjialive_lesson,
        "references": _references(kanjialive),
        "kanjialive_id": _clean_scalar(kanjialive.get("ka_id")),
        "kanjialive_name": _clean_scalar(kanjialive.get("kname")),
        "jisho_uri": _clean_scalar(jisho.get("uri")),
        "upstreams": {
            "kanjialive": bool(kanjialive),
            "kanjialive_kanji_level": bool(ka_kanji),
            "jisho": bool(jisho),
            "jisho_found": bool(jisho.get("found")),
        },
        "source_url": url,
        "parse_notes": parse_notes,
    }

    record["_provenance"] = build_provenance_map(
        source=SITE_ID,
        source_url=url,
        factual_fields=FACTUAL_FIELDS,
        authored_fields=AUTHORED_FIELDS,
    )
    return record


def _title_character(tree: HtmlElement) -> str | None:
    """The character from ``<title>X | The Kanji Map</title>``, DOM scoped."""
    for title in tree.iter("title"):
        text = text_or_none(title)
        if not text:
            continue
        head = text.split("|", 1)[0].strip()
        if head and head != "The Kanji Map":
            return head
    return None


# Rows of kanjialiveData.txt_books that are not a textbook. "lesson" is Kanji
# Alive's own lesson number for the character, filed in the same list as the
# books, and emitting it as a textbook named "lesson" mixed a curriculum index
# into a bibliography on 354 pages.
_NON_TEXTBOOK_KEYS = frozenset({"lesson"})


def _textbooks(kanjialive: dict[str, Any]) -> tuple[list[dict[str, Any]], int | None]:
    """Textbook chapter references, and the Kanji Alive lesson number apart."""
    out: list[dict[str, Any]] = []
    lesson: int | None = None
    for item in _as_list(kanjialive.get("txt_books")):
        entry = _as_dict(item)
        book = _clean_scalar(entry.get("txt_bk"))
        if not book:
            continue
        if book.lower() in _NON_TEXTBOOK_KEYS:
            if lesson is None:
                lesson = parse_int(entry.get("chapter"))
            continue
        out.append({"textbook": book, "chapter": _clean_scalar(entry.get("chapter"))})
    return out, lesson


def _references(kanjialive: dict[str, Any]) -> dict[str, Any] | None:
    """Dictionary index numbers, or None when the page carries neither.

    Emitted as None rather than as a dict of two nulls, so a fill rate counted on
    this field measures data instead of counting the container.
    """
    references = _as_dict(kanjialive.get("references"))
    payload = {
        "kodansha": _clean_scalar(references.get("kodansha")) or _clean_scalar(kanjialive.get("dick")),
        "classic_nelson": _clean_scalar(references.get("classic_nelson"))
        or _clean_scalar(kanjialive.get("dicn")),
    }
    return payload if any(payload.values()) else None


__all__ = [
    "SITE_ID",
    "EXTRACTABLE",
    "UnexpectedMarkup",
    "infer_page_type",
    "is_shell",
    "dedupe_key",
    "parse",
    "load_props",
    "parse_mnemonic_hint",
    "parse_jisho_examples",
    "normalize_reading",
    "split_meanings",
    "merge_radical",
]
