"""In-app feedback - ideas, bugs, love letters.

One low-friction channel beats a support email nobody writes to: the app
attaches the diagnostic context itself (platform, packs, offline state), so a
two-line message from a user is still actionable. Anonymous submissions are
accepted (the app works without an account); an optional reply-to email lets
them hear back.
"""

from __future__ import annotations

from django.conf import settings
from django.db import models
from django.utils.translation import gettext_lazy as _


class FeedbackKind(models.TextChoices):
    IDEA = "idea", _("Idea")
    BUG = "bug", _("Bug")
    LOVE = "love", _("Love")
    OTHER = "other", _("Other")


class FeedbackStatus(models.TextChoices):
    NEW = "new", _("New")
    SEEN = "seen", _("Seen")
    DONE = "done", _("Done")


class Feedback(models.Model):
    id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="feedback",
    )
    kind = models.CharField(max_length=8, choices=FeedbackKind.choices)
    message = models.TextField(max_length=4000)
    # Reply-to for anonymous/local-only senders; never required.
    email = models.EmailField(blank=True)
    # Auto-attached by the client: app version, platform, screen, installed
    # packs, offline flags - whatever makes the report actionable.
    context = models.JSONField(default=dict, blank=True)

    status = models.CharField(
        max_length=8, choices=FeedbackStatus.choices, default=FeedbackStatus.NEW
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "feedback"
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["status", "created_at"])]

    def __str__(self) -> str:
        return f"feedback#{self.pk} [{self.kind}] {self.message[:40]}"


class ContentItemType(models.TextChoices):
    KANJI = "kanji", _("Kanji")
    KANA = "kana", _("Kana")
    WORD = "word", _("Word")


class ContentReportReason(models.TextChoices):
    WRONG = "wrong", _("Something is wrong")
    MISSING = "missing", _("Something is missing")
    TYPO = "typo", _("Typo or formatting")
    OTHER = "other", _("Something else")


class ContentReport(models.Model):
    """A signed-in learner flagging a dictionary entry (a kanji, a kana, or a
    word): a wrong reading, a missing meaning, a typo. Unlike open product
    feedback these must carry an account, so a correction is accountable and we
    can reply, and re-reporting the same item just updates the existing row.

    Distinct from mnemonics' MnemonicReport, which moderates user-generated
    content; this is about the reference data itself.
    """

    id = models.BigAutoField(primary_key=True)
    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="content_reports"
    )
    # What entry was flagged. item_ref is the kanji/kana glyph or the word id as
    # a string, so one column addresses all three dictionaries.
    item_type = models.CharField(max_length=8, choices=ContentItemType.choices)
    item_ref = models.CharField(max_length=64)
    reason = models.CharField(
        max_length=8, choices=ContentReportReason.choices, default=ContentReportReason.OTHER
    )
    message = models.TextField(max_length=2000, blank=True)
    # Auto-attached by the client (platform, app mode, the entry's label) so the
    # report is actionable without a lookup.
    context = models.JSONField(default=dict, blank=True)

    status = models.CharField(
        max_length=8, choices=FeedbackStatus.choices, default=FeedbackStatus.NEW
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "content_reports"
        ordering = ["-created_at"]
        constraints = [
            # One active report per user per entry: re-reporting updates in place
            # rather than piling up duplicates a human has to dedupe.
            models.UniqueConstraint(
                fields=["reporter", "item_type", "item_ref"], name="uq_content_report_per_user"
            )
        ]
        indexes = [models.Index(fields=["status", "created_at"])]

    def __str__(self) -> str:
        return f"report#{self.pk} [{self.reason}] {self.item_type}:{self.item_ref}"
