"""/study/sync - booster grants and the card collection (docs/REWARDS.md):
idempotent replay of client rewards ops, first-open-wins, duplicate counting,
full rewards state in every response, replace_cloud semantics."""

import uuid
from datetime import timedelta

import pytest
from django.utils import timezone

pytestmark = pytest.mark.django_db

SYNC = "/api/v1/study/sync"

GRANT_ID = "streak:2026-07-13:3"


def _op(kind, payload, performed_at=None):
    return {
        "client_op_id": str(uuid.uuid4()),
        "kind": kind,
        "payload": payload,
        "performed_at": (performed_at or timezone.now()).isoformat(),
    }


def _grant_op(status="unopened", grant_id=GRANT_ID, milestone=3, **kw):
    return _op(
        "booster_grant",
        {
            "grant_id": grant_id,
            "source": "streak_milestone",
            "milestone": milestone,
            "status": status,
        },
        **kw,
    )


def _open_op(cards, grant_id=GRANT_ID, **kw):
    return _op("booster_open", {"grant_id": grant_id, "milestone": 3, "cards": cards}, **kw)


CARDS = [
    {"card_id": "set001-001", "is_new": True, "count_after": 1},
    {"card_id": "set001-003", "is_new": True, "count_after": 1},
    {"card_id": "set001-003", "is_new": False, "count_after": 2},
    {"card_id": "set001-017", "is_new": True, "count_after": 1},
]


def test_grant_then_open_builds_the_collection(api, user):
    from srs.models import BoosterGrant, CollectionCard

    resp = api.post(SYNC, {"ops": [_grant_op()]}, format="json")
    assert resp.status_code == 200
    body = resp.json()
    assert body["rejected_ops"] == []
    (grant,) = body["rewards"]["grants"]
    assert grant["grant_id"] == GRANT_ID
    assert grant["status"] == "unopened"
    assert body["rewards"]["collection"] == []

    body = api.post(SYNC, {"ops": [_open_op(CARDS)]}, format="json").json()
    assert body["rejected_ops"] == []
    (grant,) = body["rewards"]["grants"]
    assert grant["status"] == "opened"
    assert grant["cards"] == CARDS
    collection = {c["card_id"]: c["count"] for c in body["rewards"]["collection"]}
    assert collection == {"set001-001": 1, "set001-003": 2, "set001-017": 1}

    assert BoosterGrant.objects.filter(user=user).count() == 1
    assert CollectionCard.objects.filter(user=user).count() == 3


def test_redelivered_ops_do_not_double_apply(api, user):
    from srs.models import CollectionCard

    grant = _grant_op()
    opened = _open_op(CARDS)
    api.post(SYNC, {"ops": [grant, opened]}, format="json")
    body = api.post(SYNC, {"ops": [grant, opened]}, format="json").json()
    assert body["rejected_ops"] == []
    counts = {c.card_id: c.count for c in CollectionCard.objects.filter(user=user)}
    assert counts == {"set001-001": 1, "set001-003": 2, "set001-017": 1}


def test_same_milestone_from_two_devices_converges(api, user):
    """Deterministic grant ids: two devices that honor the same milestone
    produce distinct ops but a single grant, and the first opening wins."""
    from srs.models import BoosterGrant, CollectionCard

    device_a = [_grant_op(), _open_op(CARDS)]
    device_b = [
        _grant_op(performed_at=timezone.now() + timedelta(seconds=5)),
        _open_op(CARDS, performed_at=timezone.now() + timedelta(seconds=6)),
    ]
    api.post(SYNC, {"ops": device_a}, format="json")
    body = api.post(SYNC, {"ops": device_b}, format="json").json()
    assert body["rejected_ops"] == []
    assert BoosterGrant.objects.filter(user=user).count() == 1
    counts = {c.card_id: c.count for c in CollectionCard.objects.filter(user=user)}
    assert counts == {"set001-001": 1, "set001-003": 2, "set001-017": 1}


def test_open_before_grant_still_applies(api, user):
    """An opening replayed before its grant op (multi-device order) implies
    the grant instead of failing."""
    from srs.models import BoosterGrant

    body = api.post(SYNC, {"ops": [_open_op(CARDS)]}, format="json").json()
    assert body["rejected_ops"] == []
    grant = BoosterGrant.objects.get(user=user, grant_id=GRANT_ID)
    assert grant.status == "opened"


def test_skipped_milestones_sync_and_never_regrant(api, user):
    from srs.models import BoosterGrant

    skipped = _grant_op(status="skipped_full", grant_id="streak:2026-07-01:21", milestone=21)
    api.post(SYNC, {"ops": [skipped]}, format="json")
    grant = BoosterGrant.objects.get(user=user, grant_id="streak:2026-07-01:21")
    assert grant.status == "skipped_full"


def test_malformed_rewards_ops_are_rejected_not_retried(api):
    body = api.post(
        SYNC,
        {
            "ops": [
                _op("booster_grant", {"grant_id": GRANT_ID, "milestone": 3, "status": "opened"}),
                _op("booster_open", {"grant_id": GRANT_ID, "cards": []}),
            ]
        },
        format="json",
    ).json()
    assert {o["reason"] for o in body["rejected_ops"]} == {"invalid"}
    assert body["applied_op_ids"] == []


def test_replace_cloud_resets_rewards_before_replay(api, user):
    """"Keep local" wipes the cloud rewards; the ops carried by the same
    request rebuild them from the device's state."""
    from srs.models import BoosterGrant, CollectionCard

    api.post(SYNC, {"ops": [_grant_op(), _open_op(CARDS)]}, format="json")
    local_cards = CARDS[:2]
    body = api.post(
        SYNC,
        {
            "mode": "replace_cloud",
            "last_synced_at": None,
            "ops": [
                _grant_op(grant_id="streak:2026-07-14:3"),
                _open_op(local_cards, grant_id="streak:2026-07-14:3"),
            ],
        },
        format="json",
    ).json()
    assert body["rejected_ops"] == []
    assert BoosterGrant.objects.filter(user=user).count() == 1
    counts = {c.card_id: c.count for c in CollectionCard.objects.filter(user=user)}
    assert counts == {"set001-001": 1, "set001-003": 1}
