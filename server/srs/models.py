"""SRS persistence: one Card per (user, study item) carrying its FSRS memory
state, plus a full ReviewLog (needed later to train per-user FSRS parameters - the
DEEP_SEARCH "store full review logs from day one" rule).

A study item is one of three dictionary rows - a Word, a Kanji, or a Kana - held
as three nullable FKs with a DB check that exactly one is set. That keeps the
linked object directly serializable (no generic-relation joins) while a single
Card table spans all item kinds.
"""

from __future__ import annotations

from django.conf import settings
from django.db import models
from django.utils import timezone
from django.utils.translation import gettext_lazy as _

from .fsrs import LEARNING, NEW, REVIEW, MemoryState


class ItemType(models.TextChoices):
    WORD = "word", _("Word")
    KANJI = "kanji", _("Kanji")
    KANA = "kana", _("Kana")


class State(models.IntegerChoices):
    NEW = 0, _("New")
    LEARNING = 1, _("Learning")
    REVIEW = 2, _("Review")
    RELEARNING = 3, _("Relearning")


class CardQuerySet(models.QuerySet):
    def due(self, now=None):
        now = now or timezone.now()
        return self.filter(due__lte=now).exclude(state=State.NEW)

    def new(self):
        return self.filter(state=State.NEW)


class Card(models.Model):
    id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="cards"
    )
    item_type = models.CharField(max_length=8, choices=ItemType.choices)

    word = models.ForeignKey("dictionary.Word", null=True, blank=True, on_delete=models.CASCADE)
    kanji = models.ForeignKey("dictionary.Kanji", null=True, blank=True, on_delete=models.CASCADE)
    kana = models.ForeignKey("dictionary.Kana", null=True, blank=True, on_delete=models.CASCADE)

    # FSRS memory state (null stability/difficulty until the first review).
    stability = models.FloatField(null=True, blank=True)
    difficulty = models.FloatField(null=True, blank=True)
    state = models.PositiveSmallIntegerField(choices=State.choices, default=State.NEW)
    step = models.PositiveSmallIntegerField(null=True, blank=True)
    due = models.DateTimeField(default=timezone.now)
    last_review = models.DateTimeField(null=True, blank=True)
    reps = models.PositiveIntegerField(default=0)
    lapses = models.PositiveIntegerField(default=0)
    favorite = models.BooleanField(default=False)

    # Optional provenance from a reader/dictionary capture. Keeping this on the
    # card makes reviews useful after the original browser tab is gone and gives
    # Yomitan, jpdb and a future mobile share action one stable contract.
    source_sentence = models.TextField(blank=True)
    source_url = models.URLField(blank=True)
    source_title = models.CharField(max_length=200, blank=True)
    source_media = models.CharField(max_length=200, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    # Sync cursor: /study/sync sends every card with updated_at past the
    # client's watermark. Any save() bumps it; update_fields callers must
    # include it explicitly.
    updated_at = models.DateTimeField(auto_now=True)

    objects = CardQuerySet.as_manager()

    class Meta:
        db_table = "srs_cards"
        ordering = ["due"]
        constraints = [
            models.UniqueConstraint(
                fields=["user", "word"],
                condition=models.Q(word__isnull=False),
                name="uq_card_user_word",
            ),
            models.UniqueConstraint(
                fields=["user", "kanji"],
                condition=models.Q(kanji__isnull=False),
                name="uq_card_user_kanji",
            ),
            models.UniqueConstraint(
                fields=["user", "kana"],
                condition=models.Q(kana__isnull=False),
                name="uq_card_user_kana",
            ),
            models.CheckConstraint(
                name="card_exactly_one_item",
                condition=(
                    models.Q(word__isnull=False, kanji__isnull=True, kana__isnull=True)
                    | models.Q(word__isnull=True, kanji__isnull=False, kana__isnull=True)
                    | models.Q(word__isnull=True, kanji__isnull=True, kana__isnull=False)
                ),
            ),
        ]
        indexes = [
            models.Index(fields=["user", "due"]),
            models.Index(fields=["user", "state"]),
            models.Index(fields=["user", "updated_at"]),
        ]

    def __str__(self) -> str:
        return f"card#{self.pk} ({self.item_type}:{self.item_ref})"

    @property
    def item(self):
        return self.word or self.kanji or self.kana

    @property
    def item_ref(self) -> str:
        if self.word_id:
            return str(self.word_id)
        if self.kanji_id:
            return self.kanji.literal if self.kanji else ""
        return self.kana.char if self.kana else ""

    def to_memory_state(self) -> MemoryState:
        return MemoryState(
            state=self.state,
            step=self.step,
            stability=self.stability,
            difficulty=self.difficulty,
            due=self.due,
            last_review=self.last_review,
        )

    def apply_memory_state(self, ms: MemoryState) -> None:
        self.state = ms.state
        self.step = ms.step
        self.stability = ms.stability
        self.difficulty = ms.difficulty
        self.due = ms.due
        self.last_review = ms.last_review


class ReviewLog(models.Model):
    """Append-only record of every rating. Kept complete from day one so per-user
    FSRS optimization (fsrs-rs) can train weights once ~1000 reviews accumulate."""

    id = models.BigAutoField(primary_key=True)
    card = models.ForeignKey(Card, on_delete=models.CASCADE, related_name="logs")
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="review_logs"
    )
    rating = models.PositiveSmallIntegerField()  # 1..4

    # Idempotency key for offline replay: the client stamps every review with a
    # UUID so redelivered sync batches are acked without duplicating the log.
    # Null for reviews born through the online endpoint.
    client_review_id = models.UUIDField(null=True, blank=True, unique=True)

    # Snapshot of the state the scheduler saw / produced (for offline retraining).
    state_before = models.PositiveSmallIntegerField()
    stability = models.FloatField(null=True, blank=True)
    difficulty = models.FloatField(null=True, blank=True)
    elapsed_days = models.FloatField(default=0.0)
    scheduled_days = models.PositiveIntegerField(default=0)
    duration_ms = models.PositiveIntegerField(default=0)

    reviewed_at = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = "srs_review_logs"
        ordering = ["-reviewed_at"]
        indexes = [
            models.Index(fields=["user", "reviewed_at"]),
            models.Index(fields=["card", "reviewed_at"]),
        ]

    def __str__(self) -> str:
        return f"log#{self.pk} card#{self.card_id} rating={self.rating}"


