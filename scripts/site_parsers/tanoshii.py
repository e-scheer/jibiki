"""Parser for the mirrored www.tanoshiijapanese.com dictionary.

Route mix in the mirror (56719 successful HTML pages) decides what this site is
worth. It is a thin per-kanji source (1400 ``kanji_details.cfm``) but the
richest vocabulary and example-sentence corpus of the five mirrored sites:

===============================  ======  ==================================
route                            pages   what it carries
===============================  ======  ==================================
entry_details.cfm                18305   one full word entry
stroke_order_details.cfm         17387   word entry plus per-character strokes
conjugation_details.cfm          10670   word entry plus its conjugation table
sentence_details.cfm              4391   one sentence plus a word breakdown
index.cfm                         1524   up to 20 full word cards
kanji_details.cfm                 1400   one full kanji entry
kanji_stroke_order_details.cfm    1021   the same kanji entry plus strokes
kanji.cfm                          767   up to 20 full kanji cards
sentences.cfm                      719   up to 20 sentence pairs
browse.cfm                         529   up to 20 full word cards
===============================  ======  ==================================

So words and sentences are first class here: they are what populates the
example words and example sentences of a kanji. The list routes are not chrome,
they carry complete cards, which is why ``parse`` returns a list of records for
them (roughly 2271 kanji exist only as a ``kanji.cfm`` card, with no
``kanji_details`` page in the mirror).

Design notes, each answering a defect of the previous generation
----------------------------------------------------------------

* Every reading line is kept. The old code captured ``(.*?)<br/>`` and dropped
  every line after the first, losing 1000 of 1380 on'yomi blocks. Reading
  classification notes (``Jouyou Reading``, ``Go-on, Kan-on Readings``) are
  lifted out of the Japanese text before splitting, so the ASCII comma inside a
  note can no longer be mistaken for a reading separator.
* Text comes from the DOM helpers in :mod:`site_parsers.common`, never from a
  tag-stripping regex, so ``さくら。`` no longer becomes ``さくら 。`` and
  ``ヒトの雌`` no longer becomes ``ヒト の 雌``.
* Furigana never interleaves. ``ruby``/``rt`` is split off, and the purely
  decorative ``span.dl`` and ``ruby.desktop`` middot separators are removed, so
  a sentence reads ``実際のところ私が思っていたよりもずっと楽しかった。``
* Marked-up prose is emitted as ``RichText.to_json()``. ``span.minidictionary``
  marks linkable dictionary terms and carries the character-formation category
  in its ``definition`` attribute, so those boundaries are kept as role spans
  rather than flattened away.
* ``character_id`` is emitted on kanji, kanji_strokes and kanji card records,
  and ``entry_id`` on every word record, so the orchestrator can join a
  ``kanji_details`` record with the ``kanji_stroke_order_details`` record of the
  same character instead of reporting ``stroke_order_count == 0``.
* Nothing is swallowed. Unexpected markup raises :class:`TanoshiiParseError`.
  The one exception the site itself creates is its soft 404, an error card served
  with status 200, which ``is_shell`` recognises so a refetchable url is not
  booked as breakage.

What a word url selects
-----------------------

63 percent of the mirrored word pages carry ``element_id`` and/or
``conjugation_type_id``, and both change what the page renders as its headword.
``conjugation_details.cfm?entry_id=30193`` renders 持つ,
``...&element_id=41310&conjugation_type_id=28`` renders 持たなければ and
``...&conjugation_type_id=50`` renders 持たされます, all three under the same
``entry_id``. Likewise ``stroke_order_details.cfm?entry_id=52516`` renders 余 with
7 strokes and ``...&element_id=67064`` renders 餘 with 16.

Two consequences run through this module. ``dedupe_key`` treats those two
parameters as part of the entity's identity, because collapsing them made 512
different pages share one key and left the surviving record arbitrary. And every
word record states what it is showing: ``headword_element_id``,
``headword_is_inflected`` with the matched conjugation's type and label,
``requested_element_id`` / ``requested_conjugation_type_id`` and
``headword_is_entry_default_view``. Without them a consumer joining on
``entry_id`` reads an inflection as the lemma.

Licensing
---------

Factual dictionary data (stroke counts, readings, JLPT level, grade, jouyou
flag, radical decomposition, sprite references, EDICT/KANJIDIC gloss lists)
goes to ``factual_fields``. Authored third-party prose goes to
``authored_fields`` and is therefore stamped ``ship: "reference-only"``: the
curated example sentences, the Japanese editorial definitions, the
character-origin explanations and the WordNet-style synonym and category
definitions. The EDICT/KANJIDIC notice and the per-sentence Tatoeba
attribution are captured as explicit fields so the redistribution terms travel
with the data instead of hiding in a trailing paragraph.

Known source limitations, reported on the records themselves rather than
silently papered over: the site exposes only Kun'yomi and On'yomi, so nanori is
conflated into ``kun_readings``; there is no mnemonic, hint or frequency rank;
and stroke data is a raster CSS sprite sheet, so stroke geometry has to come
from a vector source elsewhere. ``source_limitations`` is a module constant, not
a parse result, so its provenance says ``module_constant`` rather than claiming
the dom parser, and the routing fields taken from the url say ``url_route``.

Source data quality is also reported rather than assumed. The reading spans of 17
of the 2420 mirrored kanji pages contain tokens that are not readings at all (行
is served as ``C、A、ゴウ、...``, 姐 lists ``名詞``, 杁 lists ``愛知県``), so
anything whose kana is not kana is quarantined in ``rejected_readings`` instead of
shipping as a factual on'yomi or kun'yomi.
"""

from __future__ import annotations

import copy
import re
import urllib.parse
from typing import Any

from lxml.html import HtmlElement

from .common import (
    RichText,
    build_provenance_map,
    is_kana,
    normalize_jlpt,
    normalize_text,
    parse_int,
    plain_text,
    rich_text,
    ruby_pairs,
    split_english_glosses,
    split_on_japanese_separators,
    text_or_none,
    unique_list,
)

SITE_ID = "tanoshii_japanese"


class TanoshiiParseError(RuntimeError):
    """Raised when a page does not have the markup its route promises."""


# --- page types ---------------------------------------------------------------

PAGE_KANJI = "kanji"
PAGE_KANJI_STROKES = "kanji_strokes"
PAGE_KANJI_CARD_LIST = "kanji_card_list"
PAGE_WORD = "word"
PAGE_WORD_STROKES = "word_strokes"
PAGE_WORD_CONJUGATION = "word_conjugation"
PAGE_WORD_CARD_LIST = "word_card_list"
PAGE_SENTENCE = "sentence"
PAGE_SENTENCE_CARD_LIST = "sentence_card_list"
PAGE_KANJI_BROWSE = "kanji_browse"
PAGE_COMMENTS = "comments"
PAGE_SEARCH_FORM = "search_form"
PAGE_OTHER = "other"

_ROUTE_PAGE_TYPES = {
    "kanji_details.cfm": PAGE_KANJI,
    "kanji_stroke_order_details.cfm": PAGE_KANJI_STROKES,
    "kanji.cfm": PAGE_KANJI_CARD_LIST,
    "entry_details.cfm": PAGE_WORD,
    "stroke_order_details.cfm": PAGE_WORD_STROKES,
    "conjugation_details.cfm": PAGE_WORD_CONJUGATION,
    "sentence_details.cfm": PAGE_SENTENCE,
    "index.cfm": PAGE_WORD_CARD_LIST,
    "browse.cfm": PAGE_WORD_CARD_LIST,
    "sentences.cfm": PAGE_SENTENCE_CARD_LIST,
    "kanji_browse.cfm": PAGE_KANJI_BROWSE,
    "entry_comments.cfm": PAGE_COMMENTS,
    "kanji_comments.cfm": PAGE_COMMENTS,
    "multi_search.cfm": PAGE_SEARCH_FORM,
    "multi_find.cfm": PAGE_SEARCH_FORM,
    "word_type_select.cfm": PAGE_SEARCH_FORM,
}

EXTRACTABLE = frozenset(
    {
        PAGE_KANJI,
        PAGE_KANJI_STROKES,
        PAGE_KANJI_CARD_LIST,
        PAGE_WORD,
        PAGE_WORD_STROKES,
        PAGE_WORD_CONJUGATION,
        PAGE_WORD_CARD_LIST,
        PAGE_SENTENCE,
        PAGE_SENTENCE_CARD_LIST,
    }
)

_WORD_DETAIL_TYPES = frozenset({PAGE_WORD, PAGE_WORD_STROKES, PAGE_WORD_CONJUGATION})

RECORD_KANJI = "kanji"
RECORD_WORD = "word"
RECORD_SENTENCE = "sentence"

# --- authored versus factual --------------------------------------------------

AUTHORED_FIELDS = frozenset(
    {
        "japanese_meanings",
        "origin",
        "origin_formation_type",
        "origin_terms",
        "sample_sentences",
        "sentence_japanese",
        "sentence_english",
        "sentence_furigana",
        "synonym_senses",
        "hyponyms",
        "user_comments",
    }
)

