"""SRS domain operations - request-free and unit-testable.

Wraps the pure FSRS scheduler (fsrs.py) with persistence: resolving a study item,
creating a Card, applying a review (updating the Card + appending a ReviewLog),
and assembling the daily queue under the user's new-card limit.
"""

from __future__ import annotations

from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from dictionary.models import Kana, Kanji, Word

from .fsrs import EASY, FSRS, NEW
from .models import Card, CardTombstone, ItemType, ReviewLog, State


def scheduler_for(user) -> FSRS:
    profile = getattr(user, "profile", None)
    retention = profile.desired_retention if profile else 0.9
    params = getattr(profile, "fsrs_parameters", None) if profile else None
    # Honor trained per-user weights when present and well-formed (21 floats);
    # otherwise fall back to the FSRS-6 defaults.
    if isinstance(params, list) and len(params) == 21:
        try:
            return FSRS(parameters=[float(p) for p in params], desired_retention=retention)
        except (TypeError, ValueError):
            pass
    return FSRS(desired_retention=retention)


def resolve_item(item_type: str, ref: str):
    """Resolve an (item_type, ref) pair to a dictionary row, or None."""
    if item_type == ItemType.WORD:
        return Word.objects.filter(pk=ref).first() if str(ref).isdigit() else None
    if item_type == ItemType.KANJI:
        return Kanji.objects.filter(literal=ref).first()
    if item_type == ItemType.KANA:
        return Kana.objects.filter(char=ref).first()
    return None


def add_card(user, item_type: str, ref: str) -> tuple[Card | None, bool]:
    """Add a study item for the user (idempotent). Returns (card, created)."""
    item = resolve_item(item_type, ref)
    if item is None:
        return None, False
    field = {ItemType.WORD: "word", ItemType.KANJI: "kanji", ItemType.KANA: "kana"}[item_type]
    card, created = Card.objects.get_or_create(
        user=user,
        item_type=item_type,
        **{field: item},
        defaults={"due": timezone.now(), "state": State.NEW},
    )
    return card, created


def mark_known(user, item_type: str, ref: str, now=None) -> tuple[Card | None, bool]:
    """Add an item the user already knows: seed a mature REVIEW card via FSRS's
    initial-"Easy" state, so it isn't taught as new but still resurfaces later for
    a retention check. Idempotent, and never downgrades a card already in progress.
    Returns (card, created)."""
    item = resolve_item(item_type, ref)
    if item is None:
        return None, False
    field = {ItemType.WORD: "word", ItemType.KANJI: "kanji", ItemType.KANA: "kana"}[item_type]
    now = now or timezone.now()
    card, created = Card.objects.get_or_create(
        user=user,
        item_type=item_type,
        **{field: item},
        defaults={"due": now, "state": State.NEW},
    )
    # Promote a card that hasn't graduated yet - new OR still learning (both read as
    # not-yet-known). Marking "I know these" over kana you'd already tapped into
    # study must flip them to known, not leave them stuck as "seen". An established
    # REVIEW/RELEARNING card is left alone (already known + scheduled; don't reset
    # its history). We deliberately record NO ReviewLog: the user is asserting prior
    # knowledge, not doing a review, so the optimizer isn't fed a synthetic rating.
    if card.state in (State.NEW, State.LEARNING):
        after = scheduler_for(user).review(card.to_memory_state(), EASY, now)
        card.apply_memory_state(after)
        card.save()
    return card, created


def bulk_add(user, items: list[dict], known: bool = False, now=None) -> dict:
    """Create cards for many items in one call. ``known=True`` seeds each at a
    mature state (see :func:`mark_known`); otherwise they enter as new. Lets the
    app bootstrap a level in one gesture ("I know all hiragana"). Idempotent per
    item. Returns a summary count."""
    now = now or timezone.now()
    resolved = 0
    created = 0
    for it in items:
        if known:
            card, was_created = mark_known(user, it["item_type"], it["ref"], now=now)
        else:
            card, was_created = add_card(user, it["item_type"], it["ref"])
        if card is not None:
            resolved += 1
            created += int(was_created)
    return {"requested": len(items), "resolved": resolved, "created": created, "known": known}


def set_status(user, item_type: str, ref: str, target: str, now=None) -> str:
    """Set the user's status for one item to exactly `target` - "none" (not in the
    deck), "learning" (queued to study) or "known" (marked mature). Creates,
    promotes, resets or deletes the card as needed; idempotent. Powers the
    detail-screen Study / I-know-it toggles. Returns the resulting status."""
    item = resolve_item(item_type, ref)
    if item is None:
        return "none"
    field = {ItemType.WORD: "word", ItemType.KANJI: "kanji", ItemType.KANA: "kana"}[item_type]
    if target == "none":
        deleted, _ = Card.objects.filter(user=user, item_type=item_type, **{field: item}).delete()
        if deleted:
            write_tombstone(user, item_type, str(ref), now=now)
        return "none"
    if target == "known":
        mark_known(user, item_type, ref, now=now)
        return "known"
    # learning: make sure the card exists in the new/learning queue. Demote a
    # previously "known" card back to new so toggling Study on is honest.
    now = now or timezone.now()
    card, _ = Card.objects.get_or_create(
        user=user,
        item_type=item_type,
        **{field: item},
        defaults={"due": now, "state": State.NEW},
    )
    if card.state in (State.REVIEW, State.RELEARNING):
        card.state = State.NEW
        card.due = now
        card.save(update_fields=["state", "due", "updated_at"])
    return "learning"


