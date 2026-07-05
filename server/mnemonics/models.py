"""Community-contributed, language-dependent visual mnemonics — the DEEP_SEARCH
differentiating feature (feature 5 & 6).

A mnemonic is a first-class localized entity keyed by (character, language, kind):
because kana mnemonics ride on *sound* association, "く = a cuckoo's beak" works in
English while a French speaker keys off "coucou" — so the same character carries a
different ranked set per language. That per-language segmentation is the moat.

Moderation is designed in from day one (the Memrise / Koohii lessons):
  * uploads from low-trust users post as PENDING (held); trusted users post VISIBLE;
  * enough distinct reporters auto-HIDE a visible mnemonic pending staff review;
  * content is NEVER hard-deleted — REMOVED is a soft takedown kept for audit.
"""

from __future__ import annotations

from django.conf import settings
from django.db import models
from django.utils.translation import gettext_lazy as _


class MnemonicStatus(models.TextChoices):
    VISIBLE = "visible", _("Visible")  # public
    PENDING = "pending", _("Pending review")  # held (low-trust author)
    HIDDEN = "hidden", _("Hidden")  # auto-hidden by reports / staff (reversible)
    REMOVED = "removed", _("Removed")  # hard takedown, kept for audit


def mnemonic_image_path(instance: "Mnemonic", filename: str) -> str:
    # Grouped by character so a moderator can browse everything for a kana/kanji.
    return f"mnemonics/{instance.kind}/{instance.character}/{filename}"


class Mnemonic(models.Model):
    class Kind(models.TextChoices):
        KANA = "kana", _("Kana")
        KANJI = "kanji", _("Kanji")

    id = models.BigAutoField(primary_key=True)
    character = models.CharField(max_length=4)  # the kana / kanji literal
    kind = models.CharField(max_length=8, choices=Kind.choices)
    # Mnemonic language (ISO-639-1-ish) — separate from the app's UI language.
    language = models.CharField(max_length=8, default="en")

    story = models.TextField()
    # FileField (not ImageField) — no implicit Pillow machinery; imaging.py
    # re-encodes to WebP + strips EXIF/GPS on ingest, then sets width/height.
    image = models.FileField(upload_to=mnemonic_image_path, blank=True)
    image_width = models.PositiveIntegerField(default=0)
    image_height = models.PositiveIntegerField(default=0)

    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="mnemonics",
    )
    is_seed = models.BooleanField(default=False)  # bundled baseline content

    status = models.CharField(
        max_length=10, choices=MnemonicStatus.choices, default=MnemonicStatus.VISIBLE
    )
    # Denormalized net vote count (upvotes − downvotes), kept in sync by the vote
    # service so ranking is a plain ORDER BY without aggregating every read.
    score = models.IntegerField(default=0)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    hidden_at = models.DateTimeField(null=True, blank=True)
    moderation_note = models.TextField(blank=True)

    class Meta:
        db_table = "mnemonics"
        ordering = ["-score", "-created_at"]
        indexes = [
            models.Index(fields=["kind", "character", "language", "status"]),
            models.Index(fields=["character", "language", "score"]),
            models.Index(fields=["status"]),
        ]

    def __str__(self) -> str:
        return f"{self.character} [{self.language}] score={self.score}"

    @property
    def is_public(self) -> bool:
        return self.status == MnemonicStatus.VISIBLE

    @property
    def image_src(self) -> str:
        return self.image.url if self.image else ""


class MnemonicVote(models.Model):
    """One user's vote on a mnemonic (+1 up / −1 down). One row per (mnemonic,
    user); re-voting updates the value, voting 0 removes it. Drives Mnemonic.score."""

    id = models.BigAutoField(primary_key=True)
    mnemonic = models.ForeignKey(Mnemonic, on_delete=models.CASCADE, related_name="votes")
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="mnemonic_votes"
    )
    value = models.SmallIntegerField(default=1)  # +1 or -1
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "mnemonic_votes"
        constraints = [
            models.UniqueConstraint(fields=["mnemonic", "user"], name="uq_vote_per_user")
        ]

    def __str__(self) -> str:
        return f"{self.user_id} {'▲' if self.value > 0 else '▼'} m#{self.mnemonic_id}"


