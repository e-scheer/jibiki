"""Entitlement tiers - the groundwork for a future freemium/subscription flip.
Nothing is gated while the app is a one-shot purchase; these pin the rules the
flip will rely on."""

from datetime import timedelta

import pytest
from django.utils import timezone

from accounts.entitlements import grant, has_premium
from accounts.models import Plan

pytestmark = pytest.mark.django_db


def test_default_plan_is_lifetime_and_premium(user):
    assert user.profile.plan == Plan.LIFETIME
    assert has_premium(user) is True


def test_free_plan_is_not_premium(user):
    grant(user, Plan.FREE)
    assert has_premium(user) is False


def test_subscription_expiry_degrades_immediately(user):
    grant(user, Plan.PREMIUM, expires_at=timezone.now() + timedelta(days=30))
    assert has_premium(user) is True
    grant(user, Plan.PREMIUM, expires_at=timezone.now() - timedelta(minutes=1))
    assert has_premium(user) is False
    # No expiry recorded (e.g. grace period) → honored.
    grant(user, Plan.PREMIUM)
    assert has_premium(user) is True


def test_anonymous_is_never_premium():
    assert has_premium(None) is False


def test_plan_is_readable_but_not_patchable(api, user):
    me = api.get("/api/v1/auth/me").json()
    assert me["profile"]["plan"] == "lifetime"
    assert me["profile"]["plan_expires_at"] is None

    # A client cannot upgrade itself: the field is read-only on the wire.
    resp = api.patch("/api/v1/auth/me", {"plan": "premium"}, format="json")
    assert resp.status_code in (200, 400)
    user.profile.refresh_from_db()
    assert user.profile.plan == Plan.LIFETIME

    # The sync payload carries it too (offline clients mirror it from there).
    sync = api.post("/api/v1/study/sync", {}, format="json").json()
    assert sync["profile"]["plan"] == "lifetime"