def write_tombstone(user, item_type: str, ref: str, now=None) -> None:
    """Record a card deletion so /study/sync propagates it to other devices
    (delete wins over late reviews). Idempotent; re-deleting refreshes the
    timestamp so newer clients past the old watermark still hear about it."""
    CardTombstone.objects.update_or_create(
        user=user,
        item_type=item_type,
        item_ref=str(ref),
        defaults={"deleted_at": now or timezone.now()},
    )


def card_states(user, item_type: str | None = None) -> dict[str, int]:
    """Compact ``{item_ref: state}`` for the user's cards, so the dictionary can
    mark which items are already seen (learning) or known (review) without
    shipping full card payloads. ``item_ref`` is the word id, kanji literal or
    kana char."""
    qs = Card.objects.filter(user=user).select_related("kanji", "kana")
    if item_type:
        qs = qs.filter(item_type=item_type)
    qs = qs.only("id", "item_type", "state", "word_id", "kanji__literal", "kana__char")
    return {card.item_ref: card.state for card in qs}


@transaction.atomic
def review_card(
    card: Card, rating: int, duration_ms: int = 0, now=None, client_review_id=None
) -> ReviewLog:
    """Apply a rating to a card: advance its FSRS state, persist it, and append a
    ReviewLog. Returns the created log."""
    now = now or timezone.now()
    scheduler = scheduler_for(card.user)

    before = card.to_memory_state()
    elapsed = 0.0
    if before.last_review is not None:
        elapsed = max(0.0, (now - before.last_review).total_seconds() / 86400.0)

    after = scheduler.review(before, rating, now)

    scheduled_days = max(0, (after.due - now).days)
    was_review_or_relearn = card.state in (State.REVIEW, State.RELEARNING)

    card.apply_memory_state(after)
    card.reps += 1
    if rating == 1 and was_review_or_relearn:
        card.lapses += 1
    card.save()

    return ReviewLog.objects.create(
        card=card,
        user=card.user,
        rating=rating,
        client_review_id=client_review_id,
        state_before=before.state,
        stability=after.stability,
        difficulty=after.difficulty,
        elapsed_days=elapsed,
        scheduled_days=scheduled_days,
        duration_ms=max(0, duration_ms),
        reviewed_at=now,
    )


def new_introduced_today(user, now=None) -> int:
    """How many brand-new cards the user has already started today (state_before
    NEW), so the daily new-card limit accounts for progress within the day."""
    now = now or timezone.now()
    start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    return ReviewLog.objects.filter(user=user, state_before=NEW, reviewed_at__gte=start).count()


# One session never needs thousands of due cards materialized + serialized at
# once; cap the payload and expose the true total in `counts` (the client
# refetches when it drains the batch).
_DUE_LIMIT = 500


def queue_counts(user, now=None) -> dict:
    """The queue's headline numbers WITHOUT materializing/serializing any card -
    for StatsView and the due badge, which only need the counts."""
    now = now or timezone.now()
    profile = getattr(user, "profile", None)
    new_per_day = profile.new_cards_per_day if profile else 15
    return {
        "due": Card.objects.filter(user=user).due(now).count(),
        "new_remaining": max(0, new_per_day - new_introduced_today(user, now)),
        "new_per_day": new_per_day,
    }


def build_queue(user, now=None, new_limit=None) -> dict:
    """Assemble the review session: everything due now, plus a batch of new cards.

    The new-card count is a *per-session* batch (``new_cards_per_day`` on the
    profile - the historical field name), NOT a hard daily ceiling: opening a
    session always offers a fresh batch, and the client can pull the rest on
    demand via ``new_limit`` (the "Study more" action - see ``QueueView``). This
    is deliberate: the app lets people keep studying rather than walling them off
    with "that's it for today". ``counts.new_available`` is the total pool of
    new cards, so the client knows whether more remain."""
    now = now or timezone.now()
    profile = getattr(user, "profile", None)
    new_per_session = profile.new_cards_per_day if profile else 15
    take = min(new_per_session if new_limit is None else max(0, new_limit), _DUE_LIMIT)

    prefetch = ["word__forms", "word__senses__glosses", "kanji__meanings"]
    due_qs = (
        Card.objects.filter(user=user)
        .due(now)
        .select_related("word", "kanji", "kana")
        .prefetch_related(*prefetch)
    )
    new_base = Card.objects.filter(user=user).new()
    new_qs = (
        new_base.select_related("word", "kanji", "kana")
        .prefetch_related(*prefetch)
        .order_by("created_at")[:take]
    )
    return {
        "due": list(due_qs[:_DUE_LIMIT]),
        "new": list(new_qs),
        "counts": {
            "due": due_qs.count(),
            "new_remaining": take,
            "new_available": new_base.count(),
            "new_per_session": new_per_session,
        },
    }


