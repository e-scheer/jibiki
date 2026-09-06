"""Parser for mirrored www.kanshudo.com pages.

Replaces ``parse_site_snapshots.parse_kanshudo`` plus the kanshudo branches of
``extract_mirrored_content`` (``parse_kanshudo_word_page``,
``parse_kanshudo_component_page``, ``parse_kanshudo_draw_page`` and the generic
collectors). Everything here is DOM-scoped: the old code windowed raw HTML with
regexes and then flattened tags to spaces, which truncated multi-value rows,
fused sibling sections together and destroyed the okurigana markup that carries
meaning on this site.

Kanshudo specifics that shape the design
----------------------------------------

* The kanji detail page is a ``div.grid.gkanji`` of ``div.g-row`` rows whose
  first cell is a label ("Common readings", "Components", "Variants", "Notes",
  "See also", "Additional data"). Rows are located by that label cell, never by
  a byte window, so a row cannot leak into the next one.
* Every reading row embeds a hidden help panel plus inline scripts between the
  label and the readings. Japanese sample text inside that panel (for instance
  "行く is read as いく") would be harvested as fake readings, so chrome nodes
  are skipped structurally while their tails are kept, because the readings
  themselves are a tail of the last chrome node.
* Readings inside a row are separated by two non-breaking spaces, and okurigana
  is marked with a grey inline span (Kanshudo documents this convention in its
  own help text). Both the stem and the okurigana are kept, plus the dictionary
  form from the search link when there is one.
* The site emits no ``rel=canonical`` and was crawled with several query-string
  permutations per url, so ``dedupe_key`` works from the query-stripped
  unquoted path. ``/component_details`` and ``/component_details/joyo_components``
  serve the same document and are aliased onto one key.
* ``/kanji/draw/<char>`` is deliberately not a page type: those mirror files are
  gone, they were login-gated widget shells, and their only per-character datum
  (the stroke-order svg url) is on the ``/kanji/<char>`` page.
* ``/kanji/<char>`` is served for characters far outside the kanji blocks:
  Bopomofo letters used as kanji variants, halfwidth katakana, enclosed and
  squared ideographs, one private-use glyph. They carry the same markup as any
  character page, so they are routed by the script of the slug and the script
  itself is recorded rather than assumed.
* Jukugo group headers are prose, not a fixed template: the count is singular for
  one word and the group is sometimes not a reading at all ("Part of a
  non-standard reading"). A header that cannot be read must clear the current
  group, because carrying the previous one forward files words under a reading
  they do not have.
* The Notes cell of a kanji page is mostly Joy o' Kanji chrome: a download
  prompt, two rows of links into the essay collection, and a whole thematic
  bundle advert. Only the essay note and the grey-background radical note are
  content.
* Containers are emitted as None when the page carries nothing for them, so a
  fill rate over ``references``, ``usage`` or ``cascading_components`` counts
  data instead of counting the container.

Licensing: Kanshudo's mnemonics and hints, its editorial radical notes and its
proprietary usefulness metric are authored third-party content and are declared
as ``authored_fields`` so provenance marks them reference-only. Stroke counts,
readings, JLPT levels, grades, component decompositions and reference numbers
are facts and stay shippable.
"""

from __future__ import annotations

import copy
import re
import urllib.parse
from typing import Any, Iterable, Iterator

from lxml.html import HtmlElement

from . import common
from .common import (
    build_provenance_map,
    normalize_jlpt,
    parse_int,
    plain_text,
    rich_text,
    unique_list,
)

SITE_ID = "kanshudo"

PAGE_KANJI = "kanji"
PAGE_KANA = "kana"
PAGE_RADICAL = "radical"
PAGE_WORD = "word"
PAGE_COMPONENT_INDEX = "component_index"
PAGE_COLLECTION_INDEX = "collection_index"
PAGE_COLLECTION_SET = "collection_set"
PAGE_OTHER = "other"

EXTRACTABLE = frozenset(
    {
        PAGE_KANJI,
        PAGE_KANA,
        PAGE_RADICAL,
        PAGE_WORD,
        PAGE_COMPONENT_INDEX,
        PAGE_COLLECTION_INDEX,
        PAGE_COLLECTION_SET,
    }
)

CHARACTER_PAGES = frozenset({PAGE_KANJI, PAGE_KANA, PAGE_RADICAL})

# Utility routes that share the /kanji/<slug> and /word/<slug> shapes. They are
# not entities and previously became phantom records keyed by the raw slug.
RESERVED_KANJI_SLUGS = frozenset(
    {"draw", "mastery", "studyset", "wheel", "search", "index", "kanjimastery"}
)
RESERVED_WORD_SLUGS = frozenset({"addcard", "search_advanced", "search", "mastery", "index"})
RESERVED_COLLECTION_SLUGS = frozenset({"view", "summarize", "playmenu", "download", "print"})

COMPONENT_COLLECTION_ALIASES = {"": "joyo_components", "joyo_components": "joyo_components"}

# --- small DOM utilities ------------------------------------------------------

_HIDDEN_STYLE = re.compile(r"display\s*:\s*none", re.IGNORECASE)
_GREY_STYLE = re.compile(r"color\s*:\s*(?:#828282|#7b7b7b|darkgray|gray|grey)", re.IGNORECASE)
_DARKGRAY_STYLE = re.compile(r"color\s*:\s*darkgray", re.IGNORECASE)
_ITALIC_STYLE = re.compile(r"font-style\s*:\s*italic", re.IGNORECASE)

_NON_CONTENT_TAGS = frozenset(
    {
        "script",
        "style",
        "noscript",
        "template",
        "svg",
        "iframe",
        "button",
        "input",
        "select",
        "textarea",
        "audio",
        "canvas",
        "head",
    }
)

# Overlay panels, help popups, spinners and login-warning shells. All of them
# carry visible-looking prose that has nothing to do with the entity.
_CHROME_CLASSES = frozenset(
    {
        "cover",
        "fav_container",
        "help",
        "helpinline",
        "helpinlinemessage",
        "helptext",
        "kajax",
        "jr_details",
        "linkbuttondiv",
        "namessage",
        "ssc_container",
        "tatdd",
        "w_image",
        "w_panel",
        "w_text",
        "w_title",
        "warning",
        "x-hide",
    }
)

# Two non-breaking spaces (optionally padded with ordinary whitespace) separate
# the values inside a reading row. The cascading view uses three.
_NBSP_SEPARATOR = re.compile("[\\s ]* [\\s ]* [\\s ]*")
_LEADING_READING = re.compile(r"^\s*[-‐ー]?[ぁ-ゟァ-ヺーヽヾ]+-?")
_KATAKANA_ONLY = re.compile(r"^[ァ-ヺーヽヾ]+$")
_IDEOGRAPHIC_DESCRIPTION = re.compile(r"[⿰-⿿]")
_SVG_URL = re.compile(r"(https://kanshudo\.s3\.amazonaws\.com/svg/([0-9a-f]+)\.svg)")
_INT_WITH_COMMAS = re.compile(r"-?[\d,]+")


def _class_tokens(node: HtmlElement) -> frozenset[str]:
    value = node.get("class")
    if not value:
        return frozenset()
    return frozenset(value.split())


def _is_chrome(node: HtmlElement) -> bool:
    """True for nodes that are never entity content."""
    tag = node.tag if isinstance(node.tag, str) else ""
    if tag in _NON_CONTENT_TAGS:
        return True
    if not tag:  # comments and processing instructions
        return True
    node_id = node.get("id") or ""
    if node_id.endswith("_help") or node_id.startswith("k_spin_") or node_id.startswith("jk_spinner_"):
        return True
    if _HIDDEN_STYLE.search(node.get("style") or ""):
        return True
    return bool(_class_tokens(node) & _CHROME_CLASSES)


def _pruned(el: HtmlElement, extra_classes: Iterable[str] = ()) -> HtmlElement:
    """Deep copy with chrome subtrees removed but their tails preserved.

    The copy's own tail is cleared: ``common.rich_text`` appends the tail of the
    node it is given, so without this a label span would swallow the value that
    follows it (which is exactly how the reading label came out as "Name まと").
    """
    clone = copy.deepcopy(el)
    clone.tail = None
    extra = frozenset(extra_classes)
    for node in list(clone.iter()):
        if node is clone:
            continue
        parent = node.getparent()
        if parent is None:
            continue
        if not (_is_chrome(node) or (_class_tokens(node) & extra)):
            continue
        _drop_keeping_tail(node)
    return clone


def _drop_keeping_tail(node: HtmlElement) -> None:
    parent = node.getparent()
    if parent is None:
        return
    tail = node.tail
    if tail:
        previous = node.getprevious()
        if previous is not None:
            previous.tail = (previous.tail or "") + tail
        else:
            parent.text = (parent.text or "") + tail
    parent.remove(node)


def _squash(el: HtmlElement | None) -> str:
    """Text of a subtree with all whitespace removed.

    Used for Japanese runs (word surfaces, furigana) where any whitespace in the
    markup is indentation, never content.
    """
    if el is None:
        return ""
    return re.sub(r"\s+", "", "".join(el.itertext()))


def _own_text(el: HtmlElement | None) -> str:
    """Text of an element, excluding its tail.

    ``common.rich_text`` emits the tail of the node it is handed, which is right
    when recursing but wrong for a standalone element: a label span would then
    absorb the value printed after it.
    """
    if el is None:
        return ""
    clone = copy.deepcopy(el)
    clone.tail = None
    return plain_text(clone)


def _one_line(value: str | None) -> str | None:
    """Collapse a prose scalar onto one line.

    The markup wraps sentences across several source lines, which the text
    normaliser preserves as newlines. That is right for multi-paragraph blocks
    and wrong for a single sentence such as an attribution line.
    """
    if not value:
        return None
    return re.sub(r"\s+", " ", value).strip() or None


def _text(el: HtmlElement | None) -> str | None:
    if el is None:
        return None
    return plain_text(_pruned(el)) or None


# --- rich text helpers --------------------------------------------------------
#
# The module interface requires every field that came from marked-up prose to be
# emitted as the json form of a ``common.RichText``, so the role spans markup
# carried survive. Kanshudo happens to carry no role markup inside its prose
# today, so these spans lists come out empty, but the offsets are computed from
# the real subtree rather than asserted, so the day a ``<mark>`` or a
# ``title="Reading"`` appears it is preserved instead of silently flattened.


