"""Mnemonic domain operations - request-free and unit-testable.

Owns the trust/moderation policy: where a new mnemonic lands (visible vs pending),
how a vote mutates the denormalized score, and when accumulated reports auto-hide
a visible mnemonic.
"""

from __future__ import annotations

from django.conf import settings
from django.db import transaction
from django.db.models import Sum
from django.utils import timezone

from .imaging import ImageRejected, process_upload
from .models import (
    DeckStatus,
    Mnemonic,
    MnemonicDeck,
    MnemonicDeckItem,
    MnemonicDeckVote,
    MnemonicReport,
    MnemonicSave,
    MnemonicStatus,
    MnemonicVote,
    ReportStatus,
    UserMnemonicChoice,
)

_MODERATED = (MnemonicStatus.HIDDEN, MnemonicStatus.REMOVED)


def user_trust(user) -> int:
    """A contributor's reputation = net upvotes across their visible mnemonics.
    Above the threshold they post straight to VISIBLE; below, their posts are held
    (the Discourse/Stack-Overflow trust-tier rule)."""
    if not user or not user.is_authenticated:
        return 0
    return (
        Mnemonic.objects.filter(author=user, status=MnemonicStatus.VISIBLE).aggregate(
            s=Sum("score")
        )["s"]
        or 0
    )


def initial_status(user) -> str:
    if getattr(user, "is_staff", False):
        return MnemonicStatus.VISIBLE
    if user_trust(user) >= settings.MNEMONIC_TRUST_THRESHOLD:
        return MnemonicStatus.VISIBLE
    return MnemonicStatus.PENDING


@transaction.atomic
def create_mnemonic(user, *, character, kind, language, story, image_file=None) -> Mnemonic:
    mnemonic = Mnemonic(
        character=character,
        kind=kind,
        language=language,
        story=story,
        author=user,
        status=initial_status(user),
    )
    if image_file is not None:
        content, name, w, h = process_upload(image_file)  # may raise ImageRejected
        mnemonic.image.save(name, content, save=False)
        mnemonic.image_width, mnemonic.image_height = w, h
    mnemonic.save()
    return mnemonic


@transaction.atomic
def cast_vote(user, mnemonic: Mnemonic, value: int) -> int:
    """Set (value ∈ {+1,-1}) or clear (value == 0) the user's vote; return the new
    score. Recomputed from rows so it can never drift from the votes table."""
    if value == 0:
        MnemonicVote.objects.filter(mnemonic=mnemonic, user=user).delete()
    else:
        MnemonicVote.objects.update_or_create(
            mnemonic=mnemonic, user=user, defaults={"value": 1 if value > 0 else -1}
        )
    score = MnemonicVote.objects.filter(mnemonic=mnemonic).aggregate(s=Sum("value"))["s"] or 0
    Mnemonic.objects.filter(pk=mnemonic.pk).update(score=score)
    mnemonic.score = score
    return score


@transaction.atomic
def file_report(user, mnemonic: Mnemonic, reason: str, detail: str = "") -> bool:
    """Record a report (idempotent per user). Auto-hide the mnemonic once enough
    distinct users have flagged it. Returns True if this call hid it."""
    MnemonicReport.objects.get_or_create(
        mnemonic=mnemonic,
        reporter=user,
        defaults={"reason": reason, "detail": detail},
    )
    if mnemonic.status != MnemonicStatus.VISIBLE:
        return False
    distinct_reporters = (
        MnemonicReport.objects.filter(mnemonic=mnemonic, status=ReportStatus.PENDING)
        .values("reporter")
        .distinct()
        .count()
    )
    if distinct_reporters >= settings.MNEMONIC_AUTO_HIDE_REPORTS:
        mnemonic.status = MnemonicStatus.HIDDEN
        mnemonic.hidden_at = timezone.now()
        mnemonic.moderation_note = f"Auto-hidden after {distinct_reporters} reports."
        mnemonic.save(update_fields=["status", "hidden_at", "moderation_note"])
        return True
    return False


def visible_for(character: str, language: str, kind: str):
    """The public, ranked mnemonic set for a character in a language."""
    qs = Mnemonic.objects.filter(status=MnemonicStatus.VISIBLE, character=character, kind=kind)
    if language:
        qs = qs.filter(language=language)
    return qs.order_by("-score", "-created_at")