# Fields that are not read out of the page. ``source_limitations`` is a module
# constant about the site, and the routing fields come from the url, so neither
# may claim the dom parser as its method.
MODULE_CONSTANT_FIELDS = frozenset({"source_limitations"})
URL_DERIVED_FIELDS = frozenset(
    {
        "record_type",
        "page_type",
        "source_url",
        "dictionary_page",
        "list_route",
        "list_kind",
        "list_key",
        "page_number",
        "requested_element_id",
        "requested_conjugation_type_id",
    }
)

SOURCE_LIMITATIONS_KANJI = (
    "kun_readings conflate kun'yomi and nanori: the source labels only Kun'yomi and On'yomi",
    "no mnemonic, hint or frequency rank exists on this site",
    "stroke data is a raster CSS sprite sheet, so stroke geometry must come from a vector source",
)

# --- markup constants ---------------------------------------------------------

# span.minidictionary marks a linkable dictionary term inside Japanese prose,
# and span.relword / span.relcompound mark word boundaries inside a sentence.
# Keeping them as role spans is what stops the markup from being erased.
# Order matters: the first matching class fragment wins, and the class strings
# overlap (``relword minidictionary``, ``minidictionarykanji``).
TERM_CLASS_ROLES = {
    "minidictionarykanji": "kanji",
    "relcompound": "compound",
    "relword": "vocabulary",
    "minidictionary": "vocabulary",
}

_STROKE_SPRITE_RE = re.compile(r"url\(\s*([^)\s]+?)\s*\)")
_STROKE_OFFSET_RE = re.compile(r"background-position:\s*(-?\d+)em")
_STROKES_RE = re.compile(r"(\d+)\s*Strokes")
_RADICAL_RE = re.compile(r"^(?P<radical>.+?)\s*\+\s*(?P<residual>\d+)\s*Strokes$")
_WIKI_BOLD_RE = re.compile(r"'{2,}")
# Pitch-accent arrows the site inlines into kana, and the KANJIDIC parentheses
# that mark an optional part of the okurigana.
_PITCH_ACCENT_MARKS = "↗↘→↑↓"
_OPTIONAL_OKURIGANA_RE = re.compile(r"[（(]([^）)]*)[）)]")
_ELEMENT_TYPES = {"j": "kanji", "h": "hiragana", "k": "katakana", "v": "vocabulary", "s": "sentence"}
_LIST_QUERY_KEYS = ("k", "group_id", "concept_id", "grade", "jlpt_level", "is_jouyou", "word_definition_id", "j")


def _tok(cls: str) -> str:
    """XPath class-token test.

    ``contains(@class,'entry')`` is what made the old sentence parser iterate
    ``div.entrylinks``, and ``contains(@class,'romaji')`` is what pulled the
    ``displayromaji`` toggle label ``Hide`` into the romaji list of 4465
    records. Only exact tokens are ever matched here.
    """
    return f"contains(concat(' ',normalize-space(@class),' '),' {cls} ')"


def _by_class(node: HtmlElement, tag: str, cls: str, *, prefix: str = ".//") -> list[HtmlElement]:
    return node.xpath(f"{prefix}{tag}[{_tok(cls)}]")


def _first_by_class(node: HtmlElement, tag: str, cls: str, *, prefix: str = ".//") -> HtmlElement | None:
    found = _by_class(node, tag, cls, prefix=prefix)
    return found[0] if found else None


def _section(tree: HtmlElement, section_id: str) -> HtmlElement | None:
    found = tree.xpath(f"//*[@id='{section_id}']")
    return found[0] if found else None


def _content_body(tree: HtmlElement) -> HtmlElement | None:
    found = tree.xpath("//div[@id='cncontentbody']")
    return found[0] if found else None


# --- url handling -------------------------------------------------------------


def _split_url(url: str, *, fold_escaped_separators: bool = True) -> tuple[str, dict[str, list[str]]]:
    """Basename and query of a mirrored url.

    Some crawled urls carry the html-escaped separator, producing parameter
    names such as ``amp;element_id``. Folding them back is the defensive read
    used for the entity ids (``entry_id``, ``character_id``, ``sentence_id``),
    which are always the first parameter and therefore never escaped.

    It is the wrong read for the selection parameters. The server never received
    a parameter called ``element_id`` on those 40 urls, so it rendered the
    entry's default view: ``entry_details.cfm?entry_id=19621`` and
    ``entry_details.cfm?entry_id=19621&amp%3Belement_id=28795&amp%3Bconjugation_type_id=28``
    both render 楽しい, not the conjugated form. So the code that decides what a
    page rendered, and the code that names the entity it rendered, both read the
    query with ``fold_escaped_separators=False``.
    """
    split = urllib.parse.urlsplit(url)
    path = urllib.parse.unquote(split.path or "/")
    basename = path.rsplit("/", 1)[-1]
    raw_query = urllib.parse.parse_qs(split.query, keep_blank_values=True)
    query: dict[str, list[str]] = {}
    for key, values in raw_query.items():
        clean = key
        if fold_escaped_separators:
            while clean.lower().startswith("amp;"):
                clean = clean[4:]
        query.setdefault(clean, []).extend(values)
    return basename, query


def _query_value(query: dict[str, list[str]], key: str) -> str | None:
    values = query.get(key) or []
    for value in values:
        text = value.strip()
        if text:
            return text
    return None


def infer_page_type(url: str) -> str:
    basename, _ = _split_url(url)
    split = urllib.parse.urlsplit(url)
    path = urllib.parse.unquote(split.path or "/")
    if not path.startswith("/dictionary/"):
        return PAGE_OTHER
    return _ROUTE_PAGE_TYPES.get(basename.lower(), PAGE_OTHER)


def dedupe_key(url: str, page_type: str) -> str:
    """Identity of the entity a url renders.

    ``element_id`` and ``conjugation_type_id`` are part of that identity, not
    incidental: they change what the page renders as its headword.
    ``conjugation_details.cfm?entry_id=30193`` renders 持つ,
    ``...&element_id=41310&conjugation_type_id=28`` renders 持たなければ and
    ``...&conjugation_type_id=50`` renders 持たされます. Keying on ``entry_id``
    alone made 512 different pages share the key ``word:56851``, so which record
    survived deduplication was arbitrary.

    ``sentence_id`` alone is enough for the sentence route: over 40 random
    multi-hash sentence buckets the parsed record never differed, only the
    randomised sample-sentence block did. List routes keep their whole query,
    because the query is what selects the list.
    """
    basename, query = _split_url(url, fold_escaped_separators=False)
    if page_type in {PAGE_KANJI, PAGE_KANJI_STROKES}:
        key = _query_value(query, "character_id") or _query_value(query, "k") or ""
        return f"{page_type}:{key}"
    if page_type in _WORD_DETAIL_TYPES:
        parts = [_query_value(query, "entry_id") or ""]
        element = _query_value(query, "element_id")
        if element:
            parts.append(f"element={element}")
        conjugation = _query_value(query, "conjugation_type_id")
        if conjugation:
            parts.append(f"conjugation={conjugation}")
        return f"{page_type}:{':'.join(parts)}"
    if page_type == PAGE_SENTENCE:
        key = _query_value(query, "sentence_id") or ""
        return f"{page_type}:{key}"
    parts = []
    for name in sorted(query):
        for value in sorted(query[name]):
            parts.append(f"{name}={value.strip()}")
    return f"{basename.lower()}:{'&'.join(parts)}"


def is_shell(tree: HtmlElement, url: str) -> bool:
    """True when the mirrored file is not the page the url asked for.

    On this site a real page always has a ``<title>`` and a
    ``div#cncontentbody`` with content in it. A fragment endpoint such as
    ``word_type_select.cfm`` has neither, and a login wall would replace the
    content body with the sign-in form.

    The site also answers an unresolvable id with a status 200 page whose
    content body holds an error card instead of the entity, which is a soft 404:
    ``kanji_details.cfm?character_id=131490&k=%F0%A0%86%A2`` returns
    ``An invalid kanji was supplied (55360)``. It has a title and a non-empty
    content body, so it has to be recognised by its own marker, otherwise the
    caller books a refetchable url as parser breakage.
    """
    body = _content_body(tree)
    if body is None:
        return True
    if not plain_text(body):
        return True
    if not normalize_text(tree.xpath("string(//title)")):
        return True
    if body.xpath(".//form[@name='fLogin']|.//*[@id='idLoginRequired']"):
        return True
    if _is_soft_error(tree, body):
        return True
    return False


# The heading and the document title of the site's own error card. Matched on a
# prefix because the title appends the site name and the heading a bang.
_SOFT_ERROR_MARKER = "there was an error processing your request"


def _is_soft_error(tree: HtmlElement, body: HtmlElement) -> bool:
    if normalize_text(tree.xpath("string(//title)")).lower().startswith(_SOFT_ERROR_MARKER):
        return True
    for heading in body.xpath(".//h1|.//h2|.//h3|.//h4"):
        if plain_text(heading).strip().lower().startswith(_SOFT_ERROR_MARKER):
            return True
    return False


# --- small text helpers -------------------------------------------------------


