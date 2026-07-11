"""Offline sync - replay the client's outbox, return the server's delta.

The review log is the source of truth; a card's FSRS state is derived. Reviews
that arrive in chronological order take the normal ``review_card`` path; a
review older than the card's ``last_review`` (multi-device, delayed outbox) is
inserted into the log and the card is recomputed as a pure fold over its full
log ordered by ``(reviewed_at, client_review_id)`` - every replica converges
to the same state regardless of sync order, and no rating is ever discarded.

Known divergence, accepted: initial conditions living outside the log (a card
seeded mature by "I know this", a demote-reset via set_status) are not
reconstructed by the fold - it restarts from NEW over the logged reviews only.
A fold only runs on out-of-order replay, stays deterministic, and FSRS
reconverges within a few reviews; completeness of the log (what the optimizer
trains on) is never affected.

Non-review ops (status toggles, favorites, votes…) are last-write-wins,
applied in ``performed_at`` order and acked through ``SyncedOp`` so redelivery
is idempotent even for non-idempotent payloads.
"""

from __future__ import annotations

from datetime import timedelta

from django.db import transaction
from django.db.models import Max
from django.utils import timezone
from django.utils.translation import gettext
from rest_framework import serializers as drf_serializers

from accounts.serializers import ProfileSerializer

from . import services
from .fsrs import MemoryState
from .models import Card, CardTombstone, ItemType, ReviewLog, State, SyncedOp

# Client clocks can drift; what matters is per-card monotonic order, not wall
# accuracy. Timestamps from the future are clamped to roughly "now".
MAX_CLOCK_SKEW = timedelta(minutes=2)

OP_KINDS = (
    "set_status",
    "favorite",
    "bulk_add",
    "deck_enroll",
    "profile_patch",
    "mnemonic_vote",
    "mnemonic_save",
    "mnemonic_choose",
    "mnemonic_deck_enroll",
    "mnemonic_deck_apply",
)


class OpRejected(Exception):
    """An op that must not be retried - acked to the client with a reason."""


@transaction.atomic
def apply_sync(user, data: dict) -> dict:
    """Apply one sync request. Returns the response payload with ``cards`` as
    model instances (the view serializes them)."""
    now = timezone.now()
    cursor = data.get("last_synced_at")
    mode = data.get("mode", "sync")

    if mode == "preview":
        return _empty_response(user, now, cloud=_cloud_status(user))
    if mode == "replace_cloud":
        if cursor is not None:
            raise drf_serializers.ValidationError(
                {
                    "last_synced_at": gettext(
                        "Cloud replacement requires an initial sync."
                    )
                }
            )
        _clear_study_cloud(user)

    applied_ops, rejected_ops = _apply_ops(user, data.get("ops") or [], now)
    applied_reviews, rejected_reviews = _apply_reviews(user, data.get("reviews") or [], now)

    delta_cards, deleted = _delta(user, cursor)
    from accounts.models import UserProfile

    profile, _ = UserProfile.objects.get_or_create(user=user)
    return {
        "synced_at": now,
        "applied_review_ids": applied_reviews,
        "rejected": rejected_reviews,
        "applied_op_ids": applied_ops,
        "rejected_ops": rejected_ops,
        "cards": delta_cards,
        "deleted": deleted,
        "profile": ProfileSerializer(profile).data,
        "cloud": _cloud_status(user),
    }


def _cloud_status(user) -> dict:
    card_at = Card.objects.filter(user=user).aggregate(value=Max("updated_at"))["value"]
    review_at = ReviewLog.objects.filter(user=user).aggregate(value=Max("reviewed_at"))["value"]
    changed_at = max((value for value in (card_at, review_at) if value), default=None)
    return {
        "cards": Card.objects.filter(user=user).count(),
        "reviews": ReviewLog.objects.filter(user=user).count(),
        "changed_at": changed_at,
    }


def _empty_response(user, now, *, cloud: dict) -> dict:
    from accounts.models import UserProfile

    profile, _ = UserProfile.objects.get_or_create(user=user)
    return {
        "synced_at": now,
        "applied_review_ids": [],
        "rejected": [],
        "applied_op_ids": [],
        "rejected_ops": [],
        "cards": [],
        "deleted": [],
        "profile": ProfileSerializer(profile).data,
        "cloud": cloud,
    }


def _clear_study_cloud(user) -> None:
    ReviewLog.objects.filter(user=user).delete()
    Card.objects.filter(user=user).delete()
    CardTombstone.objects.filter(user=user).delete()
    SyncedOp.objects.filter(user=user).delete()