def review_sessions(user) -> list[list[tuple[int, object]]]:
    """Each card's reviews, chronologically, as (rating, reviewed_at) - the input
    the FSRS optimizer replays."""
    logs = (
        ReviewLog.objects.filter(user=user)
        .order_by("card_id", "reviewed_at")
        .values_list("card_id", "rating", "reviewed_at")
    )
    by_card: dict[int, list[tuple[int, object]]] = {}
    for card_id, rating, when in logs:
        by_card.setdefault(card_id, []).append((rating, when))
    return list(by_card.values())


def optimize_readiness(user) -> dict:
    from django.conf import settings

    reviews = ReviewLog.objects.filter(user=user).count()
    min_reviews = settings.FSRS_OPTIMIZE_MIN_REVIEWS
    profile = getattr(user, "profile", None)
    return {
        "reviews": reviews,
        "min_reviews": min_reviews,
        "ready": reviews >= min_reviews,
        "using_custom_parameters": bool(getattr(profile, "fsrs_parameters", None)),
    }


def optimize_user(user, min_reviews: int | None = None) -> dict:
    """Fit and (if it beats defaults) persist per-user FSRS weights. Returns a
    report; does nothing until the review threshold is met."""
    from django.conf import settings

    from .optimize import optimize

    if min_reviews is None:
        min_reviews = settings.FSRS_OPTIMIZE_MIN_REVIEWS

    readiness = optimize_readiness(user)
    if readiness["reviews"] < min_reviews:
        return {"ran": False, "reason": "not_enough_reviews", **readiness}

    retention = getattr(getattr(user, "profile", None), "desired_retention", 0.9)
    result = optimize(review_sessions(user), retention)

    if result["improved"]:
        profile = user.profile
        profile.fsrs_parameters = result["parameters"]
        profile.save(update_fields=["fsrs_parameters"])

    return {"ran": True, **readiness, **result}


def export_tsv(user, lang: str = "en") -> str:
    """The user's deck as Anki-importable TSV (front⇥back⇥tags). Anki imports TSV
    natively, so this lowers switching cost with no proprietary .apkg tooling."""
    cards = (
        Card.objects.filter(user=user)
        .select_related("word", "kanji", "kana")
        .prefetch_related("word__forms", "word__senses__glosses", "kanji__meanings")
        .order_by("item_type", "id")
    )
    lines = ["#separator:tab", "#html:false", "#columns:Front\tBack\tTags"]
    for c in cards:
        front = _front(c)
        back = _back(c, lang)
        tags = f"jibiki::{c.item_type}"
        lines.append(f"{_clean(front)}\t{_clean(back)}\t{tags}")
    return "\n".join(lines) + "\n"


def _front(card) -> str:
    if card.word_id:
        return card.word.headword
    if card.kanji_id:
        return card.kanji.literal
    return card.kana.char if card.kana_id else card.item_ref


def _back(card, lang: str) -> str:
    if card.word_id:
        reading = card.word.primary_reading
        # Use the prefetched senses cache (.first() would fire a fresh query).
        meaning = next(iter(card.word.senses.all()), None)
        gloss = ""
        if meaning:
            glosses = [g.text for g in meaning.glosses.all() if g.lang == lang] or [
                g.text for g in meaning.glosses.all()
            ]
            gloss = "; ".join(glosses[:3])
        return f"{reading} - {gloss}" if reading and reading != card.word.headword else gloss
    if card.kanji_id:
        readings = " ".join([*card.kanji.kun_readings, *card.kanji.on_readings][:4])
        meanings = "; ".join(
            m.text for m in card.kanji.meanings.all() if m.lang == lang
        ) or "; ".join(m.text for m in card.kanji.meanings.all()[:3])
        return f"{readings} - {meanings}"
    return card.kana.romaji if card.kana_id else ""


def _clean(s: str) -> str:
    # Tabs/newlines would break the TSV row; collapse them.
    return (s or "").replace("\t", " ").replace("\n", " ").strip()


def streak_days(user, now=None) -> int:
    """Consecutive days (ending today or yesterday) with at least one review."""
    now = now or timezone.now()
    # A streak longer than this is implausible; bounding the window keeps /stats
    # from transferring a lifetime of timestamps on every call.
    window_start = now - timedelta(days=400)
    dates = (
        ReviewLog.objects.filter(user=user, reviewed_at__gte=window_start)
        .values_list("reviewed_at", flat=True)
        .order_by("-reviewed_at")
    )
    review_days = {timezone.localtime(dt).date() for dt in dates}
    if not review_days:
        return 0
    today = timezone.localtime(now).date()
    # Allow the streak to be "alive" if the user reviewed today OR yesterday.
    cursor = today if today in review_days else today - timedelta(days=1)
    if cursor not in review_days:
        return 0
    count = 0
    while cursor in review_days:
        count += 1
        cursor -= timedelta(days=1)
    return count
