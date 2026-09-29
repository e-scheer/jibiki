"""Shared fixtures. The test database is Postgres, pinned in
``jibiki_server.settings_test`` (it must be set before pytest-django configures
Django); this file only holds fixtures used across the suite.
"""

import pytest
from django.core.management import call_command


@pytest.fixture
def seeded(db):
    """Dictionary plus explicitly published test mnemonics for API behavior.

    Seed publication policy is tested separately in test_seed_*; API tests need
    a public catalogue to exercise ranking, reporting and language selection.
    """
    from mnemonics.models import DeckStatus, Mnemonic, MnemonicDeck, MnemonicStatus

    call_command("seed_demo")
    Mnemonic.objects.filter(is_seed=True).update(status=MnemonicStatus.VISIBLE)
    MnemonicDeck.objects.filter(is_seed=True).update(status=DeckStatus.VISIBLE)


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
