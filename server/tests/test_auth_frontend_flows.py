"""Headless allauth contracts consumed by the Flutter Web recovery routes."""

import pytest
from allauth.account import app_settings as account_settings
from allauth.account.models import EmailAddress, EmailConfirmationHMAC
from allauth.account.utils import user_pk_to_url_str
from allauth.core.internal.httpkit import add_query_params
from django.conf import settings
from rest_framework.test import APIClient

pytestmark = pytest.mark.django_db

VERIFY_EMAIL = "/_allauth/app/v1/auth/email/verify"
REQUEST_PASSWORD_RESET = "/_allauth/app/v1/auth/password/request"
RESET_PASSWORD = "/_allauth/app/v1/auth/password/reset"


def test_cors_allows_allauth_recovery_inspection_headers():
    assert {
        "x-email-verification-key",
        "x-password-reset-key",
    } <= set(settings.CORS_ALLOW_HEADERS)


def test_headless_frontend_urls_match_flutter_routes():
    urls = settings.HEADLESS_FRONTEND_URLS

    assert urls["account_confirm_email"].endswith("/verify-email/{key}")
    assert urls["account_reset_password"].endswith("/reset-password")
    assert urls["account_reset_password_from_key"].endswith("/reset-password/{key}")
    assert urls["socialaccount_login_error"].endswith("/social-error")
    assert urls["account_signup"].endswith("/register")


def test_hash_router_social_errors_keep_the_outer_query_contract():
    url = add_query_params(
        "https://my.jibiki.app/#/social-error",
        {"error": "denied", "error_process": "login"},
    )

    assert url == ("https://my.jibiki.app/?error=denied&error_process=login#/social-error")


def test_email_verification_key_can_be_inspected_then_confirmed(django_user_model):
    user = django_user_model.objects.create_user(
        email="verify@example.com", password="before-password-123"
    )
    address = EmailAddress.objects.create(
        user=user,
        email=user.email,
        primary=True,
        verified=False,
    )
    key = EmailConfirmationHMAC(address).key
    client = APIClient()

    inspected = client.get(VERIFY_EMAIL, HTTP_X_EMAIL_VERIFICATION_KEY=key)
    assert inspected.status_code == 200, inspected.content

    confirmed = client.post(VERIFY_EMAIL, {"key": key}, format="json")
    assert confirmed.status_code in (200, 401), confirmed.content
    address.refresh_from_db()
    assert address.verified is True


def test_password_reset_key_can_be_inspected_then_used(django_user_model):
    user = django_user_model.objects.create_user(
        email="reset@example.com", password="before-password-123"
    )
    EmailAddress.objects.create(
        user=user,
        email=user.email,
        primary=True,
        verified=True,
    )
    uid = user_pk_to_url_str(user)
    token_generator = account_settings.PASSWORD_RESET_TOKEN_GENERATOR()
    key = f"{uid}-{token_generator.make_token(user)}"
    client = APIClient()

    inspected = client.get(RESET_PASSWORD, HTTP_X_PASSWORD_RESET_KEY=key)
    assert inspected.status_code == 200, inspected.content

    reset = client.post(
        RESET_PASSWORD,
        {"key": key, "password": "after-password-456"},
        format="json",
    )
    assert reset.status_code in (200, 401), reset.content
    user.refresh_from_db()
    assert user.check_password("after-password-456")


def test_password_reset_request_does_not_reveal_unknown_accounts():
    response = APIClient().post(
        REQUEST_PASSWORD_RESET,
        {"email": "unknown@example.com"},
        format="json",
    )

    assert response.status_code == 200, response.content
