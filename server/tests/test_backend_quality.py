"""Regressions found during the application quality audit."""

import io
import sqlite3
import uuid
import zipfile
from datetime import datetime, timedelta
from datetime import timezone as dt_timezone

import pytest
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.test import APIClient

from tests.test_sync import SYNC, _op, _review

pytestmark = pytest.mark.django_db


@pytest.fixture
def kana():
    from dictionary.models import Kana

    return Kana.objects.create(char="あ", romaji="a", script="hiragana")


def test_review_uuid_is_scoped_to_account(api, user, kana):
    review = _review("あ", 3, timezone.now())
    assert api.post(SYNC, {"reviews": [review]}, format="json").status_code == 200
    other = get_user_model().objects.create_user(email="other@example.com")
    client = APIClient()
    client.force_authenticate(other)
    response = client.post(SYNC, {"reviews": [review]}, format="json")
    assert response.status_code == 200
    assert user.review_logs.count() == other.review_logs.count() == 1


def test_same_time_reviews_converge_across_batches(api, user, kana):
    from srs.models import Card

    when = timezone.now() - timedelta(hours=1)
    first = _review("あ", 1, when, client_review_id=str(uuid.UUID(int=1)))
    second = _review("あ", 4, when, client_review_id=str(uuid.UUID(int=2)))
    api.post(SYNC, {"reviews": [second]}, format="json")
    api.post(SYNC, {"reviews": [first]}, format="json")
    other = get_user_model().objects.create_user(email="ordered@example.com")
    client = APIClient()
    client.force_authenticate(other)
    client.post(SYNC, {"reviews": [first, second]}, format="json")
    a, b = Card.objects.get(user=user), Card.objects.get(user=other)
    assert (a.state, a.step, a.due, a.stability, a.difficulty, a.reps) == (
        b.state,
        b.step,
        b.due,
        b.stability,
        b.difficulty,
        b.reps,
    )


def test_stale_card_instances_preserve_every_review(user, kana):
    from srs.models import Card
    from srs.services import add_card, review_card

    card, _ = add_card(user, "kana", "あ")
    stale = Card.objects.get(pk=card.pk)
    review_card(card, 3)
    review_card(stale, 3)
    stale.refresh_from_db()
    assert stale.reps == stale.logs.count() == 2


def test_online_review_retry_is_idempotent(api, user, kana):
    card = api.post("/api/v1/study/add", {"item_type": "kana", "ref": "あ"}, format="json").json()
    payload = {"rating": 3, "client_review_id": str(uuid.uuid4())}
    url = f"/api/v1/study/cards/{card['id']}/review"
    first = api.post(url, payload, format="json")
    assert first.status_code == 200
    second = api.post(url, payload, format="json")
    assert second.status_code == 200
    assert first.json()["review"]["id"] == second.json()["review"]["id"]
    assert user.review_logs.count() == 1


def test_delayed_offline_deletion_is_in_delta(api, kana):
    api.post("/api/v1/study/add", {"item_type": "kana", "ref": "あ"}, format="json")
    cursor = api.post(SYNC, {}, format="json").json()["synced_at"]
    deletion = _op(
        "set_status",
        {"item_type": "kana", "ref": "あ", "status": "none"},
        performed_at=timezone.now() - timedelta(days=3),
    )
    body = api.post(SYNC, {"last_synced_at": cursor, "ops": [deletion]}, format="json").json()
    assert body["deleted"] == [{"item_type": "kana", "ref": "あ"}]


def test_late_favorite_and_profile_edits_do_not_replace_newer_fields(api, kana):
    now = timezone.now()
    newer = [
        _op("favorite", {"item_type": "kana", "ref": "あ", "value": True}, now),
        _op("profile_patch", {"new_cards_per_day": 7}, now),
    ]
    api.post(SYNC, {"ops": newer}, format="json")
    older = [
        _op(
            "favorite", {"item_type": "kana", "ref": "あ", "value": False}, now - timedelta(days=1)
        ),
        _op(
            "profile_patch",
            {"new_cards_per_day": 20, "display_name": "Name"},
            now - timedelta(days=1),
        ),
    ]
    body = api.post(SYNC, {"ops": older}, format="json").json()
    assert body["cards"][0]["favorite"] is True
    assert body["profile"]["new_cards_per_day"] == 7
    assert body["profile"]["display_name"] == "Name"