def visible_or_own_for(user, character: str, language: str, kind: str):
    """The public feed for a character PLUS the signed-in user's own PENDING
    submissions, surfaced on top so authors always see their own work (badged
    "in review" client-side) instead of wondering where it went. Removed/hidden
    content stays out. Their VISIBLE mnemonics are already in the public set.

    Deliberately STRICT on language (no English fallback here, unlike
    `active_for_many`): the browse feed must return empty for an uncurated
    language so the client can detect it and show its own badged English
    backup + "draw the first one" prompt. `active_for_many` falls back
    server-side because the everywhere-visual layer has no per-character UI to
    badge the fallback."""
    base = list(visible_for(character, language, kind).select_related("author__profile"))
    if not (user and getattr(user, "is_authenticated", False)):
        return base
    own = Mnemonic.objects.filter(
        author=user, character=character, kind=kind, status=MnemonicStatus.PENDING
    )
    if language:
        own = own.filter(language=language)
    own_pending = list(own.select_related("author__profile").order_by("-created_at"))
    return own_pending + base


def active_for_many(user, characters, kind, language) -> dict:
    """The active mnemonic for each character: the user's explicit choice if any,
    else the top-ranked visible one. Returns {character: Mnemonic}. Two queries
    total (choices + fallback), regardless of how many characters."""
    chars = list(dict.fromkeys(characters))  # dedupe, preserve order
    if not chars:
        return {}
    result: dict[str, Mnemonic] = {}
    if user and user.is_authenticated:
        choices = UserMnemonicChoice.objects.filter(
            user=user, kind=kind, language=language, character__in=chars
        ).select_related("mnemonic__author__profile")
        for c in choices:
            if c.mnemonic and c.mnemonic.status not in _MODERATED:
                result[c.character] = c.mnemonic
    missing = [c for c in chars if c not in result]
    if missing:
        qs = (
            Mnemonic.objects.filter(
                status=MnemonicStatus.VISIBLE, kind=kind, language=language, character__in=missing
            )
            .select_related("author__profile")
            .order_by("character", "-score", "-created_at")
        )
        for m in qs:
            result.setdefault(m.character, m)  # ordering → first per char is best
    # English backup: mnemonic languages are open (community can start any
    # language), so a fresh language must degrade to the English set instead
    # of a blank visual layer. The serializer carries `language`, letting the
    # client badge the fallback.
    still_missing = [c for c in chars if c not in result]
    if still_missing and language != "en":
        qs = (
            Mnemonic.objects.filter(
                status=MnemonicStatus.VISIBLE, kind=kind, language="en", character__in=still_missing
            )
            .select_related("author__profile")
            .order_by("character", "-score", "-created_at")
        )
        for m in qs:
            result.setdefault(m.character, m)
    return result


@transaction.atomic
def set_choice(user, mnemonic: Mnemonic) -> UserMnemonicChoice:
    """Override one character's active mnemonic for this user."""
    obj, _ = UserMnemonicChoice.objects.update_or_create(
        user=user,
        kind=mnemonic.kind,
        character=mnemonic.character,
        language=mnemonic.language,
        defaults={"mnemonic": mnemonic},
    )
    return obj


@transaction.atomic
def apply_pack(user, deck: MnemonicDeck) -> int:
    """Adopt a whole pack: materialize one per-character choice per pack item and
    record it as the user's active pack. Returns how many characters were set."""
    n = 0
    for item in deck.items.select_related("mnemonic").all():
        m = item.mnemonic
        if m is None:
            continue
        UserMnemonicChoice.objects.update_or_create(
            user=user,
            kind=m.kind,
            character=m.character,
            language=m.language,
            defaults={"mnemonic": m},
        )
        n += 1
    profile = getattr(user, "profile", None)
    if profile is not None:
        profile.active_pack = deck
        profile.save(update_fields=["active_pack", "updated_at"])
    return n


@transaction.atomic
def reset_choices(user, kind: str | None = None) -> int:
    """Drop the user's overrides (back to the score-ranked default) and clear the
    active pack. Returns how many overrides were removed."""
    qs = UserMnemonicChoice.objects.filter(user=user)
    if kind:
        qs = qs.filter(kind=kind)
    count, _ = qs.delete()
    profile = getattr(user, "profile", None)
    if profile is not None and profile.active_pack_id is not None and not kind:
        profile.active_pack = None
        profile.save(update_fields=["active_pack", "updated_at"])
    return count


def toggle_save(user, mnemonic: Mnemonic) -> bool:
    """Bookmark / un-bookmark a mnemonic (Instagram 🔖). Returns the new state."""
    obj, created = MnemonicSave.objects.get_or_create(mnemonic=mnemonic, user=user)
    if not created:
        obj.delete()
        return False
    return True


def set_save(user, mnemonic: Mnemonic, value: bool) -> bool:
    """Explicit-value bookmark. Unlike toggle_save this is replay-safe, so the
    offline sync can redeliver it without flipping the state back."""
    if value:
        MnemonicSave.objects.get_or_create(mnemonic=mnemonic, user=user)
        return True
    MnemonicSave.objects.filter(mnemonic=mnemonic, user=user).delete()
    return False


def saved_for(user):
    """The user's saved mnemonics, most-recently-saved first."""
    return Mnemonic.objects.filter(saves__user=user).order_by("-saves__created_at")


