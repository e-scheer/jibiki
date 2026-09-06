"""Parser for mirrored WaniKani subject pages (kanji, vocabulary, radicals).

What this module replaces
------------------------

The first generation of this parser lived in two places:
``parse_site_snapshots.parse_wanikani`` (kanji only, regex windows over the raw
HTML) and ``extract_mirrored_content.parse_wanikani_vocabulary_page`` /
``parse_wanikani_radical_page`` (lxml, but with substring class matching). Both
routed prose through ``clean_text``, which substituted a space for every
stripped tag. That single line produced three families of defect, all of them
reproduced against the mirror:

* role annotations lost: ``<mark title="Radical">tree</mark>`` became ``tree``,
  so nothing recorded that "tree", "grass" and "woman" are the three radicals
  of 桜 while "sakura" is the kanji meaning,
* punctuation artifacts: ``"who loves sakura , or cherry tree ,"`` and
  ``"Sakura ( さくら )"``,
* words split mid-token: ``"man"+"ga"`` became ``"man ga"``, ``"drop"+"s"``
  became ``"drop s"``.

Everything textual here therefore goes through ``common.rich_text``, which is
DOM-aware, never inserts a separator inside an inline run, and keeps the mark
roles as offset-annotated spans.

Structural notes about the markup, measured over the mirror
----------------------------------------------------------

* Sections are addressable by id: ``section-components``, ``section-meaning``,
  ``section-reading``, ``section-context``, ``section-amalgamations``,
  ``section-similar-subjects``. Section ids are used instead of byte windows or
  heading walks, so a field can never pick up the next section's text.
* Class matching is always whole-token. Substring matching was the cause of
  three separate defects: ``subject-character`` matched the
  ``subject-character__content`` and ``subject-character__info`` wrappers
  (3 rows per grid card), ``reading-with-audio__audio-item`` matched the
  ``reading-with-audio__audio-items`` container (a phantom leading voice), and
  ``subject-section__text`` matched ``subject-section__text--grouped``
  (context sentences leaking into mnemonics).
* Mnemonic and hint blocks hold one to three paragraphs. Only reading the first
  one truncated 桜's siblings mid-thought, often on a dangling colon.
* The alternatives label is ``Alternative`` when there is exactly one and
  ``Alternatives`` when there are several. The old regex only matched the
  plural, so single-alternative pages silently lost the field. Meanings are
  read by iterating the meaning blocks and keying on their own title instead.
* WaniKani publishes no stroke count, no JLPT tag, no school grade and no
  frequency rank. The WaniKani level is the only difficulty signal here, and
  it is present on every subject page.

Licensing
---------

Mnemonics, hints, explanations, context sentences, collocations, mnemonic
illustrations and pronunciation recordings are Tofugu editorial content. They
are classified ``authored_fields`` so provenance marks them
``ship: "reference-only"``: they exist as local reference, never in the app.

WaniKani radical *names* ("Beggar", "Death Star") are WaniKani coinages rather
than facts, so on a radical page the name fields are authored, and on a kanji
page the radical decomposition is split into a factual list of component glyphs
plus an authored list of their WaniKani names.

Everything WaniKani draws or coins follows the name to the authored side:

* ``character_image`` is an illustration hosted by WaniKani, drawn for a radical
  that has no Unicode codepoint at all. It is WaniKani artwork, not a fact about
  the writing system, so it is authored on every page type.
* ``character_image_label`` is that illustration's ``aria-label``, and on all 15
  image radicals it is byte-identical to the coined ``subject_name``
  ("Death Star"). Stamping it factual re-exported the exact string the paragraph
  above forbids, so it is authored too.
* the same coinage reaches a kanji page through its component cards, so
  ``radical_combination`` carries only the component glyph and its position.
  The component slug, name, page url and illustration are all WaniKani coinage
  or WaniKani assets, so they live in ``radical_component_names``, joined back
  to the decomposition by ``position``. A component with no codepoint keeps a
  factual row with ``character: null`` and ``presence: "image_only"``, so the
  arity of the decomposition survives without inventing a glyph.
"""

from __future__ import annotations

import re
import unicodedata
import urllib.parse
from typing import Any

from lxml.html import HtmlElement

from site_parsers.common import (
    RichText,
    build_provenance_map,
    first,
    plain_text,
    section_rich_text,
    split_english_glosses,
    split_on_japanese_separators,
    text_or_none,
    unique_list,
)

SITE_ID = "wanikani"

PAGE_TYPE_KANJI = "kanji"
PAGE_TYPE_VOCABULARY = "vocabulary"
PAGE_TYPE_RADICALS = "radicals"
PAGE_TYPE_SUBJECT_INDEX = "subject_index"