def _collapsed(source: common.RichText) -> common.RichText:
    """One-line rendering of a RichText, with span offsets rebased.

    The scalar prose fields on this site are wrapped across several source lines,
    which the text normaliser keeps as newlines. Collapsing the plain string
    without moving the spans would leave every offset pointing at the wrong
    characters, so the rewrite carries an index map.
    """
    chars: list[str] = []
    mapping: list[int] = []
    previous_space = False
    for character in source.text:
        if character.isspace():
            mapping.append(len(chars))
            if previous_space:
                continue
            chars.append(" ")
            previous_space = True
            continue
        mapping.append(len(chars))
        chars.append(character)
        previous_space = False
    mapping.append(len(chars))
    flat = "".join(chars)
    lead = len(flat) - len(flat.lstrip())
    text = flat.strip()

    def rebase(index: int) -> int:
        position = mapping[min(index, len(source.text))] - lead
        return max(0, min(position, len(text)))

    spans: list[common.TextSpan] = []
    for span in source.spans:
        start, end = rebase(span.start), rebase(span.end)
        if end <= start:
            continue
        spans.append(common.TextSpan(text=text[start:end], role=span.role, start=start, end=end))
    return common.RichText(text, spans)


def _slice_rich(source: common.RichText, start: int, end: int) -> common.RichText:
    """Sub-RichText of ``source[start:end]``, whitespace trimmed, spans rebased."""
    fragment = source.text[start:end]
    lead = len(fragment) - len(fragment.lstrip())
    trail = len(fragment) - len(fragment.rstrip())
    start, end = start + lead, end - trail
    text = source.text[start:end]
    spans: list[common.TextSpan] = []
    for span in source.spans:
        begin, finish = max(span.start, start), min(span.end, end)
        if finish <= begin:
            continue
        spans.append(
            common.TextSpan(
                text=source.text[begin:finish],
                role=span.role,
                start=begin - start,
                end=finish - start,
            )
        )
    return common.RichText(text, spans)


def _rich_of(el: HtmlElement | None, extra_classes: Iterable[str] = ()) -> common.RichText:
    """RichText of a subtree with chrome pruned and the node's own tail dropped."""
    if el is None:
        return common.RichText("")
    return rich_text(_pruned(el, extra_classes))


def _rich_line(el: HtmlElement | None, extra_classes: Iterable[str] = ()) -> dict[str, Any] | None:
    """Json RichText of a subtree, collapsed onto one line."""
    return _collapsed(_rich_of(el, extra_classes)).to_json()


def _joined_rich(segments: list[dict[str, Any] | None]) -> dict[str, Any] | None:
    """Join json RichText fragments with "; ", rebasing their spans."""
    text_parts: list[str] = []
    spans: list[common.TextSpan] = []
    for segment in segments:
        if not segment or not segment.get("text"):
            continue
        offset = sum(len(part) for part in text_parts) + 2 * len(text_parts)
        for span in segment.get("spans") or []:
            spans.append(
                common.TextSpan(
                    text=span["text"],
                    role=span["role"],
                    start=span["start"] + offset,
                    end=span["end"] + offset,
                )
            )
        text_parts.append(segment["text"])
    return common.RichText("; ".join(text_parts), spans).to_json()


def _rich_own_line(el: HtmlElement | None) -> dict[str, Any] | None:
    """Json RichText of a subtree with nothing removed but the node's own tail."""
    if el is None:
        return None
    clone = copy.deepcopy(el)
    clone.tail = None
    return _collapsed(rich_text(clone)).to_json()


def _first(nodes: list[HtmlElement]) -> HtmlElement | None:
    return nodes[0] if nodes else None


def _clean_href(href: str | None) -> str | None:
    """Drop the incidental query kanshudo appends to internal links.

    Search links are the exception: their ``q`` parameter is the whole target
    (``/searchq?q=%E6%9C%AC``), so their query is kept.
    """
    if not href:
        return None
    split = urllib.parse.urlsplit(href)
    path = urllib.parse.unquote(split.path)
    query = split.query if path.startswith("/search") else ""
    if split.netloc:
        return urllib.parse.urlunsplit((split.scheme, split.netloc, path, query, ""))
    return urllib.parse.urlunsplit(("", "", path, query, "")) or None


def _link(node: HtmlElement) -> dict[str, Any]:
    href = node.get("href")
    link: dict[str, Any] = {"surface": _one_line(_own_text(node)), "href": _clean_href(href)}
    target = _query_value(href, "q")
    if target:
        link["target"] = urllib.parse.unquote(target)
    return link


def _query_value(href: str | None, key: str) -> str | None:
    if not href:
        return None
    query = urllib.parse.urlsplit(href).query
    for name, value in urllib.parse.parse_qsl(query, keep_blank_values=True):
        if name == key:
            return value
    return None


def _int_from(value: str | None) -> int | None:
    if value is None:
        return None
    match = _INT_WITH_COMMAS.search(value)
    if not match:
        return None
    digits = match.group(0).replace(",", "")
    try:
        return int(digits)
    except ValueError:
        return None


def _badge_level(scope: HtmlElement, prefix: str) -> int | None:
    """Read a ``ja-<prefix>_<n>`` badge class, scoped to one row."""
    pattern = re.compile(rf"\bja-{re.escape(prefix)}_(\d+)\b")
    for node in scope.iter():
        if not isinstance(node.tag, str):
            continue
        match = pattern.search(node.get("class") or "")
        if match:
            return int(match.group(1))
    return None


# --- page routing -------------------------------------------------------------


def _script_of(character: str) -> str | None:
    """Script of a one-character page slug.

    Kanshudo serves a full character page for shapes well outside the kanji
    blocks: Bopomofo letters used as kanji variants ("ㄋ means 'three'"),
    halfwidth katakana, enclosed and squared ideographs (㈱, 🈚) and a private-use
    glyph. They carry an h1, a ``div.kdetails2`` and a stroke-order animator like
    any other character page, so returning None here dropped 20 real pages.
    """
    code = ord(character)
    if 0x3041 <= code <= 0x309F:
        return "hiragana"
    if 0x30A0 <= code <= 0x30FF or 0x31F0 <= code <= 0x31FF or 0xFF66 <= code <= 0xFF9F:
        return "katakana"
    if 0x2E80 <= code <= 0x2EFF or 0x2F00 <= code <= 0x2FDF or 0x31C0 <= code <= 0x31EF:
        return "radical"
    if 0x3105 <= code <= 0x312F:
        return "bopomofo"
    if 0x3200 <= code <= 0x32FF or 0x1F200 <= code <= 0x1F2FF:
        return "enclosed_cjk"
    if 0xE000 <= code <= 0xF8FF or 0xF0000 <= code <= 0xFFFFD or 0x100000 <= code <= 0x10FFFD:
        return "private_use"
    if (
        0x3400 <= code <= 0x4DBF
        or 0x4E00 <= code <= 0x9FFF
        or 0xF900 <= code <= 0xFAFF
        or 0x20000 <= code <= 0x3FFFF
    ):
        return "kanji"
    return None


# Scripts whose /kanji/<char> page is a kanji-shaped character detail page. The
# script itself is recorded on the record, so routing them together does not
# claim that a Bopomofo letter or a squared ideograph is a kanji.
_KANJI_SHAPED_SCRIPTS = frozenset({"kanji", "bopomofo", "enclosed_cjk", "private_use"})


def _path_of(url: str) -> str:
    return urllib.parse.unquote(urllib.parse.urlsplit(url).path or "/")


def _path_segments(url: str) -> list[str]:
    return [segment for segment in _path_of(url).split("/") if segment]


def _is_word_slug(slug: str) -> bool:
    if not slug or len(slug) > 12:
        return False
    for character in slug:
        script = _script_of(character)
        if script in {"hiragana", "katakana", "kanji"}:
            continue
        if character in "々〆・":  # 々 〆 ・
            continue
        return False
    return True


def infer_page_type(url: str) -> str:
    segments = _path_segments(url)
    if not segments:
        return PAGE_OTHER

    head = segments[0]

    if head == "kanji":
        # /kanji/draw/<char> is dropped on purpose, see the module docstring.
        if len(segments) != 2:
            return PAGE_OTHER
        slug = segments[1]
        if slug in RESERVED_KANJI_SLUGS or len(slug) != 1:
            return PAGE_OTHER
        script = _script_of(slug)
        if script in {"hiragana", "katakana"}:
            return PAGE_KANA
        if script == "radical":
            return PAGE_RADICAL
        if script in _KANJI_SHAPED_SCRIPTS:
            return PAGE_KANJI
        return PAGE_OTHER

    if head == "word":
        if len(segments) != 2:
            return PAGE_OTHER
        slug = segments[1]
        if slug in RESERVED_WORD_SLUGS or not _is_word_slug(slug):
            return PAGE_OTHER
        return PAGE_WORD

    if head == "component_details":
        if len(segments) > 2:
            return PAGE_OTHER
        return PAGE_COMPONENT_INDEX

    if head == "collections":
        if len(segments) == 2 and segments[1] not in RESERVED_COLLECTION_SLUGS:
            return PAGE_COLLECTION_INDEX
        if len(segments) == 3 and segments[1] not in RESERVED_COLLECTION_SLUGS:
            return PAGE_COLLECTION_SET
        return PAGE_OTHER

    return PAGE_OTHER


def dedupe_key(url: str, page_type: str) -> str:
    """Identity of the underlying entity, ignoring query-string permutations.

    Kanshudo emits no ``rel=canonical`` and the crawl produced up to five
    byte-identical files per path (``?oq=&st=`` versus ``?oq=&amp%3Bst=``
    versus ``?section=readings``), so the key is the unquoted path alone.
    """
    segments = _path_segments(url)
    path = "/" + "/".join(segments)
    if page_type == PAGE_COMPONENT_INDEX:
        slug = segments[1] if len(segments) > 1 else ""
        slug = COMPONENT_COLLECTION_ALIASES.get(slug, slug)
        return f"{SITE_ID}:{page_type}:/component_details/{slug}"
    return f"{SITE_ID}:{page_type}:{path}"