def _term_rich_text(node: HtmlElement | None) -> RichText:
    return rich_text(node, class_roles=TERM_CLASS_ROLES)


def _detached(node: HtmlElement) -> HtmlElement:
    """Copy of a node with its tail dropped.

    The shared text helpers include the tail of the node they are given, which
    is what a document walk needs. When the node is an inline marker inside
    prose, its tail is the surrounding sentence, so extracting the marker's own
    text requires detaching it first.
    """
    clone = copy.deepcopy(node)
    clone.tail = None
    return clone


def _own_text(node: HtmlElement | None) -> str | None:
    if node is None:
        return None
    return text_or_none(_detached(node))


def _strip_wiki_bold(node: HtmlElement) -> HtmlElement:
    """Remove the site's literal ``'''`` emphasis markers from a copy.

    They are MediaWiki leftovers in the origin prose (14 of 207 non-empty
    values) and must not reach the text. Stripping them in the DOM rather than
    in the finished string keeps :class:`RichText` span offsets exact.
    """
    clone = copy.deepcopy(node)
    for element in clone.iter():
        if isinstance(element.tag, str) and element.text:
            element.text = _WIKI_BOLD_RE.sub("", element.text)
        if element.tail:
            element.tail = _WIKI_BOLD_RE.sub("", element.tail)
    return clone


def _without_decoration(node: HtmlElement) -> HtmlElement:
    """Copy of a Japanese node with purely visual delimiters removed.

    ``span.dl`` holds a middot between sentence words and ``span.bk`` holds the
    display brackets around a furigana reading. Both are chrome, and both used
    to end up inside the extracted Japanese string.
    """
    clone = copy.deepcopy(node)
    for junk in clone.xpath(f".//span[{_tok('dl')}]|.//span[{_tok('bk')}]"):
        tail = junk.tail
        parent = junk.getparent()
        if tail:
            previous = junk.getprevious()
            if previous is not None:
                previous.tail = (previous.tail or "") + tail
            else:
                parent.text = (parent.text or "") + tail
        parent.remove(junk)
    return clone


def _surface_text(node: HtmlElement | None) -> str | None:
    if node is None:
        return None
    return text_or_none(_without_decoration(node))


def _reading_text(node: HtmlElement | None) -> str | None:
    """Full kana reading of a ruby-annotated Japanese node.

    Substitutes each ruby base with its ``rt`` annotation, so
    ``<ruby><rb>実</rb><rt>じっ</rt></ruby><ruby><rb>際</rb><rt>さい</rt></ruby>のところ``
    yields ``じっさいのところ``. The decorative ``ruby.desktop`` separators have
    an empty base and a middot annotation, so they contribute nothing.
    """
    if node is None:
        return None
    clone = _without_decoration(node)
    parts: list[str] = []

    def walk(element: HtmlElement) -> None:
        tag = element.tag if isinstance(element.tag, str) else ""
        if tag in {"script", "style", "rp"}:
            return
        if tag == "ruby":
            annotation = normalize_text(
                "".join(rich_text(rt, keep_ruby_annotations=True).text for rt in element.findall("rt"))
            )
            annotation = annotation.replace("·", "").replace("・", "").strip()
            if annotation:
                parts.append(annotation)
            else:
                base = normalize_text(
                    (element.text or "")
                    + "".join(
                        plain_text(_detached(child))
                        for child in element
                        if child.tag not in {"rt", "rp"}
                    )
                )
                parts.append(base)
            if element.tail:
                parts.append(element.tail)
            return
        if element.text:
            parts.append(element.text)
        for child in element:
            walk(child)
        if element.tail:
            parts.append(element.tail)

    walk(clone)
    return normalize_text("".join(parts)) or None


def _romaji(node: HtmlElement | None) -> str | None:
    """Romaji of one element, read from ``div.romaji`` only.

    Never from ``//*[contains(@class,'romaji')]``, which also matches the
    ``span.value.displayromaji`` toggle whose label ``Hide`` became the first
    romaji of 4465 records.
    """
    if node is None:
        return None
    found = node.xpath(f"./div[{_tok('romaji')}]") or _by_class(node, "div", "romaji")
    return text_or_none(found[0]) if found else None


def _element_reference(node: HtmlElement) -> dict[str, Any]:
    """``element_type``/``element_id`` pair the site puts on its action widgets."""
    element_type = (node.get("element_type") or "").strip() or None
    element_id = parse_int(node.get("element_id"))
    character = None
    if element_type in {"j", "h", "k"} and element_id and 0x2E80 <= element_id <= 0x2FA1F:
        character = chr(element_id)
    return {
        "element_type": element_type,
        "element_kind": _ELEMENT_TYPES.get(element_type or ""),
        "element_id": element_id,
        "character": character,
    }


def _anchor_record(anchor: HtmlElement) -> dict[str, str | None] | None:
    """``{label, href}`` for a real link, ``None`` for a UI widget.

    ``<a href="#" onclick="fShowElementPopup(this)">Add to ▼</a>`` is the
    add-to-list popup, so it is chrome rather than an entity link. It used to be
    filtered on detail records and kept on card records (326 of 1361 links on
    ``browse.cfm`` cards), which made one field name carry two different kinds of
    thing depending on the route that produced it.
    """
    href = (anchor.get("href") or "").strip()
    if not href or href == "#" or href.lower().startswith("javascript:"):
        return None
    return {"label": _own_text(anchor), "href": href}


def _links(node: HtmlElement | None, *, prefix: str = ".//") -> list[dict[str, str | None]]:
    """``{label, href}`` records for every anchor of a links block.

    Always one record per anchor. Calling ``text_content()`` on the container is
    what produced ``"Kanji Details »Stroke Order Diagrams »Comments »"`` as a
    single label with no hrefs at all.
    """
    if node is None:
        return []
    records: list[dict[str, str | None]] = []
    for anchor in node.xpath(f"{prefix}div[{_tok('entrylinks')}]//a|{prefix}span[{_tok('entrylinks')}]//a"):
        record = _anchor_record(anchor)
        if record is not None:
            records.append(record)
    return unique_list(records)


def _page_links(tree: HtmlElement) -> list[dict[str, str | None]]:
    """Every navigational link of a detail page, one record per anchor.

    A detail page describes exactly one entity, so page scope and card scope
    are the same thing, and the links blocks that matter sit outside the
    headword card (in the stroke-order and dictionary-entry sections). Comment
    threads are excluded: they are forum chrome, not entity data.
    """
    body = _content_body(tree)
    if body is None:
        return []
    records: list[dict[str, str | None]] = []
    for block in _by_class(body, "div", "entrylinks"):
        if block.xpath("ancestor-or-self::*[@id='idComments']"):
            continue
        for anchor in block.xpath(".//a"):
            record = _anchor_record(anchor)
            if record is not None:
                records.append(record)
    return unique_list(records)


def _query_of_href(href: str | None, key: str) -> str | None:
    if not href:
        return None
    query = urllib.parse.parse_qs(urllib.parse.urlsplit(href).query, keep_blank_values=True)
    for name, values in query.items():
        clean = name
        while clean.lower().startswith("amp;"):
            clean = clean[4:]
        if clean != key:
            continue
        for value in values:
            text = urllib.parse.unquote(value).strip()
            if text:
                return text
    return None


def _content_licence(tree: HtmlElement) -> dict[str, str | None] | None:
    """The EDICT/KANJIDIC notice, as a labelled field rather than a stray paragraph."""
    for paragraph in tree.xpath("//p[.//a[contains(@href,'edrdg.org/edrdg/licence')]]"):
        return {
            "notice": text_or_none(paragraph),
            "licence_url": paragraph.xpath("string(.//a[contains(@href,'edrdg.org/edrdg/licence')]/@href)") or None,
        }
    return None


# --- readings -----------------------------------------------------------------


def _reading_note(node: HtmlElement) -> tuple[str, str | None]:
    """Classification label of a reading line and its ``definition`` key."""
    label = plain_text(node).strip()
    if label.startswith("(") and label.endswith(")"):
        label = label[1:-1].strip()
    key = (node.get("definition") or "").strip() or None
    if key is None:
        for nested in node.xpath(".//*[@definition]"):
            key = (nested.get("definition") or "").strip() or None
            if key:
                break
    return label, key


def _reading_lines(info: HtmlElement) -> list[tuple[str, str | None, str | None]]:
    """Split a reading ``span.info`` into ``(japanese, label, label_key)`` lines.

    The whole span is consumed, not just its first ``<br/>``-delimited line, and
    each line's trailing ``span.note`` is lifted out before the Japanese text is
    split. Both matter: 1000 of 1380 on'yomi spans hold more than one line, and
    the note ``(Go-on, Kan-on Readings)`` contains an ASCII comma that used to
    be read as a reading separator.
    """
    lines: list[tuple[str, str | None, str | None]] = []
    buffer: list[str] = []
    label: str | None = None
    label_key: str | None = None

    def flush() -> None:
        nonlocal buffer, label, label_key
        text = normalize_text("".join(buffer))
        if text or label:
            lines.append((text, label, label_key))
        buffer = []
        label = None
        label_key = None

    if info.text:
        buffer.append(info.text)
    for child in info:
        tag = child.tag if isinstance(child.tag, str) else ""
        classes = (child.get("class") or "").split()
        if tag == "br":
            flush()
            if child.tail:
                buffer.append(child.tail)
            continue
        if "note" in classes:
            label, label_key = _reading_note(child)
        else:
            buffer.append(plain_text(child))
        if child.tail:
            buffer.append(child.tail)
    flush()
    return lines