EXTRACTABLE = frozenset(
    {PAGE_TYPE_KANJI, PAGE_TYPE_VOCABULARY, PAGE_TYPE_RADICALS, PAGE_TYPE_SUBJECT_INDEX}
)

SUBJECT_SEGMENTS = ("kanji", "vocabulary", "radicals")

HEADING_TAGS = ("h1", "h2", "h3", "h4", "h5", "h6")

READING_TYPES = {
    "onyomi": "onyomi",
    "kunyomi": "kunyomi",
    "nanori": "nanori",
}

_APOSTROPHES = "’ʼ‘'`"
_LEVEL_HREF = re.compile(r"/level/(\d+)")
_LEVEL_TEXT = re.compile(r"Level\s+(\d+)", re.IGNORECASE)


class WanikaniParseError(ValueError):
    """Raised when the markup does not match what this parser was written for.

    Raising is deliberate. The previous pipeline wrapped every site parser in
    ``except Exception: return {}``, so thousands of pages silently produced
    empty records. The caller is expected to record the failure instead.
    """


# --- url routing --------------------------------------------------------------


def _path_segments(url: str) -> list[str]:
    path = urllib.parse.unquote(urllib.parse.urlsplit(url).path or "/")
    return [segment for segment in path.strip("/").split("/") if segment]


def infer_page_type(url: str) -> str:
    segments = _path_segments(url)
    if not segments:
        return "other"
    head = segments[0].lower()
    if head not in SUBJECT_SEGMENTS:
        return "other"
    if len(segments) == 1:
        return PAGE_TYPE_SUBJECT_INDEX
    if len(segments) == 2:
        return head
    return "other"


def dedupe_key(url: str, page_type: str) -> str:
    """Entity identity, ignoring query strings and encoding differences.

    WaniKani urls percent-encode the subject, so the same entity can arrive as
    ``/kanji/%E6%A1%9C`` or ``/kanji/桜``, and a trailing slash or a tracking
    query must not create a second entity.
    """
    segments = _path_segments(url)
    if page_type == PAGE_TYPE_SUBJECT_INDEX and segments:
        return f"{SITE_ID}:index:{segments[0].lower()}"
    if page_type in {PAGE_TYPE_KANJI, PAGE_TYPE_VOCABULARY, PAGE_TYPE_RADICALS} and len(segments) >= 2:
        slug = unicodedata.normalize("NFC", segments[1])
        return f"{SITE_ID}:{page_type}:{slug}"
    normalized = "/".join(unicodedata.normalize("NFC", segment) for segment in segments)
    return f"{SITE_ID}:other:/{normalized}"


def _slug_from_url(url: str) -> str | None:
    segments = _path_segments(url)
    if len(segments) < 2:
        return None
    return unicodedata.normalize("NFC", segments[1])


# --- dom helpers --------------------------------------------------------------


def _class_predicate(token: str) -> str:
    return f"contains(concat(' ', normalize-space(@class), ' '), ' {token} ')"


def _by_class(root: HtmlElement | None, token: str, tag: str = "*") -> list[HtmlElement]:
    """Whole-token class lookup.

    Substring ``contains(@class, ...)`` is never used here: BEM element and
    modifier classes share prefixes, and every substring match in the previous
    parser produced duplicated or misattributed rows.
    """
    if root is None:
        return []
    return root.xpath(f".//{tag}[{_class_predicate(token)}]")


def _first_by_class(root: HtmlElement | None, token: str, tag: str = "*") -> HtmlElement | None:
    return first(_by_class(root, token, tag))


def _has_class(el: HtmlElement, token: str) -> bool:
    return token in (el.get("class") or "").split()


def _section(tree: HtmlElement, section_id: str) -> HtmlElement | None:
    return first(tree.xpath(f".//*[@id='{section_id}']"))


def _attr(el: HtmlElement | None, name: str) -> str | None:
    if el is None:
        return None
    value = (el.get(name) or "").strip()
    return value or None


def _assert_no_heading_inside(nodes: list[HtmlElement], field: str, url: str) -> None:
    """Structural guard against a section label bleeding into a data field.

    The previous generation collected text by walking siblings after a heading,
    so a nested ``<h3>Hints</h3>`` ended up inside the mnemonic and a
    ``div.heading`` label ended up inside a component list. Here every text
    field is read from an element chosen by class, so a heading can only appear
    inside it if the markup changed shape, which must be a failure rather than a
    silently polluted value.

    Note that a prefix check against a list of known label strings, which is
    what the audit suggested, is not usable on this corpus: 釈 has the primary
    meaning "Explanation", 解釈 likewise, and the reading mnemonic of 治 opens
    with "Alternative ways to cure yourself ...". All three are legitimate
    values that such a check rejects.
    """
    for node in nodes:
        if node.xpath("|".join(f".//{tag}" for tag in HEADING_TAGS)):
            raise WanikaniParseError(f"{url}: heading element inside the {field!r} block")
        if node.xpath(f"ancestor::*[{_class_predicate('wk-hint')}]") and "hint" not in field:
            raise WanikaniParseError(f"{url}: {field!r} block sits inside a wk-hint aside")