def is_shell(tree: HtmlElement, url: str) -> bool:
    """True when the mirrored file carries no entity for its page type.

    Covers the login-gated utility routes that share an entity url shape
    (``/kanji/mastery``, ``/word/addcard``), soft 404s, and collection routes
    such as ``/collections/jok/playmenu`` that match the set url shape but
    contain no rows.
    """
    page_type = infer_page_type(url)
    if page_type not in EXTRACTABLE:
        # The router already excluded utility routes such as /kanji/mastery and
        # /word/addcard. They are real pages, not crawl artifacts, so they are
        # skipped by page type rather than reported as needing a refetch.
        return False
    if page_type in CHARACTER_PAGES:
        if not tree.xpath("//h1"):
            return True
        return not tree.xpath("//div[contains(@class,'kdetails2')]")
    if page_type == PAGE_WORD:
        return not tree.xpath("//div[@class='entity']//div[@class='ent_w']")
    if page_type == PAGE_COMPONENT_INDEX:
        return not tree.xpath("//div[@class='clist']//div[@class='cbox']")
    if page_type == PAGE_COLLECTION_SET:
        return not tree.xpath(
            "//div[starts-with(@id,'jukugo_')] | //div[contains(@class,'kanjirow')]"
        )
    if page_type == PAGE_COLLECTION_INDEX:
        if tree.xpath("//span[@class='kanji']/a[starts-with(@href,'/kanji/')]"):
            return False
        slug = _path_segments(url)[1]
        return not tree.xpath(f"//a[starts-with(@href,'/collections/{slug}/')]")
    return not tree.xpath("//*[@id='main-content']")  # pragma: no cover


# --- shared markup readers ----------------------------------------------------


def _grid_rows(tree: HtmlElement) -> dict[str, HtmlElement]:
    """Label to value-cell map for the ``div.g-row`` grid of a detail page."""
    rows: dict[str, HtmlElement] = {}
    for row in tree.xpath("//div[contains(@class,'g-row')]"):
        label_cell = _first(row.xpath("./div[contains(@class,'col-1-4')]"))
        value_cell = _first(row.xpath("./div[contains(@class,'col-3-4')]"))
        if label_cell is None or value_cell is None:
            continue
        label = _own_text(label_cell).strip()
        if label and label not in rows:
            rows[label] = value_cell
    return rows


def _token_stream(el: HtmlElement) -> Iterator[tuple[str, str, str | None]]:
    """Flatten a reading-ish container into ``(kind, text, href)`` tokens.

    ``kind`` is ``anchor`` (a search link, which starts a new value),
    ``okurigana`` (a grey inline span, Kanshudo's okurigana marker) or
    ``plain``. Chrome subtrees are skipped but their tails are kept, because on
    this site the readings are the tail of the last help node.
    """
    if el.text:
        yield "plain", el.text, None
    for child in el:
        yield from _child_tokens(child)
        if child.tail:
            yield "plain", child.tail, None


def _child_tokens(node: HtmlElement) -> Iterator[tuple[str, str, str | None]]:
    tag = node.tag if isinstance(node.tag, str) else ""
    if _is_chrome(node):
        return
    if tag == "a":
        href = node.get("href") or ""
        yield "anchor", "", href
        if node.text:
            yield "plain", node.text, None
        for child in node:
            yield from _child_tokens(child)
            if child.tail:
                yield "plain", child.tail, None
        return
    if tag == "span" and _GREY_STYLE.search(node.get("style") or ""):
        yield "okurigana", "".join(node.itertext()), None
        return
    if node.text:
        yield "plain", node.text, None
    for child in node:
        yield from _child_tokens(child)
        if child.tail:
            yield "plain", child.tail, None


def _split_values(tokens: Iterable[tuple[str, str, str | None]]) -> list[list[tuple[str, str, str | None]]]:
    """Group tokens into one list per value, splitting on the nbsp separator."""
    groups: list[list[tuple[str, str, str | None]]] = []
    current: list[tuple[str, str, str | None]] = []

    def close() -> None:
        nonlocal current
        if current:
            groups.append(current)
        current = []

    for kind, text, href in tokens:
        if kind == "anchor":
            close()
            current.append(("anchor", "", href))
            continue
        if kind != "plain":
            current.append((kind, text, href))
            continue
        pieces = _NBSP_SEPARATOR.split(text)
        for index, piece in enumerate(pieces):
            if index:
                close()
            if piece:
                current.append(("plain", piece, None))
    close()
    return groups


def _reading_value(group: list[tuple[str, str, str | None]]) -> dict[str, Any] | None:
    """Turn one token group into ``{reading, okurigana, dictionary_form, gloss}``."""
    href: str | None = None
    reading_parts: list[str] = []
    okurigana_parts: list[str] = []
    gloss_parts: list[str] = []
    in_gloss = False

    for kind, text, token_href in group:
        if kind == "anchor":
            href = token_href
            continue
        if kind == "okurigana":
            if in_gloss:
                gloss_parts.append(text)
            else:
                okurigana_parts.append(text)
            continue
        if in_gloss:
            gloss_parts.append(text)
            continue
        match = _LEADING_READING.match(text)
        if match:
            reading_parts.append(match.group(0).strip())
            rest = text[match.end() :]
        else:
            rest = text
        if rest.strip():
            in_gloss = True
            gloss_parts.append(rest)

    reading = "".join(reading_parts)
    okurigana = re.sub(r"\s+", "", "".join(okurigana_parts))
    gloss = common.normalize_text("".join(gloss_parts).replace(" ", " ")).strip(" ;")
    if not reading and not gloss:
        return None
    dictionary_form = None
    if href:
        target = _query_value(href, "q")
        dictionary_form = urllib.parse.unquote(target) if target else None
    return {
        "reading": reading or None,
        "okurigana": okurigana or None,
        "gloss": gloss or None,
        "dictionary_form": dictionary_form,
    }


def _parse_reading_row(row: HtmlElement) -> list[dict[str, Any]]:
    """One ``div.reading`` of a Common or Additional readings cell.

    The label span is consumed for the reading type but its tail is kept: on
    Additional rows the readings live in that tail.
    """
    label_span = None
    for child in row:
        if child.tag == "span" and _DARKGRAY_STYLE.search(child.get("style") or ""):
            label_span = child
            break
    if label_span is None:
        raise ValueError("kanshudo reading row without a type label")
    label = _own_text(label_span).strip().rstrip(":").strip().lower()
    if not label:
        raise ValueError("kanshudo reading row with an empty type label")

    tokens: list[tuple[str, str, str | None]] = []
    if row.text:
        tokens.append(("plain", row.text, None))
    for child in row:
        if child is not label_span:
            tokens.extend(_child_tokens(child))
        if child.tail:
            tokens.append(("plain", child.tail, None))

    values: list[dict[str, Any]] = []
    for group in _split_values(tokens):
        value = _reading_value(group)
        if value is None or not value["reading"]:
            continue
        value["type"] = label
        values.append(value)
    return values


def _parse_reading_cell(cell: HtmlElement | None) -> list[dict[str, Any]]:
    if cell is None:
        return []
    readings: list[dict[str, Any]] = []
    for row in cell.xpath("./div[contains(@class,'reading')]"):
        readings.extend(_parse_reading_row(row))
    return readings


def _parse_components_cell(cell: HtmlElement | None) -> tuple[str | None, list[dict[str, Any]]]:
    """Components row: composition pattern, repeated components, canonical aliases."""
    if cell is None:
        return None, []
    pattern_chars: list[str] = []
    items: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    gloss_parts: dict[int, list[str]] = {}
    last_text = ""
    strip_close_paren = False

    def push_text(text: str) -> None:
        nonlocal last_text, strip_close_paren
        value = text.replace(" ", " ")
        if strip_close_paren:
            value = re.sub(r"^\s*\)", "", value)
            strip_close_paren = False
        if current is None:
            pattern_chars.extend(_IDEOGRAPHIC_DESCRIPTION.findall(value))
        else:
            gloss_parts[id(current)].append(value)
        last_text = text

    if cell.text:
        push_text(cell.text)
    for child in cell:
        tag = child.tag if isinstance(child.tag, str) else ""
        if tag == "a" and (child.get("href") or "").startswith("/kanji/"):
            alias = last_text.replace(" ", " ").rstrip().endswith("(")
            if alias and current is not None:
                parts = gloss_parts[id(current)]
                if parts:
                    parts[-1] = re.sub(r"\(\s*$", "", parts[-1])
                current["canonical_form"] = _link(child)
                strip_close_paren = True
            else:
                current = {
                    "symbol": _squash(child) or None,
                    "href": _clean_href(child.get("href")),
                    "canonical_form": None,
                    "occurrence_index": len(items),
                }
                gloss_parts[id(current)] = []
                items.append(current)
            last_text = ""
        if child.tail:
            push_text(child.tail)

    for item in items:
        gloss = common.normalize_text("".join(gloss_parts[id(item)])).strip(" ;")
        item["meaning"] = gloss or None
    pattern = "".join(pattern_chars)
    return pattern or None, items


_VARIANT_LABEL = re.compile(r"^(?P<character>\S+?)\s*(?:\((?P<label>[^)]*)\))?$")


def _parse_variants_cell(cell: HtmlElement | None) -> list[dict[str, Any]]:
    """Variants row, with the qualifier some rows carry kept out of the glyph.

    The qualifier can sit inside the anchor ("⺎ (Chinese)") or after it, and
    folding it into the character makes the variant unresolvable.
    """
    if cell is None:
        return []
    variants: list[dict[str, Any]] = []
    for anchor in cell.xpath(".//a[starts-with(@href,'/kanji/')]"):
        text = _one_line(_own_text(anchor))
        if not text:
            continue
        match = _VARIANT_LABEL.match(text)
        character = match.group("character") if match else text
        label = (match.group("label") if match else None) or None
        trailing = _one_line((anchor.tail or "").replace(" ", " "))
        if trailing:
            label = f"{label} {trailing}".strip() if label else trailing
        variants.append(
            {
                "character": character,
                "href": _clean_href(anchor.get("href")),
                "label": label,
            }
        )
    return variants


