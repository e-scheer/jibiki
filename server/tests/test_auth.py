"""allauth headless auth flow + the DRF X-Session-Token bridge.

Verifies the exact contract the Flutter app relies on: sign up via the headless
app-client endpoint, receive a session token, and reuse it as X-Session-Token to
reach an authenticated domain endpoint (/api/v1/auth/me).
"""

import pytest
from rest_framework.test import APIClient

pytestmark = pytest.mark.django_db

SIGNUP = "/_allauth/app/v1/auth/signup"
LOGIN = "/_allauth/app/v1/auth/login"
ME = "/api/v1/auth/me"


def _session_token(resp) -> str:
    body = resp.json()
    # allauth returns the app-client token in meta.session_token (and echoes it in
    # the X-Session-Token response header).
    return body.get("meta", {}).get("session_token") or resp.headers.get("X-Session-Token", "")


def test_signup_returns_token_and_me_works():
    client = APIClient()
    resp = client.post(
        SIGNUP, {"email": "new@example.com", "password": "pw-test-12345"}, format="json"
    )
    assert resp.status_code in (200, 201), resp.content
    token = _session_token(resp)
    assert token

    me = client.get(ME, HTTP_X_SESSION_TOKEN=token)
    assert me.status_code == 200, me.content
    data = me.json()
    assert data["email"] == "new@example.com"
    # the profile auto-provisioned by the signal is present
    assert data["profile"]["mode"] in {"dictionary", "middle", "learning"}


def test_me_requires_a_token():
    client = APIClient()
    assert client.get(ME).status_code in (401, 403)


def test_profile_patch_updates_mode_and_language():
    client = APIClient()
    resp = client.post(
        SIGNUP, {"email": "p@example.com", "password": "pw-test-12345"}, format="json"
    )
    token = _session_token(resp)
    patched = client.patch(
        ME,
        {"mode": "learning", "mnemonic_language": "fr", "new_cards_per_day": 20},
        format="json",
        HTTP_X_SESSION_TOKEN=token,
    )
    assert patched.status_code == 200, patched.content
    profile = patched.json()["profile"]
    assert profile["mode"] == "learning"
    assert profile["mnemonic_language"] == "fr"
    assert profile["new_cards_per_day"] == 20


def test_login_after_signup():
    client = APIClient()
    client.post(SIGNUP, {"email": "back@example.com", "password": "pw-test-12345"}, format="json")
    # a fresh client logs in with the same credentials
    fresh = APIClient()
    resp = fresh.post(
        LOGIN, {"email": "back@example.com", "password": "pw-test-12345"}, format="json"
    )
    assert resp.status_code == 200, resp.content
    assert _session_token(resp)
