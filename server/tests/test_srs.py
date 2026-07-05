import pytest

pytestmark = pytest.mark.django_db


def _first_word_id():
    from dictionary.models import Word

    return Word.objects.filter(forms__text="食べる").first().pk


def test_add_card_then_appears_as_new(seeded, api):
    wid = _first_word_id()
    resp = api.post("/api/v1/study/add", {"item_type": "word", "ref": str(wid)}, format="json")
    assert resp.status_code == 201
    assert resp.json()["item_type"] == "word"

    queue = api.get("/api/v1/study/queue").json()
    new_refs = {c["item_ref"] for c in queue["new"]}
    assert str(wid) in new_refs


def test_add_card_is_idempotent(seeded, api):
    wid = _first_word_id()
    r1 = api.post("/api/v1/study/add", {"item_type": "word", "ref": str(wid)}, format="json")
    r2 = api.post("/api/v1/study/add", {"item_type": "word", "ref": str(wid)}, format="json")
    assert r1.status_code == 201
    assert r2.status_code == 200  # already existed


def test_add_kana_and_kanji_cards(seeded, api):
    assert (
        api.post("/api/v1/study/add", {"item_type": "kana", "ref": "く"}, format="json").status_code
        == 201
    )
    assert (
        api.post(
            "/api/v1/study/add", {"item_type": "kanji", "ref": "水"}, format="json"
        ).status_code
        == 201
    )


def test_review_advances_card_and_logs(seeded, api):
    wid = _first_word_id()
    card = api.post(
        "/api/v1/study/add", {"item_type": "word", "ref": str(wid)}, format="json"
    ).json()
    resp = api.post(
        f"/api/v1/study/cards/{card['id']}/review",
        {"rating": 3, "duration_ms": 2500},
        format="json",
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["card"]["reps"] == 1
    assert body["card"]["stability"] is not None
    assert body["review"]["rating"] == 3

    stats = api.get("/api/v1/study/stats").json()
    assert stats["reviews_today"] == 1
    assert stats["streak"] == 1


def test_unknown_item_is_404(seeded, api):
    resp = api.post("/api/v1/study/add", {"item_type": "kanji", "ref": "🍜"}, format="json")
    assert resp.status_code == 404


def test_delete_card(seeded, api):
    card = api.post("/api/v1/study/add", {"item_type": "kana", "ref": "あ"}, format="json").json()
    assert api.delete(f"/api/v1/study/cards/{card['id']}").status_code == 204
    assert api.get("/api/v1/study/cards").json() == []


def test_queue_requires_auth(seeded, client):
    assert client.get("/api/v1/study/queue").status_code in (401, 403)


def test_new_cards_are_a_session_batch_not_a_daily_wall(seeded, api, user):
    """The queue serves a per-session batch of new cards, and `?new_limit=` pulls
    the rest on demand — so the app can offer "Study more" instead of walling the
    user off for the day."""
    user.profile.new_cards_per_day = 2
    user.profile.save()
    for ch in ["あ", "い", "う", "え"]:
        assert (
            api.post("/api/v1/study/add", {"item_type": "kana", "ref": ch}, format="json").status_code
            == 201
        )

    # Default: one batch of new cards, with the full pool size reported.
    q = api.get("/api/v1/study/queue").json()
    assert len(q["new"]) == 2
    assert q["counts"]["new_available"] == 4
    assert q["counts"]["new_remaining"] == 2

    # "Study more": pull everything left — no daily cap in the way.
    more = api.get("/api/v1/study/queue?new_limit=100").json()
    assert len(more["new"]) == 4
    assert more["counts"]["new_available"] == 4


def test_bulk_add_new_cards(seeded, api):
    items = [{"item_type": "kana", "ref": ch} for ch in ["あ", "い", "う"]]
    resp = api.post("/api/v1/study/add/bulk", {"items": items}, format="json")
    assert resp.status_code == 200
    body = resp.json()
    assert body == {"requested": 3, "resolved": 3, "created": 3, "known": False}

    # They land as new cards, ready to learn.
    q = api.get("/api/v1/study/queue?new_limit=100").json()
    new_refs = {c["item_ref"] for c in q["new"]}
    assert {"あ", "い", "う"} <= new_refs


def test_bulk_mark_known_seeds_mature_cards_out_of_the_new_queue(seeded, api):
    """"I know all of these": known items become mature REVIEW cards, so they are
    counted as studied and kept OUT of the new-learning queue."""
    items = [{"item_type": "kana", "ref": ch} for ch in ["あ", "い", "う", "え", "お"]]
    resp = api.post("/api/v1/study/add/bulk", {"items": items, "known": True}, format="json")
    assert resp.status_code == 200
    assert resp.json() == {"requested": 5, "resolved": 5, "created": 5, "known": True}

    # None of them show up as new to learn.
    q = api.get("/api/v1/study/queue?new_limit=100").json()
    new_refs = {c["item_ref"] for c in q["new"]}
    assert new_refs.isdisjoint({"あ", "い", "う", "え", "お"})

    # They count as studied (REVIEW state), not new.
    stats = api.get("/api/v1/study/stats").json()
    assert stats["by_state"]["review"] == 5
    assert stats["by_state"]["new"] == 0

    # No synthetic reviews were logged.
    assert stats["reviews_today"] == 0


def test_card_states_reports_seen_and_known(seeded, api):
    api.post("/api/v1/study/add", {"item_type": "kana", "ref": "か"}, format="json")
    api.post(
        "/api/v1/study/add/bulk",
        {"items": [{"item_type": "kana", "ref": "き"}], "known": True},
        format="json",
    )
    states = api.get("/api/v1/study/states?item_type=kana").json()
    assert states["か"] == 0  # new / seen
    assert states["き"] == 2  # review / known


def test_bulk_add_rejects_empty(seeded, api):
    resp = api.post("/api/v1/study/add/bulk", {"items": []}, format="json")
    assert resp.status_code == 400