def _rich_nodes(nodes: list[HtmlElement], field: str, url: str) -> dict[str, Any] | None:
    if not nodes:
        return None
    _assert_no_heading_inside(nodes, field, url)
    return section_rich_text(nodes).to_json()


# --- header -------------------------------------------------------------------


def _level(tree: HtmlElement, url: str) -> int:
    container = _first_by_class(tree, "subject-page-header__level")
    if container is None:
        raise WanikaniParseError(f"{url}: no subject-page-header__level block")
    for href in container.xpath(".//a/@href"):
        match = _LEVEL_HREF.search(str(href))
        if match:
            return int(match.group(1))
    match = _LEVEL_TEXT.search(plain_text(container))
    if match:
        return int(match.group(1))
    raise WanikaniParseError(f"{url}: level block present but no level number in it")


def _character_of(container: HtmlElement | None) -> dict[str, str | None]:
    """Glyph, or the image that stands in for a radical with no codepoint.

    15 of the 491 mirrored radicals render a ``<wk-character-image>`` because
    they have no Unicode codepoint at all. Emitting ``None`` and nothing else,
    as the previous parser did, was permanent data loss.
    """
    holder = _first_by_class(container, "subject-character__characters-text")
    image = _first_by_class(container, "subject-character__character-image")
    if image is None and holder is not None:
        image = first(holder.iter("wk-character-image"))
    glyph = text_or_none(holder) if holder is not None else None
    return {
        "character": glyph,
        "character_image": _attr(image, "src"),
        "character_image_label": _attr(image, "aria-label"),
    }


def _header(tree: HtmlElement, url: str) -> dict[str, Any]:
    prefix = _first_by_class(tree, "page-header__prefix")
    title = _first_by_class(tree, "page-header__title-text")
    if title is None:
        raise WanikaniParseError(f"{url}: no page-header__title-text, page is not a subject page")
    header = _character_of(prefix)
    header["subject_name"] = text_or_none(title)
    header["level"] = _level(tree, url)
    header["slug"] = _slug_from_url(url)
    if header["character"] is None and header["character_image"] is None:
        # Kanji and vocabulary always carry a glyph; only image radicals may not.
        header["character"] = header["slug"]
    return header


# --- meanings -----------------------------------------------------------------


def _meaning_blocks(section: HtmlElement | None) -> dict[str, str]:
    """Map a meanings block title to its items text.

    Keyed on the block's own ``<h2>`` so that both ``Alternative`` and
    ``Alternatives`` are found, which a fixed-string regex could not do.
    """
    blocks: dict[str, str] = {}
    for block in _by_class(section, "subject-section__meanings"):
        title_el = _first_by_class(block, "subject-section__meanings-title")
        items_el = _first_by_class(block, "subject-section__meanings-items")
        if title_el is None or items_el is None:
            continue
        title = plain_text(title_el).strip()
        if title:
            blocks[title] = plain_text(items_el)
    return blocks


def _meanings(section: HtmlElement | None, url: str) -> dict[str, Any]:
    blocks = _meaning_blocks(section)
    primary = blocks.get("Primary")
    if not primary:
        raise WanikaniParseError(f"{url}: no Primary meaning block")
    alternatives: list[str] = []
    for key in ("Alternative", "Alternatives"):
        alternatives.extend(split_english_glosses(blocks.get(key)))
    return {
        "primary_meaning": primary,
        "alternative_meanings": unique_list(alternatives),
        "word_type": blocks.get("Word Type"),
        "word_types": split_english_glosses(blocks.get("Word Type")),
    }


# --- mnemonics ----------------------------------------------------------------


def _mnemonic_paragraphs(section: HtmlElement) -> list[HtmlElement]:
    return [
        node
        for node in _by_class(section, "subject-section__text", tag="p")
        if not _has_class(node, "subject-section__text--grouped")
    ]


def _mnemonic_image(section: HtmlElement) -> dict[str, str | None] | None:
    image = _first_by_class(section, "subject-mnemonic-image__image")
    if image is None:
        image = first(section.iter("wk-mnemonic-image"))
    if image is None:
        return None
    src = _attr(image, "src")
    if not src:
        return None
    return {"url": src, "description": _attr(image, "aria-label")}


