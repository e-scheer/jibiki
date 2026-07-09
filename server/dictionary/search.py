"""Dictionary search - the query planner behind GET /dict/search.

Kept request-free and unit-testable. It decides, from the shape of the query,
whether the user typed Japanese (match surface forms) or a Latin gloss (match
translated meanings), and ranks results the way a good dictionary does: exact
before prefix before substring, common words before rare ones.
"""

from __future__ import annotations

from django.db.models import Case, IntegerField, Q, Value, When

from .models import Gloss, Word, WordForm

# Unicode blocks that mark a query as Japanese input.
_HIRAGANA = (0x3040, 0x309F)
_KATAKANA = (0x30A0, 0x30FF)
_CJK = (0x4E00, 0x9FFF)


def is_japanese(text: str) -> bool:
    for ch in text:
        cp = ord(ch)
        if (
            _HIRAGANA[0] <= cp <= _HIRAGANA[1]
            or _KATAKANA[0] <= cp <= _KATAKANA[1]
            or _CJK[0] <= cp <= _CJK[1]
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
            WordForm.objects.filter(**{f"text__{lookup}": q})
            .order_by("-is_common", "order")
            .values_list("word_id", flat=True)[: limit * 4]
        )
        ordered.extend(qs)
    return _dedupe(ordered, limit)


def _gloss_word_ids(q: str, lang: str, limit: int) -> list[int]:
    """Match translated glosses in the requested language, falling back to English
    so a French user still finds an entry that only has an English gloss."""
    langs = [lang] if lang == "en" else [lang, "en"]
    ordered: list[int] = []
    # Whole-word-ish exact first (a gloss that IS the query), then contains.
    for lookup in ("iexact", "istartswith", "icontains"):
        qs = (
            Gloss.objects.filter(lang__in=langs, **{f"text__{lookup}": q})
            .select_related("sense")
            .order_by("sense__word__freq_rank")
            .values_list("sense__word_id", flat=True)[: limit * 6]
        )
        ordered.extend(qs)
    return _dedupe(ordered, limit)


def search_words(q: str, *, lang: str = "en", limit: int = 25) -> list[Word]:
    """Return ranked Word rows for a free-text query. Preserves rank order via an
    explicit CASE so the DB doesn't reshuffle the carefully-ordered id list."""
    q = (q or "").strip()
    if not q:
        return []

    ids = _japanese_word_ids(q, limit) if is_japanese(q) else _gloss_word_ids(q, lang, limit)
    if not ids:
        return []

    rank = Case(
        *[When(pk=pk, then=Value(i)) for i, pk in enumerate(ids)],
        output_field=IntegerField(),
    )
    return list(
        Word.objects.filter(pk__in=ids)
        .prefetch_related("forms", "senses__glosses")
        .annotate(_rank=rank)
        .order_by("_rank")
    )


def kanji_in(text: str) -> list[str]:
    """The distinct CJK characters in a string, in order - used to break a word
    into its constituent kanji for the entry detail's kanji breakdown."""
    out: list[str] = []
    seen: set[str] = set()
    for ch in text:
        if _CJK[0] <= ord(ch) <= _CJK[1] and ch not in seen:
            seen.add(ch)
            out.append(ch)
    return out


__all__ = ["Q", "is_japanese", "kanji_in", "search_words"]
