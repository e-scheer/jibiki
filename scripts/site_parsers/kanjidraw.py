"""Parser for the kanjidraw.com mirror.

Replaces ``parse_site_snapshots.parse_kanjidraw`` plus the four
``parse_kanjidraw_*_page`` helpers in ``extract_mirrored_content.py``.

Three things drive the design.

1. The mirror is largely rotten. About 74 percent of the mirrored
   ``/dictionary/`` pages are byte copies of the site homepage, produced by the
   crawler getting the single-page-app fallback instead of the prerendered
   entry. They are refetchable crawl artifacts, not missing entries, so
   :func:`is_shell` reports them and the caller routes them to a refetch list.
   Detection is structural (canonical target, preload presence, loading
   placeholder) and never size based: real and shell files overlap in size.
2. The payload is JSON, not DOM. Every real page carries one to nine
   ``window.__PRELOAD_*`` assignments holding KANJIDIC data, KanjiVG file
   pointers, Heisig entries, JMdict senses and compounds, and tokenized Tatoeba
   sentences. The old parser read three of them and scraped the rest with
   regexes. Here the JSON is the primary source and the DOM only supplies what
   the JSON does not carry: badges, kana examples, collection grids. Radical
   variant glyphs come from the radical pages only, joined by radical number,
   because the chips rendered on a kanji page contradict them.
3. Grade codes are KANJIDIC buckets, not school years. 8 means junior high and
   9 means jinmeiyō. They are emitted as ``grade_code`` plus a decoded
   ``grade_label`` so no consumer can read the integer as an ordinal year.
4. A badge label is a fact, a badge tooltip is authored copy. They are split
   into ``badges`` and ``badge_notes`` so provenance can classify them apart,
   and no hardcoded upstream source list is stamped onto a record as if the
   page had declared it.

Page types, all keyed off the url alone:

``kanji``              ``/dictionary/<single kanji>/``
``word``               ``/dictionary/<multi character slug>/``
``dictionary_kana``    ``/dictionary/<single kana>/``
``dictionary_index``   ``/dictionary/`` (carries the upstream data credits)
``kana``               ``/kana/<script>-<romaji>/``
``kana_index``         ``/kana/`` (gojūon grid plus the romanization table)
``radical``            ``/radicals/<1..214>/``
``radical_index``      ``/radicals/``
``collection``         ``/collections/<slug>/``
``collection_index``   ``/collections/``
"""

from __future__ import annotations

import copy
import json
import re
import unicodedata
import urllib.parse
from typing import Any, Iterable

from lxml import etree
from lxml.html import HtmlElement

from site_parsers.common import (
    build_provenance_map,
    normalize_jlpt,
    normalize_text,
    parse_int,
    plain_text,
    rich_text,
    split_english_glosses,
    unique_list,
)

SITE_ID = "kanjidraw"

PAGE_KANJI = "kanji"
PAGE_WORD = "word"
PAGE_DICTIONARY_KANA = "dictionary_kana"
PAGE_DICTIONARY_INDEX = "dictionary_index"
PAGE_KANA = "kana"
PAGE_KANA_INDEX = "kana_index"
PAGE_RADICAL = "radical"
PAGE_RADICAL_INDEX = "radical_index"
PAGE_COLLECTION = "collection"
PAGE_COLLECTION_INDEX = "collection_index"
PAGE_OTHER = "other"

EXTRACTABLE = frozenset(
    {
        PAGE_KANJI,
        PAGE_WORD,
        PAGE_DICTIONARY_KANA,
        PAGE_DICTIONARY_INDEX,
        PAGE_KANA,
        PAGE_KANA_INDEX,
        PAGE_RADICAL,
        PAGE_RADICAL_INDEX,
        PAGE_COLLECTION,
        PAGE_COLLECTION_INDEX,
    }
)

# Page types served from /dictionary/<slug>/. All of them carry preload JSON on
# a healthy fetch, which is what makes the missing-preload shell test valid.
DICTIONARY_ENTRY_TYPES = frozenset({PAGE_KANJI, PAGE_WORD, PAGE_DICTIONARY_KANA})

# Upstream datasets the site itself credits on /dictionary/. This is site level
# metadata, not page data: it is deliberately NOT emitted on any record, because
# stamping a hardcoded seven-name list as parsed factual provenance asserts
# something the page never said. A word page carrying only JMdict preloads would
# claim a Heisig source it does not have. The credits that really are on a page
# are parsed from the dom into ``upstream_credits`` on the dictionary index
# record; this tuple exists so an attribution manifest can read the licence set
# once for the whole site.
UPSTREAM_SOURCES = (
    {"name": "KanjiVG", "used_for": "stroke order svg", "url": "https://kanjivg.tagaini.net"},
    {
        "name": "KANJIDIC",
        "used_for": "kanji readings, grades, stroke counts",
        "url": "https://www.edrdg.org/kanjidic/kanjidic_doc.html",
    },
    {
        "name": "JMdict",
        "used_for": "word senses and compounds",
        "url": "https://www.edrdg.org/jmdict/j_jmdict.html",
    },
    {"name": "Tanos", "used_for": "JLPT word lists", "url": "https://www.tanos.co.uk/"},
    {"name": "Tatoeba", "used_for": "example sentences", "url": "https://tatoeba.org"},
    {
        "name": "Wiki Corpus",
        "used_for": "example sentences",
        "url": "https://alaginrc.nict.go.jp/WikiCorpus/index_E.html",
    },
    {
        "name": "Remembering the Kanji (James Heisig)",
        "used_for": "rtk keyword, primitives, frame number",
        "url": None,
    },
)

# KANJIDIC grade buckets. The integers are not school years: 8 is junior high
# and 9 is jinmeiyō. The labels are definitional decodings of the code written
# for this project, not the site's badge tooltip copy.
GRADE_LABELS = {
    0: "outside the jōyō and jinmeiyō sets",
    8: "taught in Japanese junior high (jōyō)",
    9: "jinmeiyō, a name-use character outside the jōyō set",
    10: "jinmeiyō variant of a jōyō kanji",
}

PRELOAD_KANJI = "__PRELOAD_KANJI__"
PRELOAD_KANJI_DETAILS = "__PRELOAD_KANJI_DETAILS__"
PRELOAD_COMPONENT_INFO = "__PRELOAD_KANJI_COMPONENT_INFO__"
PRELOAD_HEISIG = "__PRELOAD_HEISIG__"
PRELOAD_TATOEBA = "__PRELOAD_TATAEBA__"
PRELOAD_TATOEBA_VERB = "__PRELOAD_TATAEBA_VERB__"
PRELOAD_JMDICT_AUGMENT = "__PRELOAD_JMDICT_AUGMENT__"
PRELOAD_JMDICT_COMPOUNDS = "__PRELOAD_JMDICT_COMPOUNDS__"
PRELOAD_JMDICT_SENSES = "__PRELOAD_JMDICT_SENSES__"
PRELOAD_JMDICT_EXAMPLES = "__PRELOAD_JMDICT_EXAMPLES__"
PRELOAD_RADICAL = "__PRELOAD_RADICAL__"
PRELOAD_RADICAL_INDEX = "__PRELOAD_RADICAL_INDEX__"

KNOWN_PRELOADS = frozenset(
    {
        PRELOAD_KANJI,
        PRELOAD_KANJI_DETAILS,
        PRELOAD_COMPONENT_INFO,
        PRELOAD_HEISIG,
        PRELOAD_TATOEBA,
        PRELOAD_TATOEBA_VERB,
        PRELOAD_JMDICT_AUGMENT,
        PRELOAD_JMDICT_COMPOUNDS,
        PRELOAD_JMDICT_SENSES,
        PRELOAD_JMDICT_EXAMPLES,
        PRELOAD_RADICAL,
        PRELOAD_RADICAL_INDEX,
    }
)