@pytest.mark.parametrize(
    "kind,payload",
    [
        ("set_status", {"item_type": "kana", "ref": "あ", "status": "invalid"}),
        ("favorite", {"item_type": "kana", "ref": "あ", "value": []}),
        ("profile_patch", [1]),
        ("bulk_add", {"items": [{"item_type": "kana", "ref": "あ"}], "source_title": "x" * 201}),
        ("booster_grant", {"grant_id": "grant", "milestone": -1}),
        ("booster_open", {"grant_id": "grant", "cards": [{"card_id": "x", "count_after": -1}]}),
    ],
)
def test_malformed_op_is_rejected_without_aborting_batch(api, kana, kind, payload):
    bad = _op(kind, payload)
    good = _op("profile_patch", {"display_name": "Works"})
    response = api.post(SYNC, {"ops": [bad, good]}, format="json")
    assert response.status_code == 200
    assert response.json()["rejected_ops"] == [{"id": bad["client_op_id"], "reason": "invalid"}]
    assert response.json()["profile"]["display_name"] == "Works"


def test_pending_mnemonic_of_another_author_is_private(api, user):
    from mnemonics.models import Mnemonic

    other = get_user_model().objects.create_user(email="author@example.com")
    mnemonic = Mnemonic.objects.create(
        author=other,
        character="あ",
        kind="kana",
        language="en",
        story="Pending private work",
        status="pending",
    )
    op = _op("mnemonic_choose", {"mnemonic_id": mnemonic.pk})
    body = api.post(SYNC, {"ops": [op]}, format="json").json()
    assert body["rejected_ops"] == [{"id": op["client_op_id"], "reason": "unknown_mnemonic"}]
    assert not user.mnemonic_choices.exists()


def test_deck_serialization_excludes_moderated_and_other_pending_content(user):
    from mnemonics.models import Mnemonic
    from mnemonics.serializers import MnemonicDeckDetailSerializer
    from mnemonics.services import create_deck

    public = Mnemonic.objects.create(
        author=user, character="あ", kind="kana", language="en", story="Public"
    )
    hidden = Mnemonic.objects.create(
        author=user, character="い", kind="kana", language="en", story="Hidden", status="hidden"
    )
    pending = Mnemonic.objects.create(
        author=user, character="う", kind="kana", language="en", story="Pending", status="pending"
    )
    deck = create_deck(user, title="Pack", mnemonic_ids=[public.pk, hidden.pk, pending.pk])
    serialized = MnemonicDeckDetailSerializer(deck).data
    assert serialized["item_count"] == 1
    assert [item["id"] for item in serialized["items"]] == [public.pk]
    assert Mnemonic.objects.filter(pk=hidden.pk).exists()


def test_profile_update_does_not_overwrite_concurrent_entitlement(user):
    from accounts.models import UserProfile
    from accounts.serializers import ProfileSerializer

    profile = user.profile
    UserProfile.objects.filter(pk=profile.pk).update(plan="premium")
    serializer = ProfileSerializer(profile, data={"display_name": "New"}, partial=True)
    assert serializer.is_valid()
    serializer.save()
    profile.refresh_from_db()
    assert profile.plan == "premium"


def test_profile_rejects_invalid_timezone(user):
    from accounts.serializers import ProfileSerializer

    serializer = ProfileSerializer(
        user.profile, data={"timezone": "invalid/timezone"}, partial=True
    )
    assert not serializer.is_valid()


def test_daily_introductions_use_profile_timezone(user, kana):
    from srs.services import add_card, new_introduced_today, review_card, streak_days

    user.profile.timezone = "Asia/Tokyo"
    user.profile.save()
    now = datetime(2026, 8, 5, 16, tzinfo=dt_timezone.utc)
    card, _ = add_card(user, "kana", "あ")
    review_card(card, 3, now=now - timedelta(hours=2))
    assert new_introduced_today(user, now=now) == 0
    assert streak_days(user, now=now) == 1