def _normalize_reading(raw: str) -> dict[str, Any]:
    """Split a KANJIDIC-style reading into its parts.

    ``い.きる`` is a stem plus okurigana, ``-う`` is a suffix reading and
    ``なま-`` a prefix reading. The old parser emitted all of them as
    undifferentiated kun readings.

    Two further annotations travel inside the kana on this site and must not be
    left inside ``reading`` or ``kana``, which are the fields a consumer matches
    on: the pitch-accent arrows of 地 (``ジ↗``, ``つ↗ち↘``) and the optional
    okurigana parentheses of 代 (``か.(わ)る``). Both are lifted into their own
    field, and ``raw`` keeps the source token verbatim so nothing is lost.
    """
    text = raw.strip()
    affix = None
    if text.startswith("-"):
        affix = "suffix"
    elif text.endswith("-"):
        affix = "prefix"
    core = text.strip("-")
    pitch_accent = core if any(ch in _PITCH_ACCENT_MARKS for ch in core) else None
    core = "".join(ch for ch in core if ch not in _PITCH_ACCENT_MARKS)
    optional_match = _OPTIONAL_OKURIGANA_RE.search(core)
    optional_okurigana = (optional_match.group(1) or None) if optional_match else None
    core = _OPTIONAL_OKURIGANA_RE.sub(r"\1", core)
    stem, _, okurigana = core.partition(".")
    prefix = "-" if affix == "suffix" else ""
    suffix = "-" if affix == "prefix" else ""
    return {
        "raw": text,
        "reading": f"{prefix}{core}{suffix}",
        "kana": core.replace(".", ""),
        "stem": stem or None,
        "okurigana": okurigana or None,
        "affix": affix,
        "optional_okurigana": optional_okurigana,
        "pitch_accent": pitch_accent,
    }


def _readings(card: HtmlElement) -> dict[str, list[dict[str, Any]]]:
    """On'yomi and kun'yomi lists, with every non-kana token quarantined.

    The reading spans of this site are not clean. 行 really is served as
    ``<span class="info">C、A、ゴウ、...``, 姐 lists ``名詞`` and ``姉`` among its
    kun'yomi, 区 lists ``熟字訓`` and 杁 lists ``愛知県``. Those are source
    defects, and 17 of the 2420 mirrored kanji pages carry at least one. Shipping
    them as ``factual`` readings would put ``C`` on the reading side of an N5
    jouyou kanji, so anything whose kana is not kana goes to
    ``rejected_readings`` instead, where it stays visible without being usable as
    a reading.
    """
    out: dict[str, list[dict[str, Any]]] = {
        "kun_readings": [],
        "on_readings": [],
        "rejected_readings": [],
    }
    for block in _by_class(card, "div", "reading"):
        heading = _first_by_class(block, "span", "heading")
        kind_key = None
        if heading is not None:
            definitions = heading.xpath(".//*[@definition]")
            if definitions:
                kind_key = (definitions[0].get("definition") or "").strip() or None
        info = _first_by_class(block, "span", "info")
        if info is None:
            continue
        field = {"kunyomi": "kun_readings", "onyomi": "on_readings"}.get(kind_key or "")
        if field is None:
            raise TanoshiiParseError(f"unknown reading block definition {kind_key!r}")
        for line_index, (japanese, label, label_key) in enumerate(_reading_lines(info)):
            for raw in split_on_japanese_separators(japanese):
                entry = _normalize_reading(raw)
                entry["classification"] = label
                entry["classification_key"] = label_key
                entry["line_index"] = line_index
                if not is_kana(entry["kana"]):
                    out["rejected_readings"].append(
                        {
                            "field": field,
                            "raw": entry["raw"],
                            "reason": "not_kana",
                            "classification": label,
                            "classification_key": label_key,
                            "line_index": line_index,
                        }
                    )
                    continue
                out[field].append(entry)
    return out


# --- stroke sprites -----------------------------------------------------------


def _stroke_group_reference(ul: HtmlElement) -> dict[str, Any]:
    """Identity of the character a ``ul.stroke-order`` group belongs to.

    The group's own markup does not name it. The following siblings do, up to
    the next group: a hidden ``list_ids_<id>`` input and a links block whose
    action widget carries ``element_type``/``element_id``. On a word page those
    ids are the only per-character key, and they include the kana, which is the
    site's only per-kana stroke source.
    """
    fallback: dict[str, Any] | None = None
    for sibling in ul.itersiblings():
        tag = sibling.tag if isinstance(sibling.tag, str) else ""
        if tag == "ul" and "stroke-order" in (sibling.get("class") or "").split():
            break
        for node in sibling.xpath(".//*[@element_id and @element_type]|self::*[@element_id and @element_type]"):
            reference = _element_reference(node)
            if reference["element_id"]:
                return reference
        if fallback is None and tag == "input" and (sibling.get("name") or "").startswith("list_ids_"):
            element_id = parse_int((sibling.get("name") or "").rsplit("_", 1)[-1])
            if element_id:
                fallback = {
                    "element_type": None,
                    "element_kind": None,
                    "element_id": element_id,
                    "character": chr(element_id) if 0x2E80 <= element_id <= 0x2FA1F else None,
                }
    if fallback is not None:
        return fallback
    return {"element_type": None, "element_kind": None, "element_id": None, "character": None}


def _stroke_groups(scope: HtmlElement) -> list[dict[str, Any]]:
    """Per-character stroke groups, with the sprite reference kept.

    Tanoshii has no vector stroke data, only a raster sprite sheet with one
    ``background-position`` per stroke, so the sprite url and the offsets are
    the only stroke payload it can contribute. A word page opens each group with
    an ``0em`` frame showing the finished character, so counting every ``<li>``
    over-counts by one per group (19 instead of 16 for 楽しい); only non-zero
    offsets are strokes.
    """
    groups: list[dict[str, Any]] = []
    for ul in _by_class(scope, "ul", "stroke-order"):
        sprite: str | None = None
        offsets: list[int] = []
        frame_count = 0
        for item in ul.findall("li"):
            style = " ".join((div.get("style") or "") for div in item.findall("div"))
            frame_count += 1
            sprite_match = _STROKE_SPRITE_RE.search(style)
            if sprite_match and sprite is None and "images/standard/" in sprite_match.group(1):
                sprite = sprite_match.group(1)
            offset_match = _STROKE_OFFSET_RE.search(style)
            if offset_match:
                offset = int(offset_match.group(1))
                if offset:
                    offsets.append(offset)
        reference = _stroke_group_reference(ul)
        character = reference["character"]
        element_type = reference["element_type"]
        if sprite:
            # ../images/standard/<j|h|k>/<codepoint>.png names both the script
            # and the character, so it recovers the identity of a group whose
            # action widget is missing.
            parts = sprite.split("/")
            if element_type is None and len(parts) >= 2 and parts[-2] in _ELEMENT_TYPES:
                element_type = parts[-2]
            codepoint = parse_int(parts[-1])
            if character is None and codepoint and 0x2E80 <= codepoint <= 0x2FA1F:
                character = chr(codepoint)
        groups.append(
            {
                "character": character,
                "element_type": element_type,
                "element_kind": _ELEMENT_TYPES.get(element_type or ""),
                "element_id": reference["element_id"],
                "sprite_url": sprite,
                "stroke_count": len(offsets),
                "frame_count": frame_count,
                "stroke_offsets_em": offsets,
            }
        )
    return groups


# --- kanji cards --------------------------------------------------------------


def _kanji_profile_values(card: HtmlElement) -> dict[str, Any]:
    """``Stroke Count`` and ``Radical`` from the label/value span pairs."""
    values: dict[str, Any] = {
        "stroke_count": None,
        "radical": None,
        "radical_residual_strokes": None,
    }
    for info_block in _by_class(card, "div", "kanjiinfo"):
        pending_key: str | None = None
        for span in info_block.xpath("./span"):
            classes = (span.get("class") or "").split()
            text = plain_text(span).strip()
            if "heading" in classes:
                definition = (span.get("definition") or "").strip()
                if definition == "radicals" or text.lower().startswith("radical"):
                    pending_key = "radical"
                elif text.lower().startswith("stroke count"):
                    pending_key = "stroke_count"
                else:
                    pending_key = None
                continue
            if "info" not in classes or pending_key is None:
                continue
            if pending_key == "stroke_count":
                match = _STROKES_RE.search(text)
                values["stroke_count"] = int(match.group(1)) if match else None
            else:
                match = _RADICAL_RE.match(text)
                if match:
                    values["radical"] = match.group("radical").strip() or None
                    values["radical_residual_strokes"] = int(match.group("residual"))
                else:
                    values["radical"] = text or None
            pending_key = None
    return values


