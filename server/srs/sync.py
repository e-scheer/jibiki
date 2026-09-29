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
from .models import (
    BoosterGrant,
    BoosterStatus,
    Card,
    CardTombstone,
    CloudReplacement,
    CollectionCard,
    ItemType,
    ReviewLog,
    State,
    SyncedOp,
    SyncFieldClock,
)

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
    "booster_grant",
    "booster_open",
)


class OpRejected(Exception):
    """An op that must not be retried - acked to the client with a reason."""


@transaction.atomic
def apply_sync(user, data: dict) -> dict:
    """Apply one sync request. Returns the response payload with ``cards`` as
    model instances (the view serializes them)."""
    # Serialize a user's outboxes, including first card creation and reward
    # opening, before checking their idempotency ledgers.
    type(user).objects.select_for_update().get(pk=user.pk)
    now = timezone.now()
    cursor = data.get("last_synced_at")
    mode = data.get("mode", "sync")
    replacement_id = data.get("replacement_id") if mode == "replace_cloud" else None
    previous_replacement = None

    if mode == "preview":
        return _empty_response(user, now, cloud=_cloud_status(user))
    if mode == "replace_cloud":
        if cursor is not None:
            raise drf_serializers.ValidationError(
                {"last_synced_at": gettext("Cloud replacement requires an initial sync.")}
            )
        if replacement_id:
            previous_replacement = CloudReplacement.objects.filter(
                user=user, replacement_id=replacement_id
            ).first()
        if previous_replacement is None:
            _clear_study_cloud(user)

    if previous_replacement is not None:
        result = previous_replacement.result
        applied_ops, rejected_ops = result["applied_op_ids"], result["rejected_ops"]
        applied_reviews, rejected_reviews = result["applied_review_ids"], result["rejected"]
    else:
        applied_ops, rejected_ops = _apply_ops(user, data.get("ops") or [], now)
        applied_reviews, rejected_reviews = _apply_reviews(
            user, data.get("reviews") or [], now, allow_deleted=mode == "replace_cloud"
        )
        if replacement_id:
            CloudReplacement.objects.create(
                user=user,
                replacement_id=replacement_id,
                result={
                    "applied_op_ids": applied_ops,
                    "rejected_ops": rejected_ops,
                    "applied_review_ids": applied_reviews,
                    "rejected": rejected_reviews,
                },
            )

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
        "rewards": _rewards_state(user),
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
        "rewards": _rewards_state(user),
    }


def _clear_study_cloud(user) -> None:
    removed = [
        CardTombstone(user=user, item_type=card.item_type, item_ref=card.item_ref)
        for card in Card.objects.filter(user=user).select_related("kanji", "kana")
    ]
    ReviewLog.objects.filter(user=user).delete()
    Card.objects.filter(user=user).delete()
    # Other devices still need deletions after a replacement. A re-added live
    # card takes precedence when the delta is assembled.
    CardTombstone.objects.bulk_create(
        removed,
        update_conflicts=True,
        update_fields=["deleted_at"],
        unique_fields=["user", "item_type", "item_ref"],
    )
    SyncedOp.objects.filter(user=user).delete()
    SyncFieldClock.objects.filter(user=user).delete()
    # "Keep local" replaces the cloud rewards too: the client regenerates
    # booster_grant/booster_open ops from its local state in the same request.
    BoosterGrant.objects.filter(user=user).delete()
    CollectionCard.objects.filter(user=user).delete()


def _ms(dt) -> int | None:
    return None if dt is None else int(dt.timestamp() * 1000)


def _rewards_state(user) -> dict:
    """The full booster/collection state, included in every sync response.
    Small by construction (a handful of grants, at most one collection row per
    catalog card), so a delta cursor would be more machinery than data."""
    return {
        "grants": [
            {
                "grant_id": g.grant_id,
                "source": g.source,
                "milestone": g.milestone,
                "status": g.status,
                "granted_at": _ms(g.granted_at),
                "opened_at": _ms(g.opened_at),
                "cards": g.cards,
            }
            for g in BoosterGrant.objects.filter(user=user).order_by("granted_at")
        ],
        "collection": [
            {
                "card_id": c.card_id,
                "count": c.count,
                "first_obtained_at": _ms(c.first_obtained_at),
            }
            for c in CollectionCard.objects.filter(user=user).order_by("card_id")
        ],
    }


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
                _apply_ordered_op(user, op, performed_at)
                SyncedOp.objects.create(user=user, client_op_id=op_id)
            applied.append(str(op_id))
        except OpRejected as exc:
            rejected.append({"id": str(op_id), "reason": str(exc)})
        except (KeyError, TypeError, ValueError, drf_serializers.ValidationError):
            # Malformed payload: rejecting (not erroring) lets the client drop
            # the op instead of retrying it forever.
            rejected.append({"id": str(op_id), "reason": "invalid"})
    return applied, rejected


