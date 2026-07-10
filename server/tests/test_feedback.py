"""In-app feedback endpoint - open, validated, context-preserving."""

import pytest

pytestmark = pytest.mark.django_db

URL = "/api/v1/feedback"


def test_signed_in_feedback_attaches_the_user(api, user):
    from feedback.models import Feedback

    resp = api.post(
        URL,
        {
            "kind": "idea",
            "message": "Let me pin a deck to the home screen.",
            "context": {"platform": "android", "packs": ["dict-base"]},
        },
        format="json",
    )
    assert resp.status_code == 201
    item = Feedback.objects.get(pk=resp.json()["id"])
    assert item.user == user
    assert item.kind == "idea"
    assert item.context["platform"] == "android"
    assert item.status == "new"


def test_anonymous_feedback_is_accepted_with_reply_email(db):
    from rest_framework.test import APIClient

    from feedback.models import Feedback

    resp = APIClient().post(
        URL,
        {"kind": "bug", "message": "Stroke order stalls on 水.", "email": "who@example.com"},
        format="json",
    )
    assert resp.status_code == 201
    item = Feedback.objects.get(pk=resp.json()["id"])
    assert item.user is None
    assert item.email == "who@example.com"


def test_empty_or_junk_messages_are_rejected(api):
    assert api.post(URL, {"kind": "bug", "message": "  "}, format="json").status_code == 400
    assert (
        api.post(URL, {"kind": "nope", "message": "hello there"}, format="json").status_code == 400
    )


REPORT_URL = "/api/v1/feedback/report"


def test_signed_in_user_can_report_a_dictionary_entry(api, user):
    from feedback.models import ContentReport

    resp = api.post(
        REPORT_URL,
        {
            "item_type": "kanji",
            "item_ref": "水",
            "reason": "missing",
            "message": "The nanori reading is missing.",
            "context": {"platform": "android"},
        },
        format="json",
    )
    assert resp.status_code == 201
    report = ContentReport.objects.get(pk=resp.json()["id"])
    assert report.reporter == user
    assert report.item_type == "kanji"
    assert report.item_ref == "水"
    assert report.reason == "missing"
    assert report.status == "new"


def test_reporting_requires_sign_in(db):
    from rest_framework.test import APIClient

    resp = APIClient().post(
        REPORT_URL,
        {"item_type": "word", "item_ref": "1234", "reason": "wrong"},
        format="json",
    )
    assert resp.status_code in (401, 403)


def test_re_reporting_the_same_entry_updates_in_place(api, user):
    from feedback.models import ContentReport

    first = api.post(
        REPORT_URL, {"item_type": "kana", "item_ref": "あ", "reason": "typo"}, format="json"
    )
    second = api.post(
        REPORT_URL,
        {"item_type": "kana", "item_ref": "あ", "reason": "wrong", "message": "Actually mislabeled."},
        format="json",
    )
    assert first.status_code == second.status_code == 201
    # Same row, updated, not a duplicate.
    assert first.json()["id"] == second.json()["id"]
    assert ContentReport.objects.filter(reporter=user, item_type="kana", item_ref="あ").count() == 1
    report = ContentReport.objects.get(pk=second.json()["id"])
    assert report.reason == "wrong"
    assert report.message == "Actually mislabeled."


def test_invalid_report_fields_are_rejected(api):
    # Unknown reason.
    assert (
        api.post(
            REPORT_URL, {"item_type": "kanji", "item_ref": "火", "reason": "nope"}, format="json"
        ).status_code
        == 400
    )
    # Unknown item type.
    assert (
        api.post(
            REPORT_URL, {"item_type": "sentence", "item_ref": "x", "reason": "wrong"}, format="json"
        ).status_code
        == 400
    )
    # Blank item ref.
    assert (
        api.post(
            REPORT_URL, {"item_type": "kanji", "item_ref": "", "reason": "wrong"}, format="json"
        ).status_code
        == 400
    )