def _kanji_classification(card: HtmlElement) -> dict[str, Any]:
    jlpt = None
    for anchor in card.xpath(f".//a[{_tok('jlpt')}]"):
        jlpt = normalize_jlpt(plain_text(anchor).replace("JLPT Level", "").strip())
        if jlpt:
            break
    kyouiku = _first_by_class(card, "span", "kyouiku")
    is_jouyou: bool | None = None
    grade: int | None = None
    if kyouiku is not None:
        is_jouyou = bool(kyouiku.xpath(".//a[contains(@href,'is_jouyou=Y')]"))
        for anchor in kyouiku.xpath(".//a[contains(@href,'grade=')]"):
            grade = parse_int(_query_of_href(anchor.get("href"), "grade"))
            break
    return {"jlpt_level": jlpt, "is_jouyou": is_jouyou, "grade": grade}


def _kanji_card(card: HtmlElement) -> dict[str, Any]:
    """One ``div.kanji`` card: identical markup on detail pages and on kanji.cfm."""
    image = _first_by_class(card, "div", "kanjiimg")
    if image is None:
        raise TanoshiiParseError("kanji card without div.kanjiimg")
    character = plain_text(image).strip() or None
    sprite = None
    sprite_match = _STROKE_SPRITE_RE.search(image.get("style") or "")
    if sprite_match and "images/standard/" in sprite_match.group(1):
        sprite = sprite_match.group(1)

    character_id: int | None = None
    for node in card.xpath(".//*[@element_id and @element_type='j']"):
        character_id = parse_int(node.get("element_id"))
        if character_id:
            break
    if character_id is None:
        for anchor in card.xpath(".//a[contains(@href,'kanji_details.cfm')]"):
            character_id = parse_int(_query_of_href(anchor.get("href"), "character_id"))
            if character_id:
                break

    gloss_nodes = card.xpath(f".//ol[{_tok('en')}]/li")
    gloss_text = normalize_text("; ".join(plain_text(node) for node in gloss_nodes))
    record: dict[str, Any] = {
        "character": character,
        "character_id": character_id,
        "kanji_sprite_url": sprite,
        "english_meanings": split_english_glosses(gloss_text),
        "english_meaning_text": gloss_text or None,
    }
    record.update(_kanji_profile_values(card))
    record.update(_kanji_classification(card))
    record.update(_readings(card))
    record["entry_links"] = _links(card)
    return record


# --- word cards ---------------------------------------------------------------


def _senses(container: HtmlElement) -> list[dict[str, Any]]:
    """Pair each ``span.partofspeech`` with the ``<ol>`` that follows it.

    Two independent document-wide lists cannot be realigned afterwards: on 791
    of 1155 multi-sense records the deduped part-of-speech list and the gloss
    list have incompatible lengths. A gloss's nested ``span.partofspeech`` is a
    sense note, not a part of speech, and is kept as a note.

    One group is a part-of-speech group, not one sense: the ``<ol start>`` of
    entry 32894 (ところ) goes 1, 2, 9 because the second group holds seven
    ``<li>``. So the group carries the range it spans and every gloss carries the
    site's own sense number, instead of a single ``sense_no`` that silently meant
    the number of the group's first sense.
    """
    senses: list[dict[str, Any]] = []
    current_pos: str | None = None
    for child in container:
        tag = child.tag if isinstance(child.tag, str) else ""
        classes = (child.get("class") or "").split()
        if tag == "span" and "partofspeech" in classes:
            current_pos = plain_text(child).strip() or None
            continue
        if tag != "ol":
            continue
        glosses: list[dict[str, Any]] = []
        for item in child.findall("li"):
            clone = copy.deepcopy(item)
            notes: list[str] = []
            for note in clone.xpath(f".//span[{_tok('partofspeech')}]"):
                label = plain_text(note).strip()
                if label.startswith("(") and label.endswith(")"):
                    label = label[1:-1].strip()
                if label:
                    notes.append(label)
                tail = note.tail
                parent = note.getparent()
                if tail:
                    previous = note.getprevious()
                    if previous is not None:
                        previous.tail = (previous.tail or "") + tail
                    else:
                        parent.text = (parent.text or "") + tail
                parent.remove(note)
            gloss = plain_text(clone).strip()
            if not gloss and not notes:
                continue
            glosses.append(
                {
                    "gloss": gloss or None,
                    "terms": [part.strip() for part in gloss.split(";") if part.strip()],
                    "notes": notes,
                }
            )
        if not glosses:
            continue
        start = parse_int(child.get("start"))
        if start is None:
            start = senses[-1]["sense_no_end"] + 1 if senses else 1
        for offset, gloss in enumerate(glosses):
            gloss["sense_no"] = start + offset
        senses.append(
            {
                "sense_no_start": start,
                "sense_no_end": start + len(glosses) - 1,
                "part_of_speech": current_pos,
                "glosses": glosses,
            }
        )
    return senses


def _word_elements(entry_block: HtmlElement) -> list[dict[str, Any]]:
    """Every written form of an entry, keyed on ``element_id``.

    Iterating ``div.furigana`` instead of ``div.jmdelement`` dropped every
    kana-only form (398 of 1565 word pages had no form at all), kept the
    ``[ ]`` display brackets, inlined the ruby reading-first and lost the
    ``Outdated Kanji`` / ``Irregular Reading`` annotations plus the
    Alternate-Written-Forms grouping.

    ``is_alternate`` is relative to the rendered view, not to the entry: the site
    hoists the selected written form to the top and files the others under
    ``Alternate Written Forms:``, so on
    ``stroke_order_details.cfm?entry_id=52516&element_id=67064`` it is 餘 that is
    primary and 余 that is alternate. ``headword_is_entry_default_view`` on the
    record says whether that ordering is the entry's own.
    """
    elements: list[dict[str, Any]] = []
    is_alternate = False
    for child in entry_block.iter():
        tag = child.tag if isinstance(child.tag, str) else ""
        if tag == "h4" and plain_text(child).strip().lower().startswith("alternate written form"):
            is_alternate = True
            continue
        if tag != "div" or "jmdelement" not in (child.get("class") or "").split():
            continue
        japanese = _first_by_class(child, "div", "jp")
        furigana = _first_by_class(child, "div", "furigana")
        surface = _surface_text(japanese)
        reading = _reading_text(japanese) or _surface_text(furigana)
        if reading is None and surface is not None:
            reading = surface
        elements.append(
            {
                "element_id": parse_int(child.get("element_id")),
                "surface": surface,
                "reading": reading,
                "romaji": _romaji(child),
                "furigana": ruby_pairs(_without_decoration(japanese)) if japanese is not None else [],
                "part_of_speech": text_or_none(_first_by_class(child, "div", "partofspeech")),
                "annotation": text_or_none(_first_by_class(child, "div", "elementinfo")),
                "is_alternate": is_alternate,
                "detail_href": (
                    child.xpath(f"string(.//div[{_tok('link')}]//a/@href)") or None
                ),
            }
        )
    return elements


def _matched_conjugations(card: HtmlElement) -> list[dict[str, Any]]:
    """The ``Matched Conjugations:`` rows a search-match view puts on its card.

    Their presence is the site's own statement that the card's headword is an
    inflection rather than the dictionary form: the card of
    ``conjugation_details.cfm?entry_id=30193&element_id=41310&conjugation_type_id=28``
    renders 持たなければ while the entry is 持つ, and the English block of that
    same page carries the warning that the readings are in the provisional
    present indicative negative form while the meanings are the dictionary
    form's. The block is absent when the url selects no conjugation and when it
    selects the dictionary form (``conjugation_type_id=1``), which is why this is
    read off the page instead of off the query string.
    """
    rows: list[dict[str, Any]] = []
    for block in _by_class(card, "div", "conjugations"):
        for node in _by_class(block, "div", "jmdelement"):
            rows.append(_conjugation_row(node))
    return rows


def _vocabulary_card(card: HtmlElement) -> dict[str, Any]:
    """One ``div.vocabulary`` card.

    The same card markup is reused on ``entry_details``, on the vocabulary list
    of a sentence page, on the ``Dictionary Entries`` block of a kanji page and
    on every ``browse.cfm`` / ``index.cfm`` result page, so one parser serves
    all of them.

    ``surface``, ``reading`` and ``romaji`` are what this card renders, which is
    not always the entry's lemma, so the selection is recorded next to them:
    ``headword_element_id`` names the written form that was rendered and
    ``headword_is_inflected`` says whether it is a conjugated form of the entry.
    Without those a consumer joining on ``entry_id`` would read 持たなければ as
    the dictionary form of 持つ.
    """
    entry_id = parse_int(card.get("entry_id"))
    entry_block = _first_by_class(card, "div", "jmdentry")
    if entry_block is None:
        entry_block = card
    elements = _word_elements(entry_block)
    english = _first_by_class(card, "div", "en")
    senses = _senses(english) if english is not None else []
    headword = elements[0] if elements else None
    matched = _matched_conjugations(card)
    record: dict[str, Any] = {
        "entry_id": entry_id,
        "surface": headword["surface"] if headword else None,
        "reading": headword["reading"] if headword else None,
        "romaji": headword["romaji"] if headword else None,
        "headword_part_of_speech": headword["part_of_speech"] if headword else None,
        "headword_element_id": headword["element_id"] if headword else None,
        "headword_is_inflected": bool(matched),
        "headword_conjugation_type_id": matched[0]["conjugation_type_id"] if matched else None,
        "headword_conjugation_label": matched[0]["label"] if matched else None,
        "matched_conjugations": matched,
        "elements": elements,
        "senses": senses,
        "english_meanings": unique_list(
            gloss["gloss"] for sense in senses for gloss in sense["glosses"] if gloss["gloss"]
        ),
        "sense_parts_of_speech": unique_list(sense["part_of_speech"] for sense in senses),
    }
    return record