class CardTombstone(models.Model):
    """Remembers card deletions so /study/sync can propagate them to other
    devices and refuse late reviews of a deleted card (delete wins). Keyed by
    the natural item key - the card row itself is gone. Prunable after ~90
    days; a tombstone whose item has a live card again is simply not sent."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="card_tombstones"
    )
    item_type = models.CharField(max_length=8, choices=ItemType.choices)
    item_ref = models.CharField(max_length=64)
    deleted_at = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = "srs_card_tombstones"
        constraints = [
            models.UniqueConstraint(
                fields=["user", "item_type", "item_ref"], name="uq_tombstone_user_item"
            ),
        ]
        indexes = [models.Index(fields=["user", "deleted_at"])]

    def __str__(self) -> str:
        return f"tombstone({self.user_id}, {self.item_type}:{self.item_ref})"


class SyncedOp(models.Model):
    """Ack ledger for non-review sync ops (set_status, favorite, votes…): a
    redelivered op is acked from here without being re-applied, which makes the
    whole op stream idempotent even for non-idempotent payloads."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="synced_ops"
    )
    client_op_id = models.UUIDField()
    applied_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "srs_synced_ops"
        constraints = [
            models.UniqueConstraint(fields=["user", "client_op_id"], name="uq_synced_op_user"),
        ]

    def __str__(self) -> str:
        return f"synced-op({self.user_id}, {self.client_op_id})"


# Re-export the FSRS state ints so callers can `from srs.models import REVIEW`.
__all__ = [
    "LEARNING",
    "NEW",
    "REVIEW",
    "Card",
    "CardTombstone",
    "ItemType",
    "ReviewLog",
    "State",
    "SyncedOp",
]
