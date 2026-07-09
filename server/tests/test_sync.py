"""/study/sync - offline outbox replay, idempotency, convergence, delta."""

import uuid
from datetime import timedelta

import pytest
from django.utils import timezone

pytestmark = pytest.mark.django_db

SYNC = "/api/v1/study/sync"


def _review(ref, rating, reviewed_at, item_type="kana", **extra):
    return {
        "client_review_id": str(uuid.uuid4()),
        "item_type": item_type,
        "ref": ref,
        "rating": rating,
        "reviewed_at": reviewed_at.isoformat(),
        **extra,
    }


def _op(kind, payload, performed_at=None):
    return {
        "client_op_id": str(uuid.uuid4()),
        "kind": kind,
        "payload": payload,
        "performed_at": (performed_at or timezone.now()).isoformat(),
    }


@pytest.fixture
def kana(db):
    from dictionary.models import Kana

    return Kana.objects.create(char="あ", romaji="a", script="hiragana")


def test_reviews_create_missing_cards_and_apply(kana, api):
    t = timezone.now() - timedelta(hours=1)
    reviews = [_review("あ", 3, t), _review("あ", 3, t + timedelta(minutes=10))]
    resp = api.post(SYNC, {"last_synced_at": None, "reviews": reviews}, format="json")
    assert resp.status_code == 200
    body = resp.json()
    assert set(body["applied_review_ids"]) == {r["client_review_id"] for r in reviews}
    assert body["rejected"] == []
    # A review proves intent to study: the card was created and advanced.
    (card,) = body["cards"]
    assert card["item_ref"] == "あ"
    assert card["reps"] == 2
    assert card["state"] == 2  # graduated through both learning steps


def test_redelivery_is_idempotent(kana, api, user):
    from srs.models import ReviewLog

    t = timezone.now() - timedelta(minutes=30)
    reviews = [_review("あ", 3, t)]
    first = api.post(SYNC, {"reviews": reviews}, format="json").json()
    second = api.post(SYNC, {"reviews": reviews}, format="json").json()
    assert first["applied_review_ids"] == second["applied_review_ids"]
    assert ReviewLog.objects.filter(user=user).count() == 1


def test_shuffled_outboxes_converge(kana, api):
    """Two devices review the same card offline; whatever order their outboxes
    reach the server, the folded state is identical (the convergence rule)."""
    from django.contrib.auth import get_user_model
    from rest_framework.test import APIClient

    from srs.models import Card

    t0 = timezone.now() - timedelta(days=10)
    # Device A reviewed early, device B later; B syncs first → out-of-order fold.
    device_a = [_review("あ", 3, t0), _review("あ", 3, t0 + timedelta(minutes=10))]
    device_b = [_review("あ", 2, t0 + timedelta(days=3)), _review("あ", 4, t0 + timedelta(days=6))]

    users = []
    for i, batches in enumerate([(device_a, device_b), (device_b, device_a)]):
        u = get_user_model().objects.create_user(
            email=f"sync-{i}@example.com", password="pw-test-12345"
        )
        client = APIClient()
        client.force_authenticate(user=u)
        for batch in batches:
            # Fresh UUIDs per user - the id is an idempotency key, not identity.
            resp = client.post(
                SYNC,
                {"reviews": [{**r, "client_review_id": str(uuid.uuid4())} for r in batch]},
                format="json",
            )
            assert resp.status_code == 200
        users.append(u)

    a = Card.objects.get(user=users[0])
    b = Card.objects.get(user=users[1])
    assert (a.state, a.step, a.reps, a.lapses) == (b.state, b.step, b.reps, b.lapses)
    assert a.stability == pytest.approx(b.stability, rel=1e-12)
    assert a.difficulty == pytest.approx(b.difficulty, rel=1e-12)
    assert a.due == b.due
    assert a.last_review == b.last_review


def test_tombstone_wins_over_late_review(kana, api):
    # Add + delete (tombstone) online, then a stale offline review arrives.
    api.post(
        SYNC, {"reviews": [_review("あ", 3, timezone.now() - timedelta(days=2))]}, format="json"
    )
    api.post(
        "/api/v1/study/set",
        {"item_type": "kana", "ref": "あ", "status": "none"},
        format="json",
    )
    stale = _review("あ", 4, timezone.now() - timedelta(days=1))
    body = api.post(SYNC, {"reviews": [stale]}, format="json").json()
    assert body["applied_review_ids"] == []
    assert body["rejected"] == [{"id": stale["client_review_id"], "reason": "deleted"}]


def test_deleted_cards_reach_other_devices(kana, api):
    first = api.post(SYNC, {"reviews": [_review("あ", 3, timezone.now())]}, format="json").json()
    cursor = first["synced_at"]
    api.post(
        "/api/v1/study/set",
        {"item_type": "kana", "ref": "あ", "status": "none"},
        format="json",
    )
    body = api.post(SYNC, {"last_synced_at": cursor}, format="json").json()
    assert body["deleted"] == [{"item_type": "kana", "ref": "あ"}]
    # Re-adding revokes the tombstone from the delta.
    api.post("/api/v1/study/add", {"item_type": "kana", "ref": "あ"}, format="json")
    body = api.post(SYNC, {"last_synced_at": cursor}, format="json").json()
    assert body["deleted"] == []
    assert [c["item_ref"] for c in body["cards"]] == ["あ"]