_PRELOAD_ASSIGNMENT = re.compile(r"window\.(__[A-Z0-9_]+__)\s*=\s*")
_ENTRY_MARKER_CLASSES = ("dict-word-hero-char", "kana-title-emoji", "dict-meanings-list")
_JLPT_LABEL = re.compile(r"^(?:JLPT\s*)?N\s*([1-5])(?![0-9])", re.IGNORECASE)
_LEADING_SEPARATOR = re.compile(r"^[\s:\u00b7\-\u2013\u2014]+")


# --- url routing --------------------------------------------------------------


def _path_segments(url: str) -> list[str]:
    path = urllib.parse.unquote(urllib.parse.urlsplit(url).path or "/")
    return [segment for segment in path.split("/") if segment]


def _normalize_slug(value: str) -> str:
    return unicodedata.normalize("NFC", value)


def _is_kana_char(value: str) -> bool:
    if len(value) != 1:
        return False
    code = ord(value)
    return 0x3040 <= code <= 0x30FF or code == 0x31F0 or code == 0xFF70


def _is_kanji_char(value: str) -> bool:
    if len(value) != 1:
        return False
    code = ord(value)
    return (
        0x3400 <= code <= 0x4DBF
        or 0x4E00 <= code <= 0x9FFF
        or 0xF900 <= code <= 0xFAFF
        or 0x20000 <= code <= 0x2FA1F
        or value == "々"
    )


def infer_page_type(url: str) -> str:
    segments = _path_segments(url)
    if not segments:
        return PAGE_OTHER
    section = segments[0]
    rest = segments[1:]

    if section == "dictionary":
        if not rest:
            return PAGE_DICTIONARY_INDEX
        if len(rest) > 1:
            return PAGE_OTHER
        slug = _normalize_slug(rest[0])
        if _is_kana_char(slug):
            return PAGE_DICTIONARY_KANA
        if _is_kanji_char(slug):
            return PAGE_KANJI
        return PAGE_WORD

    if section == "kana":
        if not rest:
            return PAGE_KANA_INDEX
        return PAGE_KANA if len(rest) == 1 else PAGE_OTHER
    if section == "radicals":
        if not rest:
            return PAGE_RADICAL_INDEX
        return PAGE_RADICAL if len(rest) == 1 else PAGE_OTHER
    if section == "collections":
        if not rest:
            return PAGE_COLLECTION_INDEX
        # /collections/<slug>/ and /collections/<slug>/page/<n>/ are both
        # collection pages: the paginated ones carry the rest of the items.
        if len(rest) == 1 or (len(rest) == 3 and rest[1] == "page"):
            return PAGE_COLLECTION
        return PAGE_OTHER
    return PAGE_OTHER


def dedupe_key(url: str, page_type: str) -> str:
    """Identity of the entity, query string and percent-encoding ignored."""
    segments = [_normalize_slug(segment) for segment in _path_segments(url)]
    if page_type == PAGE_RADICAL and len(segments) > 1:
        number = parse_int(segments[1])
        if number is not None:
            segments[1] = str(number)
    if page_type == PAGE_KANA and len(segments) > 1:
        segments[1] = segments[1].lower()
    if page_type == PAGE_COLLECTION:
        slug, page_number = _collection_slug_and_page(url)
        suffix = f"/page/{page_number}" if page_number > 1 else ""
        return f"{SITE_ID}:{page_type}:/collections/{slug.lower()}{suffix}"
    return f"{SITE_ID}:{page_type}:/" + "/".join(segments)


# --- dom helpers --------------------------------------------------------------


def _class_predicate(name: str) -> str:
    """Token-safe class test.

    ``contains(@class, 'radical-neighbor')`` also matches ``radical-neighbors``
    and ``radical-neighbor-char``, which is what produced five duplicate
    neighbour entries with a null href for every single link.
    """
    return f"contains(concat(' ',normalize-space(@class),' '),' {name} ')"


def _by_class(node: HtmlElement, name: str, prefix: str = ".//") -> list[HtmlElement]:
    """Descendants of ``node`` carrying ``name`` as a class token.

    The default prefix is ``.//`` and there is no reason to ever pass ``//``.
    An absolute ``//`` is resolved from the document root whatever the context
    node is, so a per-item read inside a loop silently returns the first match
    in the whole page: every card on a collection page got the badges of the
    first card, which made the conjugation group wrong on 103 of 119 items and
    invented a JLPT level for the 9 items that carry no JLPT badge. Scoping by
    default removes the whole class of defect rather than one instance of it.
    """
    return node.xpath(f"{prefix}*[{_class_predicate(name)}]")


def _first_by_class(node: HtmlElement, name: str, prefix: str = ".//") -> HtmlElement | None:
    found = _by_class(node, name, prefix=prefix)
    return found[0] if found else None


def _node_text(node: HtmlElement | None) -> str | None:
    """Text of one element, excluding its tail.

    The shared extractor appends ``node.tail`` so that concatenating siblings
    works, which is right for prose but wrong for a scalar read off a single
    element: taking the ``<b>`` of a list item would otherwise return the whole
    sentence that follows it, and an attribution link would return the clause
    after it. The tail is stripped on the working copy and put back.
    """
    if node is None:
        return None
    tail = node.tail
    node.tail = None
    try:
        value = plain_text(node)
    finally:
        node.tail = tail
    return value or None


def _text_by_class(node: HtmlElement, name: str, prefix: str = ".//") -> str | None:
    return _node_text(_first_by_class(node, name, prefix=prefix))


def _own_text(node: HtmlElement | None) -> str | None:
    """Only the element's own leading text node.

    A kana heading is ``<h1 class="kana-detail-char">ば<span
    class="kana-detail-char-label">(ba) ... Hiragana</span></h1>`` and must
    yield ``ば``. ``text_content()`` swallowed the label span, so the kana
    identity field carried the romaji and the script name as well.
    """
    if node is None:
        return None
    return normalize_text(node.text or "") or None


def _attr(node: HtmlElement | None, name: str) -> str | None:
    if node is None:
        return None
    value = (node.get(name) or "").strip()
    return value or None


def _class_suffix(node: HtmlElement, prefix: str) -> str | None:
    for token in (node.get("class") or "").split():
        if token.startswith(prefix) and len(token) > len(prefix):
            return token[len(prefix) :]
    return None


def _prepare(tree: HtmlElement) -> HtmlElement:
    """Working copy with react splice comments removed and emphasis kept.

    Two transforms, both required for correct text:

    * ``<!-- -->`` markers carry a space of content, so ``JLPT N<!-- -->2``
      extracts as ``JLPT N 2`` unless the comments go away first.
    * ``b``/``strong``/``em`` become ``mark``, which the shared extractor turns
      into an ``emphasis`` role span with offsets, so bolded terms survive
      instead of being flattened into the sentence.
    """
    working = copy.deepcopy(tree)
    etree.strip_tags(working, etree.Comment)
    for node in working.iter("b", "strong", "em"):
        node.tag = "mark"
    return working


def _rich(node: HtmlElement | None) -> dict[str, Any] | None:
    if node is None:
        return None
    return rich_text(node).to_json()


# --- embedded json ------------------------------------------------------------


def _scan_json_literal(text: str, start: int) -> tuple[Any, int]:
    """Read one balanced JSON object or array starting at ``start``."""
    opener = text[start]
    if opener not in "{[":
        raise ValueError(f"preload assignment does not start with json at offset {start}")
    closer = "}" if opener == "{" else "]"
    depth = 0
    index = start
    in_string = False
    escaped = False
    while index < len(text):
        char = text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
        elif char == '"':
            in_string = True
        elif char in "{[":
            depth += 1
        elif char in "}]":
            depth -= 1
            if depth == 0:
                body = text[start : index + 1]
                if char != closer:
                    raise ValueError("unbalanced json in preload assignment")
                return json.loads(body), index + 1
        index += 1
    raise ValueError("unterminated json in preload assignment")


def preload_names(tree: HtmlElement) -> list[str]:
    """Names of the ``window.__X__`` assignments present, without parsing them."""
    names: list[str] = []
    for script in tree.iter("script"):
        if script.get("src"):
            continue
        text = script.text or ""
        if "window.__" not in text:
            continue
        names.extend(match.group(1) for match in _PRELOAD_ASSIGNMENT.finditer(text))
    return names


