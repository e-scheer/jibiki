from __future__ import annotations

from django.conf import settings
from django.db import models
from django.utils import timezone


class WaniKaniConnection(models.Model):
    """A read-only WaniKani connection with an explicit import preview.

    The API token is encrypted with a key derived from Django's secret key. A
    connection never applies changes while refreshing: the pending preview must
    be explicitly imported, so a sync can never create a surprise review pile.
    """

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="wanikani_connection",
    )
    token_ciphertext = models.TextField()
    username = models.CharField(max_length=120, blank=True)
    mastery_threshold = models.PositiveSmallIntegerField(default=5)
    pending_preview = models.JSONField(default=dict, blank=True)
    last_synced_at = models.DateTimeField(null=True, blank=True)
    last_imported_at = models.DateTimeField(null=True, blank=True)
    last_error = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "integrations_wanikani_connection"

    def clear_preview(self) -> None:
        self.pending_preview = {}
        self.save(update_fields=["pending_preview", "updated_at"])

    def mark_imported(self) -> None:
        now = timezone.now()
        self.pending_preview = {}
        self.last_imported_at = now
        self.last_error = ""
        self.save(
            update_fields=[
                "pending_preview",
                "last_imported_at",
                "last_error",
                "updated_at",
            ]
        )