def _parse_see_also_cell(cell: HtmlElement | None) -> list[dict[str, Any]]:
    if cell is None:
        return []
    entries: list[dict[str, Any]] = []
    for anchor in cell.xpath(".//a[starts-with(@href,'/kanji/')]"):
        character = _squash(anchor)
        if not character:
            continue
        meaning = common.normalize_text((anchor.tail or "").replace(" ", " ")).strip(" ;")
        entries.append(
            {
                "character": character,
                "href": _clean_href(anchor.get("href")),
                "meaning": meaning or None,
            }
        )
    return entries


def _is_notes_chrome(block: HtmlElement) -> bool:
    """True for the Joy o' Kanji navigation and advertising blocks of a Notes cell.

    The essay note itself sits in ``div.essayteaser`` (or, on radical pages, in a
    grey-background block). Around it Kanshudo puts a download prompt, two rows of
    links into its essay collection, a lead-in sentence and a whole thematic
    bundle advert with its own title, teaser and VIEW ESSAYS button. All of those
    are interface copy: they were the majority of what this field shipped.
    """
    classes = _class_tokens(block)
    if "grayitalic" in classes:
        return True
    return bool(block.xpath(".//div[contains(@class,'jok-bundle')]"))


def _parse_notes_cell(
    cell: HtmlElement | None,
) -> tuple[list[dict[str, Any]], dict[str, Any] | None]:
    """Notes row: editorial prose blocks plus the Joy o' Kanji attribution."""
    if cell is None:
        return [], None
    notes: list[dict[str, Any]] = []
    attribution: dict[str, Any] | None = None
    for block in cell.xpath("./div"):
        if _is_chrome(block):
            continue
        if _ITALIC_STYLE.search(block.get("style") or ""):
            attribution = _rich_own_line(block)
            continue
        if _is_notes_chrome(block):
            continue
        inner_divs = [node for node in block.xpath("./div") if not _is_chrome(node)]
        has_own_text = bool((block.text or "").strip())
        targets = inner_divs if inner_divs and not has_own_text else [block]
        for target in targets:
            text = rich_text(_pruned(target))
            if not text.text:
                continue
            notes.append(
                {
                    "text": text.to_json(),
                    "links": [_link(anchor) for anchor in target.xpath(".//a")],
                }
            )
    return notes, attribution


def _parse_additional_data_cell(cell: HtmlElement | None) -> dict[str, Any] | None:
    """Reference numbers row (Henshall, Joy o' Kanji, Key to Kanji).

    Returns None rather than a dict of Nones when the page carries no reference
    numbers, so a fill rate measured on this field counts data instead of
    counting the container.
    """
    references: dict[str, Any] = {
        "henshall": None,
        "henshall_original": None,
        "joy_o_kanji": None,
        "key_to_kanji": None,
    }
    if cell is None:
        return None
    for span in cell.xpath("./span"):
        label = _own_text(span).strip().rstrip(":").strip().lower()
        value = common.normalize_text((span.tail or "").replace(" ", " ")).strip()
        if not value:
            continue
        if label.startswith("henshall"):
            references["henshall"] = _int_from(value)
            original = re.search(r"originally:\s*([\d,]+)", value)
            references["henshall_original"] = _int_from(original.group(1)) if original else None
        elif "joy o" in label:
            references["joy_o_kanji"] = _int_from(value)
        elif label.startswith("key to kanji"):
            references["key_to_kanji"] = _int_from(value)
    if not any(value is not None for value in references.values()):
        return None
    return references


_HEADLINE_SCRIPT = re.compile(r"is\s+(hiragana|katakana)\s*'([^']*)'")
_HEADLINE_VARIANT = re.compile(r"is\s+an?\s+(?:(\w+)\s+)?variant\s+of\s*$")
_HEADLINE_VARIANT_CLAUSE = re.compile(r"\band\s+is\s+an?\b")
_QUOTED = re.compile(r"'([^']*)'")


def _headline_meanings(flat: str) -> list[str]:
    """Every quoted meaning after "means", not only the first.

    An h1 can chain them: "ノ is katakana 'no' and means 'whereupon' or
    'splitting away from'". The quoted romaji before "means" must not become a
    meaning, and the trailing variant clause must not be scanned at all.
    """
    start = flat.find("means")
    if start < 0:
        return []
    tail = flat[start:]
    clause = _HEADLINE_VARIANT_CLAUSE.search(tail)
    if clause:
        tail = tail[: clause.start()]
    meanings: list[str] = []
    for quoted in _QUOTED.findall(tail):
        meanings.extend(common.split_english_glosses(quoted))
    return unique_list(meanings)


def _parse_headline(heading: HtmlElement) -> dict[str, Any]:
    """The h1 carries meanings, kana romaji and variant relations."""
    text = _own_text(heading)
    flat = text.replace("\n", " ")
    out: dict[str, Any] = {
        "headline": _rich_own_line(heading),
        "meanings": _headline_meanings(flat),
        "romaji": None,
        "script": None,
        "variant_of": None,
        "variant_kind": None,
    }
    script = _HEADLINE_SCRIPT.search(flat)
    if script:
        out["script"] = script.group(1)
        out["romaji"] = script.group(2) or None
    for anchor in heading.xpath(".//a[starts-with(@href,'/kanji/')]"):
        before = flat[: flat.find(_squash(anchor))] if _squash(anchor) else flat
        relation = _HEADLINE_VARIANT.search(before.strip())
        if relation:
            out["variant_of"] = _link(anchor)
            out["variant_kind"] = (relation.group(1) or "").lower() or None
            break
    return out


_METADATA_PATTERNS = {
    "stroke_count": re.compile(r"Strokes?\s*:\s*([\d,]+)"),
    "frequency_rank": re.compile(r"Frequency\s*:\s*([\d,]+)"),
    "jlpt_level": re.compile(r"JLPT\s*:\s*(N\d)"),
    "usefulness_level": re.compile(r"Usefulness\s*:\s*([\d,]+)"),
    "study_set": re.compile(r"Study set\s*:\s*(\S+)"),
    "grade": re.compile(r"Grade\s*:\s*([\d,]+)"),
    "intermediate_lesson": re.compile(r"Intermediate lesson\s*:\s*([\d,]+)"),
    "beginner_lesson": re.compile(r"Beginner lesson\s*:\s*([\d,]+)"),
    "words_starting_with": re.compile(r"Begins\s*([\d,]+)\s*words"),
    "words_containing": re.compile(r"Used in\s*([\d,]+)\s*words"),
    "names_containing": re.compile(r"Used in\s*([\d,]+)\s*names"),
    "radical_number": re.compile(r"Radical number\s*:\s*([\d,]+)"),
}
_COMPONENT_IN = re.compile(r"Component in\s*([\d,]+)\s*kanji\s*\(\s*([\d,]+)")


def _parse_detail_metadata(tree: HtmlElement) -> dict[str, Any]:
    """The ``div.kdetails2`` label/value run above the grid.

    Read from the pruned text of that block rather than from raw html: the block
    also holds a hidden help panel and an inline script.
    """
    block = _first(tree.xpath("//div[contains(@class,'kdetails2')]"))
    out: dict[str, Any] = {name: None for name in _METADATA_PATTERNS}
    out["component_in_kanji"] = None
    out["component_in_joyo_kanji"] = None
    out["character_type"] = None
    if block is None:
        return out
    pruned = _pruned(block, extra_classes={"keymessage", "typemessage"})
    text = plain_text(pruned).replace(" ", " ")
    for name, pattern in _METADATA_PATTERNS.items():
        match = pattern.search(text)
        if not match:
            continue
        raw = match.group(1)
        if name == "jlpt_level":
            out[name] = normalize_jlpt(raw)
        elif name == "study_set":
            out[name] = raw if raw.strip("-") else None
        else:
            out[name] = _int_from(raw)
    component_in = _COMPONENT_IN.search(text)
    if component_in:
        out["component_in_kanji"] = _int_from(component_in.group(1))
        out["component_in_joyo_kanji"] = _int_from(component_in.group(2))
    out["character_type"] = _text(_first(block.xpath(".//div[@class='typemessage']")))
    return out


def _mnemonic_state(tree: HtmlElement) -> bool | None:
    """Whether Kanshudo has a mnemonic for this character.

    The previous field was inverted: it was true only when the login gate was
    absent, so it could never be true for a kanji that actually has one. Both
    gate shapes count, and the value is None when the page has no detail block
    at all.
    """
    block = _first(tree.xpath("//div[contains(@class,'kdetails2')]"))
    if block is None:
        return None
    for node in block.iter():
        if not isinstance(node.tag, str):
            continue
        if "mnemonic" not in "".join(node.itertext()).lower():
            continue
        if node.xpath(".//a[@href='/users/sign_in' or @href='/kanshudo_system']"):
            return True
    return False


def _stroke_order(tree: HtmlElement, character: str) -> dict[str, Any]:
    """KanjiVG animator url, present on every kanji, kana and radical page.

    The file name is the zero-padded codepoint, so it doubles as a check that the
    mirrored file really is the page for this slug. Finding animator urls but
    none for this character means the snapshot is not what its path claims, which
    is unexpected markup rather than missing data.
    """
    out: dict[str, Any] = {"stroke_order_svg_url": None, "stroke_order_codepoint": None}
    seen: list[str] = []
    for script in tree.xpath("//script"):
        for url, hex_codepoint in _SVG_URL.findall(script.text_content() or ""):
            seen.append(hex_codepoint)
            if int(hex_codepoint, 16) != ord(character):
                continue
            out["stroke_order_svg_url"] = url
            out["stroke_order_codepoint"] = f"U+{ord(character):04X}"
            return out
    if seen:
        raise ValueError(
            f"kanshudo stroke-order svg codepoints {seen} do not include character {character!r}"
        )
    return out


# --- furigana aware text ------------------------------------------------------


