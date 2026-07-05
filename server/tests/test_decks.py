import pytest

pytestmark = pytest.mark.django_db


def test_deck_catalogue(seeded, api):
    resp = api.get("/api/v1/study/decks")
    assert resp.status_code == 200
    ids = {d["id"] for d in resp.json()}
    assert {"hiragana", "katakana", "kana", "kanji_n5", "kanji_all",
            "words_common", "words_all", "favorites", "struggling"} <= ids


def test_enroll_a_whole_deck_at_once(seeded, api):
    resp = api.post("/api/v1/study/decks/hiragana/enroll", {}, format="json")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] >= 46
    assert data["enrolled"] == data["total"]  # the whole syllabary is now studyable

    # re-enrolling is idempotent (no duplicate cards)
    again = api.post("/api/v1/study/decks/hiragana/enroll", {}, format="json").json()
    assert again["enrolled"] == data["enrolled"]

    queue = api.get("/api/v1/study/decks/hiragana/queue").json()
    assert len(queue["new"]) >= 1
    assert all(c["item_type"] == "kana" for c in queue["new"])


def test_favorites_deck(seeded, api):
    card = api.post("/api/v1/study/add", {"item_type": "kana", "ref": "く"}, format="json").json()
    fav = api.post(f"/api/v1/study/cards/{card['id']}/favorite", {"value": True}, format="json")
    assert fav.status_code == 200 and fav.json()["favorite"] is True

    decks = {d["id"]: d for d in api.get("/api/v1/study/decks").json()}
    assert decks["favorites"]["enrolled"] >= 1


def test_unknown_deck_404(seeded, api):
    assert api.get("/api/v1/study/decks/nope/queue").status_code == 404