def test_future_timestamps_are_clamped(kana, api, user):
    from srs.models import ReviewLog

    body = api.post(
        SYNC,
        {"reviews": [_review("あ", 3, timezone.now() + timedelta(days=7))]},
        format="json",
    ).json()
    assert len(body["applied_review_ids"]) == 1
    log = ReviewLog.objects.get(user=user)
    assert log.reviewed_at <= timezone.now() + timedelta(minutes=3)


def test_unknown_item_is_rejected(api):
    ghost = _review("🍜", 3, timezone.now(), item_type="kanji")
    body = api.post(SYNC, {"reviews": [ghost]}, format="json").json()
    assert body["rejected"] == [{"id": ghost["client_review_id"], "reason": "unknown_item"}]


def test_null_cursor_downloads_full_deck(kana, api):
    api.post("/api/v1/study/add", {"item_type": "kana", "ref": "あ"}, format="json")
    body = api.post(SYNC, {"last_synced_at": None}, format="json").json()
    assert [c["item_ref"] for c in body["cards"]] == ["あ"]
    assert body["profile"]["new_cards_per_day"] > 0
    assert "fsrs_parameters" in body["profile"]


def test_delta_only_returns_changed_cards(kana, api):
    from dictionary.models import Kana

    Kana.objects.create(char="い", romaji="i", script="hiragana")
    api.post("/api/v1/study/add", {"item_type": "kana", "ref": "あ"}, format="json")
    cursor = api.post(SYNC, {}, format="json").json()["synced_at"]

    body = api.post(
        SYNC,
        {"last_synced_at": cursor, "reviews": [_review("い", 3, timezone.now())]},
        format="json",
    ).json()
    # Only the card touched by this very request comes back, not the idle one.
    assert [c["item_ref"] for c in body["cards"]] == ["い"]


def test_ops_apply_and_are_idempotent(kana, api, user):
    from srs.models import Card

    ops = [
        _op("set_status", {"item_type": "kana", "ref": "あ", "status": "learning"}),
        _op("favorite", {"item_type": "kana", "ref": "あ", "value": True}),
        _op("profile_patch", {"new_cards_per_day": 7}),
    ]
    body = api.post(SYNC, {"ops": ops}, format="json").json()
    assert set(body["applied_op_ids"]) == {o["client_op_id"] for o in ops}
    assert body["rejected_ops"] == []
    card = Card.objects.get(user=user)
    assert card.favorite is True
    assert body["profile"]["new_cards_per_day"] == 7

    # Redelivery acks without re-applying (favorite would toggle if re-run).
    again = api.post(SYNC, {"ops": ops}, format="json").json()
    assert set(again["applied_op_ids"]) == {o["client_op_id"] for o in ops}
    assert Card.objects.get(user=user).favorite is True


def test_bad_ops_are_rejected_not_retried(api):
    ops = [
        _op("deck_enroll", {"deck_id": "nope"}),
        _op("teleport", {}),
        _op("set_status", {"oops": True}),
    ]
    body = api.post(SYNC, {"ops": ops}, format="json").json()
    reasons = {r["id"]: r["reason"] for r in body["rejected_ops"]}
    assert reasons[ops[0]["client_op_id"]] == "unknown_deck"
    assert reasons[ops[1]["client_op_id"]] == "unknown_kind"
    assert reasons[ops[2]["client_op_id"]] == "invalid"
    assert body["applied_op_ids"] == []


def test_mnemonic_ops(kana, api, user):
    from mnemonics.models import Mnemonic, MnemonicSave, MnemonicStatus, MnemonicVote

    m = Mnemonic.objects.create(
        character="あ",
        kind="kana",
        language="en",
        story="Antenna!",
        status=MnemonicStatus.VISIBLE,
        is_seed=True,
    )
    ops = [
        _op("mnemonic_vote", {"mnemonic_id": m.id, "value": 1}),
        _op("mnemonic_save", {"mnemonic_id": m.id, "value": True}),
        _op("mnemonic_choose", {"mnemonic_id": m.id}),
    ]
    body = api.post(SYNC, {"ops": ops}, format="json").json()
    assert body["rejected_ops"] == []
    assert MnemonicVote.objects.filter(user=user, mnemonic=m, value=1).exists()
    assert MnemonicSave.objects.filter(user=user, mnemonic=m).exists()
    assert user.mnemonic_choices.filter(mnemonic=m).exists()

    # Redelivered save must not toggle back off.
    api.post(SYNC, {"ops": [ops[1]]}, format="json")
    assert MnemonicSave.objects.filter(user=user, mnemonic=m).exists()


def test_local_only_history_upload(kana, api, user):
    """Account-link: a device that studied without an account uploads its whole
    history in one first sync - logs land chronologically, state folds once."""
    from srs.models import Card, ReviewLog

    t0 = timezone.now() - timedelta(days=30)
    reviews = [
        _review("あ", 3, t0),
        _review("あ", 3, t0 + timedelta(minutes=10)),
        _review("あ", 3, t0 + timedelta(days=3)),
        _review("あ", 1, t0 + timedelta(days=10)),
        _review("あ", 3, t0 + timedelta(days=10, minutes=10)),
    ]
    body = api.post(SYNC, {"last_synced_at": None, "reviews": reviews}, format="json").json()
    assert len(body["applied_review_ids"]) == 5
    card = Card.objects.get(user=user)
    assert card.reps == 5
    assert card.lapses == 1  # the Again from review state
    assert ReviewLog.objects.filter(user=user).count() == 5