def extract_preloads(tree: HtmlElement) -> dict[str, Any]:
    """Parse every ``window.__X__ = <json>`` assignment.

    A malformed payload raises: silently skipping it is how the previous
    generation lost five preloads per page without anyone noticing.
    """
    payload: dict[str, Any] = {}
    for script in tree.iter("script"):
        if script.get("src"):
            continue
        text = script.text or ""
        if "window.__" not in text:
            continue
        for match in _PRELOAD_ASSIGNMENT.finditer(text):
            name = match.group(1)
            value, _ = _scan_json_literal(text, match.end())
            payload[name] = value
    return payload


def _json_ld_nodes(tree: HtmlElement) -> list[dict[str, Any]]:
    nodes: list[dict[str, Any]] = []
    for script in tree.xpath(".//script[@type='application/ld+json']"):
        text = (script.text or "").strip()
        if not text:
            continue
        parsed = json.loads(text)
        candidates = parsed if isinstance(parsed, list) else [parsed]
        for candidate in candidates:
            if not isinstance(candidate, dict):
                continue
            graph = candidate.get("@graph")
            if isinstance(graph, list):
                nodes.extend(item for item in graph if isinstance(item, dict))
            else:
                nodes.append(candidate)
    return nodes


def _json_ld_of_type(nodes: list[dict[str, Any]], wanted: str) -> dict[str, Any]:
    for node in nodes:
        node_type = node.get("@type")
        types = node_type if isinstance(node_type, list) else [node_type]
        if wanted in types:
            return node
    return {}


# --- shell detection ----------------------------------------------------------


def _canonical_path(tree: HtmlElement) -> str | None:
    for node in tree.xpath(".//link[@rel='canonical']/@href"):
        value = str(node).strip()
        if value:
            return _compare_path(value)
    return None


def _compare_path(url: str) -> str:
    path = urllib.parse.unquote(urllib.parse.urlsplit(url).path or "/")
    path = unicodedata.normalize("NFC", path).rstrip("/")
    return path or "/"


def is_shell(tree: HtmlElement, url: str) -> bool:
    """True when the file is a crawl artifact rather than the requested page.

    Three independent artifact shapes exist in this mirror:

    * the homepage single-page-app fallback, which canonicalises to
      ``https://kanjidraw.com`` and carries no preload,
    * a client-side loading placeholder (``dict-loading-screen``) with the right
      canonical but no rendered entry,
    * an entry page fetched without its preload JSON and without any rendered
      hero, which is the same fallback caught by a different signal.

    Size is deliberately not used: real pages and shells overlap in byte size,
    and the shell sizes drift between crawl sessions.
    """
    canonical = _canonical_path(tree)
    if canonical is None or canonical != _compare_path(url):
        return True
    if _by_class(tree, "dict-loading-screen"):
        return True

    page_type = infer_page_type(url)
    names = set(preload_names(tree))
    if page_type in DICTIONARY_ENTRY_TYPES:
        if not names and not any(_by_class(tree, name) for name in _ENTRY_MARKER_CLASSES):
            return True
    if page_type == PAGE_RADICAL:
        if PRELOAD_RADICAL not in names and not _by_class(tree, "radical-detail-glyph"):
            return True
    if page_type == PAGE_RADICAL_INDEX:
        if PRELOAD_RADICAL_INDEX not in names and not _by_class(tree, "radical-card"):
            return True
    return False


# --- shared field builders ----------------------------------------------------


def _grade_fields(raw: Any) -> dict[str, Any]:
    """Decode a KANJIDIC grade bucket.

    ``0`` must survive: it means outside jōyō and jinmeiyō, which the old
    ``preload.get("grade") or fallback`` chain collapsed into ``None`` and made
    indistinguishable from no data at all.
    """
    if raw is None or isinstance(raw, bool):
        return {"grade_code": None, "grade_label": None}
    code = parse_int(raw)
    if code is None:
        return {"grade_code": None, "grade_label": None}
    if 1 <= code <= 6:
        label = f"taught in Japanese elementary grade {code} (kyōiku)"
    else:
        label = GRADE_LABELS.get(code)
    return {"grade_code": code, "grade_label": label}


def _meanings_by_lang(english: Iterable[Any], russian: Iterable[Any]) -> dict[str, list[str]]:
    """Locale-keyed meanings, never an empty bucket for an absent language."""
    out: dict[str, list[str]] = {}
    en = unique_list(str(item).strip() for item in english if isinstance(item, str) and item.strip())
    ru = unique_list(str(item).strip() for item in russian if isinstance(item, str) and item.strip())
    if en:
        out["en"] = en
    if ru:
        out["ru"] = ru
    return out


def _split_russian_glosses(value: str | None) -> list[str]:
    """Split a russian gloss blob without breaking its numbers.

    ``common.split_english_glosses`` cuts on every comma, which is correct for
    English but destroys Russian: the comma is the decimal separator there, so
    ``"= 10 сэ = 0,0992 га"`` came out as ``["= 10 сэ = 0", "0992 га"]`` and the
    bare enumeration ``"ごう【号】 1, 3, 5"`` came out as three glosses ``"1"``,
    ``"3"``, ``"5"``. A comma sitting between two digits is never a gloss
    separator, so those are left alone; semicolons and ordinary commas still
    split. Parenthesis depth is tracked as in the shared splitter so an aside
    stays attached to its gloss.
    """
    if not value:
        return []
    items: list[str] = []
    buffer: list[str] = []
    depth = 0
    for index, char in enumerate(value):
        if char in "([{（【「":
            depth += 1
        elif char in ")]}）】」":
            depth = max(0, depth - 1)
        if char in ";；" and depth == 0:
            items.append("".join(buffer))
            buffer = []
            continue
        if char in ",，" and depth == 0 and not _between_digits(value, index):
            items.append("".join(buffer))
            buffer = []
            continue
        buffer.append(char)
    items.append("".join(buffer))
    return unique_list(item.strip() for item in items if item.strip())


def _between_digits(value: str, index: int) -> bool:
    """True when the character at ``index`` separates two numbers."""
    before = value[:index].rstrip()
    after = value[index + 1 :].lstrip()
    return bool(before) and before[-1].isdigit() and bool(after) and after[0].isdigit()


def _russian_only(english: Iterable[Any], russian: Iterable[Any]) -> dict[str, list[str]] | None:
    """Locale map for a nested item, emitted only when a russian gloss exists.

    Nested items already carry their english gloss in ``meaning``, so adding a
    single-locale map to every one of them would be pure noise. The map exists
    to keep the russian text language scoped instead of letting a bare
    ``meaningRu`` sit inside an otherwise english record.
    """
    by_lang = _meanings_by_lang(english, russian)
    return by_lang if "ru" in by_lang else None


def _flatten_meaning_entries(entries: Any) -> tuple[list[str], list[str]]:
    """``__PRELOAD_KANJI_DETAILS__`` mixes bare strings and per-locale dicts."""
    english: list[str] = []
    russian: list[str] = []
    if not isinstance(entries, list):
        return english, russian
    for entry in entries:
        if isinstance(entry, str):
            english.append(entry)
        elif isinstance(entry, dict):
            if entry.get("meaning"):
                english.append(str(entry["meaning"]))
            if entry.get("meaningRu"):
                russian.append(str(entry["meaningRu"]))
    return english, russian


def _map_compounds(raw: Any) -> list[dict[str, Any]]:
    """``__PRELOAD_KANJI__.compounds`` entries, russian gloss kept locale scoped."""
    out: list[dict[str, Any]] = []
    if not isinstance(raw, list):
        return out
    for item in raw:
        if not isinstance(item, dict):
            continue
        entry: dict[str, Any] = {
            "word": item.get("word"),
            "reading": item.get("reading"),
            "meaning": item.get("meaning"),
        }
        by_lang = _russian_only(
            [item.get("meaning")] if item.get("meaning") else [],
            [item.get("meaningRu")] if item.get("meaningRu") else [],
        )
        if by_lang:
            entry["meanings_by_lang"] = by_lang
        if entry["word"]:
            out.append(entry)
    return out