class ReportReason(models.TextChoices):
    OFFENSIVE = "offensive", _("Offensive or explicit")
    INACCURATE = "inaccurate", _("Inaccurate or misleading")
    SPAM = "spam", _("Spam or advertising")
    OFF_TOPIC = "off_topic", _("Off-topic")
    OTHER = "other", _("Something else")


class ReportStatus(models.TextChoices):
    PENDING = "pending", _("Pending")
    REVIEWED = "reviewed", _("Reviewed")
    DISMISSED = "dismissed", _("Dismissed")
    ACTIONED = "actioned", _("Actioned")


class MnemonicReport(models.Model):
    """A flag raised by a signed-in user. Enough distinct PENDING reporters
    auto-hide a visible mnemonic (settings.MNEMONIC_AUTO_HIDE_REPORTS)."""

    id = models.BigAutoField(primary_key=True)
    mnemonic = models.ForeignKey(Mnemonic, on_delete=models.CASCADE, related_name="reports")
    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="mnemonic_reports"
    )
    reason = models.CharField(
        max_length=16, choices=ReportReason.choices, default=ReportReason.OTHER
    )
    detail = models.TextField(blank=True)
    status = models.CharField(
        max_length=10, choices=ReportStatus.choices, default=ReportStatus.PENDING
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "mnemonic_reports"
        ordering = ["-created_at"]
        constraints = [
            # One active report per user per mnemonic (re-reporting is a no-op).
            models.UniqueConstraint(fields=["mnemonic", "reporter"], name="uq_report_per_user")
        ]
        indexes = [models.Index(fields=["status", "created_at"])]

    def __str__(self) -> str:
        return f"report#{self.pk} [{self.reason}] m#{self.mnemonic_id}"


class MnemonicSave(models.Model):
    """The Instagram "🔖 save": one user bookmarking one mnemonic. Unique per
    (mnemonic, user); toggled on/off. Powers the user's saved collection."""

    id = models.BigAutoField(primary_key=True)
    mnemonic = models.ForeignKey(Mnemonic, on_delete=models.CASCADE, related_name="saves")
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="mnemonic_saves"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "mnemonic_saves"
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(fields=["mnemonic", "user"], name="uq_save_per_user")
        ]
        indexes = [models.Index(fields=["user", "created_at"])]

    def __str__(self) -> str:
        return f"save u#{self.user_id} m#{self.mnemonic_id}"


class UserMnemonicChoice(models.Model):
    """A user's chosen mnemonic for one character — their per-character override of
    the score-ranked default. Applying a whole pack materializes one row per pack
    item; a single swap upserts one row. Keyed like a Mnemonic: (character,
    language, kind), scoped to the user."""

    id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="mnemonic_choices"
    )
    kind = models.CharField(max_length=8, choices=Mnemonic.Kind.choices)
    character = models.CharField(max_length=4)
    language = models.CharField(max_length=8, default="en")
    mnemonic = models.ForeignKey(Mnemonic, on_delete=models.CASCADE, related_name="chosen_by")
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "mnemonic_choices"
        constraints = [
            models.UniqueConstraint(
                fields=["user", "kind", "character", "language"], name="uq_choice_per_char"
            )
        ]
        indexes = [models.Index(fields=["user", "kind", "language"])]

    def __str__(self) -> str:
        return f"choice u#{self.user_id} {self.character}[{self.language}]→m#{self.mnemonic_id}"