# ── ops ──────────────────────────────────────────────────────────────────────


def _apply_ops(user, ops: list[dict], now) -> tuple[list[str], list[dict]]:
    applied: list[str] = []
    rejected: list[dict] = []
    for op in sorted(ops, key=lambda o: (o["performed_at"], str(o["client_op_id"]))):
        op_id = op["client_op_id"]
        if SyncedOp.objects.filter(user=user, client_op_id=op_id).exists():
            applied.append(str(op_id))  # duplicate delivery - ack, don't re-apply
            continue
        performed_at = min(op["performed_at"], now + MAX_CLOCK_SKEW)
        try:
            with transaction.atomic():
                _apply_op(user, op["kind"], op.get("payload") or {}, performed_at)
                SyncedOp.objects.create(user=user, client_op_id=op_id)
            applied.append(str(op_id))
        except OpRejected as exc:
            rejected.append({"id": str(op_id), "reason": str(exc)})
        except (KeyError, TypeError, ValueError, drf_serializers.ValidationError):
            # Malformed payload: rejecting (not erroring) lets the client drop
            # the op instead of retrying it forever.
            rejected.append({"id": str(op_id), "reason": "invalid"})
    return applied, rejected


def _apply_op(user, kind: str, payload: dict, performed_at) -> None:
    if kind == "set_status":
        services.set_status(
            user, payload["item_type"], payload["ref"], payload["status"], now=performed_at
        )
    elif kind == "favorite":
        card, _ = services.add_card(user, payload["item_type"], payload["ref"])
        if card is None:
            raise OpRejected("unknown_item")
        card.favorite = bool(payload["value"])
        card.save(update_fields=["favorite", "updated_at"])
    elif kind == "bulk_add":
        items = payload["items"]
        if not isinstance(items, list):
            raise OpRejected("invalid")
        context = {
            field: payload.get(field, "")
            for field in ("source_sentence", "source_url", "source_title", "source_media")
        }
        if any(context.values()):
            for item in items:
                card, _ = services.add_card(
                    user,
                    item["item_type"],
                    item["ref"],
                    context=context,
                )
                if card is None:
                    raise OpRejected("unknown_item")
        else:
            services.bulk_add(user, items, known=bool(payload.get("known")), now=performed_at)
    elif kind == "deck_enroll":
        from .decks import deck_by_id, enroll

        spec = deck_by_id(payload["deck_id"])
        if spec is None:
            raise OpRejected("unknown_deck")
        enroll(user, spec)
    elif kind == "profile_patch":
        from accounts.models import UserProfile

        profile, _ = UserProfile.objects.get_or_create(user=user)
        serializer = ProfileSerializer(profile, data=payload, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
    elif kind.startswith("mnemonic_"):
        _apply_mnemonic_op(user, kind, payload)
    else:
        raise OpRejected("unknown_kind")


def _apply_mnemonic_op(user, kind: str, payload: dict) -> None:
    from mnemonics.models import DeckStatus, Mnemonic, MnemonicDeck, MnemonicStatus
    from mnemonics.services import apply_pack, cast_vote, enroll_deck, set_choice, set_save

    if kind in ("mnemonic_vote", "mnemonic_save", "mnemonic_choose"):
        qs = Mnemonic.objects.filter(pk=payload["mnemonic_id"])
        if kind == "mnemonic_choose":
            qs = qs.exclude(status__in=[MnemonicStatus.HIDDEN, MnemonicStatus.REMOVED])
        else:
            qs = qs.filter(status=MnemonicStatus.VISIBLE)
        mnemonic = qs.first()
        if mnemonic is None:
            raise OpRejected("unknown_mnemonic")
        if kind == "mnemonic_vote":
            cast_vote(user, mnemonic, int(payload["value"]))
        elif kind == "mnemonic_save":
            set_save(user, mnemonic, bool(payload["value"]))
        else:
            set_choice(user, mnemonic)
    elif kind in ("mnemonic_deck_enroll", "mnemonic_deck_apply"):
        deck = MnemonicDeck.objects.filter(pk=payload["deck_id"], status=DeckStatus.VISIBLE).first()
        if deck is None:
            raise OpRejected("unknown_deck")
        if kind == "mnemonic_deck_enroll":
            enroll_deck(user, deck)
        else:
            apply_pack(user, deck)
    else:
        raise OpRejected("unknown_kind")


# ── reviews ──────────────────────────────────────────────────────────────────


def _apply_reviews(user, reviews: list[dict], now) -> tuple[list[str], list[dict]]:
    applied: list[str] = []
    rejected: list[dict] = []
    for r in sorted(reviews, key=lambda x: (x["reviewed_at"], str(x["client_review_id"]))):
        rid = r["client_review_id"]
        if ReviewLog.objects.filter(user=user, client_review_id=rid).exists():
            applied.append(str(rid))  # duplicate delivery - already in the log
            continue
        reviewed_at = min(r["reviewed_at"], now + MAX_CLOCK_SKEW)
        item_type, ref = r["item_type"], r["ref"]

        card = _card_for(user, item_type, ref)
        if card is None:
            if CardTombstone.objects.filter(
                user=user, item_type=item_type, item_ref=str(ref)
            ).exists():
                # Delete wins: the card was removed on another device and not
                # re-added; the client drops the review and the local card.
                rejected.append({"id": str(rid), "reason": "deleted"})
                continue
            # A review proves intent to study - create the missing card.
            card, _ = services.add_card(user, item_type, ref)
            if card is None:
                rejected.append({"id": str(rid), "reason": "unknown_item"})
                continue

        with transaction.atomic():
            if card.last_review is None or reviewed_at >= card.last_review:
                services.review_card(
                    card,
                    r["rating"],
                    r.get("duration_ms", 0),
                    now=reviewed_at,
                    client_review_id=rid,
                )
            else:
                _insert_and_fold(card, r, reviewed_at)
        applied.append(str(rid))
    return applied, rejected


def _card_for(user, item_type: str, ref: str) -> Card | None:
    """Resolve a card by its natural key - mirrors Card.item_ref."""
    qs = Card.objects.filter(user=user, item_type=item_type)
    if item_type == ItemType.WORD:
        return qs.filter(word_id=ref).first() if str(ref).isdigit() else None
    if item_type == ItemType.KANJI:
        return qs.filter(kanji__literal=ref).select_related("kanji").first()
    return qs.filter(kana__char=ref).select_related("kana").first()


def _insert_and_fold(card: Card, r: dict, reviewed_at) -> None:
    ReviewLog.objects.create(
        card=card,
        user=card.user,
        rating=r["rating"],
        client_review_id=r["client_review_id"],
        state_before=r.get("state_before") or State.NEW,  # rewritten by the fold
        duration_ms=max(0, r.get("duration_ms", 0)),
        reviewed_at=reviewed_at,
    )
    fold_card_state(card)


def fold_card_state(card: Card) -> None:
    """Recompute the card as a pure fold over its full review log - the
    multi-device convergence rule. Postgres sorts NULL client_review_ids last,
    so online-born logs tie-break deterministically after replayed ones."""
    scheduler = services.scheduler_for(card.user)
    logs = list(card.logs.order_by("reviewed_at", "client_review_id", "id"))

    state = MemoryState()
    reps = lapses = 0
    for log in logs:
        before_state = state.state
        elapsed = 0.0
        if state.last_review is not None:
            elapsed = max(0.0, (log.reviewed_at - state.last_review).total_seconds() / 86400.0)
        state = scheduler.review(state, log.rating, log.reviewed_at)
        reps += 1
        if log.rating == 1 and before_state in (State.REVIEW, State.RELEARNING):
            lapses += 1

        # Keep each row's snapshot fold-consistent (the optimizer only reads
        # rating + reviewed_at, but the snapshots should not lie).
        snapshot = {
            "state_before": before_state,
            "stability": state.stability,
            "difficulty": state.difficulty,
            "elapsed_days": elapsed,
            "scheduled_days": max(0, (state.due - log.reviewed_at).days),
        }
        if any(getattr(log, k) != v for k, v in snapshot.items()):
            ReviewLog.objects.filter(pk=log.pk).update(**snapshot)

    card.apply_memory_state(state)
    card.reps = reps
    card.lapses = lapses
    card.save()


# ── delta ────────────────────────────────────────────────────────────────────


def _delta(user, cursor) -> tuple[list[Card], list[dict]]:
    """Everything the client is missing: cards touched after its watermark
    (including by this very request) and deletions. A null cursor is the
    initial download - full deck, no tombstones."""
    cards = Card.objects.filter(user=user).select_related("kanji", "kana")
    if cursor is None:
        return list(cards), []
    changed = list(cards.filter(updated_at__gt=cursor))
    tombstones = CardTombstone.objects.filter(user=user, deleted_at__gt=cursor)
    # A tombstoned item with a live card again was re-added - don't delete it.
    deleted = [
        {"item_type": t.item_type, "ref": t.item_ref}
        for t in tombstones
        if _card_for(user, t.item_type, t.item_ref) is None
    ]
    return changed, deleted