def _furigana_pair(el: HtmlElement) -> tuple[str, str]:
    """``(surface, reading)`` for ``span.f_container`` markup.

    Never interleaves the furigana into the surface, which is what turned
    example sentences into "いろ 色 んな ところ 所".
    """
    surface: list[str] = []
    reading: list[str] = []

    def add(text: str | None, ruby: str | None = None) -> None:
        if text is None:
            text = ""
        if not text and not ruby:
            return
        surface.append(text)
        reading.append(ruby if ruby is not None else text)

    def handle(node: HtmlElement) -> None:
        if _is_chrome(node):
            return
        classes = _class_tokens(node)
        if "f_container" in classes:
            children = [child for child in node if isinstance(child.tag, str)]
            skip: set[int] = set()
            for index, child in enumerate(children):
                if id(child) in skip:
                    if child.tail:
                        add(child.tail)
                    continue
                child_classes = _class_tokens(child)
                if "furigana" in child_classes:
                    base = ""
                    if index + 1 < len(children) and "f_kanji" in _class_tokens(children[index + 1]):
                        base = _squash(children[index + 1])
                        skip.add(id(children[index + 1]))
                    add(base, _squash(child) or base)
                elif "f_kanji" in child_classes:
                    add(_squash(child))
                else:
                    handle(child)
                if child.tail:
                    add(child.tail)
            return
        if node.text:
            add(node.text)
        for child in node:
            if isinstance(child.tag, str):
                handle(child)
            if child.tail:
                add(child.tail)

    handle(el)
    tight = lambda value: re.sub(r"\s+", "", value)
    return tight("".join(surface)), tight("".join(reading))


# --- senses -------------------------------------------------------------------


def _semicolon_ranges(value: str) -> list[tuple[int, int]]:
    """Paren-aware split points on ';' only. JMdict glosses may contain commas.

    Returns offsets rather than substrings so a RichText can be sliced with its
    spans kept instead of being flattened into bare strings.
    """
    ranges: list[tuple[int, int]] = []
    depth = 0
    start = 0
    for index, character in enumerate(value):
        if character in "([{（【「":
            depth += 1
        elif character in ")]}）】」":
            depth = max(0, depth - 1)
        if character == ";" and depth == 0:
            ranges.append((start, index))
            start = index + 1
    ranges.append((start, len(value)))
    return [(begin, end) for begin, end in ranges if value[begin:end].strip()]


def _rich_segments(source: common.RichText) -> list[common.RichText]:
    return [_slice_rich(source, begin, end) for begin, end in _semicolon_ranges(source.text)]


def _gloss_rich(block: HtmlElement) -> common.RichText:
    """RichText of the gloss of a sense block: its own text nodes, nothing else.

    Every element child of a ``div.vm`` is metadata (the part-of-speech header,
    the sense number, the note span, the click prompt), so the gloss is what
    remains once they are removed with their tails kept.
    """
    clone = copy.deepcopy(block)
    clone.tail = None
    for child in list(clone):
        if isinstance(child.tag, str):
            _drop_keeping_tail(child)
        else:
            clone.remove(child)
    return rich_text(clone)


def _parse_note_span(span: HtmlElement) -> tuple[list[common.RichText], list[dict[str, Any]]]:
    """The parenthesised note span of a sense: usage notes plus cross references."""
    source = _rich_of(span)
    text = source.text
    begin, end = 0, len(text)
    if text.startswith("("):
        begin += 1
    if text.endswith(")"):
        end -= 1
    references = [_link(anchor) for anchor in span.xpath(".//a")]
    notes = [
        segment
        for segment in _rich_segments(_slice_rich(source, begin, max(begin, end)))
        if not segment.text.lower().startswith("see also")
    ]
    return notes, references


def _sense_from_block(block: HtmlElement) -> dict[str, Any]:
    """One sense, read from a ``div.vm`` or from a bare-text gloss container."""
    parts_of_speech: list[str] = []
    index: int | None = None
    notes: list[common.RichText] = []
    references: list[dict[str, Any]] = []

    for child in block:
        tag = child.tag if isinstance(child.tag, str) else ""
        classes = _class_tokens(child)
        if tag == "div" and not classes:
            parts_of_speech = common.split_english_glosses(_own_text(child))
        elif tag == "span" and "vm_id" in classes:
            index = parse_int(_own_text(child))
        elif tag == "span" and not classes:
            span_notes, span_references = _parse_note_span(child)
            notes.extend(span_notes)
            references.extend(span_references)

    return {
        "index": index,
        "parts_of_speech": parts_of_speech,
        "glosses": [segment.to_json() for segment in _rich_segments(_gloss_rich(block))],
        "cross_references": references,
        "usage_notes": [note.to_json() for note in notes],
    }


def _parse_senses(scope: HtmlElement) -> list[dict[str, Any]]:
    """One record per ``div.vm`` block.

    The part-of-speech header is optional and, when present, applies to the
    sense it introduces and to the following senses until the next header, so it
    is carried forward.
    """
    senses: list[dict[str, Any]] = []
    carried: list[str] = []
    for block in scope.xpath(".//div[@class='vm']"):
        sense = _sense_from_block(block)
        if sense["parts_of_speech"]:
            carried = sense["parts_of_speech"]
        else:
            sense["parts_of_speech"] = list(carried)
        senses.append(sense)
    return senses


def _parse_bare_senses(scope: HtmlElement) -> list[dict[str, Any]]:
    """Fallback for a jukugo gloss that Kanshudo emits without a ``div.vm``.

    Some rows put the meaning straight into ``div#jk_abbr_<id>`` as bare text,
    for instance "Sumitomo (company)" on /kanji/住 and "sixty years" in the
    Routledge collection. Those meanings were dropped entirely: no other field on
    the record carried them.
    """
    container = _first(scope.xpath(".//div[starts-with(@id,'jk_abbr_')]"))
    if container is None:
        container = scope
    if container.xpath(".//div[@class='vm']"):
        return []
    sense = _sense_from_block(container)
    if not sense["glosses"]:
        return []
    return [sense]


# --- jukugo rows (example words, collection word sets) ------------------------


_SPEAK_JAPANESE = re.compile(r"speakJapanese\('([^']*)'\)")
_WORD_DETAILS = re.compile(r"wordDetails\(\s*(\d+)")
_TAT_DETAILS = re.compile(r"tatDetails\(\s*this\s*,\s*(\d+)\s*,\s*\"((?:[^\"\\]|\\.)*)\"")
_KANJI_DETAILS = re.compile(r"kanjiDetails\(\s*(\d+)")
# A jukugo group header counts its words in the singular when there is one of
# them ("ハク (read as ぱく) : 1 word."), and the group is not always a reading:
# "Part of a non-standard reading: 1 word." heads the leftovers. The label is
# therefore captured whole and only then interpreted, because a header that fails
# to parse must clear the current group rather than leave the previous reading in
# place, which is how a word read ぱく came to be filed under バク.
_GROUP_HEADER = re.compile(r"^(?P<label>.*?)\s*:\s*(?P<count>[\d,]+)\s*words?\b")
_GROUP_READING = re.compile(r"^(?P<reading>[^\s:()]+)(?:\s*\(read as (?P<variant>[^)]*)\))?$")


def _parse_group_header(node: HtmlElement) -> dict[str, Any] | None:
    text = plain_text(_pruned(node)).replace("\n", " ")
    text = re.sub(r"\s+", " ", text).strip()
    match = _GROUP_HEADER.match(text)
    if not match:
        return None
    label = match.group("label").strip()
    reading = _GROUP_READING.match(label)
    return {
        "label": label or None,
        "reading": reading.group("reading") if reading else None,
        "variant_reading": (
            ((reading.group("variant") or "").strip() or None) if reading else None
        ),
        "word_count": _int_from(match.group("count")),
    }


_WITHHELD_FORMS = re.compile(r"additional[^.]*?(\d+)\s*forms?\b", re.IGNORECASE)
_WITHHELD_READINGS = re.compile(r"additional[^.]*?(\d+)\s*readings?\b", re.IGNORECASE)
_WITHHELD_MEANINGS = re.compile(r"additional[^.]*?(\d+)\s*meanings?\b", re.IGNORECASE)
_WITHHELD_EXPRESSIONS = re.compile(r"useful expressions", re.IGNORECASE)


def _parse_withheld_detail(scope: HtmlElement) -> dict[str, Any] | None:
    """What the row says it is not showing, as counts rather than as UI copy.

    The ``div.ent_item`` of a jukugo row is pure interface prose ("(click the word
    to view an additional 2 forms, examples and links)") and used to be shipped
    verbatim in a field declared factual. Only the numbers inside it are data, so
    only the numbers are kept, and a row that withholds nothing gets None.
    """
    note = _first(scope.xpath(".//div[@class='ent_item']"))
    if note is None:
        return None
    text = _one_line(_text(note)) or ""
    detail = {
        "additional_forms": _int_from(match.group(1)) if (match := _WITHHELD_FORMS.search(text)) else None,
        "additional_readings": (
            _int_from(match.group(1)) if (match := _WITHHELD_READINGS.search(text)) else None
        ),
        "additional_meanings": (
            _int_from(match.group(1)) if (match := _WITHHELD_MEANINGS.search(text)) else None
        ),
        "has_useful_expressions": bool(_WITHHELD_EXPRESSIONS.search(text)),
    }
    if not any(detail.values()):
        return None
    return detail