def _mnemonic(
    section: HtmlElement | None,
    *,
    kind: str,
    reading: str | None,
    url: str,
) -> dict[str, Any] | None:
    """One mnemonic record, identified by (kind, reading, language).

    ``docs/CONTENT_PACK.md`` gives a mnemonic the identity
    ``(kind, character, reading, language)``. A flat scalar cannot express that,
    and cannot distinguish "this source has no mnemonic" from "extraction
    failed", which is why ``presence`` is explicit here. The WaniKani corpus is
    English only, so ``language`` is a constant, but it is recorded rather than
    implied: a fallback must never look like content authored in the selected
    language.
    """
    if section is None:
        return None
    paragraphs = _mnemonic_paragraphs(section)
    hints = _by_class(section, "wk-hint__text", tag="p")
    subtitle = _first_by_class(section, "subject-section__subtitle", tag="h3")
    text = _rich_nodes(paragraphs, f"{kind}_mnemonic", url)
    hint = _rich_nodes(hints, f"{kind}_hint", url)
    image = _mnemonic_image(section)
    if text is None and hint is None and image is None:
        return None
    if text and hint and hint["text"] in text["text"]:
        # Mnemonic and hint must be disjoint by construction. The old pipeline
        # captured the Hints aside as part of the mnemonic and then also emitted
        # it as the hint, so the same prose appeared twice in one record.
        raise WanikaniParseError(f"{url}: the {kind} hint is contained in the {kind} mnemonic")
    return {
        "kind": kind,
        "label": text_or_none(subtitle),
        "language": "en",
        "reading": reading,
        "origin": "extracted",
        "presence": "present" if text else "absent",
        "text": text,
        "hint": hint,
        "image": image,
    }


# --- readings -----------------------------------------------------------------


def _normalize_reading_title(value: str) -> str:
    lowered = value.strip().lower()
    for apostrophe in _APOSTROPHES:
        lowered = lowered.replace(apostrophe, "")
    return lowered.replace(" ", "")


def _kanji_readings(section: HtmlElement | None, url: str) -> dict[str, Any]:
    """Per-reading records that keep their type and their primary flag.

    WaniKani marks primacy on the group wrapper
    (``subject-readings__reading--primary``) and it is the single most useful
    bit here: it names the reading the site drills, and it anchors the reading
    mnemonic. Collapsing the three groups into flat lists, as the previous
    parser did, threw it away.
    """
    if section is None:
        raise WanikaniParseError(f"{url}: kanji page with no reading section")
    groups = _by_class(section, "subject-readings__reading", tag="div")
    if not groups:
        raise WanikaniParseError(f"{url}: reading section with no subject-readings__reading blocks")

    readings: list[dict[str, Any]] = []
    by_type: dict[str, list[str]] = {"onyomi": [], "kunyomi": [], "nanori": []}
    primary_type: str | None = None
    for group in groups:
        title_el = first(group.xpath(f".//*[{_class_predicate('subject-readings__reading-title')}]"))
        if title_el is None:
            raise WanikaniParseError(f"{url}: reading block with no title")
        key = _normalize_reading_title(plain_text(title_el))
        reading_type = READING_TYPES.get(key)
        if reading_type is None:
            raise WanikaniParseError(f"{url}: unknown reading type {plain_text(title_el)!r}")
        items_el = first(group.xpath(f".//*[{_class_predicate('subject-readings__reading-items')}]"))
        values = split_on_japanese_separators(plain_text(items_el)) if items_el is not None else []
        is_primary = _has_class(group, "subject-readings__reading--primary")
        if is_primary and primary_type is None:
            primary_type = reading_type
        by_type[reading_type].extend(values)
        for value in values:
            readings.append({"reading": value, "type": reading_type, "primary": is_primary})
    return {
        "readings": readings,
        "on_readings": unique_list(by_type["onyomi"]),
        "kun_readings": unique_list(by_type["kunyomi"]),
        "nanori": unique_list(by_type["nanori"]),
        "primary_reading_type": primary_type,
    }


def _primary_reading(readings: list[dict[str, Any]]) -> str | None:
    for entry in readings:
        if entry.get("primary"):
            return entry.get("reading")
    return None


def _audio_sources(item: HtmlElement) -> list[dict[str, str | None]]:
    sources: list[dict[str, str | None]] = []
    for source in item.iter("source"):
        src = _attr(source, "src")
        if not src:
            continue
        # lxml lowercases attribute names, and WaniKani spells this
        # non-standard attribute content_type rather than type.
        sources.append({"url": src, "content_type": _attr(source, "content_type") or _attr(source, "type")})
    return sources