# ── Community decks - the drawing → pack → propose flow ──────────────────────


def deck_initial_status(user, *, publish: bool) -> str:
    """A draft stays private until published; on publish it lands VISIBLE for
    staff / trusted authors, else PENDING - mirroring `initial_status`."""
    if not publish:
        return DeckStatus.DRAFT
    if getattr(user, "is_staff", False):
        return DeckStatus.VISIBLE
    if user_trust(user) >= settings.MNEMONIC_TRUST_THRESHOLD:
        return DeckStatus.VISIBLE
    return DeckStatus.PENDING


@transaction.atomic
def set_deck_items(deck: MnemonicDeck, user, mnemonic_ids) -> int:
    """Replace a deck's contents with the author's own mnemonics, in the given
    order. Only the author's own drawings of the deck's kind are admitted (a pack
    is your own work), so passing someone else's id is silently ignored."""
    owned = {
        m.id: m for m in Mnemonic.objects.filter(id__in=mnemonic_ids, author=user, kind=deck.kind)
    }
    deck.items.all().delete()
    items = [
        MnemonicDeckItem(deck=deck, mnemonic=owned[mid], position=pos)
        for pos, mid in enumerate(mnemonic_ids)
        if mid in owned
    ]
    if items:
        MnemonicDeckItem.objects.bulk_create(items)
    return len(items)


@transaction.atomic
def create_deck(
    user,
    *,
    title,
    description="",
    language="en",
    kind=Mnemonic.Kind.KANA,
    mnemonic_ids=None,
    publish=False,
) -> MnemonicDeck:
    deck = MnemonicDeck.objects.create(
        title=title,
        description=description,
        language=language,
        kind=kind,
        author=user,
        status=deck_initial_status(user, publish=publish),
    )
    if mnemonic_ids:
        set_deck_items(deck, user, mnemonic_ids)
    return deck


@transaction.atomic
def publish_deck(deck: MnemonicDeck, user) -> str:
    """Move a draft into the community (VISIBLE or PENDING by trust). A no-op for
    moderated (hidden/removed) decks."""
    if deck.status in (DeckStatus.HIDDEN, DeckStatus.REMOVED):
        return deck.status
    deck.status = deck_initial_status(user, publish=True)
    deck.save(update_fields=["status", "updated_at"])
    return deck.status


@transaction.atomic
def cast_deck_vote(user, deck: MnemonicDeck, value: int) -> int:
    """Like (value > 0) or un-like (value <= 0) a deck; return the new score."""
    if value <= 0:
        MnemonicDeckVote.objects.filter(deck=deck, user=user).delete()
    else:
        MnemonicDeckVote.objects.update_or_create(deck=deck, user=user, defaults={"value": 1})
    score = MnemonicDeckVote.objects.filter(deck=deck).aggregate(s=Sum("value"))["s"] or 0
    MnemonicDeck.objects.filter(pk=deck.pk).update(score=score)
    deck.score = score
    return score


def visible_decks(language: str | None = None, kind: str | None = None):
    """The public, ranked community decks (optionally filtered by language/kind)."""
    qs = MnemonicDeck.objects.filter(status=DeckStatus.VISIBLE)
    if language:
        qs = qs.filter(language=language)
    if kind:
        qs = qs.filter(kind=kind)
    return qs.order_by("-score", "-created_at")


@transaction.atomic
def enroll_deck(user, deck: MnemonicDeck) -> int:
    """Study a community deck: create SRS cards for every distinct character it
    covers (idempotent - the unique (user,item) constraint skips duplicates)."""
    from dictionary.models import Kana, Kanji
    from srs.models import Card, ItemType, State

    chars = list(dict.fromkeys(deck.mnemonics.values_list("character", flat=True)))
    if not chars:
        return 0
    now = timezone.now()
    rows: list = []
    if deck.kind == Mnemonic.Kind.KANA:
        for k in Kana.objects.filter(char__in=chars):
            rows.append(Card(user=user, item_type=ItemType.KANA, kana=k, due=now, state=State.NEW))
    else:
        for k in Kanji.objects.filter(literal__in=chars):
            rows.append(
                Card(user=user, item_type=ItemType.KANJI, kanji=k, due=now, state=State.NEW)
            )
    if rows:
        Card.objects.bulk_create(rows, ignore_conflicts=True)
    return len(rows)


__all__ = [
    "ImageRejected",
    "active_for_many",
    "apply_pack",
    "cast_deck_vote",
    "cast_vote",
    "create_deck",
    "create_mnemonic",
    "deck_initial_status",
    "enroll_deck",
    "file_report",
    "initial_status",
    "publish_deck",
    "reset_choices",
    "saved_for",
    "set_choice",
    "set_deck_items",
    "set_save",
    "toggle_save",
    "user_trust",
    "visible_decks",
    "visible_for",
]