def _parse_jukugo_row(row: HtmlElement) -> dict[str, Any]:
    word_id = parse_int((row.get("id") or "").split("_")[-1])
    anchor = _first(row.xpath(".//div[contains(@class,'jukugo')]//a[starts-with(@id,'jk_')]"))
    if anchor is None:
        anchor = _first(row.xpath(".//a[starts-with(@id,'jk_')]"))
    if anchor is None:
        raise ValueError("kanshudo jukugo row without a word anchor")
    surface, reading = _furigana_pair(anchor)
    if not surface:
        raise ValueError("kanshudo jukugo row without a surface form")
    onclick = anchor.get("onclick") or ""
    details = _WORD_DETAILS.search(onclick)
    if details and word_id is None:
        word_id = int(details.group(1))

    sense_scope = _first(row.xpath(".//div[contains(@class,'jukugo_reading')]"))
    if sense_scope is None:
        sense_scope = row
    senses = _parse_senses(sense_scope)
    if not senses:
        senses = _parse_bare_senses(sense_scope)
    # A handful of rows print "(same as above)" instead of a gloss. The row really
    # has no gloss of its own, so it is recorded as a pointer rather than left
    # looking like a parse failure or filled with the interface sentence.
    repeats = bool(sense_scope.xpath(".//span[contains(@class,'juk_mess')]"))
    audio = _first(row.xpath(".//div[contains(@class,'tat_audio2')]"))
    audio_kana = None
    if audio is not None:
        spoken = _SPEAK_JAPANESE.search(audio.get("onclick") or "")
        audio_kana = spoken.group(1) if spoken else None

    pitch_pattern = None
    pitch = _first(row.xpath(".//a[contains(@class,'pitch-link')]"))
    if pitch is not None:
        numbers = [
            node.text.strip()
            for node in pitch.iter()
            if isinstance(node.tag, str)
            and node.tag.endswith("text")
            and (node.text or "").strip().isdigit()
        ]
        if numbers:
            pitch_pattern = int(numbers[-1])

    return {
        "word_id": word_id,
        "surface": surface,
        "reading": reading or None,
        "senses": senses,
        "gloss_repeats_previous_row": repeats,
        "jlpt_level": normalize_jlpt(_badge_level(row, "jlpt")),
        "usefulness_level": _badge_level(row, "ufn"),
        "pitch_pattern": pitch_pattern,
        "audio_kana": audio_kana,
        "withheld_detail": _parse_withheld_detail(sense_scope),
    }


def _parse_jukugo_groups(cell: HtmlElement) -> list[dict[str, Any]]:
    """Jukugo rows attached to the ``div.halfspaced`` reading group above them."""
    words: list[dict[str, Any]] = []
    group: dict[str, Any] | None = None
    for node in cell.iter():
        if not isinstance(node.tag, str):
            continue
        classes = _class_tokens(node)
        if "halfspaced" in classes:
            # Assigned unconditionally: an unreadable header means the rows below
            # it belong to no known group, never to the group above it.
            group = _parse_group_header(node)
            continue
        if (node.get("id") or "").startswith("jukugo_"):
            record = _parse_jukugo_row(node)
            record["reading_group"] = dict(group) if group else None
            words.append(record)
    return words


# --- cascading kanji rows -----------------------------------------------------


def _parse_kanjirow(row: HtmlElement) -> dict[str, Any]:
    anchor = _first(row.xpath(".//div[contains(@class,'kanji')]/a"))
    if anchor is None:
        raise ValueError("kanshudo kanjirow without a character anchor")
    character = _squash(anchor)
    if not character:
        raise ValueError("kanshudo kanjirow with an empty character")
    depth = None
    for token in _class_tokens(row):
        match = re.fullmatch(r"level(\d+)", token)
        if match:
            depth = int(match.group(1))
    kanji_id = None
    details = _KANJI_DETAILS.search(anchor.get("onclick") or "")
    if details:
        kanji_id = int(details.group(1))

    on_readings: list[dict[str, Any]] = []
    kun_readings: list[dict[str, Any]] = []
    meanings: list[str] = []
    mnemonic_available = False
    reading_cell = _first(row.xpath(".//div[contains(@class,'reading')]"))
    if reading_cell is not None:
        for node in reading_cell.iter():
            if not isinstance(node.tag, str):
                continue
            if node.xpath("./a[@href='/users/sign_in']") and "mnemonic" in "".join(
                node.itertext()
            ).lower():
                mnemonic_available = True
        # The login gate for the mnemonic sits inside the reading cell; keeping it
        # would turn "Please LOG IN to view this kanji's mnemonic" into meanings.
        readable = _pruned(reading_cell, extra_classes={"keymessage"})
        for gate in readable.xpath(".//a[@href='/users/sign_in']"):
            parent = gate.getparent()
            while parent is not None and parent is not readable:
                gate, parent = parent, parent.getparent()
            if parent is readable:
                _drop_keeping_tail(gate)
        for group in _split_values(_token_stream(readable)):
            value = _reading_value(group)
            if value is None:
                continue
            reading = value["reading"]
            if reading and _KATAKANA_ONLY.match(reading):
                on_readings.append({"reading": reading, "gloss": value["gloss"]})
            elif reading:
                kun_readings.append(
                    {
                        "reading": reading,
                        "okurigana": value["okurigana"],
                        "gloss": value["gloss"],
                    }
                )
            elif value["gloss"]:
                meanings.extend(common.split_english_glosses(value["gloss"]))
    return {
        "character": character,
        "kanji_id": kanji_id,
        "depth": depth,
        "on_readings": on_readings,
        "kun_readings": kun_readings,
        "meanings": unique_list(meanings),
        "usefulness_level": _badge_level(row, "ufn"),
        "mnemonic_available": mnemonic_available,
    }


def _parse_kanjirows(scope: HtmlElement) -> list[dict[str, Any]]:
    """Flat rows plus the parent link the ``levelN`` class encodes."""
    rows: list[dict[str, Any]] = []
    stack: list[str] = []
    for node in scope.xpath(".//div[contains(@class,'kanjirow')]"):
        record = _parse_kanjirow(node)
        depth = record["depth"]
        if depth is None:
            record["parent"] = None
        else:
            del stack[depth:]
            record["parent"] = stack[depth - 1] if depth and len(stack) >= depth else None
            stack.append(record["character"])
        rows.append(record)
    return rows


# --- example sentences --------------------------------------------------------


def _parse_sentence(block: HtmlElement) -> dict[str, Any]:
    sentence_id = None
    toggle = _first(block.xpath(".//div[starts-with(@id,'tf_')]"))
    if toggle is not None:
        sentence_id = parse_int((toggle.get("id") or "").split("_")[-1])
    if sentence_id is None:
        link = _first(block.xpath(".//a[contains(@href,'/example/')]"))
        if link is not None:
            sentence_id = parse_int((link.get("href") or "").rstrip("/").split("/")[-1])

    tokens: list[dict[str, Any]] = []
    surfaces: list[str] = []
    readings: list[str] = []
    for node in block:
        classes = _class_tokens(node)
        if "tatvoc" not in classes and "tatvoc-stop" not in classes:
            continue
        surface, reading = _furigana_pair(node)
        if not surface:
            continue
        lemma = None
        details = _TAT_DETAILS.search(node.get("onclick") or "")
        if details:
            lemma = details.group(2)
        tokens.append(
            {
                "surface": surface,
                "reading": reading if reading != surface else None,
                "lemma": lemma,
                "is_stop": "tatvoc-stop" in classes,
            }
        )
        surfaces.append(surface)
        readings.append(reading)

    audio = _first(block.xpath(".//div[contains(@class,'tat_audio2')]"))
    jp_kana = None
    if audio is not None:
        spoken = _SPEAK_JAPANESE.search(audio.get("onclick") or "")
        jp_kana = spoken.group(1) if spoken else None
    audio_url = _first(block.xpath(".//source/@src"))

    return {
        "sentence_id": sentence_id,
        "jp": "".join(surfaces) or None,
        "jp_reading": "".join(readings) or None,
        "jp_kana": jp_kana,
        "en": _rich_line(_first(block.xpath(".//span[@class='tat_eng']/span[@class='text']"))),
        "tokens": tokens,
        "audio_url": audio_url if isinstance(audio_url, str) else None,
    }


def _parse_sentences(tree: HtmlElement) -> list[dict[str, Any]]:
    return [
        _parse_sentence(block)
        for block in tree.xpath("//div[contains(@class,'tatoeba')]")
    ]


# --- character pages ----------------------------------------------------------


_USAGE_LINE = re.compile(r"is used ([\d,]+) times, read (\d+) way")


def _parse_usage(cell: HtmlElement | None) -> dict[str, Any] | None:
    """How often the character is used, or None when the page says nothing.

    Returning the empty container made this field look 100% filled when the real
    rate is closer to two thirds on kanji and almost nothing on radicals.
    """
    usage: dict[str, Any] = {"useful_words": None, "all_words": None, "summary": []}
    if cell is None:
        return None
    for node in cell.xpath("./div"):
        if _class_tokens(node) or _is_chrome(node):
            continue
        line = _collapsed(_rich_of(node))
        if not line.text:
            continue
        usage["summary"].append(line.to_json())
        match = _USAGE_LINE.search(line.text)
        if not match:
            continue
        payload = {"uses": _int_from(match.group(1)), "readings": _int_from(match.group(2))}
        if line.text.lower().startswith("in the"):
            usage["useful_words"] = payload
        else:
            usage["all_words"] = payload
    if not usage["summary"] and usage["useful_words"] is None and usage["all_words"] is None:
        return None
    return usage


def _character_from_url(url: str, page_type: str) -> str:
    segments = _path_segments(url)
    if len(segments) != 2:
        raise ValueError(f"kanshudo {page_type} url without a character slug: {url}")
    slug = segments[1]
    if len(slug) != 1:
        raise ValueError(f"kanshudo {page_type} url slug is not one character: {url}")
    return slug