def _vocabulary_readings(section: HtmlElement | None, url: str) -> dict[str, Any]:
    if section is None:
        raise WanikaniParseError(f"{url}: vocabulary page with no reading section")
    blocks = _by_class(section, "reading-with-audio", tag="div")
    if not blocks:
        raise WanikaniParseError(f"{url}: reading section with no reading-with-audio block")
    readings: list[str] = []
    audio: list[dict[str, Any]] = []
    for block in blocks:
        reading = text_or_none(_first_by_class(block, "reading-with-audio__reading"))
        if reading:
            readings.append(reading)
        voices: list[dict[str, Any]] = []
        # Whole-token match: reading-with-audio__audio-items (the <ul>) contains
        # the singular class as a substring and used to yield a phantom voice.
        for item in _by_class(block, "reading-with-audio__audio-item", tag="li"):
            sources = _audio_sources(item)
            name = text_or_none(_first_by_class(item, "reading-with-audio__voice-actor-name"))
            description = text_or_none(
                _first_by_class(item, "reading-with-audio__voice-actor-description")
            )
            if not (sources or name or description):
                continue
            voices.append({"name": name, "description": description, "sources": sources})
        if reading or voices:
            audio.append({"reading": reading, "voices": voices})
    return {"readings": unique_list(readings), "reading_audio": audio}


# --- subject cards ------------------------------------------------------------

_CARD_KINDS = ("radical", "kanji", "vocabulary")


def _card_kind(card: HtmlElement) -> str | None:
    classes = (card.get("class") or "").split()
    for kind in _CARD_KINDS:
        if f"subject-character--{kind}" in classes:
            return kind
    return None


def _cards(section: HtmlElement | None, url: str) -> list[dict[str, Any]]:
    """Subject cards of a grid or list section, one row per real card.

    The previous xpath matched any descendant whose class *contained*
    ``subject-character``, which also hit ``subject-character__content`` and
    ``subject-character__info``, so one card produced three rows, two of them
    with a null character or a null href. A whole-token match on
    ``subject-character`` selects the card element itself and nothing else.
    """
    if section is None:
        return []
    cards = _by_class(section, "subject-character")
    containers = [
        node
        for node in section.xpath(".//li")
        if _has_class(node, "subject-character-grid__item") or _has_class(node, "subject-list__item")
    ]
    if containers and len(containers) != len(cards):
        raise WanikaniParseError(
            f"{url}: {len(containers)} card containers but {len(cards)} subject-character nodes"
        )
    rows: list[dict[str, Any]] = []
    for card in cards:
        row = _character_of(card)
        href = _attr(card, "href")
        reading = text_or_none(_first_by_class(card, "subject-character__reading"))
        meaning = text_or_none(_first_by_class(card, "subject-character__meaning"))
        kind = _card_kind(card)
        if reading is None and kind in {"kanji", "vocabulary"}:
            # The card title attribute carries the reading for kanji and
            # vocabulary cards, and the WaniKani name for radical cards.
            reading = _attr(card, "title")
        row.update(
            {
                "kind": kind,
                "reading": reading,
                "meaning": meaning,
                "slug": _slug_from_url(href) if href else None,
                "url": href,
            }
        )
        if row["character"] is None and row["character_image"] is None and meaning is None:
            raise WanikaniParseError(f"{url}: subject card with neither character nor meaning")
        rows.append(row)
    return rows