def _apply_ordered_op(user, op, performed_at):
    """Track independent preference fields across batches, not just within one upload."""
    kind, payload = op["kind"], op.get("payload") or {}
    if not isinstance(payload, dict):
        raise OpRejected("invalid")
    key = None
    if kind in ("set_status", "favorite"):
        key = f"{kind}:{payload.get('item_type')}:{payload.get('ref')}"
    elif kind in ("mnemonic_vote", "mnemonic_save"):
        key = f"{kind}:{payload.get('mnemonic_id')}"
    elif kind == "mnemonic_choose":
        from mnemonics.services import accessible_for

        mnemonic = accessible_for(user).filter(pk=payload["mnemonic_id"]).first()
        if mnemonic is None:
            raise OpRejected("unknown_mnemonic")
        key = f"choice:{mnemonic.kind}:{mnemonic.character}:{mnemonic.language}:{mnemonic.reading}"
    elif kind == "profile_patch":
        validator = ProfileSerializer(data=payload, partial=True)
        validator.is_valid(raise_exception=True)
        for field, value in validator.validated_data.items():
            _apply_with_clock(user, f"profile:{field}", op, performed_at, {field: value})
        return
    if key is None:
        _apply_op(user, kind, payload, performed_at)
    else:
        _apply_with_clock(user, key, op, performed_at, payload)


def _apply_with_clock(user, key, op, performed_at, payload):
    previous = SyncFieldClock.objects.filter(user=user, key=key).first()
    current_order = (performed_at, str(op["client_op_id"]))
    if previous and current_order <= (previous.performed_at, str(previous.client_op_id)):
        return
    _apply_op(user, op["kind"], payload, performed_at)
    SyncFieldClock.objects.update_or_create(
        user=user,
        key=key,
        defaults={"performed_at": performed_at, "client_op_id": op["client_op_id"]},
    )


def _apply_op(user, kind: str, payload: dict, performed_at) -> None:
    from .serializers import AddCardSerializer, BulkAddSerializer, SetStatusSerializer

    if not isinstance(payload, dict):
        raise OpRejected("invalid")
    if kind == "set_status":
        validator = SetStatusSerializer(data=payload)
        validator.is_valid(raise_exception=True)
        payload = validator.validated_data
        if services.resolve_item(payload["item_type"], payload["ref"]) is None:
            raise OpRejected("unknown_item")
        services.set_status(
            user, payload["item_type"], payload["ref"], payload["status"], now=performed_at
        )
    elif kind == "favorite":
        validator = AddCardSerializer(data=payload)
        validator.is_valid(raise_exception=True)
        value = drf_serializers.BooleanField().run_validation(payload["value"])
        card, _ = services.add_card(user, payload["item_type"], payload["ref"])
        if card is None:
            raise OpRejected("unknown_item")
        card.favorite = value
        card.save(update_fields=["favorite", "updated_at"])
    elif kind == "bulk_add":
        validator = BulkAddSerializer(data=payload)
        validator.is_valid(raise_exception=True)
        context_validator = AddCardSerializer(
            data={**payload, "item_type": "kana", "ref": "context"}
        )
        context_validator.is_valid(raise_exception=True)
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
                if validator.validated_data["known"]:
                    services.mark_known(user, item["item_type"], item["ref"], now=performed_at)
        else:
            services.bulk_add(
                user, items, known=validator.validated_data["known"], now=performed_at
            )
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
    elif kind == "booster_grant":
        _apply_booster_grant(user, payload, performed_at)
    elif kind == "booster_open":
        _apply_booster_open(user, payload, performed_at)
    else:
        raise OpRejected("unknown_kind")


# ── rewards (docs/REWARDS.md) ────────────────────────────────────────────────