def _card_links(card: HtmlElement) -> list[dict[str, str | None]]:
    """Links of a card, which live in a sibling block, not inside the card."""
    records = _links(card)
    for sibling in card.itersiblings():
        tag = sibling.tag if isinstance(sibling.tag, str) else ""
        if tag == "div" and "vocabulary" in (sibling.get("class") or "").split():
            break
        if tag == "div" and "entrylinks" in (sibling.get("class") or "").split():
            for anchor in sibling.xpath(".//a"):
                record = _anchor_record(anchor)
                if record is not None:
                    records.append(record)
    return unique_list(records)


# --- tables -------------------------------------------------------------------


def _kanji_meanings(tree: HtmlElement) -> list[dict[str, Any]]:
    """``Meanings for each kanji`` rows, typed instead of a cell array.

    The ``»`` anchor is chrome, and its href is the only place the row's
    ``character_id`` appears.
    """
    section = _section(tree, "idKanjiMeanings")
    if section is None:
        return []
    rows: list[dict[str, Any]] = []
    for row in section.xpath(".//tr"):
        cells = row.xpath("./td")
        if not cells:
            continue
        character_id = None
        for anchor in row.xpath(".//a[contains(@href,'kanji_details.cfm')]"):
            character_id = parse_int(_query_of_href(anchor.get("href"), "character_id"))
            break
        japanese = _first_by_class(row, "td", "jp", prefix="./")
        meaning_cells = [cell for cell in cells if cell is not japanese and not cell.xpath("./a")]
        rows.append(
            {
                "character": _own_text(japanese),
                "character_id": character_id,
                "meaning": _own_text(meaning_cells[-1]) if meaning_cells else None,
            }
        )
    return [row for row in rows if row["character"] or row["meaning"]]


def _definition_table(tree: HtmlElement, section_id: str) -> list[dict[str, Any]]:
    """``idSynonyms`` and ``idHyponyms`` share one three-row-per-sense layout.

    The old code gave ``idHyponyms`` the untyped extractor, so the Japanese and
    English halves of one category became unrelated rows and the
    ``Show all words in category »`` link became a content row while its
    ``word_definition_id`` was dropped.
    """
    section = _section(tree, section_id)
    if section is None:
        return []
    senses: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for row in section.xpath(".//tr"):
        classes = (row.get("class") or "").split()
        cells = row.xpath("./td")
        texts = [_own_text(cell) for cell in cells]
        if "jp" in classes:
            current = {
                "index": parse_int(texts[0]) if texts else None,
                "jp": texts[1] if len(texts) > 1 else None,
                "jp_gloss": texts[2] if len(texts) > 2 else None,
                "en": None,
                "en_gloss": None,
                "synonyms": [],
                "category_id": None,
            }
            senses.append(current)
            continue
        if current is None:
            continue
        if "en" in classes:
            current["en"] = texts[1] if len(texts) > 1 else None
            current["en_gloss"] = texts[2] if len(texts) > 2 else None
            continue
        if "syn" in classes:
            current["synonyms"] = [
                {"surface": _own_text(span), "entry_id": parse_int(span.get("entry_id"))}
                for span in row.xpath(f".//span[{_tok('minidictionary')}]")
            ]
            continue
        for anchor in row.xpath(".//a[contains(@href,'word_definition_id')]"):
            current["category_id"] = parse_int(_query_of_href(anchor.get("href"), "word_definition_id"))
            break
    return senses


def _sentence_cards(scope: HtmlElement) -> list[dict[str, Any]]:
    """Curated example sentences: ``div.sentence`` blocks with a jp/en pair.

    ``japanese`` is a ``RichText`` payload, like the sentence detail route emits,
    because these blocks carry the same ``span.relword`` and
    ``span.minidictionary`` term markup: 7 of 547 cards over 40 random
    ``sentences.cfm`` pages do, and a bare string drops the role spans that the
    interface asks marked-up prose to preserve.
    """
    sentences: list[dict[str, Any]] = []
    for block in _by_class(scope, "div", "sentence"):
        japanese = _first_by_class(block, "div", "jp")
        english = _first_by_class(block, "div", "en")
        if japanese is None and english is None:
            continue
        # The detail link sits inside the block on a word page and in a sibling
        # block on a sentences.cfm result page, so both places are searched.
        candidates = list(block.xpath(".//a[contains(@href,'sentence_details.cfm')]"))
        identifiers = list(block.xpath(".//*[@element_type='s' and @element_id]"))
        for sibling in block.itersiblings():
            tag = sibling.tag if isinstance(sibling.tag, str) else ""
            if tag == "div" and "sentence" in (sibling.get("class") or "").split():
                break
            candidates.extend(sibling.xpath(".//a[contains(@href,'sentence_details.cfm')]"))
            identifiers.extend(sibling.xpath(".//*[@element_type='s' and @element_id]"))
        href = candidates[0].get("href") if candidates else None
        sentence_id = parse_int(_query_of_href(href, "sentence_id")) if href else None
        if sentence_id is None and identifiers:
            sentence_id = parse_int(identifiers[0].get("element_id"))
        if sentence_id is None and japanese is not None:
            # The already-selected sentence of a result page has no detail link,
            # but its div.jp id is JS<sentence_id>.
            element_id = (japanese.get("id") or "").strip()
            if element_id.startswith("JS"):
                sentence_id = parse_int(element_id[2:])
        sentences.append(
            {
                "sentence_id": sentence_id,
                "japanese": (
                    _term_rich_text(_without_decoration(japanese)).to_json()
                    if japanese is not None
                    else None
                ),
                "furigana": ruby_pairs(_without_decoration(japanese)) if japanese is not None else [],
                "english": text_or_none(english),
                "detail_href": href,
            }
        )
    return sentences


def _user_comments(tree: HtmlElement) -> list[dict[str, Any]]:
    """Forum comments, attributed instead of interleaved with entity data.

    The generic ``//p`` collector mixed the boilerplate, the author lines and a
    genuinely useful learner explanation of 楽しい versus 嬉しい into one
    undifferentiated paragraph array. These are user-authored, so they are
    reference-only.
    """
    section = _section(tree, "idComments")
    if section is None:
        return []
    comments: list[dict[str, Any]] = []
    for block in _by_class(section, "div", "messagecomment"):
        body = _first_by_class(block, "div", "body")
        info = _first_by_class(block, "div", "info")
        author = None
        author_id = None
        posted_at = None
        relative_time = None
        if info is not None:
            for node in info.xpath(f".//span[{_tok('name')}]"):
                author = _own_text(node)
                author_id = parse_int(node.get("user_id"))
                break
            for node in info.xpath(".//utc"):
                posted_at = (node.get("datetime") or "").strip() or None
                relative_time = _own_text(node)
                break
        comment_no = None
        if info is not None:
            match = re.search(r"#(\d+)", plain_text(info))
            if match:
                comment_no = int(match.group(1))
        payload = _term_rich_text(_detached(body)).to_json() if body is not None else None
        if payload is None and author is None:
            continue
        comments.append(
            {
                "comment_no": comment_no,
                "author": author,
                "author_user_id": author_id,
                "posted_at": posted_at,
                "relative_time": relative_time,
                "body": payload,
            }
        )
    return comments


def _related_groups(tree: HtmlElement) -> list[dict[str, Any]]:
    """``idRelatedKanji`` heading/list pairs, with the group label kept.

    The characters already leaked into a generic paragraph array as 248
    single-character strings; what was missing is which group each run belongs
    to, because the labels are ``div.heading`` and no xpath collected them.
    """
    section = _section(tree, "idRelatedKanji")
    if section is None:
        return []
    groups: list[dict[str, Any]] = []
    pending: dict[str, Any] | None = None
    for child in section:
        tag = child.tag if isinstance(child.tag, str) else ""
        classes = (child.get("class") or "").split()
        if tag == "div" and "heading" in classes:
            href = child.xpath("string(./a/@href)") or None
            kind = None
            key = None
            for candidate in ("concept_id", "group_id", "k"):
                value = _query_of_href(href, candidate)
                if value:
                    kind, key = candidate, value
                    break
            pending = {"label": text_or_none(child), "kind": kind, "key": key, "href": href, "characters": []}
            continue
        if tag == "ul" and pending is not None:
            pending["characters"] = unique_list(
                _own_text(node) for node in child.xpath(f".//span[{_tok('minidictionarykanji')}]/p")
            )
            groups.append(pending)
            pending = None
    return groups


