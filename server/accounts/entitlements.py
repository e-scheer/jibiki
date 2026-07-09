"""Entitlement checks - the single server-side gate between tiers.

Nothing is gated today (one-shot purchase, every account LIFETIME); when a
freemium tier appears, premium features get `permission_classes = [...,
IsPremium]` (or a `has_premium(user)` branch) and the client's mirror gates
light up from the profile payload. The check is server-side by design: the
client copy of `plan` is presentation only - API features, sync, and pack
downloads are what actually enforce it.
"""

from __future__ import annotations

from django.utils import timezone
from rest_framework.permissions import BasePermission

from .models import Plan, UserProfile


def has_premium(user) -> bool:
    """Whether the user's plan grants full access right now. Expiry is checked
    here (not via a cron flipping rows) so a lapsed subscription degrades the
    moment it lapses, and un-lapses the moment the store webhook renews it."""
    if not user or not getattr(user, "is_authenticated", False):
        return False
    profile, _ = UserProfile.objects.get_or_create(user=user)
    if profile.plan == Plan.FREE:
        return False
    if profile.plan == Plan.PREMIUM:
        expires = profile.plan_expires_at
        return expires is None or expires > timezone.now()
    return True  # LIFETIME


class IsPremium(BasePermission):
    """DRF permission for premium-gated endpoints (unused while the app is a
    one-shot purchase - ready for the flip)."""

    message = "This feature requires an active subscription."

    def has_permission(self, request, view) -> bool:
        return has_premium(request.user)


def grant(user, plan: str, expires_at=None) -> UserProfile:
    """Set a user's plan - the hook a store webhook (RevenueCat / Play / App
    Store server notifications) will call. Kept trivial on purpose."""
    profile, _ = UserProfile.objects.get_or_create(user=user)
    profile.plan = plan
    profile.plan_expires_at = expires_at
    profile.save(update_fields=["plan", "plan_expires_at", "updated_at"])
    return profile