def _apply_booster_grant(user, payload: dict, performed_at) -> None:
    grant_id = drf_serializers.CharField(max_length=64).run_validation(payload["grant_id"])
    milestone = drf_serializers.IntegerField(min_value=0, max_value=2147483647).run_validation(
        payload["milestone"]
    )
    source = drf_serializers.CharField(max_length=32).run_validation(
        payload.get("source", "streak_milestone")
    )
    status_value = str(payload.get("status", BoosterStatus.UNOPENED))
    if status_value not in (BoosterStatus.UNOPENED, BoosterStatus.SKIPPED_FULL):
        # "opened" only ever arrives through booster_open.
        raise OpRejected("invalid")
    BoosterGrant.objects.get_or_create(
        user=user,
        grant_id=grant_id,
        defaults={
            "source": source,
            "milestone": milestone,
            "status": status_value,
            "granted_at": performed_at,
        },
    )


def _apply_booster_open(user, payload: dict, performed_at) -> None:
    grant_id = drf_serializers.CharField(max_length=64).run_validation(payload["grant_id"])
    milestone = drf_serializers.IntegerField(min_value=0, max_value=2147483647).run_validation(
        payload.get("milestone", 0)
    )
    source = drf_serializers.CharField(max_length=32).run_validation(
        payload.get("source", "streak_milestone")
    )
    raw_cards = payload["cards"]
    if not isinstance(raw_cards, list) or not raw_cards or len(raw_cards) > 16:
        raise OpRejected("invalid")
    cards = [
        {
            "card_id": drf_serializers.CharField(max_length=64).run_validation(card["card_id"]),
            "is_new": drf_serializers.BooleanField().run_validation(card.get("is_new", False)),
            "count_after": drf_serializers.IntegerField(
                min_value=1, max_value=2147483647
            ).run_validation(card.get("count_after", 1)),
        }
        for card in raw_cards
    ]
    # An opening implies its grant (a device may replay the open before the
    # grant op from another device arrives).
    grant, _ = BoosterGrant.objects.get_or_create(
        user=user,
        grant_id=grant_id,
        defaults={
            "source": source,
            "milestone": milestone,
            "status": BoosterStatus.UNOPENED,
            "granted_at": performed_at,
        },
    )
    if grant.status == BoosterStatus.OPENED:
        # First open wins; the client draw is deterministic per grant anyway.
        return
    grant.status = BoosterStatus.OPENED
    grant.opened_at = performed_at
    grant.cards = cards
    grant.save(update_fields=["status", "opened_at", "cards"])
    for card in cards:
        entry, created = CollectionCard.objects.get_or_create(
            user=user,
            card_id=card["card_id"],
            defaults={"count": 1, "first_obtained_at": performed_at},
        )
        if not created:
            entry.count += 1
            entry.save(update_fields=["count"])


def _apply_mnemonic_op(user, kind: str, payload: dict) -> None:
    from mnemonics.models import DeckStatus, Mnemonic, MnemonicDeck, MnemonicStatus
    from mnemonics.serializers import VoteSerializer
    from mnemonics.services import (
        accessible_for,
        apply_pack,
        cast_vote,
        enroll_deck,
        set_choice,
        set_save,
    )

    if kind in ("mnemonic_vote", "mnemonic_save", "mnemonic_choose"):
        qs = Mnemonic.objects.filter(pk=payload["mnemonic_id"])
        if kind == "mnemonic_choose":
            qs = accessible_for(user).filter(pk=payload["mnemonic_id"])
        else:
            qs = qs.filter(status=MnemonicStatus.VISIBLE)
        mnemonic = qs.first()
        if mnemonic is None:
            raise OpRejected("unknown_mnemonic")
        if kind == "mnemonic_vote":
            validator = VoteSerializer(data=payload)
            validator.is_valid(raise_exception=True)
            cast_vote(user, mnemonic, validator.validated_data["value"])
        elif kind == "mnemonic_save":
            set_save(
                user, mnemonic, drf_serializers.BooleanField().run_validation(payload["value"])
            )
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


def _apply_reviews(
    user, reviews: list[dict], now, *, allow_deleted=False
) -> tuple[list[str], list[dict]]:
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
            if (
                not allow_deleted
                and CardTombstone.objects.filter(
                    user=user, item_type=item_type, item_ref=str(ref)
                ).exists()
            ):
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
            card = Card.objects.select_for_update().get(pk=card.pk)
            if card.last_review is None or reviewed_at > card.last_review:
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
        value = str(ref)
        if not value.isascii() or not value.isdigit() or not 0 < int(value) < 2**63:
            return None
        return qs.filter(word_id=int(value)).first()
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