def _parse_character_page(tree: HtmlElement, url: str, page_type: str) -> dict[str, Any]:
    character = _character_from_url(url, page_type)
    heading = _first(tree.xpath("//h1"))
    if heading is None:
        raise ValueError(f"kanshudo {page_type} page without an h1: {url}")

    record: dict[str, Any] = {"character": character, "script": _script_of(character)}
    headline = _parse_headline(heading)
    script_from_headline = headline.pop("script")
    if script_from_headline:
        record["script"] = script_from_headline
    record.update(headline)

    metadata = _parse_detail_metadata(tree)
    record.update(metadata)
    record.update(_stroke_order(tree, character))

    rows = _grid_rows(tree)
    record["common_readings"] = _parse_reading_cell(rows.get("Common readings"))
    record["additional_readings"] = _parse_reading_cell(rows.get("Additional readings"))
    pattern, components = _parse_components_cell(rows.get("Components"))
    record["composition_pattern"] = pattern
    record["components"] = components
    record["variants"] = _parse_variants_cell(rows.get("Variants"))
    record["see_also"] = _parse_see_also_cell(rows.get("See also"))
    notes, attribution = _parse_notes_cell(rows.get("Notes"))
    record["notes"] = notes
    record["notes_attribution"] = attribution
    record["references"] = _parse_additional_data_cell(rows.get("Additional data"))

    readings_section = _first(tree.xpath("//div[@id='sectionreadings']//div[contains(@class,'col-3-4')]"))
    record["usage"] = _parse_usage(readings_section)
    record["example_words"] = (
        _parse_jukugo_groups(readings_section) if readings_section is not None else []
    )

    cascade = _first(tree.xpath("//div[contains(@class,'bodyarea')]"))
    if cascade is None:
        cascade = tree
    cascading = _parse_kanjirows(cascade)
    # The page character is itself the root kanjirow, so a character with no
    # decomposition still produced a one-row list. That made the field look
    # always filled while carrying no component information at all.
    if len(cascading) == 1 and cascading[0]["character"] == character:
        cascading = []
    record["cascading_components"] = cascading

    record["mnemonic_exists"] = _mnemonic_state(tree)
    record["mnemonic_text"] = None

    record["_provenance"] = build_provenance_map(
        source=SITE_ID,
        source_url=url,
        factual_fields=[
            "character",
            "script",
            "romaji",
            "character_type",
            "headline",
            "meanings",
            "variant_of",
            "variant_kind",
            "stroke_count",
            "frequency_rank",
            "jlpt_level",
            "grade",
            "study_set",
            "beginner_lesson",
            "intermediate_lesson",
            "words_starting_with",
            "words_containing",
            "names_containing",
            "component_in_kanji",
            "component_in_joyo_kanji",
            "radical_number",
            "references",
            "stroke_order_svg_url",
            "stroke_order_codepoint",
            "common_readings",
            "additional_readings",
            "components",
            "composition_pattern",
            "variants",
            "see_also",
            "usage",
            "example_words",
            "cascading_components",
            "mnemonic_exists",
        ],
        authored_fields=[
            "usefulness_level",
            "notes",
            "notes_attribution",
            "mnemonic_text",
            "example_words[].usefulness_level",
            "cascading_components[].usefulness_level",
        ],
    )
    return record


# --- word pages ---------------------------------------------------------------


_USEFULNESS_LEVEL = re.compile(r"usefulness level\s*:\s*(\d+)\s*(?:\(([^)]*)\))?", re.IGNORECASE)
_USEFULNESS_SCORE = re.compile(r"usefulness score of\s*([\d,]+)", re.IGNORECASE)
_USEFULNESS_RANK = re.compile(r"rank of\s*([\d,]+)", re.IGNORECASE)
_FORM_SHARE = re.compile(r"used about\s*([\d,.]+)\s*%", re.IGNORECASE)
_FORM_RARE = re.compile(r"this form is (?:rarely|not) used", re.IGNORECASE)
_GOOGLE_RANK = re.compile(r"Google Japan frequency rank\s*:\s*([\d,]+)", re.IGNORECASE)
_GOOGLE_RESULTS = re.compile(r"about\s*([\d,]+)\s*results", re.IGNORECASE)
_JLPT_VALUE = re.compile(r"JLPT value\s*=\s*(N\d)", re.IGNORECASE)


def _bullets(scope: HtmlElement, wrapper_class: str) -> list[common.RichText]:
    """The bullet lines of a word-page section, as RichText.

    The bullet marker is part of the list styling rather than of the sentence, so
    it is trimmed off the front with the span offsets moved with it.
    """
    out: list[common.RichText] = []
    for wrapper in scope.xpath(f"./div[@class='{wrapper_class}']"):
        for bullet in wrapper.xpath("./div[@class='ent_item']"):
            line = _collapsed(_rich_of(bullet))
            stripped = line.text.lstrip("• ")
            line = _slice_rich(line, len(line.text) - len(stripped), len(line.text))
            if line.text:
                out.append(line)
    return out


def _parse_form_usage(block: HtmlElement) -> dict[str, Any]:
    usage: dict[str, Any] = {
        "share_text": None,
        "share_pct": None,
        "google_rank": None,
        "google_results": None,
        "jlpt_level": None,
        "wordlists": [],
    }
    for section in block.xpath(".//div[@class='ent_section']"):
        for bullet in _bullets(section, "ent_fr"):
            text = bullet.text
            share = _FORM_SHARE.search(text)
            if share or _FORM_RARE.search(text):
                # Only the share bullet describes how often this form is written;
                # the other "This form ..." bullets are word-list memberships.
                if usage["share_text"] is None:
                    usage["share_text"] = bullet.to_json()
                    usage["share_pct"] = _int_from(share.group(1)) if share else None
                continue
            rank = _GOOGLE_RANK.search(text)
            if rank:
                usage["google_rank"] = _int_from(rank.group(1))
                results = _GOOGLE_RESULTS.search(text)
                usage["google_results"] = _int_from(results.group(1)) if results else None
                continue
            jlpt = _JLPT_VALUE.search(text)
            if jlpt:
                usage["jlpt_level"] = normalize_jlpt(jlpt.group(1))
                continue
            usage["wordlists"].append(bullet.to_json())
    return usage


def _parse_word_usefulness(block: HtmlElement) -> dict[str, Any]:
    out: dict[str, Any] = {
        "level": None,
        "level_blurb": None,
        "score": None,
        "rank": None,
        "notes": [],
        "collection": None,
    }
    for section in block.xpath(".//div[@class='ent_section']"):
        label = _text(_first(section.xpath("./div/span[@class='ent_item']"))) or ""
        if not label.lower().startswith("usefulness"):
            continue
        for bullet in _bullets(section, "ent_m"):
            level = _USEFULNESS_LEVEL.search(bullet.text)
            if level:
                out["level"] = _int_from(level.group(1))
                out["level_blurb"] = (level.group(2) or "").strip() or None
            score = _USEFULNESS_SCORE.search(bullet.text)
            if score:
                out["score"] = _int_from(score.group(1))
            rank = _USEFULNESS_RANK.search(bullet.text)
            if rank:
                out["rank"] = _int_from(rank.group(1))
        for wrapper in section.xpath("./div[@class='ent_m']"):
            if wrapper.xpath("./div[@class='ent_item']"):
                continue
            collection = _first(wrapper.xpath(".//a[contains(@href,'/collections/')]"))
            if collection is not None and out["collection"] is None:
                out["collection"] = _link(collection)
            # The collection membership note ends in a button, so without dropping
            # the button rows the note shipped as "... in Japanese: VIEW
            # COLLECTION". The button target is already kept as ``collection``.
            note = _collapsed(_rich_of(wrapper, extra_classes={"action", "searchbutton"}))
            note = _slice_rich(note, 0, len(note.text.rstrip(" :")))
            if note.text:
                out["notes"].append(note.to_json())
    return out


_EXPRESSION_DETAILS = re.compile(r"expressionDetails\(\s*(\d+)")
# The Japanese expression and its English gloss share one text run, separated by
# a space and a non-breaking space rather than by markup.
_EXPRESSION_SEPARATOR = re.compile("[\\s ]{2,}")


def _split_expression(node: HtmlElement) -> tuple[HtmlElement, str]:
    """Separate the Japanese expression from the English gloss glued after it.

    Both live in the same text run, so the furigana walk would otherwise fold the
    gloss into the surface form. The returned element holds the Japanese only.
    """
    clone = copy.deepcopy(node)
    clone.tail = None
    gloss_parts: list[str] = []
    state = {"found": False}

    def cut(value: str | None) -> str | None:
        if value is None:
            return None
        if state["found"]:
            gloss_parts.append(value)
            return ""
        match = _EXPRESSION_SEPARATOR.search(value)
        if not match:
            return value
        state["found"] = True
        gloss_parts.append(value[match.end() :])
        return value[: match.start()]

    def walk(el: HtmlElement) -> None:
        el.text = cut(el.text)
        for child in el:
            if isinstance(child.tag, str):
                walk(child)
            child.tail = cut(child.tail)

    walk(clone)
    return clone, common.normalize_text("".join(gloss_parts))


def _parse_useful_expressions(tree: HtmlElement) -> list[dict[str, Any]]:
    """The "Useful expressions" section of a word page.

    It sits in a ``div.ent_section`` that carries no ``div.ent_w``, so walking
    only the surface-form blocks dropped it: on /word/行く the two expressions
    地で行く and 先を行く appeared in no field at all.
    """
    expressions: list[dict[str, Any]] = []
    for node in tree.xpath("//div[@class='exp_head']/div[contains(@onclick,'expressionDetails')]"):
        japanese, gloss = _split_expression(node)
        surface, reading = _furigana_pair(japanese)
        if not surface:
            continue
        details = _EXPRESSION_DETAILS.search(node.get("onclick") or "")
        expressions.append(
            {
                "expression_id": int(details.group(1)) if details else None,
                "surface": surface,
                "reading": reading or None,
                "glosses": [
                    segment.to_json() for segment in _rich_segments(common.RichText(gloss))
                ],
            }
        )
    return expressions


def _badge_scope(block: HtmlElement) -> HtmlElement:
    """The form header, which is where the form's own usefulness badge lives.

    Scoping matters: a form block also contains the badges of the words listed
    further down, so a document-wide badge scan reports the wrong level.
    """
    header = _first(block.xpath("./div[@class='ent_f']"))
    return block if header is None else header


def _parse_word_form(block: HtmlElement, is_primary: bool) -> dict[str, Any]:
    form = _text(_first(block.xpath("./div[@class='ent_w']")))
    word_id = None
    for node in block.xpath(".//div[starts-with(@id,'ufn_')] | .//a[starts-with(@id,'inflcall_')]"):
        word_id = parse_int((node.get("id") or "").split("_")[-1])
        if word_id is not None:
            break

    readings: list[dict[str, Any]] = []
    distribution = None
    reading_cell = _first(block.xpath("./div[@class='ent_r']"))
    if reading_cell is not None:
        for anchor in reading_cell.xpath("./a"):
            reading = _squash(anchor)
            if reading:
                readings.append({"reading": reading, "href": _clean_href(anchor.get("href"))})
        distribution = _rich_line(_first(reading_cell.xpath("./span[@class='ent_mostcommon']")))

    senses: list[dict[str, Any]] = []
    sense_scope = _first(block.xpath("./div[@class='ent_m']"))
    if sense_scope is not None:
        senses = _parse_senses(sense_scope)

    return {
        "form": form,
        "is_primary": is_primary,
        "word_id": word_id,
        "readings": readings,
        "reading_distribution": distribution,
        "senses": senses,
        "usefulness_level": _badge_level(_badge_scope(block), "ufn"),
        "form_usage": _parse_form_usage(block),
    }


