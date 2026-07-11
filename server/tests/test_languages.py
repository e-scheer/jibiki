"""Open-but-validated mnemonic languages: any real ISO 639-1 code is accepted
(the community can start a language before we curate it), anything else is
rejected, and display falls back to English where a language has no content."""

import pytest

pytestmark = pytest.mark.django_db


def test_profile_accepts_any_real_language(api, user):
    for code in ("ko", "vi", "sw"):
        resp = api.patch("/api/v1/auth/me", {"mnemonic_language": code}, format="json")
        assert resp.status_code == 200, code
    user.profile.refresh_from_db()
    assert user.profile.mnemonic_language == "sw"


def test_profile_rejects_phantom_languages(api, user):
    for bad in ("xx", "klingon", "e", "en_US"):
        resp = api.patch("/api/v1/auth/me", {"mnemonic_language": bad}, format="json")
        assert resp.status_code == 400, bad
    user.profile.refresh_from_db()
    assert user.profile.mnemonic_language == "en"


def test_profile_normalizes_case(api, user):
    resp = api.patch("/api/v1/auth/me", {"mnemonic_language": "PT"}, format="json")
    assert resp.status_code == 200
    user.profile.refresh_from_db()
    assert user.profile.mnemonic_language == "pt"


def test_interface_language_is_normalized_and_restricted(api, user):
    resp = api.patch(
        "/api/v1/auth/me", {"interface_language": "FR-be"}, format="json"
    )
    assert resp.status_code == 200
    user.profile.refresh_from_db()
    assert user.profile.interface_language == "fr"

    resp = api.patch(
        "/api/v1/auth/me", {"interface_language": "ja"}, format="json"
    )
    assert resp.status_code == 400


def test_mnemonic_create_rejects_phantom_language(api):
    resp = api.post(
        "/api/v1/mnemonics/create",
        {"character": "あ", "kind": "kana", "language": "xx", "story": "nope"},
        format="json",
    )
    assert resp.status_code == 400


def test_mnemonic_create_accepts_community_language(api):
    resp = api.post(
        "/api/v1/mnemonics/create",
        {"character": "あ", "kind": "kana", "language": "vi", "story": "A! Ada... một con rắn!"},
        format="json",
    )
    assert resp.status_code == 201
    assert resp.json()["language"] == "vi"


def test_active_mnemonics_fall_back_to_english(api):
    from mnemonics.models import Mnemonic, MnemonicStatus

    Mnemonic.objects.create(
        character="あ",
        kind="kana",
        language="en",
        story="Antenna says ah!",
        status=MnemonicStatus.VISIBLE,
        is_seed=True,
    )
    # A Vietnamese user with zero vi content sees the English set (badged by
    # its language field), never a blank visual layer.
    resp = api.post(
        "/api/v1/mnemonics/active",
        {"kind": "kana", "characters": ["あ"], "language": "vi"},
        format="json",
    )
    body = resp.json()
    assert body["results"]["あ"] is not None
    assert body["results"]["あ"]["language"] == "en"

    # The moment a vi mnemonic exists, it wins over the English backup.
    Mnemonic.objects.create(
        character="あ",
        kind="kana",
        language="vi",
        story="A! Con rắn!",
        status=MnemonicStatus.VISIBLE,
    )
    resp = api.post(
        "/api/v1/mnemonics/active",
        {"kind": "kana", "characters": ["あ"], "language": "vi"},
        format="json",
    )
    assert resp.json()["results"]["あ"]["language"] == "vi"


def test_read_paths_normalize_case(api):
    """Stored codes are lowercase (validate on write); read/filter endpoints
    must match regardless of the query param's case, not silently return
    empty."""
    from mnemonics.models import Mnemonic, MnemonicStatus

    Mnemonic.objects.create(
        character="か",
        kind="kana",
        language="fr",
        story="Un coup de karaté !",
        status=MnemonicStatus.VISIBLE,
    )
    # Uppercased language on the browse feed still finds the fr mnemonic.
    resp = api.get("/api/v1/mnemonics/?character=か&kind=kana&language=FR")
    assert resp.status_code == 200
    body = resp.json()
    assert body["language"] == "fr"  # normalized in the echo too
    assert any(m["language"] == "fr" for m in body["results"])

    # And on the active-resolve endpoint.
    resp = api.post(
        "/api/v1/mnemonics/active",
        {"kind": "kana", "characters": ["か"], "language": "FR"},
        format="json",
    )
    assert resp.json()["results"]["か"] is not None
