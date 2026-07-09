"""Smart decks - study a whole set at once instead of adding items one by one.

A deck is either a *content* set (all hiragana, all katakana, all kana, JLPT-N5
kanji, all kanji, common words, all words) whose items are enrolled as cards on
demand, or a *filter* over the user's existing cards (favorites, the ones they
struggle with). Enrolling is idempotent; the daily new-card limit still paces how
many actually surface in review.
"""

from __future__ import annotations

from dataclasses import dataclass

from django.db.models import Count, Q
from django.utils import timezone

from dictionary.models import Kana, Kanji, Word

from .models import Card, ItemType, State


@dataclass(frozen=True)
class DeckSpec:
    id: str
    title: str
    subtitle: str
    icon: str
    kind: str  # "content" | "filter"
    item_type: str | None = None


CATALOG: list[DeckSpec] = [
    DeckSpec("hiragana", "Hiragana", "The full ひらがな syllabary", "あ", "content", ItemType.KANA),
    DeckSpec("katakana", "Katakana", "The full カタカナ syllabary", "ア", "content", ItemType.KANA),
    DeckSpec("kana", "All kana", "Hiragana + katakana", "か", "content", ItemType.KANA),
    DeckSpec(
        "kanji_n5", "JLPT N5 kanji", "The beginner kanji set", "水", "content", ItemType.KANJI
    ),
    DeckSpec(
        "kanji_all", "All kanji", "Every kanji in the dictionary", "漢", "content", ItemType.KANJI
    ),
    DeckSpec(
        "words_common", "Common words", "The everyday vocabulary", "語", "content", ItemType.WORD
    ),
    DeckSpec("words_all", "All words", "The whole dictionary", "本", "content", ItemType.WORD),
    DeckSpec("favorites", "Favorites", "Everything you starred", "★", "filter"),
    DeckSpec("struggling", "Struggling", "The ones you keep missing", "🔥", "filter"),
]

_BY_ID = {d.id: d for d in CATALOG}


def deck_by_id(deck_id: str) -> DeckSpec | None:
    return _BY_ID.get(deck_id)


def _universe(spec: DeckSpec):
    """The dictionary rows a content deck enrolls (a queryset), else None."""
    match spec.id:
        case "hiragana":
            return Kana.objects.filter(script=Kana.Script.HIRAGANA)
        case "katakana":
            return Kana.objects.filter(script=Kana.Script.KATAKANA)
        case "kana":
            return Kana.objects.all()
        case "kanji_n5":
            return Kanji.objects.filter(jlpt=5)
        case "kanji_all":
            return Kanji.objects.all()
        case "words_common":
            return Word.objects.filter(is_common=True)
        case "words_all":
            return Word.objects.all()
    return None


def deck_cards(user, spec: DeckSpec):
    """The user's cards belonging to this deck."""
    qs = Card.objects.filter(user=user)
    match spec.id:
        case "hiragana":
            return qs.filter(item_type=ItemType.KANA, kana__script=Kana.Script.HIRAGANA)
        case "katakana":
            return qs.filter(item_type=ItemType.KANA, kana__script=Kana.Script.KATAKANA)
        case "kana":
            return qs.filter(item_type=ItemType.KANA)
        case "kanji_n5":
            return qs.filter(item_type=ItemType.KANJI, kanji__jlpt=5)
        case "kanji_all":
            return qs.filter(item_type=ItemType.KANJI)
        case "words_common":
            return qs.filter(item_type=ItemType.WORD, word__is_common=True)
        case "words_all":
            return qs.filter(item_type=ItemType.WORD)
        case "favorites":
            return qs.filter(favorite=True)
        case "struggling":
            return qs.filter(lapses__gte=1)
    return qs.none()


def enroll(user, spec: DeckSpec, limit: int = 20000) -> int:
    """Create cards for every deck item the user doesn't have yet (idempotent).
    Returns how many rows were attempted (existing ones are skipped by the DB)."""
    universe = _universe(spec)
    if universe is None:  # filter decks operate on existing cards
        return 0
    field = {ItemType.KANA: "kana", ItemType.KANJI: "kanji", ItemType.WORD: "word"}[spec.item_type]
    now = timezone.now()
    rows = [
        Card(user=user, item_type=spec.item_type, due=now, state=State.NEW, **{field: obj})
        for obj in universe.iterator()
    ][:limit]
    if rows:
        Card.objects.bulk_create(rows, ignore_conflicts=True)  # unique (user,item) skips dups
    return len(rows)


def deck_stats(user, spec: DeckSpec, now=None) -> dict:
    now = now or timezone.now()
    cards = deck_cards(user, spec)
    # One conditional aggregate instead of three separate COUNT queries.
    agg = cards.aggregate(
        enrolled=Count("id"),
        studied=Count("id", filter=~Q(state=State.NEW)),
        due=Count("id", filter=Q(due__lte=now) & ~Q(state=State.NEW)),
    )
    universe = _universe(spec)
    total = universe.count() if universe is not None else agg["enrolled"]
    return {
        "id": spec.id,
        "title": spec.title,
        "subtitle": spec.subtitle,
        "icon": spec.icon,
        "kind": spec.kind,
        "total": total,
        "enrolled": agg["enrolled"],
        "studied": agg["studied"],
        "due": agg["due"],
    }


def all_deck_stats(user) -> list[dict]:
    now = timezone.now()
    return [deck_stats(user, spec, now) for spec in CATALOG]


_PREFETCH = ["word__forms", "word__senses__glosses", "kanji__meanings"]


def deck_queue(user, spec: DeckSpec, now=None, new_limit=None) -> dict:
    """Deck-scoped review session: everything due in the deck + a per-session
    batch of new cards. Like the global queue, the new-card count is a batch, not
    a daily ceiling; `new_limit` pulls more on demand. See `build_queue`."""
    now = now or timezone.now()
    profile = getattr(user, "profile", None)
    new_per_session = profile.new_cards_per_day if profile else 15
    take = min(new_per_session if new_limit is None else max(0, new_limit), 500)

    base = (
        deck_cards(user, spec).select_related("word", "kanji", "kana").prefetch_related(*_PREFETCH)
    )
    due = base.due(now)
    new_base = base.new()
    new = new_base.order_by("created_at")[:take]
    return {
        "due": list(due),
        "new": list(new),
        "counts": {
            "due": due.count(),
            "new_remaining": take,
            "new_available": new_base.count(),
            "new_per_session": new_per_session,
        },
    }
