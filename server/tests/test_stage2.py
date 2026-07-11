import io
import zipfile
from datetime import timedelta

import pytest
from django.utils import timezone

from srs.fsrs import DEFAULT_PARAMETERS
from srs.models import Card
from srs.services import (
    add_card,
    export_apkg,
    export_tsv,
    optimize_readiness,
    optimize_user,
    review_card,
    scheduler_for,
)

pytestmark = pytest.mark.django_db


def _build_history(user):
    for ch in ["あ", "い", "う", "え", "お", "か", "き"]:
        add_card(user, "kana", ch)
    base = timezone.now() - timedelta(days=12)
    for card in Card.objects.filter(user=user):
        for d in range(0, 7):  # spaced reviews across days → scoreable retention signal
            review_card(card, 3, now=base + timedelta(days=d))


def test_optimize_readiness_not_ready_by_default(seeded, user):
    _build_history(user)
    r = optimize_readiness(user)
    assert r["ready"] is False  # default threshold is 1000
    assert r["reviews"] > 0
    assert r["using_custom_parameters"] is False


def test_optimize_runs_and_returns_21_params(seeded, user):
    _build_history(user)
    result = optimize_user(user, min_reviews=1)  # low threshold for the test
    assert result["ran"] is True
    assert len(result["parameters"]) == 21
    assert result["scored_reviews"] >= 1
    # baseline metric computed
    assert result["baseline_log_loss"] is not None


def test_scheduler_honours_custom_parameters(seeded, user):
    custom = list(DEFAULT_PARAMETERS)
    custom[0] = 5.0  # a distinctive initial-stability weight for "Again"
    user.profile.fsrs_parameters = custom
    user.profile.save()
    user.refresh_from_db()
    sched = scheduler_for(user)
    assert sched.w[0] == 5.0


def test_export_tsv_is_anki_importable(seeded, user):
    add_card(user, "kana", "く")
    tsv = export_tsv(user, lang="en")
    assert "#columns:Front\tBack\tTags" in tsv
    lines = [ln for ln in tsv.splitlines() if not ln.startswith("#")]
    assert any(ln.startswith("く\t") for ln in lines)
    assert all(ln.count("\t") == 2 for ln in lines)  # exactly 3 columns


def test_export_endpoint(seeded, api):
    add_card_resp = api.post("/api/v1/study/add", {"item_type": "kana", "ref": "あ"}, format="json")
    assert add_card_resp.status_code == 201
    resp = api.get("/api/v1/study/export")
    assert resp.status_code == 200
    assert resp["Content-Type"].startswith("text/tab-separated-values")
    body = resp.content.decode()
    assert "#columns" in body and "あ\t" in body


def test_export_apkg_contains_collection_and_media(seeded, user):
    add_card(user, "kana", "あ")
    package = export_apkg(user, lang="en")
    with zipfile.ZipFile(io.BytesIO(package)) as archive:
        assert {"collection.anki2", "media"}.issubset(archive.namelist())
        assert archive.read("collection.anki2").startswith(b"SQLite format 3")


def test_export_apkg_endpoint(seeded, api):
    api.post("/api/v1/study/add", {"item_type": "kana", "ref": "あ"}, format="json")
    resp = api.get("/api/v1/study/export/apkg")
    assert resp.status_code == 200
    assert resp["Content-Type"].startswith("application/zip")
    with zipfile.ZipFile(io.BytesIO(resp.content)) as archive:
        assert "collection.anki2" in archive.namelist()


def test_capture_context_is_returned_on_card(seeded, api):
    response = api.post(
        "/api/v1/study/add",
        {
            "item_type": "kana",
            "ref": "あ",
            "source_sentence": "A source sentence.",
            "source_title": "Reader",
            "source_url": "https://example.test/1",
        },
        format="json",
    )
    assert response.status_code == 201
    payload = response.json()
    assert payload["source_sentence"] == "A source sentence."
    assert payload["source_title"] == "Reader"