def _map_jmdict_word(raw: Any) -> dict[str, Any] | None:
    """One JMdict headword: ``w`` surface, ``r`` reading, ``m`` glosses, ``mr`` russian."""
    if not isinstance(raw, dict) or not raw.get("w"):
        return None
    glosses = split_english_glosses(raw.get("m"))
    entry: dict[str, Any] = {
        "word": raw.get("w"),
        "reading": raw.get("r"),
        "glosses": glosses,
        "pos": _listify(raw.get("p")),
    }
    by_lang = _russian_only(glosses, _split_russian_glosses(raw.get("mr")))
    if by_lang:
        entry["meanings_by_lang"] = by_lang
    return entry


def _map_jmdict_words(raw: Any) -> list[dict[str, Any]]:
    if not isinstance(raw, list):
        return []
    mapped = (_map_jmdict_word(item) for item in raw)
    return [entry for entry in mapped if entry]


def _listify(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item) for item in value if item not in (None, "")]
    return [str(value)]


def _map_senses(raw: Any) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    if not isinstance(raw, dict):
        return out
    for index, sense in enumerate(raw.get("senses") or []):
        if not isinstance(sense, dict):
            continue
        entry = {
            "index": index,
            "glosses": _listify(sense.get("g")),
            "pos": _listify(sense.get("pos")),
            "misc": _listify(sense.get("misc")),
            "field": _listify(sense.get("field")),
            "info": _listify(sense.get("info")),
        }
        if entry["glosses"]:
            out.append(entry)
    return out


def _map_sense_examples(raw: Any) -> list[dict[str, Any]]:
    """``__PRELOAD_JMDICT_EXAMPLES__`` is a per-sense list of sentence pairs."""
    out: list[dict[str, Any]] = []
    if not isinstance(raw, dict):
        return out
    for sense_index, bucket in enumerate(raw.get("examples") or []):
        if not isinstance(bucket, list):
            continue
        for item in bucket:
            if not isinstance(item, dict) or not item.get("jp"):
                continue
            out.append(
                {
                    "sense_index": sense_index,
                    "japanese": item.get("jp"),
                    "english": item.get("en"),
                }
            )
    return out


def _map_tokens(raw: Any) -> list[dict[str, Any]]:
    tokens: list[dict[str, Any]] = []
    if not isinstance(raw, list):
        return tokens
    for token in raw:
        if not isinstance(token, dict) or not token.get("t"):
            continue
        entry: dict[str, Any] = {"text": token.get("t"), "is_content": bool(token.get("c"))}
        if token.get("b"):
            entry["base_form"] = token["b"]
        tokens.append(entry)
    return tokens


def _map_tatoeba(preloads: dict[str, Any]) -> list[dict[str, Any]]:
    """Tokenized example sentences from the tatoeba preloads.

    ``tokens`` is kept: it is a ready-made segmentation with base forms, which
    is exactly what furigana alignment needs later.
    """
    out: list[dict[str, Any]] = []
    buckets = [
        (PRELOAD_TATOEBA, "examples", "general"),
        (PRELOAD_TATOEBA, "onExamples", "on_reading"),
        (PRELOAD_TATOEBA, "kunExamples", "kun_reading"),
        (PRELOAD_TATOEBA_VERB, "examples", "verb"),
    ]
    for preload_name, key, kind in buckets:
        payload = preloads.get(preload_name)
        if not isinstance(payload, dict):
            continue
        for item in payload.get(key) or []:
            if not isinstance(item, dict) or not item.get("japanese"):
                continue
            entry: dict[str, Any] = {
                "kind": kind,
                "japanese": item.get("japanese"),
                "english": item.get("meaning"),
                "tokens": _map_tokens(item.get("tokens")),
            }
            if item.get("meaningRu"):
                entry["translations_by_lang"] = {
                    "en": item.get("meaning"),
                    "ru": item.get("meaningRu"),
                }
            out.append(entry)
    return out


def _map_badges(node: HtmlElement) -> list[dict[str, Any]]:
    """Every ``dict-badge`` under ``node``, element scoped.

    The old regex ``dict-badge[^>]*>(.*?)</a>`` matched the closing anchor only,
    so on the roughly half of kanji pages whose badges are ``<span>`` it ran on
    to the next ``</a>`` and swallowed several hundred characters of raw markup.

    ``data-tooltip`` is captured into ``note``, but a note is authored copy, not
    a fact about the character, so :func:`_split_badges` moves it to its own
    field before a record is built. Nothing here may be document scoped: the
    caller passes a single collection card as often as it passes a whole tree.
    """
    badges: list[dict[str, Any]] = []
    for badge in _by_class(node, "dict-badge"):
        label = _node_text(badge)
        if not label:
            continue
        badges.append(
            {
                "label": label,
                "kind": _class_suffix(badge, "dict-badge--"),
                "note": _strip_ui_call_to_action(_attr(badge, "data-tooltip")),
                "href": _attr(badge, "href"),
            }
        )
    return unique_list(badges)


_UI_CALL_TO_ACTION = re.compile(
    r"(?:(?<=[.!?])\s+|^)(?:Click|Tap|Press)\b[^.!?]*[.!?]\s*$", re.IGNORECASE
)


def _strip_ui_call_to_action(value: str | None) -> str | None:
    """Drop a trailing interface instruction from a tooltip.

    The jōyō tooltip ends with "Click to see the full list.", which is chrome
    for a mouse pointer and not part of the explanation. It is removed rather
    than shipped as if it were content.

    The match has to start a sentence, so a normal clause that happens to
    contain one of those verbs ("the printing press is used.") is left alone.
    """
    if not value:
        return None
    cleaned = _UI_CALL_TO_ACTION.sub("", value).strip()
    return cleaned or None


