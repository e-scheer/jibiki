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


class FeedbackKind(models.TextChoices):
    IDEA = "idea", "Idea"
    BUG = "bug", "Bug"
    LOVE = "love", "Love"
    OTHER = "other", "Other"


class FeedbackStatus(models.TextChoices):
    NEW = "new", "New"
    SEEN = "seen", "Seen"
    DONE = "done", "Done"


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
