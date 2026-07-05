"""Active-mnemonic resolution: default (score) → per-character override → pack."""

import pytest
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient

from mnemonics.models import Mnemonic, MnemonicStatus, UserMnemonicChoice
from mnemonics.services import active_for_many

pytestmark = pytest.mark.django_db

User = get_user_model()


def _mk(
    char, story, *, lang="en", kind="kana", author=None, score=0, status=MnemonicStatus.VISIBLE
):
    m = Mnemonic.objects.create(
        character=char, language=lang, kind=kind, story=story, author=author, status=status
    )
    if score:
        Mnemonic.objects.filter(pk=m.pk).update(score=score)
        m.refresh_from_db()
    return m


def test_default_is_highest_scored(user):
    low = _mk("く", "low", score=1)
    high = _mk("く", "high", score=5)
    resolved = active_for_many(user, ["く"], "kana", "en")
    assert resolved["く"].id == high.id
    assert low.id != high.id


def test_override_beats_default(user):
    _mk("く", "high", score=99)
    mine = _mk("く", "my pick", score=0)
    UserMnemonicChoice.objects.create(
        user=user, kind="kana", character="く", language="en", mnemonic=mine
    )
    resolved = active_for_many(user, ["く"], "kana", "en")
    assert resolved["く"].id == mine.id


def test_missing_character_absent_from_result(user):
    resolved = active_for_many(user, ["ず"], "kana", "en")
    assert "ず" not in resolved


def test_active_endpoint_batches(seeded, api):
    resp = api.post(
        "/api/v1/mnemonics/active",
        {"kind": "kana", "characters": ["く", "し", " zz"], "language": "en"},
        format="json",
    )
    assert resp.status_code == 200, resp.content
    results = resp.json()["results"]
    assert set(results.keys()) == {"く", "し", " zz"}
    assert results["く"] and "cuckoo" in results["く"]["story"].lower()
    assert results[" zz"] is None


def test_choose_sets_override(api, user):
    _mk("さ", "top", score=10)
    mine = _mk("さ", "mine")
    resp = api.post("/api/v1/mnemonics/choose", {"mnemonic_id": mine.id}, format="json")
    assert resp.status_code == 200
    assert active_for_many(user, ["さ"], "kana", "en")["さ"].id == mine.id


def test_reset_clears_overrides(api, user):
    top = _mk("さ", "top", score=10)
    mine = _mk("さ", "mine")
    UserMnemonicChoice.objects.create(
        user=user, kind="kana", character="さ", language="en", mnemonic=mine
    )
    assert active_for_many(user, ["さ"], "kana", "en")["さ"].id == mine.id
    resp = api.post("/api/v1/mnemonics/reset", {}, format="json")
    assert resp.status_code == 200
    assert active_for_many(user, ["さ"], "kana", "en")["さ"].id == top.id


def test_apply_pack_sets_choices_and_active_pack(seeded, api, user):
    # Build a small pack owned by staff and published, then apply it.
    staff = User.objects.create_superuser(email="mod@example.com", password="pw-test-12345")
    a = _mk("く", "pack-ku", author=staff)
    b = _mk("し", "pack-shi", author=staff)
    sc = APIClient()
    sc.force_authenticate(user=staff)
    deck_id = sc.post(
        "/api/v1/mnemonics/decks/create",
        {"title": "Pack", "kind": "kana", "mnemonic_ids": [a.id, b.id], "publish": True},
        format="json",
    ).json()["id"]

    resp = api.post(f"/api/v1/mnemonics/decks/{deck_id}/apply", format="json")
    assert resp.status_code == 200
    assert resp.json()["applied"] == 2
    resolved = active_for_many(user, ["く", "し"], "kana", "en")
    assert resolved["く"].id == a.id and resolved["し"].id == b.id
    user.refresh_from_db()
    assert user.profile.active_pack_id == deck_id


def test_seed_creates_default_pack(seeded):
    from mnemonics.models import MnemonicDeck

    packs = MnemonicDeck.objects.filter(is_seed=True)
    assert packs.filter(language="en").exists()
    assert packs.filter(language="fr").exists()
    en = packs.get(language="en")
    assert en.items.count() >= 1
