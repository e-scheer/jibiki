"""WaniKani integration safety: connect creates a preview, import is explicit."""

import pytest

pytestmark = pytest.mark.django_db


def test_wanikani_connect_returns_preview_without_creating_cards(api, user, monkeypatch):
    from integrations import services

    monkeypatch.setattr(
        services,
        "build_wanikani_preview",
        lambda _user, _token, threshold: {
            "provider": "wanikani",
            "username": "learner",
            "threshold": threshold,
            "threshold_stage": 5,
            "recognized": 2,
            "ambiguous": 0,
            "ignored": 0,
            "new_cards": 2,
            "known_cards": 1,
            "learning_cards": 1,
            "estimated_new_reviews": 1,
            "items": [
                {"item_type": "kanji", "ref": "学", "known": True},
                {"item_type": "kanji", "ref": "習", "known": False},
            ],
        },
    )
    response = api.post(
        "/api/v1/integrations/wanikani/connect",
        {"token": "a" * 32, "threshold": "guru"},
        format="json",
    )
    assert response.status_code == 200
    assert response.json()["pending"] is True
    assert response.json()["preview"]["new_cards"] == 2
    assert not user.cards.exists()


def test_wanikani_cancel_discards_pending_preview(api, user, monkeypatch):
    from integrations import services

    monkeypatch.setattr(
        services,
        "build_wanikani_preview",
        lambda *_args: {
            "provider": "wanikani",
            "username": "learner",
            "threshold": "guru",
            "threshold_stage": 5,
            "recognized": 0,
            "ambiguous": 0,
            "ignored": 0,
            "new_cards": 0,
            "known_cards": 0,
            "learning_cards": 0,
            "estimated_new_reviews": 0,
            "items": [],
        },
    )
    api.post(
        "/api/v1/integrations/wanikani/connect",
        {"token": "a" * 32, "threshold": "guru"},
        format="json",
    )
    response = api.post("/api/v1/integrations/wanikani/cancel")
    assert response.status_code == 200
    assert response.json()["cancelled"] is True