def _other_language_meanings(tree: HtmlElement) -> list[dict[str, Any]]:
    """Per-language gloss lists, keyed by their language heading.

    Seeded content is language-scoped in this project, so a French gloss must
    never arrive as an unlabelled string next to an English one.
    """
    section = _section(tree, "idOtherLanguageMeanings")
    if section is None:
        return []
    out: list[dict[str, Any]] = []
    language: str | None = None
    for child in section:
        tag = child.tag if isinstance(child.tag, str) else ""
        classes = (child.get("class") or "").split()
        if tag == "div" and "heading" in classes:
            language = text_or_none(child)
            continue
        if tag == "ol" and language:
            glosses: list[str] = []
            for item in child.findall("li"):
                text = plain_text(item).strip()
                glosses.extend(split_english_glosses(text))
            out.append({"language": language, "glosses": glosses})
            language = None
    return out


def _character_construction(tree: HtmlElement) -> dict[str, Any]:
    """Radical and part decomposition, variants and the origin prose."""
    section = _section(tree, "idCharacterConstruction")
    result: dict[str, Any] = {
        "construction": [],
        "variants": [],
        "origin": None,
        "origin_formation_type": None,
        "origin_terms": [],
    }
    if section is None:
        return result
    heading: str | None = None
    for child in section:
        tag = child.tag if isinstance(child.tag, str) else ""
        classes = (child.get("class") or "").split()
        if tag == "div" and "heading" in classes:
            heading = (text_or_none(child) or "").lower()
            continue
        if tag == "table" and heading and heading.startswith("radicals and parts"):
            for row in child.xpath("./tr|./tbody/tr"):
                cells = row.xpath("./td")
                if len(cells) < 3:
                    continue
                character_id = None
                for anchor in row.xpath(".//a[contains(@href,'kanji_details.cfm')]"):
                    character_id = parse_int(_query_of_href(anchor.get("href"), "character_id"))
                    break
                result["construction"].append(
                    {
                        "symbol": _own_text(cells[1]),
                        "character_id": character_id,
                        "role": _own_text(cells[2]),
                        "meaning": _own_text(cells[3]) if len(cells) > 3 else None,
                    }
                )
            continue
        if tag == "table" and heading and heading.startswith("kanji variants"):
            for row in child.xpath("./tr|./tbody/tr"):
                cells = row.xpath("./td")
                if len(cells) < 3:
                    continue
                result["variants"].append(
                    {"symbol": _own_text(cells[1]), "description": _own_text(cells[2])}
                )
            continue
        if tag == "ol" and heading and heading.startswith("origin and construction"):
            items = child.findall("li")
            if not items:
                continue
            stripped = _strip_wiki_bold(items[0])
            origin = _term_rich_text(stripped)
            result["origin"] = origin.to_json()
            for span in items[0].xpath(f".//span[{_tok('minidictionary')}]"):
                definition = (span.get("definition") or "").strip()
                if definition and result["origin_formation_type"] is None:
                    result["origin_formation_type"] = definition
                term = _own_text(span) or ""
                if term:
                    result["origin_terms"].append(term)
            result["origin_terms"] = unique_list(result["origin_terms"])
    return result


def _japanese_meanings(tree: HtmlElement) -> list[dict[str, Any]]:
    section = _section(tree, "idJapaneseMeaning")
    if section is None:
        return []
    out: list[dict[str, Any]] = []
    for item in section.xpath(f".//ol[{_tok('jp')}]/li"):
        payload = _term_rich_text(_strip_wiki_bold(item)).to_json()
        if payload:
            out.append(payload)
    return out


# --- list context -------------------------------------------------------------


def _list_context(tree: HtmlElement, url: str) -> dict[str, Any]:
    basename, query = _split_url(url)
    kind = None
    key = None
    for candidate in _LIST_QUERY_KEYS:
        value = _query_value(query, candidate)
        if value:
            kind, key = candidate, urllib.parse.unquote(value)
            break
    return {
        "list_route": basename,
        "list_kind": kind,
        "list_key": key,
        "list_label": normalize_text(tree.xpath("string((//h1)[1])")) or None,
        "page_number": parse_int(_query_value(query, "p")) or 1,
    }


# --- records ------------------------------------------------------------------


def _base_record(record_type: str, page_type: str, url: str) -> dict[str, Any]:
    basename, _ = _split_url(url)
    return {
        "record_type": record_type,
        "page_type": page_type,
        "source_url": url,
        "dictionary_page": basename,
    }


def _finish(record: dict[str, Any], url: str) -> dict[str, Any]:
    names = [name for name in record if not name.startswith("_")]
    record["_provenance"] = build_provenance_map(
        source=SITE_ID,
        source_url=url,
        factual_fields=[name for name in names if name not in AUTHORED_FIELDS],
        authored_fields=[name for name in names if name in AUTHORED_FIELDS],
    )
    for name in names:
        # Not everything on a record was read out of the page. Saying so in the
        # method keeps a module constant and a routing field from reading like
        # parsed data.
        if name in MODULE_CONSTANT_FIELDS:
            record["_provenance"][name]["method"] = "module_constant"
        elif name in URL_DERIVED_FIELDS:
            record["_provenance"][name]["method"] = "url_route"
    return record


def _kanji_detail_record(tree: HtmlElement, url: str, page_type: str) -> dict[str, Any]:
    cards = tree.xpath("//div[@class='kanji']")
    if not cards:
        raise TanoshiiParseError("kanji page without a div.kanji card")
    _, query = _split_url(url)
    record = _base_record(RECORD_KANJI, page_type, url)
    record.update(_kanji_card(cards[0]))
    if record["character_id"] is None:
        record["character_id"] = parse_int(_query_value(query, "character_id"))
    record["japanese_meanings"] = _japanese_meanings(tree)
    record.update(_character_construction(tree))
    if record["radical"] is None:
        for part in record["construction"]:
            if (part.get("role") or "").lower() == "radical":
                record["radical"] = part.get("symbol")
                break
    record["radical_summary"] = (
        f"{record['radical']} + {record['radical_residual_strokes']} Strokes"
        if record["radical"] and record["radical_residual_strokes"] is not None
        else record["radical"]
    )
    record["entry_links"] = _page_links(tree)
    record["related_groups"] = _related_groups(tree)
    record["other_language_meanings"] = _other_language_meanings(tree)

    strokes_section = _section(tree, "idStrokeOrderDiagrams")
    groups = _stroke_groups(strokes_section) if strokes_section is not None else []
    record["stroke_order_groups"] = groups
    record["stroke_order_count"] = groups[0]["stroke_count"] if groups else None
    record["stroke_sprite_url"] = groups[0]["sprite_url"] if groups else record["kanji_sprite_url"]

    entries_section = _section(tree, "idDictionaryEntry")
    record["example_words"] = []
    if entries_section is not None:
        for card in _by_class(entries_section, "div", "vocabulary"):
            word = _vocabulary_card(card)
            word["entry_links"] = _card_links(card)
            record["example_words"].append(word)
    record["source_limitations"] = list(SOURCE_LIMITATIONS_KANJI)
    record["user_comments"] = _user_comments(tree)
    record["content_licence"] = _content_licence(tree)
    return _finish(record, url)


def _kanji_card_list_records(tree: HtmlElement, url: str) -> list[dict[str, Any]]:
    context = _list_context(tree, url)
    records: list[dict[str, Any]] = []
    licence = _content_licence(tree)
    for rank, card in enumerate(tree.xpath("//div[@class='kanji']"), start=1):
        record = _base_record(RECORD_KANJI, PAGE_KANJI_CARD_LIST, url)
        record.update(_kanji_card(card))
        record.update(context)
        record["list_rank"] = rank
        record["source_limitations"] = list(SOURCE_LIMITATIONS_KANJI)
        record["content_licence"] = licence
        records.append(_finish(record, url))
    return records


