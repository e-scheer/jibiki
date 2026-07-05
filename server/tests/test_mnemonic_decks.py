"""Community mnemonic decks (drawing → pack → propose) + the 🔖 save bookmark."""

import pytest
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient

from mnemonics.models import Mnemonic, MnemonicStatus

pytestmark = pytest.mark.django_db

User = get_user_model()


def _mk(author, char, kind="kana", lang="en"):
    return Mnemonic.objects.create(
        character=char,
        kind=kind,
        language=lang,
        story=f"{char} story",
        author=author,
        status=MnemonicStatus.VISIBLE,
    )


def _staff_client():
    staff = User.objects.create_superuser(email="mod@example.com", password="pw-test-12345")
    client = APIClient()
    client.force_authenticate(user=staff)
    return staff, client


def test_create_deck_is_draft_by_default(api, user):
    m = _mk(user, "く")
    resp = api.post(
        "/api/v1/mnemonics/decks/create",
        {"title": "My hiragana", "language": "en", "kind": "kana", "mnemonic_ids": [m.id]},
        format="json",
    )
    assert resp.status_code == 201, resp.content
    data = resp.json()
    assert data["status"] == "draft"
    assert data["item_count"] == 1
    assert data["title"] == "My hiragana"


def test_deck_admits_only_authors_own_mnemonics_of_kind(api, user):
    mine = _mk(user, "く")
    wrong_kind = _mk(user, "水", kind="kanji")  # deck is kana → excluded
    other = User.objects.create_user(email="other@example.com", password="pw-test-12345")
    theirs = _mk(other, "さ")
    resp = api.post(
        "/api/v1/mnemonics/decks/create",
        {"title": "Pack", "kind": "kana", "mnemonic_ids": [mine.id, theirs.id, wrong_kind.id]},
        format="json",
    )
    assert resp.status_code == 201
    assert resp.json()["item_count"] == 1  # only `mine` survives


def test_draft_hidden_from_community_but_shown_in_mine(api, user):
    m = _mk(user, "く")
    api.post(
        "/api/v1/mnemonics/decks/create",
        {"title": "D", "kind": "kana", "mnemonic_ids": [m.id]},
        format="json",
    )
    assert api.get("/api/v1/mnemonics/decks").json()["results"] == []
    mine = api.get("/api/v1/mnemonics/decks", {"mine": "1"}).json()["results"]
    assert len(mine) == 1


def test_staff_publish_makes_deck_visible_in_community(seeded):
    staff, client = _staff_client()
    ms = _mk(staff, "く")
    resp = client.post(
        "/api/v1/mnemonics/decks/create",
        {"title": "Official", "kind": "kana", "mnemonic_ids": [ms.id], "publish": True},
        format="json",
    )
    assert resp.json()["status"] == "visible"
    community = client.get("/api/v1/mnemonics/decks").json()["results"]
    assert any(d["title"] == "Official" for d in community)


def test_low_trust_publish_is_held_pending(api, user):
    m = _mk(user, "く")
    resp = api.post(
        "/api/v1/mnemonics/decks/create",
        {"title": "D", "kind": "kana", "mnemonic_ids": [m.id], "publish": True},
        format="json",
    )
    assert resp.json()["status"] == "pending"


def test_publish_endpoint_transitions_draft(api, user):
    m = _mk(user, "く")
    deck_id = api.post(
        "/api/v1/mnemonics/decks/create",
        {"title": "D", "kind": "kana", "mnemonic_ids": [m.id]},
        format="json",
    ).json()["id"]
    resp = api.post(f"/api/v1/mnemonics/decks/{deck_id}/publish", format="json")
    assert resp.status_code == 200
    assert resp.json()["status"] == "pending"  # low trust → pending, not draft


def test_like_a_deck_updates_score(seeded):
    staff, client = _staff_client()
    ms = _mk(staff, "く")
    deck_id = client.post(
        "/api/v1/mnemonics/decks/create",
        {"title": "D", "kind": "kana", "mnemonic_ids": [ms.id], "publish": True},
        format="json",
    ).json()["id"]
    voter = User.objects.create_user(email="v@example.com", password="pw-test-12345")
    vc = APIClient()
    vc.force_authenticate(user=voter)
    assert (
        vc.post(f"/api/v1/mnemonics/decks/{deck_id}/vote", {"value": 1}, format="json").json()[
            "score"
        ]
        == 1
    )
    assert (
        vc.post(f"/api/v1/mnemonics/decks/{deck_id}/vote", {"value": 0}, format="json").json()[
            "score"
        ]
        == 0
    )


def test_deck_detail_includes_ordered_items(api, user):
    a, b = _mk(user, "く"), _mk(user, "さ")
    deck_id = api.post(
        "/api/v1/mnemonics/decks/create",
        {"title": "D", "kind": "kana", "mnemonic_ids": [b.id, a.id]},
        format="json",
    ).json()["id"]
    items = api.get(f"/api/v1/mnemonics/decks/{deck_id}").json()["items"]
    assert [it["character"] for it in items] == ["さ", "く"]  # preserves given order


def test_save_toggle_and_saved_list(api, user):
    m = _mk(user, "く")
    assert api.post(f"/api/v1/mnemonics/{m.id}/save", format="json").json()["saved"] is True
    saved = api.get("/api/v1/mnemonics/saved").json()
    assert any(x["id"] == m.id and x["saved"] for x in saved)
    assert api.post(f"/api/v1/mnemonics/{m.id}/save", format="json").json()["saved"] is False
    assert api.get("/api/v1/mnemonics/saved").json() == []


def test_enroll_community_deck_creates_cards(seeded, api, user):
    m = _mk(user, "く")  # く exists in the seeded kana table
    deck_id = api.post(
        "/api/v1/mnemonics/decks/create",
        {"title": "D", "kind": "kana", "mnemonic_ids": [m.id]},
        format="json",
    ).json()["id"]
    resp = api.post(f"/api/v1/mnemonics/decks/{deck_id}/enroll", format="json")
    assert resp.status_code == 200
    assert resp.json()["enrolled"] >= 1
    from srs.models import Card

    assert Card.objects.filter(user=user, kana__char="く").exists()


def test_create_deck_requires_auth(client):
    resp = client.post(
        "/api/v1/mnemonics/decks/create",
        {"title": "D", "kind": "kana"},
        format="json",
    )
    assert resp.status_code in (401, 403)