def _split_badges(badges: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Separate the factual badge from the site's explanatory copy about it.

    ``label``, ``kind`` and ``href`` are facts: which lists the character
    belongs to and where the site files them. The tooltip is authored
    third-party prose (whole sentences of editorial explanation, present on
    99.5 percent of kanji pages) and must be classified as such, exactly like
    ``radical.note`` or ``collection.description`` already are. Keeping it
    nested inside a factual field marked it shippable, because provenance is
    declared per top level field and cannot describe one key of a nested dict.
    """
    plain = [{key: value for key, value in badge.items() if key != "note"} for badge in badges]
    notes = [
        {"label": badge.get("label"), "kind": badge.get("kind"), "note": badge["note"]}
        for badge in badges
        if badge.get("note")
    ]
    return unique_list(plain), unique_list(notes)


def _jlpt_from_badges(badges: list[dict[str, Any]]) -> str | None:
    for badge in badges:
        kind = badge.get("kind") or ""
        if kind.startswith("jlpt-"):
            level = normalize_jlpt(kind[len("jlpt-") :].upper())
            if level:
                return level
    for badge in badges:
        # Strict: "Group 2" must not become N2, which a bare digit search does.
        match = _JLPT_LABEL.match((badge.get("label") or "").strip())
        if match:
            return f"N{match.group(1)}"
    return None


def _chip_links(tree: HtmlElement, class_name: str) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for node in _by_class(tree, class_name):
        text = _node_text(node)
        if not text:
            continue
        out.append({"text": text, "href": _attr(node, "href")})
    return unique_list(out)


def _stroke_svg_variants(raw: Any) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    if not isinstance(raw, list):
        return out
    for item in raw:
        if isinstance(item, dict) and item.get("file"):
            out.append({"file": item["file"], "label": item.get("label")})
    return out


def _radical_block(info: dict[str, Any]) -> dict[str, Any] | None:
    """Radical identity for a kanji, taken from the component preload only.

    No ``variant_forms`` here, on purpose. The kanji page also renders a row of
    ``radical-chip--variant`` chips, and scraping them produced a field that
    contradicted the radical record under the identical name: for radical 32
    (土) the chips on 増, 堤 and 壌 say 士, which is a different radical
    altogether, while ``/radicals/32/`` states the variant set is empty; 絃 got
    the simplified-Chinese 纟 where ``/radicals/120/`` has 糹; and the chips drop
    ⺗ from radical 61 and everything from radicals 47, 118, 140, 170 and 173.
    Measured on 300 kanji, 72 disagreed with the radical page in one direction
    or the other.

    The extraction was faithful, so the disagreement is the site's own, and a
    downstream join by radical number would have had two competing answers for
    one key. ``number`` is kept, which is all a consumer needs: the authoritative
    variant set lives on the radical record and is joined from there.
    """
    radical = info.get("radical") if isinstance(info, dict) else None
    if not isinstance(radical, dict) or not radical.get("char"):
        return None
    return {
        "number": radical.get("num"),
        "character": radical.get("char"),
        "meaning": radical.get("meaning"),
        "stroke_count": radical.get("strokes"),
    }


def _components(info: dict[str, Any]) -> list[dict[str, Any]]:
    """Explicit mapping, so ``char``/``meaningRu`` never reach the record raw."""
    out: list[dict[str, Any]] = []
    raw = info.get("components") if isinstance(info, dict) else None
    if not isinstance(raw, list):
        return out
    for item in raw:
        if not isinstance(item, dict) or not item.get("char"):
            continue
        entry: dict[str, Any] = {
            "character": item.get("char"),
            "meaning": item.get("meaning"),
            "nested": bool(item.get("nested")),
        }
        by_lang = _russian_only(
            [item.get("meaning")] if item.get("meaning") else [],
            [item.get("meaningRu")] if item.get("meaningRu") else [],
        )
        if by_lang:
            entry["meanings_by_lang"] = by_lang
        out.append(entry)
    return out


def _rtk_block(tree: HtmlElement, preloads: dict[str, Any]) -> dict[str, Any] | None:
    """Heisig keyword, primitives and frame, with their provenance attached.

    The keyword and the primitive chain are authored third-party prose from
    "Remembering the Kanji" and are classified as such by the caller. The frame
    number is a factual index.
    """
    entry = preloads.get(PRELOAD_HEISIG)
    entry = entry.get("entry") if isinstance(entry, dict) else None
    if not isinstance(entry, dict):
        return None
    primitive_chars: dict[str, str] = {}
    for node in _by_class(tree, "dict-heisig-prim-name"):
        name = _node_text(node)
        sibling = node.getnext()
        if name and sibling is not None and "dict-heisig-prim-char" in (sibling.get("class") or ""):
            glyph = (_node_text(sibling) or "").strip("() ")
            if glyph:
                primitive_chars[name] = glyph
    primitives = [
        {"name": str(name), "character": primitive_chars.get(str(name))}
        for name in entry.get("primitives") or []
        if name
    ]
    block: dict[str, Any] = {
        "keyword": entry.get("keyword"),
        "primitives": primitives,
        "source": "Remembering the Kanji, James Heisig",
        "redistributable": False,
    }
    source_note = _text_by_class(tree, "dict-heisig-source")
    if source_note:
        block["source_note"] = source_note
    if not block["keyword"] and not primitives:
        return None
    return block


def _reading_rows(tree: HtmlElement) -> dict[str, list[str]]:
    """DOM readings table, used only as a fallback for the preload arrays."""
    rows: dict[str, list[str]] = {}
    for row in _by_class(tree, "reading-row"):
        label = (_text_by_class(row, "reading-label", prefix=".//") or "").strip().lower()
        values = [_node_text(chip) for chip in _by_class(row, "reading-chip", prefix=".//")]
        values = [value for value in values if value]
        if label and values:
            rows[label] = unique_list(values)
    return rows


def _dom_meanings(tree: HtmlElement) -> list[str]:
    values = [_node_text(node) for node in _by_class(tree, "dict-meaning-text")]
    return unique_list(value for value in values if value)


# --- per page type parsers ----------------------------------------------------


def _preload_dict(preloads: dict[str, Any], name: str, *inner: str) -> dict[str, Any]:
    """A preload payload, or an empty dict, optionally following inner keys."""
    value = preloads.get(name)
    for key in inner:
        value = value.get(key) if isinstance(value, dict) else None
    return value if isinstance(value, dict) else {}


def _parse_kanji(tree: HtmlElement, url: str) -> tuple[dict[str, Any], set[str]]:
    preloads = extract_preloads(tree)
    kanji = _preload_dict(preloads, PRELOAD_KANJI)
    details = _preload_dict(preloads, PRELOAD_KANJI_DETAILS, "data")
    info = _preload_dict(preloads, PRELOAD_COMPONENT_INFO, "info")
    defined_term = _json_ld_of_type(_json_ld_nodes(tree), "DefinedTerm")

    character = (
        kanji.get("char")
        or _own_text(_first_by_class(tree, "dict-word-hero-char"))
        or defined_term.get("name")
        or _normalize_slug(_path_segments(url)[-1])
    )
    if not character:
        raise ValueError(f"no kanji character found on {url}")

    badges, badge_notes = _split_badges(_map_badges(tree))
    readings = _reading_rows(tree)
    detail_en, detail_ru = _flatten_meaning_entries(details.get("meanings"))
    meanings_en = unique_list(list(kanji.get("meaningsEn") or []) + detail_en) or _dom_meanings(tree)

    grade = _grade_fields(
        kanji.get("grade") if kanji.get("grade") is not None else details.get("grade")
    )
    jlpt = normalize_jlpt(kanji.get("jlptLevel"))
    if jlpt is None:
        jlpt = normalize_jlpt(details.get("jlptLevel"))
    if jlpt is None:
        jlpt = _jlpt_from_badges(badges)

    fields: dict[str, Any] = {
        "entry_kind": "kanji",
        "character": character,
        "codepoint_hex": kanji.get("codepointHex"),
        "hero_meaning": _text_by_class(tree, "dict-word-hero-meaning"),
        "stroke_count": kanji.get("strokeCount")
        or parse_int(_text_by_class(tree, "dict-word-hero-strokes")),
        "grade_code": grade["grade_code"],
        "grade_label": grade["grade_label"],
        "jlpt_level": jlpt,
        "in_study_set": kanji.get("inLevels"),
        "on_readings": unique_list(kanji.get("onReadings") or readings.get("on reading") or []),
        "kun_readings": unique_list(kanji.get("kunReadings") or readings.get("kun reading") or []),
        "meanings": meanings_en,
        "meanings_by_lang": _meanings_by_lang(meanings_en, detail_ru),
        "badges": badges,
        "badge_notes": badge_notes,
        "stroke_svg_default": kanji.get("defaultFile"),
        "stroke_svg_variants": _stroke_svg_variants(kanji.get("variants")),
        "radical": _radical_block(info),
        "components": _components(info),
        "popular_usage": _chip_links(tree, "dict-related-chip"),
        "compound_words": _map_compounds(kanji.get("compounds") or details.get("compounds")),
        "jmdict_entry": _map_jmdict_word(
            _preload_dict(preloads, PRELOAD_JMDICT_AUGMENT, "word")
        ),
        "senses": _map_senses(preloads.get(PRELOAD_JMDICT_SENSES)),
        "jmdict_compounds": _map_jmdict_words(
            _preload_dict(preloads, PRELOAD_JMDICT_COMPOUNDS).get("words")
        ),
        "sense_examples": _map_sense_examples(preloads.get(PRELOAD_JMDICT_EXAMPLES)),
        "example_sentences": _map_tatoeba(preloads),
        "rtk_mnemonic": _rtk_block(tree, preloads),
        "rtk_frame": _preload_dict(preloads, PRELOAD_HEISIG, "entry").get("frame"),
    }
    authored = {"rtk_mnemonic", "example_sentences", "sense_examples", "badge_notes"}
    return fields, authored


def _parse_word(tree: HtmlElement, url: str) -> tuple[dict[str, Any], set[str]]:
    preloads = extract_preloads(tree)
    defined_term = _json_ld_of_type(_json_ld_nodes(tree), "DefinedTerm")
    augment = _preload_dict(preloads, PRELOAD_JMDICT_AUGMENT)
    augment_word = _preload_dict(preloads, PRELOAD_JMDICT_AUGMENT, "word")
    jmdict_entry = _map_jmdict_word(augment_word)

    surface = (
        _own_text(_first_by_class(tree, "dict-word-hero-char"))
        or defined_term.get("name")
        or augment.get("key")
        or _normalize_slug(_path_segments(url)[-1])
    )
    if not surface:
        raise ValueError(f"no word surface found on {url}")

    badges, badge_notes = _split_badges(_map_badges(tree))
    senses = _map_senses(preloads.get(PRELOAD_JMDICT_SENSES))
    if not senses:
        dom_meanings = _dom_meanings(tree)
        if dom_meanings:
            senses = [
                {
                    "index": index,
                    "glosses": [meaning],
                    "pos": [],
                    "misc": [],
                    "field": [],
                    "info": [],
                }
                for index, meaning in enumerate(dom_meanings)
            ]
    glosses = unique_list(gloss for sense in senses for gloss in sense["glosses"])

    jlpt = _jlpt_from_badges(badges)
    if jlpt is None:
        jlpt = normalize_jlpt((defined_term.get("identifier") or "").replace("JLPT", "").strip())

    # The label is the fact ("Godan · Group 1"). The tooltip explaining what a
    # godan verb is travels with the other authored badge notes.
    verb_group = None
    for badge in badges:
        if (badge.get("kind") or "") == "verb-group":
            verb_group = badge.get("label")
            break

    russian = _split_russian_glosses(augment_word.get("mr"))

    fields: dict[str, Any] = {
        "entry_kind": "word",
        "surface": surface,
        "reading": _text_by_class(tree, "dict-word-hero-reading")
        or (jmdict_entry or {}).get("reading")
        or defined_term.get("alternateName"),
        "hero_meaning": _text_by_class(tree, "dict-word-hero-meaning"),
        "jlpt_level": jlpt,
        "senses": senses,
        "glosses": glosses,
        "meanings_by_lang": _meanings_by_lang(glosses, russian),
        "part_of_speech": unique_list(
            pos for sense in senses for pos in sense["pos"]
        ) or (jmdict_entry or {}).get("pos", []),
        "verb_group": verb_group,
        "badges": badges,
        "badge_notes": badge_notes,
        "component_kanji": _chip_links(tree, "dict-related-chip"),
        "jmdict_entry": jmdict_entry,
        "sense_examples": _map_sense_examples(preloads.get(PRELOAD_JMDICT_EXAMPLES)),
        "example_sentences": _map_tatoeba(preloads),
    }
    authored = {"example_sentences", "sense_examples", "badge_notes"}
    return fields, authored


def _kana_script_from_slug(url: str) -> str | None:
    segments = _path_segments(url)
    if len(segments) < 2:
        return None
    slug = segments[-1].lower()
    if slug.startswith("hiragana"):
        return "hiragana"
    if slug.startswith("katakana"):
        return "katakana"
    return None


def _parse_dictionary_kana(tree: HtmlElement, url: str) -> tuple[dict[str, Any], set[str]]:
    """``/dictionary/<kana>/``: a kana entry served by the dictionary route."""
    preloads = extract_preloads(tree)
    kanji = preloads.get(PRELOAD_KANJI)
    kanji = kanji if isinstance(kanji, dict) else {}
    defined_term = _json_ld_of_type(_json_ld_nodes(tree), "DefinedTerm")

    character = (
        kanji.get("char")
        or _text_by_class(tree, "kana-title-emoji")
        or defined_term.get("name")
        or _normalize_slug(_path_segments(url)[-1])
    )
    if not character:
        raise ValueError(f"no kana character found on {url}")

    subtitle = _text_by_class(tree, "kana-title-sub") or ""
    script = None
    lowered = subtitle.lower()
    if "hiragana" in lowered:
        script = "hiragana"
    elif "katakana" in lowered:
        script = "katakana"

    fields: dict[str, Any] = {
        "entry_kind": "kana",
        "character": character,
        "romaji": _text_by_class(tree, "kana-title-text") or defined_term.get("alternateName"),
        "script": script,
        "codepoint_hex": kanji.get("codepointHex"),
        "stroke_count": kanji.get("strokeCount") or parse_int(subtitle),
        "stroke_step_count": len(_by_class(tree, "stroke-step")) or None,
        "stroke_svg_default": kanji.get("defaultFile"),
        "stroke_svg_variants": _stroke_svg_variants(kanji.get("variants")),
        "compound_words": _map_compounds(kanji.get("compounds")),
        "description": defined_term.get("description"),
    }
    return fields, set()


def _parse_kana(tree: HtmlElement, url: str) -> tuple[dict[str, Any], set[str]]:
    """``/kana/<script>-<romaji>/``: the kana detail overlay.

    ``kana_cells`` is deliberately absent here. The gojūon grid is the shared
    navigation table, identical on all 186 detail pages and missing the page's
    own kana on 50 of them, so repeating it per record added 47 rows of chrome
    and no information. It is emitted once, on the index record.
    """
    heading = _first_by_class(tree, "kana-detail-char")
    character = _own_text(heading)
    label = _text_by_class(tree, "kana-detail-char-label")
    romaji = _text_by_class(tree, "kana-detail-romaji")

    script = _kana_script_from_slug(url)
    dom_script = None
    for button in _by_class(tree, "kana-seg-btn"):
        if (button.get("aria-selected") or "").lower() == "true":
            dom_script = _class_suffix(button, "kana-seg-btn--")
            break
    dom_script = {"hira": "hiragana", "kata": "katakana"}.get(dom_script or "", None)

    notes: list[str] = []
    if dom_script and script and dom_script != script:
        notes.append(f"script disagreement: slug says {script}, selected tab says {dom_script}")

    if not character:
        raise ValueError(f"no kana character found on {url}")

    examples: list[dict[str, Any]] = []
    for row in _by_class(tree, "kana-detail-example-row"):
        word = _text_by_class(row, "kana-detail-example-word", prefix=".//")
        if not word:
            continue
        examples.append(
            {
                "word": word,
                "meaning": _text_by_class(row, "kana-detail-example-meaning", prefix=".//"),
                "highlight": _text_by_class(row, "kana-example-highlight", prefix=".//"),
            }
        )

    fields: dict[str, Any] = {
        "entry_kind": "kana",
        "character": character,
        "character_label": label,
        "romaji": romaji,
        "script": script or dom_script,
        "stroke_count": parse_int(_text_by_class(tree, "kana-detail-strokes")),
        "stroke_step_count": len(_by_class(tree, "stroke-step")) or None,
        "examples": examples,
        "practice_hint": _text_by_class(tree, "kana-practice-block-desc"),
    }
    if notes:
        fields["parse_notes"] = notes
    return fields, {"practice_hint"}


def _kana_cells(tree: HtmlElement) -> list[dict[str, Any]]:
    cells: list[dict[str, Any]] = []
    for node in _by_class(tree, "kana-cell"):
        href = _attr(node, "href")
        character = _text_by_class(node, "kana-cell-char", prefix=".//")
        if not href or not character:
            continue
        romaji = _text_by_class(node, "kana-cell-romaji", prefix=".//")
        script = None
        if "/kana/hiragana" in href:
            script = "hiragana"
        elif "/kana/katakana" in href:
            script = "katakana"
        cells.append(
            {"character": character, "romaji": romaji, "script": script, "href": href}
        )
    return unique_list(cells)


def _romaji_variants(tree: HtmlElement) -> list[dict[str, Any]]:
    """The Hepburn versus Kunrei-shiki table, previously dropped entirely."""
    table = _first_by_class(tree, "kana-romaji-table")
    if table is None:
        return []
    headers = [_node_text(cell) or "" for cell in table.xpath(".//thead//th")]
    if [header.lower() for header in headers[:3]] != ["kana", "hepburn", "kunrei-shiki"]:
        raise ValueError(f"unexpected romanization table headers: {headers}")
    rows: list[dict[str, Any]] = []
    for row in table.xpath(".//tbody/tr"):
        cells = [_node_text(cell) for cell in row.xpath("./td")]
        if len(cells) < 3 or not cells[0]:
            continue
        rows.append({"kana": cells[0], "hepburn": cells[1], "kunrei_shiki": cells[2]})
    return rows


def _guide_sections(root: HtmlElement | None) -> list[dict[str, Any]]:
    """Headed prose blocks, one record per heading, emphasis roles preserved."""
    if root is None:
        return []
    sections: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for child in root:
        tag = child.tag if isinstance(child.tag, str) else ""
        if tag in {"h1", "h2", "h3", "h4"}:
            if current:
                sections.append(current)
            current = {"heading": _node_text(child), "paragraphs": []}
            continue
        if tag == "p" and current is not None:
            payload = _rich(child)
            if payload:
                current["paragraphs"].append(payload)
    if current:
        sections.append(current)
    return [section for section in sections if section["paragraphs"]]


def _parse_kana_index(tree: HtmlElement, url: str) -> tuple[dict[str, Any], set[str]]:
    fields: dict[str, Any] = {
        "entry_kind": "kana_index",
        "kana_cells": _kana_cells(tree),
        "romaji_variants": _romaji_variants(tree),
        "guide_sections": _guide_sections(_first_by_class(tree, "kana-seo")),
        "subtitle": _text_by_class(tree, "kana-title-sub"),
    }
    if not fields["kana_cells"]:
        raise ValueError(f"kana index carries no kana cells: {url}")
    return fields, {"guide_sections", "subtitle"}


def _map_radical_members(raw: Any) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    if not isinstance(raw, list):
        return out
    for item in raw:
        if not isinstance(item, dict) or not item.get("c"):
            continue
        grade = _grade_fields(item.get("g"))
        entry: dict[str, Any] = {
            "character": item.get("c"),
            "stroke_count": item.get("sc"),
            "grade_code": grade["grade_code"],
            "grade_label": grade["grade_label"],
            "on_reading": item.get("on"),
            "meaning": item.get("mn"),
            "position": item.get("p"),
        }
        by_lang = _russian_only(
            [item.get("mn")] if item.get("mn") else [],
            [item.get("mnRu")] if item.get("mnRu") else [],
        )
        if by_lang:
            entry["meanings_by_lang"] = by_lang
        out.append(entry)
    return out


def _radical_card_fields(card: dict[str, Any]) -> dict[str, Any]:
    return {
        "radical_number": card.get("num"),
        "character": card.get("char"),
        "meaning": card.get("meaning"),
        "meanings_by_lang": _meanings_by_lang(
            [card.get("meaning")] if card.get("meaning") else [],
            [card.get("meaningRu")] if card.get("meaningRu") else [],
        ),
        "stroke_count": card.get("strokes"),
        "joyo_count": card.get("joyoCount"),
        "other_count": card.get("otherCount"),
        "variant_forms": unique_list(card.get("variants") or []),
        "sample_kanji": unique_list(card.get("sample") or []),
    }


def _parse_radical(tree: HtmlElement, url: str) -> tuple[dict[str, Any], set[str]]:
    preloads = extract_preloads(tree)
    preload = preloads.get(PRELOAD_RADICAL)
    preload = preload if isinstance(preload, dict) else {}
    card = preload.get("card")
    card = card if isinstance(card, dict) else {}

    fields: dict[str, Any] = {"entry_kind": "radical"}
    fields.update(_radical_card_fields(card))
    if fields["radical_number"] is None:
        fields["radical_number"] = preload.get("num") or parse_int(_path_segments(url)[-1])
    if not fields["character"]:
        fields["character"] = _text_by_class(tree, "radical-detail-glyph")
    if not fields["meaning"]:
        fields["meaning"] = _text_by_class(tree, "radical-detail-name")
    if fields["stroke_count"] is None:
        fields["stroke_count"] = parse_int(_text_by_class(tree, "radical-detail-sub"))
    if not fields["variant_forms"]:
        fields["variant_forms"] = unique_list(
            _node_text(node) for node in _by_class(tree, "radical-variant-tile")
        )
    if not fields["character"]:
        raise ValueError(f"no radical glyph found on {url}")

    fields["component_filters"] = [
        {
            "character": item.get("c"),
            "meaning": item.get("m"),
            "count": item.get("n"),
            "meanings_by_lang": _russian_only(
                [item.get("m")] if item.get("m") else [],
                [item.get("mr")] if item.get("mr") else [],
            ),
        }
        for item in preload.get("components") or []
        if isinstance(item, dict) and item.get("c")
    ]
    fields["joyo_members"] = _map_radical_members(preload.get("members"))
    fields["other_members"] = _map_radical_members(preload.get("other"))

    neighbors: list[dict[str, Any]] = []
    for node in _by_class(tree, "radical-neighbor"):
        href = _attr(node, "href")
        direction = _class_suffix(node, "radical-neighbor--")
        label = _text_by_class(node, "radical-neighbor-dir", prefix=".//")
        neighbors.append(
            {
                "direction": direction,
                "label": label,
                "radical_number": parse_int(label),
                "character": _text_by_class(node, "radical-neighbor-char", prefix=".//"),
                "meaning": _text_by_class(node, "radical-neighbor-meaning", prefix=".//"),
                "href": href,
            }
        )
    fields["neighbors"] = unique_list(neighbors)
    fields["intro"] = _rich(_first_by_class(tree, "radical-detail-intro"))
    fields["note"] = _text_by_class(tree, "radical-detail-note")
    return fields, {"intro", "note"}


def _parse_radical_index(tree: HtmlElement, url: str) -> tuple[dict[str, Any], set[str]]:
    preloads = extract_preloads(tree)
    entries = preloads.get(PRELOAD_RADICAL_INDEX)
    radicals: list[dict[str, Any]] = []
    if isinstance(entries, list):
        for item in entries:
            if isinstance(item, dict) and item.get("char"):
                radicals.append(_radical_card_fields(item))
    if not radicals:
        for card in _by_class(tree, "radical-card"):
            glyph = _text_by_class(card, "radical-card-glyph", prefix=".//")
            if not glyph:
                continue
            radicals.append(
                {
                    "radical_number": parse_int(
                        _text_by_class(card, "radical-card-num", prefix=".//")
                    ),
                    "character": glyph,
                    "meaning": _text_by_class(card, "radical-card-meaning", prefix=".//"),
                }
            )
    if not radicals:
        raise ValueError(f"radical index carries no radicals: {url}")
    fields: dict[str, Any] = {
        "entry_kind": "radical_index",
        "radicals": radicals,
        "intro": _rich(_first_by_class(tree, "radicals-intro")),
        "subtitle": _text_by_class(tree, "radicals-subtitle"),
    }
    return fields, {"intro", "subtitle"}


def _collection_slug_and_page(url: str) -> tuple[str, int]:
    """Split ``/collections/<slug>/page/<n>/`` into the slug and the page number.

    Paginated pages carry different items for the same collection, so the page
    number is part of the record identity. Collapsing them would silently drop
    17 of the 18 pages of the jōyō collection.
    """
    segments = _path_segments(url)[1:]
    if len(segments) >= 3 and segments[-2] == "page":
        return _normalize_slug(segments[0]), parse_int(segments[-1]) or 1
    return _normalize_slug(segments[0]) if segments else "", 1


def _loading_placeholder(tree: HtmlElement) -> bool:
    for node in tree.xpath(".//p"):
        if (_node_text(node) or "").strip().rstrip(".…") == "Loading":
            return True
    return False


def _next_page_href(tree: HtmlElement) -> str | None:
    for node in _by_class(tree, "collection-page-btn"):
        href = _attr(node, "href")
        if href and "Next" in (_node_text(node) or ""):
            return href
    return None


def _parse_collection(tree: HtmlElement, url: str) -> tuple[dict[str, Any], set[str]]:
    ld_nodes = _json_ld_nodes(tree)
    meta = _json_ld_of_type(ld_nodes, "CollectionPage")

    # Two card layouts exist. Kanji collections use collection-kanji-card, and
    # verb, adjective and textbook vocabulary collections use
    # collection-verb-card with a badge row. Reading only the first layout
    # emptied the item grid on 60 percent of the collections.
    items: list[dict[str, Any]] = []
    for card in _by_class(tree, "collection-kanji-card"):
        character = _text_by_class(card, "collection-kanji-char", prefix=".//")
        if not character:
            continue
        items.append(
            {
                "kind": "kanji",
                "surface": character,
                "reading": _text_by_class(card, "collection-kanji-reading", prefix=".//"),
                "meaning": _text_by_class(card, "collection-kanji-meaning", prefix=".//"),
                "href": _attr(card, "href"),
            }
        )
    for card in _by_class(tree, "collection-verb-card"):
        surface = _text_by_class(card, "collection-verb-word", prefix=".//")
        if not surface:
            continue
        # Card scoped, not document scoped: these badges are this word's.
        badges, _ = _split_badges(_map_badges(card))
        entry: dict[str, Any] = {
            "kind": "word",
            "surface": surface,
            "reading": _text_by_class(card, "collection-verb-reading", prefix=".//"),
            "meaning": _text_by_class(card, "collection-verb-meaning", prefix=".//"),
            "href": _attr(card, "href"),
            "jlpt_level": _jlpt_from_badges(badges),
        }
        for badge in badges:
            if (badge.get("kind") or "") == "verb-group":
                entry["verb_group"] = badge.get("label")
                break
        items.append(entry)

    practice_modes: list[dict[str, Any]] = []
    for item in tree.xpath(f".//*[{_class_predicate('collection-modes-list')}]/li"):
        emoji = _text_by_class(item, "collection-modes-emoji", prefix=".//")
        marks = item.xpath(".//mark")
        name = _node_text(marks[0]) if marks else None
        body = None
        for span in item.xpath("./span"):
            if "collection-modes-emoji" in (span.get("class") or ""):
                continue
            body = rich_text(span)
            break
        description = None
        if body is not None:
            text = body.text
            if name and text.startswith(name):
                # The source separates the bolded mode name from its
                # description with a dash, which belongs to neither field.
                text = _LEADING_SEPARATOR.sub("", text[len(name) :])
            description = text or None
        if name or description:
            practice_modes.append({"emoji": emoji, "name": name, "description": description})

    title_node = _first_by_class(tree, "collection-page-title")
    indicator = _text_by_class(tree, "collection-page-indicator")
    slug, page_number = _collection_slug_and_page(url)
    notes: list[str] = []
    if not items and _loading_placeholder(tree):
        # The rtk-* collections render their grid on the client, so the mirrored
        # html genuinely has no items. Say so rather than emitting a silent [].
        notes.append("item grid was client rendered and is absent from this snapshot")
    fields: dict[str, Any] = {
        "entry_kind": "collection",
        "slug": slug,
        "page_number": page_number,
        "page_indicator": indicator,
        "next_page_href": _next_page_href(tree),
        "name": meta.get("name") or _own_text(title_node),
        "description": meta.get("description") or _text_by_class(tree, "collection-page-desc"),
        "item_count": parse_int(_text_by_class(tree, "collection-page-count")),
        "items": items,
        "practice_modes": practice_modes,
        "see_also": [
            {"label": _node_text(node), "href": _attr(node, "href")}
            for node in _by_class(tree, "collection-seealso-link")
            if _attr(node, "href")
        ],
        "note": _text_by_class(tree, "collection-page-note"),
    }
    if notes:
        fields["parse_notes"] = notes
    if not fields["name"]:
        raise ValueError(f"no collection name found on {url}")
    return fields, {"description", "practice_modes", "note"}


def _parse_collection_index(tree: HtmlElement, url: str) -> tuple[dict[str, Any], set[str]]:
    cards: list[dict[str, Any]] = []
    for card in _by_class(tree, "collection-index-card"):
        title = _text_by_class(card, "collection-index-card-title", prefix=".//")
        if not title:
            continue
        cards.append(
            {
                "title": title,
                "badge": _text_by_class(card, "collection-index-badge", prefix=".//"),
                "description": _text_by_class(card, "collection-index-card-desc", prefix=".//"),
                "href": _attr(card, "href"),
            }
        )
    if not cards:
        raise ValueError(f"collection index carries no cards: {url}")
    return (
        {
            "entry_kind": "collection_index",
            "collections": cards,
            "description": _text_by_class(tree, "collection-index-desc"),
        },
        {"description"},
    )


def _parse_dictionary_index(tree: HtmlElement, url: str) -> tuple[dict[str, Any], set[str]]:
    """The dictionary landing page, kept for its upstream data credits."""
    credits_node = _first_by_class(tree, "home-credits")
    credits = [
        {"name": _node_text(link), "url": _attr(link, "href")}
        for link in (credits_node.xpath(".//a") if credits_node is not None else [])
        if _node_text(link)
    ]
    search_methods: list[dict[str, Any]] = []
    for node in _by_class(tree, "dict-intro-method"):
        name = _text_by_class(node, "dict-intro-method-name", prefix=".//")
        if not name:
            continue
        search_methods.append(
            {"name": name, "example": _text_by_class(node, "dict-intro-method-ex", prefix=".//")}
        )
    fields: dict[str, Any] = {
        "entry_kind": "dictionary_index",
        "upstream_credits": credits,
        "credits_text": _node_text(credits_node),
        "search_methods": search_methods,
        "collection_chips": _chip_links(tree, "dict-collection-chip"),
    }
    return fields, {"credits_text"}


_PARSERS = {
    PAGE_KANJI: _parse_kanji,
    PAGE_WORD: _parse_word,
    PAGE_DICTIONARY_KANA: _parse_dictionary_kana,
    PAGE_DICTIONARY_INDEX: _parse_dictionary_index,
    PAGE_KANA: _parse_kana,
    PAGE_KANA_INDEX: _parse_kana_index,
    PAGE_RADICAL: _parse_radical,
    PAGE_RADICAL_INDEX: _parse_radical_index,
    PAGE_COLLECTION: _parse_collection,
    PAGE_COLLECTION_INDEX: _parse_collection_index,
}


def _entity_key(page_type: str, fields: dict[str, Any], url: str) -> str | None:
    for name in ("character", "surface", "slug"):
        value = fields.get(name)
        if value:
            return str(value)
    if page_type == PAGE_RADICAL and fields.get("radical_number") is not None:
        return str(fields["radical_number"])
    segments = _path_segments(url)
    return _normalize_slug(segments[-1]) if segments else None


def parse(tree: HtmlElement, url: str, page_type: str) -> dict[str, Any]:
    """Extract one record. Raises on markup that does not match expectation."""
    parser = _PARSERS.get(page_type)
    if parser is None:
        raise ValueError(f"{SITE_ID} has no parser for page type {page_type!r}")

    working = _prepare(tree)
    fields, authored = parser(working, url)

    notes = list(fields.pop("parse_notes", []) or [])
    if page_type in DICTIONARY_ENTRY_TYPES or page_type in {PAGE_RADICAL, PAGE_RADICAL_INDEX}:
        unknown = sorted(set(preload_names(working)) - KNOWN_PRELOADS)
        if unknown:
            notes.append("unrecognised preloads: " + ", ".join(unknown))
        if not preload_names(working):
            notes.append("no preload json on this page, values came from the dom only")

    record: dict[str, Any] = {
        "page_type": page_type,
        "entity_key": _entity_key(page_type, fields, url),
        "dedupe_key": dedupe_key(url, page_type),
        "source_url": url,
    }
    record.update(fields)
    if notes:
        record["parse_notes"] = notes

    reserved = {"page_type", "entity_key", "dedupe_key", "source_url", "parse_notes"}
    factual = [name for name in record if name not in reserved and name not in authored]
    record["_provenance"] = build_provenance_map(
        source=SITE_ID,
        source_url=url,
        factual_fields=factual,
        authored_fields=[name for name in record if name in authored],
    )
    return record
