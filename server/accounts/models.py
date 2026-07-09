"""User + per-user product settings.

The User is email-only (no username - the product never shows one), the same
choice tusorsou makes; allauth-headless can be layered on later without touching
the model. The UserProfile carries the DEEP_SEARCH "configurable modes" spectrum
(Dictionary ↔ Middle ↔ Learning) plus the SRS knobs (daily new limit, desired
retention) as a small set of feature flags rather than three code paths.
"""

from __future__ import annotations

from django.contrib.auth.models import AbstractUser, UserManager
from django.db import models
from django.utils.translation import gettext_lazy as _


class EmailUserManager(UserManager):
    """Username-less manager: createsuperuser and tests go through create_user/
    create_superuser; there is no username to prompt for."""

    def _create(self, email: str, password: str | None, **extra):
        if not email:
            raise ValueError("email is required")
        user = self.model(email=self.normalize_email(email), **extra)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email: str, password: str | None = None, **extra):  # type: ignore[override]
        extra.setdefault("is_staff", False)
        extra.setdefault("is_superuser", False)
        return self._create(email, password, **extra)

    def create_superuser(self, email: str, password: str | None = None, **extra):  # type: ignore[override]
        extra.setdefault("is_staff", True)
        extra.setdefault("is_superuser", True)
        return self._create(email, password, **extra)


class User(AbstractUser):
    """Email-only user (no username - the product never shows one)."""

    username = None
    email = models.EmailField(unique=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS: list[str] = []

    objects = EmailUserManager()

    def __str__(self) -> str:
        return self.email


class AppMode(models.TextChoices):
    """The onboarding-selectable spectrum (DEEP_SEARCH feature 3). Implemented as a
    single flag the client reads to lay out its home screen and default its
    notifications - not three separate apps."""

    DICTIONARY = "dictionary", _("Dictionary")  # search-first, no review nagging
    MIDDLE = "middle", _("Middle")  # dictionary home + a gentle "N due" badge
    LEARNING = "learning", _("Learning")  # review queue is home, goals + streaks


class Plan(models.TextChoices):
    """Entitlement tier. Today the app is a one-shot purchase, so every account
    is LIFETIME and nothing is gated. The tier exists so a pivot to
    freemium+subscription is a data change (default → FREE, an IAP webhook
    granting PREMIUM with an expiry), not a schema/API migration. Server-side
    checks live in accounts.entitlements - the client only mirrors them."""

    FREE = "free", _("Free")
    PREMIUM = "premium", _("Premium")  # subscription; honored until plan_expires_at
    LIFETIME = "lifetime", _("Lifetime")  # one-shot purchase, never expires


class UserProfile(models.Model):
    """One-to-one product settings for a user. Auto-created on first save (signals)."""

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="profile")

    # Entitlements: set exclusively server-side (admin / future IAP webhook),
    # read-only on the wire.
    plan = models.CharField(max_length=12, choices=Plan.choices, default=Plan.LIFETIME)
    plan_expires_at = models.DateTimeField(null=True, blank=True)

    mode = models.CharField(max_length=16, choices=AppMode.choices, default=AppMode.MIDDLE)
    display_name = models.CharField(max_length=60, blank=True)

    # Mnemonic language is deliberately separate from the UI language: kana
    # mnemonics are sound-associations, so a French speaker keys off "coucou"
    # where an English speaker keys off "cuckoo" (DEEP_SEARCH feature 6).
    mnemonic_language = models.CharField(max_length=8, default="en")

    # SRS knobs (DEEP_SEARCH feature 1). desired_retention feeds FSRS's interval
    # solver; new_cards_per_day bounds the daily intake; timezone drives when
    # "today" flips for streaks and the due badge.
    desired_retention = models.FloatField(default=0.9)
    new_cards_per_day = models.PositiveIntegerField(default=15)
    timezone = models.CharField(max_length=40, default="UTC")

    # Per-user FSRS weights, trained from this user's own review history once
    # ~1000 reviews accumulate (DEEP_SEARCH: below that, defaults perform ~like
    # SM-2). Null → the scheduler uses the FSRS-6 default parameters. A list of 21.
    fsrs_parameters = models.JSONField(null=True, blank=True)

    # Notifications (DEEP_SEARCH feature 2): opt-in, capped, fired on due-count.
    notifications_enabled = models.BooleanField(default=False)
    notify_threshold = models.PositiveIntegerField(default=15)  # min due cards to notify

    # The community mnemonic pack the user has applied as their visual base. Null
    # → the default (highest-scored mnemonic per character). Per-character
    # overrides live in mnemonics.UserMnemonicChoice. String FK avoids an import
    # cycle with the mnemonics app.
    active_pack = models.ForeignKey(
        "mnemonics.MnemonicDeck",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "accounts_profile"

    def __str__(self) -> str:
        return f"profile({self.user_id}, {self.mode})"
