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
