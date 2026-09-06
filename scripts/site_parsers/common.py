"""Shared DOM-based text extraction for mirrored site parsers.

This module replaces the regex-window approach used by the first generation of
parsers (``compact_block`` plus ``first_group`` plus ``clean_text``). That
approach had three structural defects that this module exists to remove:

1. ``clean_text`` substituted a space for every stripped tag, so any inline
   markup produced artifacts such as ``"loves sakura , or cherry tree ,"`` and
   ``"形声 。"``. Japanese text has no inter-word spaces, so the damage was
   worse in Japanese fields than in English ones.
2. Regex windows spanned sibling nodes, so a scalar field could pick up text
   belonging to the next section, and repeated blocks were truncated to the
   first or last match.
3. Inline semantic markup was flattened. In a WaniKani mnemonic the
   ``<mark title="Radical">`` tags are the meaning: they say which words name a
   radical and which encode a reading. A flat string cannot be reconstructed,
   because the same surface form can appear twice with different roles.

The model here keeps a plain string and a list of role-annotated spans with
character offsets into that string, so both the readable text and its
annotations survive.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field
from typing import Any, Iterable, Iterator

from lxml import html as lxml_html
from lxml.html import HtmlElement

# Elements that do not introduce a text break. Concatenating across these must
# not insert anything, because the source text nodes already carry the spacing
# the author intended.
INLINE_TAGS = frozenset(
    {
        "a", "abbr", "b", "bdi", "bdo", "big", "cite", "code", "data", "del",
        "dfn", "em", "font", "i", "ins", "kbd", "label", "mark", "q",
        "ruby", "rb", "rt", "rp", "rtc",
        "s", "samp", "small", "span", "strong", "sub", "sup", "time", "tt",
        "u", "var", "wbr",
    }
)

# Elements whose content is never text for our purposes.
DROPPED_TAGS = frozenset({"script", "style", "noscript", "template", "svg", "head"})

# Ruby annotation containers. Furigana is extracted separately rather than
# interleaved into the base text, which is what produced readings glued into
# the middle of example sentences.
RUBY_ANNOTATION_TAGS = frozenset({"rt", "rp"})

BLOCK_SEPARATOR = "\n"

# Default mapping from markup to a semantic role. Keyed first on the ``title``
# attribute (WaniKani sets title="Radical" / "Kanji" / "Reading" /
# "Vocabulary"), then on class name fragments.
DEFAULT_TITLE_ROLES = {
    "radical": "radical",
    "kanji": "kanji",
    "reading": "reading",
    "vocabulary": "vocabulary",
}
DEFAULT_CLASS_ROLES = {
    "radical-highlight": "radical",
    "kanji-highlight": "kanji",
    "reading-highlight": "reading",
    "vocabulary-highlight": "vocabulary",
}

_SPACE_RUN = re.compile(r"[ \t 　]+")
_NEWLINE_RUN = re.compile(r"\n{3,}")
_SPACE_AROUND_NEWLINE = re.compile(r"[ \t 　]*\n[ \t 　]*")
_ZERO_WIDTH = re.compile(r"[​-‍﻿]")

# Japanese punctuation and CJK ranges. Used to remove a space that sits between
# two Japanese characters, which can only be an artifact.
_JA_PUNCT = "。、！？「」『』（）〔〕【】・…ー〜：；"


def is_japanese_char(ch: str) -> bool:
    """True for kana, CJK ideographs and Japanese punctuation."""
    if ch in _JA_PUNCT:
        return True
    code = ord(ch)
    return (
        0x3040 <= code <= 0x30FF  # kana
        or 0x3400 <= code <= 0x4DBF  # CJK ext A
        or 0x4E00 <= code <= 0x9FFF  # CJK unified
        or 0xF900 <= code <= 0xFAFF  # CJK compatibility
        or 0x20000 <= code <= 0x2FA1F  # CJK ext B and beyond
        or 0xFF00 <= code <= 0xFF9F  # fullwidth forms
    )


@dataclass(frozen=True)
class TextSpan:
    """A role-annotated slice of a :class:`RichText` plain string."""

    text: str
    role: str
    start: int
    end: int

    def to_json(self) -> dict[str, Any]:
        return {"text": self.text, "role": self.role, "start": self.start, "end": self.end}


@dataclass
class RichText:
    """Plain text plus the semantic annotations that markup carried.

    ``text`` is what a human reads. ``spans`` records, with offsets, which
    slices were marked up and as what. Offsets matter: a mnemonic can contain
    the same word twice with different roles, so a span list without positions
    is still lossy.
    """

    text: str
    spans: list[TextSpan] = field(default_factory=list)

    def __bool__(self) -> bool:
        return bool(self.text)

    def roles(self, role: str) -> list[str]:
        return [span.text for span in self.spans if span.role == role]

    def to_json(self) -> dict[str, Any] | None:
        if not self.text:
            return None
        payload: dict[str, Any] = {"text": self.text}
        if self.spans:
            payload["spans"] = [span.to_json() for span in self.spans]
        return payload

    def to_marked(self) -> str:
        """Inline-marker rendering, useful for prompts and diffing."""
        if not self.spans:
            return self.text
        out: list[str] = []
        cursor = 0
        for span in sorted(self.spans, key=lambda s: (s.start, s.end)):
            if span.start < cursor:
                continue
            out.append(self.text[cursor : span.start])
            out.append(f"[[{span.role}:{self.text[span.start : span.end]}]]")
            cursor = span.end
        out.append(self.text[cursor:])
        return "".join(out)


def normalize_text(value: str) -> str:
    """Collapse whitespace without ever inserting a separator.

    Removes spaces that sit between two Japanese characters, since Japanese
    does not space its words and such a space can only come from markup.
    """
    if not value:
        return ""
    text = _ZERO_WIDTH.sub("", value)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = _SPACE_RUN.sub(" ", text)
    text = _SPACE_AROUND_NEWLINE.sub("\n", text)
    text = _NEWLINE_RUN.sub("\n\n", text)
    text = _strip_interior_japanese_spaces(text)
    return text.strip()


def _strip_interior_japanese_spaces(text: str) -> str:
    if " " not in text:
        return text
    out: list[str] = []
    for index, ch in enumerate(text):
        if ch == " " and 0 < index < len(text) - 1:
            before = text[index - 1]
            after = text[index + 1]
            if is_japanese_char(before) and is_japanese_char(after):
                continue
            # A space before Japanese closing punctuation is always an artifact.
            if after in "。、！？」』）〕】：；":
                continue
            if before in "「『（〔【":
                continue
        out.append(ch)
    return "".join(out)


def _role_for(el: HtmlElement, title_roles: dict[str, str], class_roles: dict[str, str]) -> str | None:
    title = (el.get("title") or "").strip().lower()
    if title in title_roles:
        return title_roles[title]
    classes = (el.get("class") or "").lower()
    for fragment, role in class_roles.items():
        if fragment in classes:
            return role
    if el.tag == "mark":
        return "emphasis"
    if (el.get("lang") or "").lower().startswith("ja"):
        return "ja"
    return None


def rich_text(
    el: HtmlElement | None,
    *,
    title_roles: dict[str, str] | None = None,
    class_roles: dict[str, str] | None = None,
    keep_ruby_annotations: bool = False,
) -> RichText:
    """Extract text from a subtree, preserving role annotations and offsets."""
    if el is None:
        return RichText("")
    title_roles = DEFAULT_TITLE_ROLES if title_roles is None else title_roles
    class_roles = DEFAULT_CLASS_ROLES if class_roles is None else class_roles

    chunks: list[str] = []
    raw_spans: list[tuple[int, int, str]] = []

    def emit(value: str | None) -> None:
        if value:
            chunks.append(value)

    def position() -> int:
        return sum(len(chunk) for chunk in chunks)

    def walk(node: HtmlElement) -> None:
        tag = node.tag if isinstance(node.tag, str) else ""
        if tag in DROPPED_TAGS:
            return
        if not keep_ruby_annotations and tag in RUBY_ANNOTATION_TAGS:
            return
        if tag == "br":
            emit(BLOCK_SEPARATOR)
            emit(node.tail)
            return

        is_block = bool(tag) and tag not in INLINE_TAGS
        if is_block:
            emit(BLOCK_SEPARATOR)

        role = _role_for(node, title_roles, class_roles) if tag else None
        start = position()
        emit(node.text)
        for child in node:
            walk(child)
        if role:
            raw_spans.append((start, position(), role))

        if is_block:
            emit(BLOCK_SEPARATOR)
        emit(node.tail)

    walk(el)
    raw = "".join(chunks)
    plain = normalize_text(raw)
    spans = _remap_spans(raw, plain, raw_spans)
    return RichText(plain, spans)


def _remap_spans(raw: str, plain: str, raw_spans: list[tuple[int, int, str]]) -> list[TextSpan]:
    """Translate offsets from the unnormalized string to the normalized one.

    Normalization only deletes characters or collapses runs, so a left-to-right
    walk that records where each retained raw index landed is exact.
    """
    if not raw_spans:
        return []
    index_map = _build_index_map(raw, plain)
    spans: list[TextSpan] = []
    for start, end, role in raw_spans:
        new_start = _map_forward(index_map, start, len(plain))
        new_end = _map_backward(index_map, end)
        if new_end <= new_start:
            continue
        text = plain[new_start:new_end].strip()
        if not text:
            continue
        offset = plain.find(text, new_start)
        if offset < 0:
            offset = new_start
        spans.append(TextSpan(text=text, role=role, start=offset, end=offset + len(text)))
    # Drop spans fully contained in an identical-role parent span.
    spans.sort(key=lambda s: (s.start, -(s.end - s.start)))
    kept: list[TextSpan] = []
    for span in spans:
        if any(
            other.role == span.role and other.start <= span.start and other.end >= span.end
            for other in kept
        ):
            continue
        kept.append(span)
    return kept


def _build_index_map(raw: str, plain: str) -> list[int]:
    """For each index in ``raw``, the index in ``plain`` it maps to."""
    mapping = [0] * (len(raw) + 1)
    plain_index = 0
    for raw_index, ch in enumerate(raw):
        mapping[raw_index] = plain_index
        if plain_index < len(plain) and plain[plain_index] == ch:
            plain_index += 1
        elif plain_index < len(plain) and ch.isspace() and plain[plain_index].isspace():
            plain_index += 1
    mapping[len(raw)] = plain_index
    return mapping


def _map_forward(mapping: list[int], index: int, limit: int) -> int:
    if index >= len(mapping):
        return limit
    return min(mapping[index], limit)


def _map_backward(mapping: list[int], index: int) -> int:
    if index >= len(mapping):
        return mapping[-1]
    return mapping[index]


def plain_text(el: HtmlElement | None) -> str:
    """DOM-aware plain text with no inserted separators inside inline runs."""
    return rich_text(el).text


def text_or_none(el: HtmlElement | None) -> str | None:
    value = plain_text(el)
    return value or None


def ruby_pairs(el: HtmlElement | None) -> list[dict[str, str]]:
    """Split ruby markup into base and annotation instead of interleaving it."""
    if el is None:
        return []
    pairs: list[dict[str, str]] = []
    for ruby in el.iter("ruby"):
        base_parts: list[str] = []
        annotation_parts: list[str] = []
        if ruby.text:
            base_parts.append(ruby.text)
        for child in ruby:
            tag = child.tag if isinstance(child.tag, str) else ""
            if tag == "rt":
                # Must keep annotations here: this is the node we want.
                annotation_parts.append(rich_text(child, keep_ruby_annotations=True).text)
            elif tag == "rp":
                continue
            else:
                base_parts.append(plain_text(child))
            if child.tail:
                base_parts.append(child.tail)
        base = normalize_text("".join(base_parts))
        annotation = normalize_text("".join(annotation_parts))
        if base:
            pairs.append({"base": base, "reading": annotation or ""})
    return pairs


def text_without_ruby(el: HtmlElement | None) -> str:
    """Base text of a ruby-annotated node, furigana removed."""
    return rich_text(el, keep_ruby_annotations=False).text


def parse_document(html_text: str) -> HtmlElement:
    return lxml_html.fromstring(html_text)


def first(nodes: Iterable[Any]) -> Any | None:
    for node in nodes:
        return node
    return None


def find_section_by_heading(
    tree: HtmlElement,
    heading_text: str,
    *,
    levels: tuple[str, ...] = ("h1", "h2", "h3", "h4", "h5", "h6"),
) -> list[HtmlElement]:
    """Nodes between a heading and the next heading of the same or higher level.

    DOM-scoped replacement for the regex ``compact_block`` window, which read a
    fixed byte count forward and therefore leaked into the next section.
    """
    wanted = heading_text.strip().lower()
    order = {tag: index for index, tag in enumerate(levels)}
    for heading in tree.iter(*levels):
        if plain_text(heading).strip().lower() != wanted:
            continue
        level = order.get(heading.tag, len(levels))
        collected: list[HtmlElement] = []
        for sibling in heading.itersiblings():
            tag = sibling.tag if isinstance(sibling.tag, str) else ""
            if tag in order and order[tag] <= level:
                break
            collected.append(sibling)
        return collected
    return []


def section_rich_text(nodes: list[HtmlElement], **kwargs: Any) -> RichText:
    """Concatenate several sibling nodes into one :class:`RichText`."""
    if not nodes:
        return RichText("")
    wrapper = lxml_html.Element("div")
    for node in nodes:
        wrapper.append(_copy_node(node))
    return rich_text(wrapper, **kwargs)


def _copy_node(node: HtmlElement) -> HtmlElement:
    import copy

    return copy.deepcopy(node)


def parse_int(value: Any) -> int | None:
    if value is None:
        return None
    match = re.search(r"-?\d+", str(value))
    return int(match.group(0)) if match else None


def normalize_jlpt(value: Any) -> str | None:
    """Return an ``N1``..``N5`` string, rejecting out-of-range input."""
    level = parse_int(value)
    if level is None:
        text = str(value or "").strip().upper()
        match = re.fullmatch(r"N([1-5])", text)
        return match.group(0) if match else None
    return f"N{level}" if 1 <= level <= 5 else None


def unique_list(values: Iterable[Any]) -> list[Any]:
    seen: set[str] = set()
    items: list[Any] = []
    for value in values:
        if value is None or value == "" or value == {}:
            continue
        key = repr(value) if not isinstance(value, str) else value
        if key in seen:
            continue
        seen.add(key)
        items.append(value)
    return items


def split_on_japanese_separators(value: str | None) -> list[str]:
    """Split a Japanese enumeration, tolerating trailing 。 and ASCII commas."""
    if not value:
        return []
    items: list[str] = []
    for part in re.split(r"[、・,，／/]\s*", value):
        cleaned = part.strip().strip("。").strip()
        if not cleaned or cleaned.lower() == "none":
            continue
        items.append(cleaned)
    return unique_list(items)


def split_english_glosses(value: str | None) -> list[str]:
    """Split an English gloss blob on commas and semicolons.

    Parenthesised asides are kept attached to their gloss, so
    ``"shill (also as 偽客); seat filler"`` yields two glosses rather than
    splitting inside the parenthesis.
    """
    if not value:
        return []
    items: list[str] = []
    depth = 0
    buffer: list[str] = []
    for ch in value:
        if ch in "([{（【「":
            depth += 1
        elif ch in ")]}）】」":
            depth = max(0, depth - 1)
        if ch in ";,；" and depth == 0:
            items.append("".join(buffer))
            buffer = []
            continue
        buffer.append(ch)
    items.append("".join(buffer))
    return unique_list(item.strip() for item in items if item.strip())


def is_kana(value: str) -> bool:
    return bool(value) and all(0x3040 <= ord(ch) <= 0x30FF or ch == "ー" for ch in value)


def is_single_cjk(value: str) -> bool:
    if len(value) != 1:
        return False
    return unicodedata.category(value) == "Lo" and 0x3400 <= ord(value) <= 0x9FFF


def iter_text_nodes(el: HtmlElement) -> Iterator[str]:
    for node in el.iter():
        tag = node.tag if isinstance(node.tag, str) else ""
        if tag in DROPPED_TAGS:
            continue
        if node.text:
            yield node.text


# --- provenance and licensing -------------------------------------------------

# Whether a field is protectable authored content or plain fact. This drives
# whether a value may ship inside the app or must stay a local reference used
# only as generation input. An LLM paraphrase of protected prose is still a
# derivative work, so paraphrasing does not move a field from one class to the
# other.
LICENSE_FACTUAL = "factual"
LICENSE_AUTHORED_THIRD_PARTY = "authored-third-party"
LICENSE_UNKNOWN = "unknown"

SHIP_ALLOWED = "allowed"
SHIP_REFERENCE_ONLY = "reference-only"


def provenance(
    *,
    source: str,
    source_url: str | None,
    license_class: str = LICENSE_FACTUAL,
    method: str = "dom_parser_v1",
) -> dict[str, Any]:
    """Per-field provenance stamp.

    ``ship`` is derived rather than passed, so a field cannot be marked
    shippable and authored-third-party at the same time.
    """
    return {
        "source": source,
        "source_url": source_url,
        "license_class": license_class,
        "ship": SHIP_REFERENCE_ONLY if license_class != LICENSE_FACTUAL else SHIP_ALLOWED,
        "method": method,
    }


def build_provenance_map(
    *,
    source: str,
    source_url: str | None,
    factual_fields: Iterable[str],
    authored_fields: Iterable[str] = (),
    method: str = "dom_parser_v1",
) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    for name in factual_fields:
        out[name] = provenance(
            source=source, source_url=source_url, license_class=LICENSE_FACTUAL, method=method
        )
    for name in authored_fields:
        out[name] = provenance(
            source=source,
            source_url=source_url,
            license_class=LICENSE_AUTHORED_THIRD_PARTY,
            method=method,
        )
    return out