def _split_component_names(cards: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Separate the factual decomposition from everything WaniKani coined.

    A radical glyph is a fact. "Beggar" or "Death Star" is WaniKani editorial
    naming, the ``/radicals/beggar`` slug and url are that same coinage spelled
    as a path, and the illustration is WaniKani artwork. None of them can ship
    with the licence of the decomposition, so the factual row keeps the glyph
    and its position only. 61 components corpus-wide have no codepoint: their
    factual row would otherwise have consisted of nothing but the coinage.

    The two lists are aligned and joined by ``position``, so the authored side
    stays reattachable to the glyph it names without duplicating the coinage
    into the factual side.
    """
    components: list[dict[str, Any]] = []
    names: list[dict[str, Any]] = []
    for position, card in enumerate(cards, start=1):
        glyph = card["character"]
        components.append(
            {
                "position": position,
                "character": glyph,
                # Explicit, so "WaniKani has no glyph for this component" is
                # never read as "extraction lost the glyph".
                "presence": "present" if glyph else "image_only",
            }
        )
        names.append(
            {
                "position": position,
                "slug": card["slug"],
                "name": card["meaning"] or card["character_image_label"],
                "url": card["url"],
                "character_image": card["character_image"],
            }
        )
    return components, names


def _assert_no_coined_card_names(rows: list[dict[str, Any]], field: str, url: str) -> list[dict[str, Any]]:
    """Guard a factual card list against WaniKani coinage.

    Radical cards exist in exactly one place in this corpus, the kanji
    ``section-components`` grid (measured over all 9374 mirrored pages: 4838
    radical cards there, zero anywhere else), and those go through
    ``_split_component_names``. Every other card list holds kanji or vocabulary
    cards, whose meaning is a dictionary gloss rather than a coinage, and holds
    no WaniKani-hosted illustration. If that ever changes, a coined name would
    ship stamped factual, so it has to fail here instead.
    """
    for row in rows:
        if row.get("kind") == "radical" or row.get("character_image") or row.get("character_image_label"):
            raise WanikaniParseError(
                f"{url}: {field!r} holds a WaniKani-coined radical card ({row.get('slug')!r}), "
                "which cannot be stamped factual"
            )
    return rows


# --- context and collocations -------------------------------------------------


def _sentence_pair(container: HtmlElement) -> dict[str, str | None] | None:
    japanese: str | None = None
    english: str | None = None
    for paragraph in container.iter("p"):
        value = text_or_none(paragraph)
        if not value:
            continue
        if (paragraph.get("lang") or "").lower().startswith("ja"):
            japanese = japanese or value
        else:
            english = english or value
    if japanese is None and english is None:
        return None
    return {"japanese": japanese, "english": english}


def _context_sentences(section: HtmlElement | None) -> list[dict[str, str | None]]:
    sentences: list[dict[str, str | None]] = []
    for group in _by_class(section, "subject-section__text--grouped"):
        pair = _sentence_pair(group)
        if pair:
            sentences.append(pair)
    return sentences


def _collocations(section: HtmlElement | None) -> list[dict[str, Any]]:
    """Curated collocations, grouped under their pattern label.

    The pattern label ("ホテルの〜") lives on a tab anchor and is joined to its
    panel through ``aria-controls`` matching the panel id. It appeared in no
    field before, and unlike the collocation strings themselves it is not
    recoverable from any unstructured bucket.
    """
    if section is None:
        return []
    labels: dict[str, str] = {}
    for tab in _by_class(section, "subject-collocations__pattern-name", tag="a"):
        target = _attr(tab, "aria-controls")
        label = text_or_none(tab)
        if target and label:
            labels[target] = label
    groups: list[dict[str, Any]] = []
    for panel in _by_class(section, "subject-collocations__pattern-collocation", tag="li"):
        items: list[dict[str, str | None]] = []
        for holder in _by_class(panel, "context-sentences", tag="div"):
            pair = _sentence_pair(holder)
            if pair:
                items.append(pair)
        if not items:
            continue
        groups.append({"pattern": labels.get(_attr(panel, "id") or ""), "items": items})
    return groups


# --- record assembly ----------------------------------------------------------

_COMMON_FACTUAL = (
    "character",
    "slug",
    "level",
    "subject_name",
    "primary_meaning",
    "alternative_meanings",
    "source_url",
    "page_type",
    "subject_type",
)

# WaniKani draws these and WaniKani names them, on every page type. See the
# Licensing note at the top of this module.
_WANIKANI_ASSETS = (
    "character_image",
    "character_image_label",
)


def _record(
    *,
    url: str,
    page_type: str,
    subject_type: str,
    fields: dict[str, Any],
    factual: tuple[str, ...],
    authored: tuple[str, ...],
) -> dict[str, Any]:
    record = dict(fields)
    record["page_type"] = page_type
    record["subject_type"] = subject_type
    record["source_url"] = url
    _assert_provenance_covers(record, factual=factual, authored=authored, url=url)
    record["_provenance"] = build_provenance_map(
        source=SITE_ID,
        source_url=url,
        factual_fields=factual,
        authored_fields=authored,
    )
    return record


def _assert_provenance_covers(
    record: dict[str, Any],
    *,
    factual: tuple[str, ...],
    authored: tuple[str, ...],
    url: str,
) -> None:
    """Every emitted field is stamped, and every stamp names an emitted field.

    ``site_parsers/__init__`` requires each field group to be declared in the
    returned ``_provenance`` mapping. A field added to a row but forgotten in
    the tuple below ships with no licence at all, which is exactly how the
    subject index came to emit ``kind`` unstamped. The reverse direction matters
    too: a stamp for a field the record does not carry advertises data that is
    not there.
    """
    declared = set(factual) | set(authored)
    both = sorted(set(factual) & set(authored))
    if both:
        raise WanikaniParseError(f"{url}: fields declared factual and authored at once: {both}")
    unstamped = sorted(set(record) - declared)
    if unstamped:
        raise WanikaniParseError(f"{url}: emitted fields with no provenance entry: {unstamped}")
    phantom = sorted(declared - set(record))
    if phantom:
        raise WanikaniParseError(f"{url}: provenance declares fields the record does not carry: {phantom}")


def _parse_kanji(tree: HtmlElement, url: str) -> dict[str, Any]:
    meaning_section = _section(tree, "section-meaning")
    reading_section = _section(tree, "section-reading")
    if meaning_section is None:
        raise WanikaniParseError(f"{url}: kanji page with no section-meaning")

    fields: dict[str, Any] = dict(_header(tree, url))
    fields.update(_meanings(meaning_section, url))
    readings = _kanji_readings(reading_section, url)
    fields.update(readings)

    components, component_names = _split_component_names(
        _cards(_section(tree, "section-components"), url)
    )
    fields["radical_combination"] = components
    fields["radical_component_names"] = component_names
    fields["visually_similar_kanji"] = _assert_no_coined_card_names(
        _cards(_section(tree, "section-similar-subjects"), url), "visually_similar_kanji", url
    )
    fields["found_in_vocabulary"] = _assert_no_coined_card_names(
        _cards(_section(tree, "section-amalgamations"), url), "found_in_vocabulary", url
    )

    mnemonics = [
        entry
        for entry in (
            _mnemonic(meaning_section, kind="meaning", reading=None, url=url),
            _mnemonic(
                reading_section,
                kind="reading",
                reading=_primary_reading(readings["readings"]),
                url=url,
            ),
        )
        if entry is not None
    ]
    fields["mnemonics"] = mnemonics
    fields.pop("word_type", None)
    fields.pop("word_types", None)

    return _record(
        url=url,
        page_type=PAGE_TYPE_KANJI,
        subject_type="kanji",
        fields=fields,
        factual=_COMMON_FACTUAL
        + (
            "readings",
            "on_readings",
            "kun_readings",
            "nanori",
            "primary_reading_type",
            "radical_combination",
            "visually_similar_kanji",
            "found_in_vocabulary",
        ),
        authored=_WANIKANI_ASSETS + ("mnemonics", "radical_component_names"),
    )


def _parse_vocabulary(tree: HtmlElement, url: str) -> dict[str, Any]:
    meaning_section = _section(tree, "section-meaning")
    reading_section = _section(tree, "section-reading")
    context_section = _section(tree, "section-context")
    if meaning_section is None:
        raise WanikaniParseError(f"{url}: vocabulary page with no section-meaning")

    fields: dict[str, Any] = dict(_header(tree, url))
    fields.update(_meanings(meaning_section, url))
    fields.update(_vocabulary_readings(reading_section, url))
    fields["component_subjects"] = _assert_no_coined_card_names(
        _cards(_section(tree, "section-components"), url), "component_subjects", url
    )
    fields["context_sentences"] = _context_sentences(context_section)
    fields["collocations"] = _collocations(context_section)

    first_reading = fields["readings"][0] if fields["readings"] else None
    mnemonics = [
        entry
        for entry in (
            _mnemonic(meaning_section, kind="meaning", reading=None, url=url),
            _mnemonic(reading_section, kind="reading", reading=first_reading, url=url),
        )
        if entry is not None
    ]
    fields["mnemonics"] = mnemonics

    return _record(
        url=url,
        page_type=PAGE_TYPE_VOCABULARY,
        subject_type="vocabulary",
        fields=fields,
        factual=_COMMON_FACTUAL
        + (
            "word_type",
            "word_types",
            "readings",
            "component_subjects",
        ),
        authored=_WANIKANI_ASSETS
        + ("mnemonics", "reading_audio", "context_sentences", "collocations"),
    )


def _parse_radical(tree: HtmlElement, url: str) -> dict[str, Any]:
    meaning_section = _section(tree, "section-meaning")
    if meaning_section is None:
        raise WanikaniParseError(f"{url}: radical page with no section-meaning")

    fields: dict[str, Any] = dict(_header(tree, url))
    fields.update(_meanings(meaning_section, url))
    fields.pop("word_type", None)
    fields.pop("word_types", None)
    fields["found_in_kanji"] = _assert_no_coined_card_names(
        _cards(_section(tree, "section-amalgamations"), url), "found_in_kanji", url
    )
    entry = _mnemonic(meaning_section, kind="meaning", reading=None, url=url)
    fields["mnemonics"] = [entry] if entry is not None else []

    # A WaniKani radical name is a WaniKani coinage, not a dictionary fact, so
    # the name fields move to the authored side on this page type. The 15 image
    # radicals carry that same coinage twice more, as the illustration's
    # aria-label and as the illustration itself, so those go with it.
    return _record(
        url=url,
        page_type=PAGE_TYPE_RADICALS,
        subject_type="radical",
        fields=fields,
        factual=(
            "character",
            "slug",
            "level",
            "source_url",
            "page_type",
            "subject_type",
            "found_in_kanji",
        ),
        authored=_WANIKANI_ASSETS
        + ("subject_name", "primary_meaning", "alternative_meanings", "mnemonics"),
    )


def _parse_subject_index(tree: HtmlElement, url: str) -> list[dict[str, Any]]:
    """One record per card on a ``/kanji``, ``/vocabulary`` or ``/radicals`` index.

    No index page exists in the current mirror (all 9374 mirrored files are
    subject pages), so this path is written defensively: it emits the cards it
    finds, carries the level from the nearest preceding "Level N" heading, and
    raises when it finds no card at all rather than returning an empty list
    that would read as a successfully empty page.
    """
    section = urllib.parse.unquote(urllib.parse.urlsplit(url).path or "/").strip("/").lower()
    level: int | None = None
    rows: list[dict[str, Any]] = []
    for node in tree.iter():
        tag = node.tag if isinstance(node.tag, str) else ""
        if tag in {"h1", "h2", "h3", "h4", "h5", "h6"}:
            match = _LEVEL_TEXT.search(plain_text(node))
            if match:
                level = int(match.group(1))
            continue
        if tag and _has_class(node, "subject-character"):
            row = _character_of(node)
            href = _attr(node, "href")
            row.update(
                {
                    "kind": _card_kind(node),
                    "reading": text_or_none(_first_by_class(node, "subject-character__reading"))
                    or _attr(node, "title"),
                    "meaning": text_or_none(_first_by_class(node, "subject-character__meaning")),
                    "slug": _slug_from_url(href) if href else None,
                    "url": href,
                    "level": level,
                    "index_section": section,
                }
            )
            rows.append(row)
    if not rows:
        raise WanikaniParseError(f"{url}: subject index with no subject cards")
    records: list[dict[str, Any]] = []
    for row in rows:
        kind = row.get("kind") or section.rstrip("s")
        # On a radicals index the card meaning is the WaniKani coinage, exactly
        # as on the radical page itself, so it cannot be stamped factual here
        # either. Kanji and vocabulary card meanings are dictionary glosses.
        coined = kind == "radical"
        factual = (
            "character",
            "kind",
            "slug",
            "level",
            "reading",
            "url",
            "index_section",
            "source_url",
            "page_type",
            "subject_type",
        )
        authored = _WANIKANI_ASSETS
        if coined:
            authored = authored + ("meaning",)
        else:
            factual = factual + ("meaning",)
        records.append(
            _record(
                url=url,
                page_type=PAGE_TYPE_SUBJECT_INDEX,
                subject_type=kind,
                fields=row,
                factual=factual,
                authored=authored,
            )
        )
    return records


# --- interface ----------------------------------------------------------------


def is_shell(tree: HtmlElement, url: str) -> bool:
    """True when the file is a crawl artifact rather than the requested page.

    The "Sign up" string is on every single page: it is sitemap chrome, not a
    login wall, so it is deliberately not a signal here. A real login wall
    posts to ``/login``, and a real subject page always carries a
    ``subject-page-header`` block.

    The title signals are only consulted when that header is absent, so a real
    subject page whose title happened to contain "404" cannot be discarded. No
    page in the mirror does, but a substring test on a title is a weak signal
    and must never outrank the structure of the page.
    """
    has_subject_header = _first_by_class(tree, "subject-page-header") is not None
    lowered = plain_text(first(tree.iter("title"))).lower()
    if not has_subject_header and ("page not found" in lowered or "404" in lowered):
        return True
    if tree.xpath(".//form[contains(@action, '/login')]") and not has_subject_header:
        return True
    page_type = infer_page_type(url)
    if page_type in {PAGE_TYPE_KANJI, PAGE_TYPE_VOCABULARY, PAGE_TYPE_RADICALS}:
        return not has_subject_header
    if page_type == PAGE_TYPE_SUBJECT_INDEX:
        return not _by_class(tree, "subject-character")
    return False


def parse(tree: HtmlElement, url: str, page_type: str) -> dict[str, Any] | list[dict[str, Any]]:
    if page_type == PAGE_TYPE_KANJI:
        return _parse_kanji(tree, url)
    if page_type == PAGE_TYPE_VOCABULARY:
        return _parse_vocabulary(tree, url)
    if page_type == PAGE_TYPE_RADICALS:
        return _parse_radical(tree, url)
    if page_type == PAGE_TYPE_SUBJECT_INDEX:
        return _parse_subject_index(tree, url)
    raise WanikaniParseError(f"{url}: page type {page_type!r} is not extractable for {SITE_ID}")


def to_marked(payload: dict[str, Any] | None) -> str | None:
    """Inline-marker rendering of a RichText payload, for prompts and diffs."""
    if not payload:
        return None
    from site_parsers.common import TextSpan

    spans = [TextSpan(**span) for span in payload.get("spans", [])]
    return RichText(payload.get("text", ""), spans).to_marked()