def _word_detail_record(tree: HtmlElement, url: str, page_type: str) -> dict[str, Any]:
    _, query = _split_url(url)
    body = _content_body(tree)
    cards = _by_class(body, "div", "vocabulary") if body is not None else []
    if not cards:
        raise TanoshiiParseError("word page without a div.vocabulary card")
    record = _base_record(RECORD_WORD, page_type, url)
    record.update(_vocabulary_card(cards[0]))
    if record["entry_id"] is None:
        record["entry_id"] = parse_int(_query_value(query, "entry_id"))

    # What the url asked the server to select, read with the escaped separator
    # left alone so that a parameter the server never saw is not reported as a
    # selection. 63 percent of the mirrored word pages select something, and the
    # selection is what decides whether ``surface`` is the entry's lemma.
    _, requested = _split_url(url, fold_escaped_separators=False)
    record["requested_element_id"] = parse_int(_query_value(requested, "element_id"))
    record["requested_conjugation_type_id"] = parse_int(
        _query_value(requested, "conjugation_type_id")
    )
    record["headword_is_entry_default_view"] = (
        record["requested_element_id"] is None and not record["headword_is_inflected"]
    )

    english_section = _section(tree, "idEnglishMeaning")
    if english_section is not None:
        english_cards = _by_class(english_section, "div", "vocabulary")
        if english_cards:
            merged = _vocabulary_card(english_cards[0])
            if merged["senses"]:
                record["senses"] = merged["senses"]
                record["english_meanings"] = merged["english_meanings"]
                record["sense_parts_of_speech"] = merged["sense_parts_of_speech"]

    record["entry_links"] = _page_links(tree)
    record["kanji_links"] = unique_list(
        {
            "label": _own_text(anchor),
            "href": anchor.get("href"),
            "character_id": parse_int(_query_of_href(anchor.get("href"), "character_id")),
        }
        for anchor in tree.xpath("//a[contains(@href,'kanji_details.cfm')]")
    )
    record["kanji_meanings"] = _kanji_meanings(tree)
    record["synonym_senses"] = _definition_table(tree, "idSynonyms")
    record["hyponyms"] = _definition_table(tree, "idHyponyms")

    samples_section = _section(tree, "idSampleSentences")
    record["sample_sentences"] = _sentence_cards(samples_section) if samples_section is not None else []

    strokes_section = _section(tree, "idStrokeOrderDiagrams")
    groups = _stroke_groups(strokes_section) if strokes_section is not None else []
    record["stroke_order_groups"] = groups
    record["stroke_order_total"] = sum(group["stroke_count"] for group in groups) if groups else None
    record["character_ids"] = unique_list(
        group["element_id"] for group in groups if group["element_type"] == "j" and group["element_id"]
    )
    record["kana_stroke_characters"] = unique_list(
        group["character"] for group in groups if group["element_type"] in {"h", "k"} and group["character"]
    )

    if page_type == PAGE_WORD_CONJUGATION:
        record["conjugations"] = _conjugations(tree)
    record["user_comments"] = _user_comments(tree)
    record["content_licence"] = _content_licence(tree)
    return _finish(record, url)


def _conjugation_row(node: HtmlElement, group: str | None = None) -> dict[str, Any]:
    """One ``div.jmdelement`` of a conjugation table or of a matched-form block.

    ``element_id`` and ``conjugation_type_id`` fall back to the row's own
    ``detail_href``, because the site omits the attributes on some rows while the
    link still carries them: on ``conjugation_details.cfm?entry_id=19621`` the
    ``Present Indicative Form`` row has no ``conjugation_type_id`` attribute and
    an href ending in ``conjugation_type_id=1``. 55 of 4646 rows over 60 random
    pages were affected.
    """
    japanese = _first_by_class(node, "div", "jp")
    detail_href = node.xpath(f"string(.//div[{_tok('link')}]//a/@href)") or None
    element_id = parse_int(node.get("element_id"))
    if element_id is None:
        element_id = parse_int(_query_of_href(detail_href, "element_id"))
    conjugation_type_id = parse_int(node.get("conjugation_type_id"))
    if conjugation_type_id is None:
        conjugation_type_id = parse_int(_query_of_href(detail_href, "conjugation_type_id"))
    return {
        "group": group,
        "label": text_or_none(_first_by_class(node, "div", "conjugation")),
        "surface": _surface_text(japanese),
        "reading": _reading_text(japanese),
        "romaji": _romaji(node),
        "element_id": element_id,
        "conjugation_type_id": conjugation_type_id,
        "part_of_speech": (node.get("part_of_speech") or "").strip().strip("&;") or None,
        "detail_href": detail_href,
    }


def _conjugations(tree: HtmlElement) -> list[dict[str, Any]]:
    section = _section(tree, "idConjugations")
    if section is None:
        return []
    rows: list[dict[str, Any]] = []
    group: str | None = None
    for node in section.iter():
        tag = node.tag if isinstance(node.tag, str) else ""
        if tag != "div":
            continue
        classes = (node.get("class") or "").split()
        if "conjugationgroup" in classes:
            group = text_or_none(node)
            continue
        if "jmdelement" not in classes:
            continue
        rows.append(_conjugation_row(node, group))
    return rows


def _word_card_list_records(tree: HtmlElement, url: str) -> list[dict[str, Any]]:
    context = _list_context(tree, url)
    body = _content_body(tree)
    if body is None:
        raise TanoshiiParseError("word list page without a content body")
    licence = _content_licence(tree)
    records: list[dict[str, Any]] = []
    for rank, card in enumerate(_by_class(body, "div", "vocabulary"), start=1):
        record = _base_record(RECORD_WORD, PAGE_WORD_CARD_LIST, url)
        record.update(_vocabulary_card(card))
        record["entry_links"] = _card_links(card)
        record.update(context)
        record["list_rank"] = rank
        record["content_licence"] = licence
        records.append(_finish(record, url))
    return records


def _source_attribution(tree: HtmlElement) -> dict[str, Any] | None:
    """Per-sentence Tatoeba credit, which lives in a quicklinks block.

    No generic collector reached it, so it was absent from all 306 sentence
    records even though 305 of them carry it in the raw html. The site
    misspells the project name, so the raw label is kept next to a normalised
    one.
    """
    for anchor in tree.xpath(f"//span[{_tok('quicklinks')}]//a[{_tok('value')}]"):
        label = _own_text(anchor)
        normalized = label
        if label and label.lower().replace("totoeba", "tatoeba") != label.lower():
            normalized = re.sub(r"[Tt]otoeba", "Tatoeba", label)
        return {"label": label, "name": normalized, "href": anchor.get("href")}
    return None


def _sentence_words(tree: HtmlElement) -> list[dict[str, Any]]:
    section = _section(tree, "idVocabularyElements")
    if section is None:
        return []
    words: list[dict[str, Any]] = []
    for card in _by_class(section, "div", "vocabulary"):
        word = _vocabulary_card(card)
        word["entry_links"] = _card_links(card)
        words.append(word)
    return words


def _sentence_record(tree: HtmlElement, url: str) -> dict[str, Any]:
    _, query = _split_url(url)
    body = _content_body(tree)
    blocks = _by_class(body, "div", "sentence") if body is not None else []
    if not blocks:
        raise TanoshiiParseError("sentence page without a div.sentence block")
    block = blocks[0]
    japanese = _first_by_class(block, "div", "jp")
    english = _first_by_class(block, "div", "en")
    if japanese is None:
        raise TanoshiiParseError("sentence block without a div.jp")

    sentence_id = parse_int(_query_value(query, "sentence_id"))
    if sentence_id is None:
        sentence_id = parse_int((japanese.get("id") or "").lstrip("JS"))

    record = _base_record(RECORD_SENTENCE, PAGE_SENTENCE, url)
    record["sentence_id"] = sentence_id
    record["sentence_japanese"] = _term_rich_text(_without_decoration(japanese)).to_json()
    record["sentence_english"] = text_or_none(english)
    record["sentence_furigana"] = ruby_pairs(_without_decoration(japanese))
    record["source_attribution"] = _source_attribution(tree)
    record["sentence_words"] = _sentence_words(tree)
    record["word_entry_ids"] = unique_list(
        parse_int(node.get("entry_id")) for node in japanese.xpath(".//span[@entry_id]")
    )
    record["content_licence"] = _content_licence(tree)
    return _finish(record, url)


def _sentence_card_list_records(tree: HtmlElement, url: str) -> list[dict[str, Any]]:
    context = _list_context(tree, url)
    body = _content_body(tree)
    if body is None:
        raise TanoshiiParseError("sentence list page without a content body")
    licence = _content_licence(tree)
    records: list[dict[str, Any]] = []
    for rank, card in enumerate(_sentence_cards(body), start=1):
        record = _base_record(RECORD_SENTENCE, PAGE_SENTENCE_CARD_LIST, url)
        record["sentence_id"] = card["sentence_id"]
        record["sentence_japanese"] = card["japanese"]
        record["sentence_english"] = card["english"]
        record["sentence_furigana"] = card["furigana"]
        record["detail_href"] = card["detail_href"]
        record.update(context)
        record["list_rank"] = rank
        record["content_licence"] = licence
        records.append(_finish(record, url))
    return records


def parse(tree: HtmlElement, url: str, page_type: str) -> dict[str, Any] | list[dict[str, Any]]:
    if page_type in {PAGE_KANJI, PAGE_KANJI_STROKES}:
        return _kanji_detail_record(tree, url, page_type)
    if page_type == PAGE_KANJI_CARD_LIST:
        return _kanji_card_list_records(tree, url)
    if page_type in {PAGE_WORD, PAGE_WORD_STROKES, PAGE_WORD_CONJUGATION}:
        return _word_detail_record(tree, url, page_type)
    if page_type == PAGE_WORD_CARD_LIST:
        return _word_card_list_records(tree, url)
    if page_type == PAGE_SENTENCE:
        return _sentence_record(tree, url)
    if page_type == PAGE_SENTENCE_CARD_LIST:
        return _sentence_card_list_records(tree, url)
    raise TanoshiiParseError(f"page type {page_type!r} is not extractable for {SITE_ID}")