class DeckStatus(models.TextChoices):
    DRAFT = "draft", _("Draft")  # private, still being assembled by its author
    PENDING = "pending", _("Pending review")  # submitted, held (low-trust author)
    VISIBLE = "visible", _("Visible")  # public in the community
    HIDDEN = "hidden", _("Hidden")  # auto-hidden by reports / staff (reversible)
    REMOVED = "removed", _("Removed")  # soft takedown, kept for audit


class MnemonicDeck(models.Model):
    """A user-authored, community-shared *pack* of visual mnemonics — e.g. "My
    full hiragana mascots (FR)". The individual-mnemonic moderation model is
    mirrored here: DRAFT while assembled, PENDING/VISIBLE on publish depending on
    author trust, HIDDEN/REMOVED on moderation. Bundles existing Mnemonic rows
    (the author's own drawings) via an ordered through table.
    """

    id = models.BigAutoField(primary_key=True)
    title = models.CharField(max_length=120)
    description = models.TextField(blank=True)
    # Same per-language segmentation as mnemonics — a FR pack keys off FR sounds.
    language = models.CharField(max_length=8, default="en")
    kind = models.CharField(max_length=8, choices=Mnemonic.Kind.choices, default=Mnemonic.Kind.KANA)

    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="mnemonic_decks",
    )
    is_seed = models.BooleanField(default=False)
    status = models.CharField(max_length=10, choices=DeckStatus.choices, default=DeckStatus.DRAFT)
    # Denormalized net likes, kept in sync by the vote service (plain ORDER BY).
    score = models.IntegerField(default=0)

    mnemonics = models.ManyToManyField(Mnemonic, through="MnemonicDeckItem", related_name="decks")

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    hidden_at = models.DateTimeField(null=True, blank=True)
    moderation_note = models.TextField(blank=True)

    class Meta:
        db_table = "mnemonic_decks"
        ordering = ["-score", "-created_at"]
        indexes = [
            models.Index(fields=["status", "language", "kind"]),
            models.Index(fields=["language", "kind", "score"]),
            models.Index(fields=["status"]),
        ]

    def __str__(self) -> str:
        return f"{self.title} [{self.language}] score={self.score}"

    @property
    def is_public(self) -> bool:
        return self.status == DeckStatus.VISIBLE

    def cover_item(self):
        """The first item carrying an image — used as the deck cover. Reads from
        a prefetched `items` relation when available to avoid an N+1."""
        for it in self.items.all():
            if it.mnemonic and it.mnemonic.image:
                return it.mnemonic
        return None


class MnemonicDeckItem(models.Model):
    """One mnemonic's membership in a deck, with an explicit display order."""

    id = models.BigAutoField(primary_key=True)
    deck = models.ForeignKey(MnemonicDeck, on_delete=models.CASCADE, related_name="items")
    mnemonic = models.ForeignKey(Mnemonic, on_delete=models.CASCADE, related_name="deck_items")
    position = models.PositiveIntegerField(default=0)
    added_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "mnemonic_deck_items"
        ordering = ["position", "id"]
        constraints = [
            models.UniqueConstraint(fields=["deck", "mnemonic"], name="uq_deck_mnemonic")
        ]

    def __str__(self) -> str:
        return f"deck#{self.deck_id} · m#{self.mnemonic_id} @{self.position}"


class MnemonicDeckVote(models.Model):
    """A community "❤ like" on a deck. One row per (deck, user); drives
    MnemonicDeck.score. Likes only (+1) — Instagram has no dislike."""

    id = models.BigAutoField(primary_key=True)
    deck = models.ForeignKey(MnemonicDeck, on_delete=models.CASCADE, related_name="votes")
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="mnemonic_deck_votes"
    )
    value = models.SmallIntegerField(default=1)  # +1 like
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "mnemonic_deck_votes"
        constraints = [
            models.UniqueConstraint(fields=["deck", "user"], name="uq_deck_vote_per_user")
        ]

    def __str__(self) -> str:
        return f"{self.user_id} ❤ deck#{self.deck_id}"
