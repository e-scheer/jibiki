"""Shared fixtures. The offline SQLite DB is pinned in the root conftest.py
(it must run before pytest-django configures Django); this file only holds
fixtures used across the suite.
"""

import pytest
from django.core.management import call_command


@pytest.fixture
def seeded(db):
    """A database populated with the curated demo dataset (dictionary + kana
    mnemonics). Exercises the seed command as a side effect."""
    call_command("seed_demo")


@pytest.fixture
def user(db):
    from django.contrib.auth import get_user_model

    return get_user_model().objects.create_user(
        email="learner@example.com", password="pw-test-12345"
    )


@pytest.fixture
def api(user):
    """An APIClient authenticated as `user` (bypasses the allauth token dance for
    domain-endpoint tests; the token bridge itself is covered in test_auth)."""
    from rest_framework.test import APIClient

    client = APIClient()
    client.force_authenticate(user=user)
    return client
