"""Dictionary search - the query planner behind GET /dict/search.

Kept request-free and unit-testable. It decides, from the shape of the query,
whether the user typed Japanese (match surface forms) or a Latin gloss (match
translated meanings), and ranks results the way a good dictionary does: exact
before prefix before substring, common words before rare ones.
"""

from __future__ import annotations

import unicodedata
from itertools import zip_longest

from django.db.models import Case, IntegerField, Q, Value, When

from .models import Gloss, Name, NameTranslation, Word, WordForm
from .romaji import romaji_to_hiragana

# Unicode blocks that mark a query as Japanese input.
_HIRAGANA = (0x3040, 0x309F)
_KATAKANA = (0x30A0, 0x30FF)


def _is_cjk_character(character: str) -> bool:
    # Unicode character names cover Extension A, supplementary-plane extensions
    # and compatibility ideographs without a BMP-only range or surrogate split.
    return unicodedata.name(character, "").startswith(
        ("CJK UNIFIED IDEOGRAPH-", "CJK COMPATIBILITY IDEOGRAPH-")
    )


def is_japanese(text: str) -> bool:
    for ch in text:
        cp = ord(ch)
        if (
            _HIRAGANA[0] <= cp <= _HIRAGANA[1]
            or _KATAKANA[0] <= cp <= _KATAKANA[1]
            or _is_cjk_character(ch)
        ):
            return True
    return False


def _dedupe(word_ids: list[int], limit: int) -> list[int]:
    seen: set[int] = set()
    out: list[int] = []
    for wid in word_ids:
        if wid not in seen:
            seen.add(wid)
            out.append(wid)
            if len(out) >= limit:
                break
    return out


def _japanese_word_ids(q: str, limit: int) -> list[int]:
    """Match Japanese surface forms, exact → prefix → substring, commons first."""
    ordered: list[int] = []
    for lookup in ("exact", "istartswith", "icontains"):
        qs = (
            WordForm.objects.filter(word__canonical_word__isnull=True, **{f"text__{lookup}": q})
            .exclude(
                word__provenance__has_key="source_status",
                word__provenance__source_status__in=[
                    "upstream_not_in_snapshot",
                    "legacy_merged_entry",
                ],
            )
            .order_by("-is_common", "order")
            .values_list("word_id", flat=True)[: limit * 4]
        )
        ordered.extend(qs)
        if len(set(ordered)) >= limit:
            break
    return _dedupe(ordered, limit)


def _gloss_word_ids(q: str, lang: str, limit: int) -> list[int]:
    """Match translated glosses in the requested language, falling back to English
    so a French user still finds an entry that only has an English gloss."""
    langs = [lang] if lang == "en" else [lang, "en"]
    ordered: list[int] = []
    # English dictionaries write verbs as "to eat". That exact infinitive is
    # more relevant to "eat" than prefix "eating" or substring "weather".
    tiers = [
        Q(language__in=langs, text__iexact=q),
        Q(language="en", text__iexact=f"to {q}"),
        Q(language__in=langs, text__istartswith=q),
        Q(language__in=langs, text__icontains=q),
    ]
    for match in tiers:
        qs = (
            Gloss.objects.filter(
                match,
                sense__word__canonical_word__isnull=True,
            )
            .exclude(
                sense__word__provenance__has_key="source_status",
                sense__word__provenance__source_status__in=[
                    "upstream_not_in_snapshot",
                    "legacy_merged_entry",
                ],
            )
            .select_related("sense")
            .order_by("sense__word__freq_rank")
            .values_list("sense__word_id", flat=True)[: limit * 6]
        )
        ordered.extend(qs)
        if len(set(ordered)) >= limit:
            break
    return _dedupe(ordered, limit)


def search_words(q: str, *, lang: str = "en", limit: int = 25) -> list[Word]:
    """Return ranked Word rows for a free-text query. Preserves rank order via an
    explicit CASE so the DB doesn't reshuffle the carefully-ordered id list."""
    q = (q or "").strip()
    if not q or limit <= 0:
        return []

    if is_japanese(q):
        ids = _japanese_word_ids(q, limit)
    else:
        kana = romaji_to_hiragana(q)
        surfaces = _japanese_word_ids(kana, limit) if kana else []
        glosses = _gloss_word_ids(q, lang, limit)
        # French "gare" and "ou" are also valid romaji. Preserve both ranked
        # interpretations, even when one alone would fill the result page.
        ids = _dedupe(
            [pk for pair in zip_longest(surfaces, glosses) for pk in pair if pk is not None], limit
        )
    if not ids:
        return []

    rank = Case(
        *[When(pk=pk, then=Value(i)) for i, pk in enumerate(ids)],
        output_field=IntegerField(),
    )
    return list(
        Word.objects.filter(pk__in=ids)
        .prefetch_related("forms", "senses__glosses", "senses__notes")
        .annotate(_rank=rank)
        .order_by("_rank")
    )


def search_names(q: str, *, lang: str = "en", limit: int = 12) -> list[Name]:
    """Bound both name matches before loading their archival metadata.

    An OR spanning names and translations forced a full catalogue join and
    DISTINCT over large JSON columns. The first N IDs of their union must be
    among the first N IDs of each individual set.
    """
    q = q.strip()
    if not q or limit <= 0:
        return []
    surface_ids = (
        Name.objects.filter(Q(kanji__icontains=q) | Q(reading__icontains=q))
        .order_by("pk")
        .values_list("pk", flat=True)[:limit]
    )
    translated_ids = (
        NameTranslation.objects.filter(
            language__in=[lang] if lang == "en" else [lang, "en"], text__icontains=q
        )
        .order_by("name_id")
        .values_list("name_id", flat=True)
        .distinct()[:limit]
    )
    ids = sorted(set(surface_ids) | set(translated_ids))[:limit]
    return list(Name.objects.filter(pk__in=ids).prefetch_related("localized_names").order_by("pk"))


def kanji_in(text: str) -> list[str]:
    """The distinct CJK characters in a string, in order - used to break a word
    into its constituent kanji for the entry detail's kanji breakdown."""
    out: list[str] = []
    seen: set[str] = set()
    for ch in text:
        if _is_cjk_character(ch) and ch not in seen:
            seen.add(ch)
            out.append(ch)
    return out


__all__ = ["Q", "is_japanese", "kanji_in", "search_words"]