def test_apkg_escapes_context_and_preserves_field_boundaries(user, kana):
    from srs.services import _clean, add_card, export_apkg

    add_card(
        user, "kana", "あ", context={"source_sentence": '<script>alert("bad")</script>\x1fextra'}
    )
    package = export_apkg(user)
    with zipfile.ZipFile(io.BytesIO(package)) as archive:
        db = sqlite3.connect(":memory:")
        db.deserialize(archive.read("collection.anki2"))
        fields = db.execute("select flds from notes").fetchone()[0]
        db.close()
    assert len(fields.split("\x1f")) == 2
    assert "<script>" not in fields
    assert "&lt;script&gt;" in fields
    assert "\r" not in _clean("one\rtwo")


@pytest.mark.django_db(transaction=True)
def test_concurrent_sync_redelivery_commits_one_review(user, kana):
    from concurrent.futures import ThreadPoolExecutor
    from threading import Barrier

    from django.db import close_old_connections

    barrier = Barrier(2)
    review = _review("あ", 3, timezone.now())

    def deliver():
        close_old_connections()
        try:
            client = APIClient()
            client.force_authenticate(get_user_model().objects.get(pk=user.pk))
            barrier.wait(timeout=10)
            response = client.post(SYNC, {"reviews": [review]}, format="json")
            return response.status_code, response.json()["applied_review_ids"]
        finally:
            close_old_connections()

    with ThreadPoolExecutor(max_workers=2) as executor:
        responses = list(executor.map(lambda _: deliver(), range(2)))
    assert responses == [(200, [review["client_review_id"]])] * 2
    assert user.review_logs.count() == 1
    assert user.cards.get().reps == 1


def test_wanikani_refresh_returns_current_connection(user, monkeypatch):
    from integrations import services

    preview = {"username": "Before", "threshold_stage": 5, "items": []}
    monkeypatch.setattr(services, "build_wanikani_preview", lambda *args: dict(preview))
    connection, _ = services.save_wanikani_preview(user, "token")
    preview.update(username="After", items=[{"item_type": "kana", "ref": "あ"}])
    result = services.refresh_wanikani_preview(connection)
    assert connection.username == result["username"] == "After"
    assert connection.pending_preview["items"]


def test_wanikani_import_rolls_back_if_second_group_fails(user, kana, monkeypatch):
    from integrations import services
    from integrations.models import WaniKaniConnection

    preview = {
        "items": [
            {"item_type": "kana", "ref": "あ", "known": True},
            {"item_type": "kana", "ref": "い", "known": False},
        ]
    }
    connection = WaniKaniConnection.objects.create(user=user, pending_preview=preview)
    original = services.bulk_add

    def add(*args, **kwargs):
        if not kwargs.get("known"):
            raise RuntimeError("Import interrupted")
        return original(*args, **kwargs)

    monkeypatch.setattr(services, "bulk_add", add)
    with pytest.raises(RuntimeError):
        services.import_wanikani_preview(connection)
    assert not user.cards.exists()
    connection.refresh_from_db()
    assert connection.pending_preview == preview


def test_cloud_replacement_retry_preserves_later_work(api, user, kana):
    from dictionary.models import Kana

    Kana.objects.create(char="い", romaji="i", script="hiragana")
    payload = {
        "mode": "replace_cloud",
        "replacement_id": str(uuid.uuid4()),
        "reviews": [_review("あ", 3, timezone.now() - timedelta(days=1))],
    }
    first = api.post(SYNC, payload, format="json")
    assert first.status_code == 200
    # First response was lost. Another device studies before the retry.
    api.post(SYNC, {"reviews": [_review("い", 3, timezone.now())]}, format="json")
    retry = api.post(SYNC, payload, format="json")
    assert retry.status_code == 200
    assert retry.json()["applied_review_ids"] == first.json()["applied_review_ids"]
    assert user.cards.count() == user.review_logs.count() == 2


def test_cloud_replacement_propagates_removed_cards(api, kana):
    api.post("/api/v1/study/add", {"item_type": "kana", "ref": "あ"}, format="json")
    cursor = api.post(SYNC, {}, format="json").json()["synced_at"]
    response = api.post(
        SYNC, {"mode": "replace_cloud", "replacement_id": str(uuid.uuid4())}, format="json"
    )
    assert response.status_code == 200
    body = api.post(SYNC, {"last_synced_at": cursor}, format="json").json()
    assert body["deleted"] == [{"item_type": "kana", "ref": "あ"}]