def _parse_word_page(tree: HtmlElement, url: str) -> dict[str, Any]:
    segments = _path_segments(url)
    surface = segments[1] if len(segments) > 1 else None
    entity = _first(tree.xpath("//div[@class='entity']"))
    if entity is None:
        raise ValueError(f"kanshudo word page without an entity block: {url}")

    # One block per surface form, in page order. The first is the headword, the
    # rest are the alternative forms that the old regex mispaired or dropped.
    blocks = entity.xpath("./div[div[@class='ent_w']]")
    if not blocks:
        raise ValueError(f"kanshudo word page without any surface form: {url}")
    forms = [_parse_word_form(block, is_primary=index == 0) for index, block in enumerate(blocks)]

    usefulness = _parse_word_usefulness(blocks[0])
    primary = forms[0]
    primary_senses = primary["senses"]

    record: dict[str, Any] = {
        "surface": surface,
        "headword": primary["form"],
        "head_note": _rich_line(_first(tree.xpath("//div[@class='ent_head']"))),
        "forms": forms,
        "senses": primary_senses,
        "part_of_speech": ", ".join(primary_senses[0]["parts_of_speech"]) if primary_senses else None,
        "primary_gloss": _joined_rich(primary_senses[0]["glosses"]) if primary_senses else None,
        "usefulness": usefulness,
        "useful_expressions": _parse_useful_expressions(tree),
        "example_sentences": _parse_sentences(tree),
        "component_kanji": _parse_kanjirows(tree),
    }
    record["_provenance"] = build_provenance_map(
        source=SITE_ID,
        source_url=url,
        factual_fields=[
            "surface",
            "headword",
            "head_note",
            "forms",
            "senses",
            "part_of_speech",
            "primary_gloss",
            "component_kanji",
            "useful_expressions",
        ],
        authored_fields=[
            "usefulness",
            "example_sentences",
            "forms[].usefulness_level",
            "component_kanji[].usefulness_level",
        ],
    )
    return record


# --- component collections ----------------------------------------------------


_CNAME_NUMBER = re.compile(r"^(\d+)\s*[.。]?\s*")


def _parse_component_box(box: HtmlElement, stroke_count: int | None) -> dict[str, Any]:
    anchor = _first(box.xpath(".//a[contains(@class,'comp')]"))
    if anchor is None:
        raise ValueError("kanshudo component box without a component anchor")
    name_node = _first(box.xpath(".//div[@class='cname']"))
    name = _own_text(name_node).replace(" ", " ").strip()
    radical_number = None
    match = _CNAME_NUMBER.match(name)
    if match:
        radical_number = int(match.group(1))
        name = name[match.end() :].strip()
    return {
        "character": _squash(anchor) or None,
        "href": _clean_href(anchor.get("href")),
        "radical_number": radical_number,
        "name": name or None,
        "stroke_count": stroke_count,
        "variants": [
            _link(variant) for variant in box.xpath(".//a[contains(@class,'kanjilink')]")
        ],
    }


def _parse_component_index(tree: HtmlElement, url: str) -> dict[str, Any]:
    segments = _path_segments(url)
    slug = segments[1] if len(segments) > 1 else ""
    components: list[dict[str, Any]] = []
    for clist in tree.xpath("//div[@class='clist']"):
        stroke_count: int | None = None
        for node in clist:
            classes = _class_tokens(node)
            if "scount" in classes:
                stroke_count = parse_int(_own_text(node))
                continue
            if "cbox" in classes:
                components.append(_parse_component_box(node, stroke_count))
    if not components:
        raise ValueError(f"kanshudo component index without any component box: {url}")

    record = {
        "collection": COMPONENT_COLLECTION_ALIASES.get(slug, slug) or None,
        "title": _text(_first(tree.xpath("//h1"))),
        "components": components,
        "component_count": len(components),
        "_provenance": build_provenance_map(
            source=SITE_ID,
            source_url=url,
            factual_fields=["collection", "title", "components", "component_count"],
        ),
    }
    return record


# --- collections --------------------------------------------------------------


_DECLARED_COUNT = re.compile(r"\((?P<count>[\d,]+)\s*kanji\)")


def _is_group_heading(node: HtmlElement) -> bool:
    """True for the subsection headings of a collection panel.

    Most collections use ``h4``. The usefulness collections use
    ``div.title_h4`` instead, which is why every usefulness band came out as a
    null title and the 2,136 kanji could not be attributed to a level.
    """
    tag = node.tag if isinstance(node.tag, str) else ""
    if tag in {"h3", "h4", "h5"}:
        return True
    return tag == "div" and "title_h4" in _class_tokens(node)


def _parse_collection_panel(panel: HtmlElement) -> list[dict[str, Any]]:
    """One group per heading, not one group per panel.

    A single ``div.infopanel`` holds several headed subsections, so keeping the
    first heading and fusing every roster underneath it labelled 170 characters
    "N4 1-100 (100 kanji)" and 1,136 characters "N1 1-100". A heading with no
    roster of its own is the panel's parent label (the usefulness level, the JLPT
    band) and is carried onto the groups it introduces.
    """
    groups: list[dict[str, Any]] = []
    parent_title: str | None = None
    title: str | None = None
    used = True
    for node in panel.iter():
        if not isinstance(node.tag, str):
            continue
        if _is_group_heading(node):
            if not used and title is not None:
                # The previous heading introduced no roster of its own, so it is
                # the label of the whole panel rather than of one roster.
                parent_title = title
            title = _one_line(_own_text(node))
            used = False
            continue
        characters = [
            _link(anchor)
            for anchor in node.xpath("./span[@class='kanji']/a[starts-with(@href,'/kanji/')]")
        ]
        if not characters:
            continue
        declared = _DECLARED_COUNT.search(title or "")
        groups.append(
            {
                "title": title,
                "parent_title": parent_title,
                "declared_count": _int_from(declared.group("count")) if declared else None,
                "characters": characters,
            }
        )
        used = True
    return groups


def _parse_collection_index(tree: HtmlElement, url: str) -> dict[str, Any]:
    segments = _path_segments(url)
    slug = segments[1]
    groups: list[dict[str, Any]] = []
    for panel in tree.xpath("//div[contains(@class,'infopanel')]"):
        groups.extend(_parse_collection_panel(panel))
    sets = [
        _link(anchor)
        for anchor in tree.xpath(f"//a[starts-with(@href,'/collections/{slug}/')]")
    ]
    # Distinct characters, because the variant panels of a collection such as
    # jinmeiyo_kanji relist characters that its main panels already listed, and
    # summing the rosters reported 1,782 kanji for a page that lists 1,074.
    distinct = unique_list(
        character["surface"]
        for group in groups
        for character in group["characters"]
        if character["surface"]
    )
    record = {
        "collection": slug,
        "title": _text(_first(tree.xpath("//h1"))),
        "kanji_groups": groups,
        "kanji_count": len(distinct),
        "sets": unique_list(sets),
        "_provenance": build_provenance_map(
            source=SITE_ID,
            source_url=url,
            factual_fields=["collection", "title", "kanji_groups", "kanji_count", "sets"],
        ),
    }
    return record


def _parse_collection_set(tree: HtmlElement, url: str) -> list[dict[str, Any]]:
    """One record per row: these sets are the vocabulary corpus of the mirror."""
    segments = _path_segments(url)
    slug, set_id = segments[1], segments[2]
    collection_title = _text(_first(tree.xpath("//h1")))
    set_title = _text(_first(tree.xpath("//div[contains(@class,'bodyarea')]//h4")))
    size_note = _collapsed(_rich_of(_first(tree.xpath("//div[contains(@class,'keymessage')]"))))

    identity = {
        "collection": slug,
        "set_id": set_id,
        "collection_title": collection_title,
        "set_title": set_title,
        "set_size": _int_from(size_note.text),
        "set_size_note": size_note.to_json(),
    }
    factual_common = [
        "collection",
        "set_id",
        "collection_title",
        "set_title",
        "set_size",
        "set_size_note",
    ]

    records: list[dict[str, Any]] = []
    for row in tree.xpath("//div[starts-with(@id,'jukugo_')]"):
        record = {"record_type": "word", **identity, **_parse_jukugo_row(row)}
        record["_provenance"] = build_provenance_map(
            source=SITE_ID,
            source_url=url,
            factual_fields=[
                *factual_common,
                "record_type",
                "word_id",
                "surface",
                "reading",
                "senses",
                "gloss_repeats_previous_row",
                "jlpt_level",
                "pitch_pattern",
                "audio_kana",
                "withheld_detail",
            ],
            authored_fields=["usefulness_level"],
        )
        records.append(record)

    for row in _parse_kanjirows(tree):
        record = {"record_type": "kanji", **identity, **row}
        record["_provenance"] = build_provenance_map(
            source=SITE_ID,
            source_url=url,
            factual_fields=[
                *factual_common,
                "record_type",
                "character",
                "kanji_id",
                "depth",
                "parent",
                "on_readings",
                "kun_readings",
                "meanings",
                "mnemonic_available",
            ],
            authored_fields=["usefulness_level"],
        )
        records.append(record)

    if not records:
        raise ValueError(f"kanshudo collection set with no rows: {url}")
    return records


# --- entry point --------------------------------------------------------------


def parse(tree: HtmlElement, url: str, page_type: str) -> dict[str, Any] | list[dict[str, Any]]:
    if page_type in CHARACTER_PAGES:
        return _parse_character_page(tree, url, page_type)
    if page_type == PAGE_WORD:
        return _parse_word_page(tree, url)
    if page_type == PAGE_COMPONENT_INDEX:
        return _parse_component_index(tree, url)
    if page_type == PAGE_COLLECTION_INDEX:
        return _parse_collection_index(tree, url)
    if page_type == PAGE_COLLECTION_SET:
        return _parse_collection_set(tree, url)
    raise ValueError(f"kanshudo has no parser for page type {page_type!r}")
