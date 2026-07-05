import pytest
from django.contrib.auth import get_user_model

from mnemonics.models import Mnemonic, MnemonicStatus

pytestmark = pytest.mark.django_db

User = get_user_model()


def test_seeded_kana_mnemonics_are_visible(seeded, client):
    resp = client.get("/api/v1/mnemonics/", {"character": "く", "language": "en", "kind": "kana"})
    assert resp.status_code == 200
    results = resp.json()["results"]
    assert results and all(m["status"] == "visible" for m in results)
    assert any("cuckoo" in m["story"].lower() for m in results)


def test_french_mnemonics_are_segmented_by_language(seeded, client):
    en = client.get(
        "/api/v1/mnemonics/", {"character": "く", "language": "en", "kind": "kana"}
    ).json()["results"]
    fr = client.get(
        "/api/v1/mnemonics/", {"character": "く", "language": "fr", "kind": "kana"}
    ).json()["results"]
    assert any("coucou" in m["story"].lower() for m in fr)
    assert not any("coucou" in m["story"].lower() for m in en)


def test_low_trust_user_post_is_held_pending(seeded, api):
    resp = api.post(
        "/api/v1/mnemonics/create",
        {
            "character": "さ",
            "kind": "kana",
            "language": "en",
            "story": "さ looks like a monkey (sa).",
        },
        format="json",
    )
    assert resp.status_code == 201
    assert resp.json()["status"] == "pending"  # 0 trust → held


def test_staff_post_is_visible(seeded):
    from rest_framework.test import APIClient

    staff = User.objects.create_superuser(email="mod@example.com", password="pw-test-12345")
    client = APIClient()
    client.force_authenticate(user=staff)
    resp = client.post(
        "/api/v1/mnemonics/create",
        {"character": "せ", "kind": "kana", "language": "en", "story": "せ is a sword hilt (se)."},
        format="json",
    )
    assert resp.json()["status"] == "visible"


def test_vote_updates_score(seeded, api):
    m = Mnemonic.objects.filter(character="く", language="en").first()
    resp = api.post(f"/api/v1/mnemonics/{m.id}/vote", {"value": 1}, format="json")
    assert resp.status_code == 200
    assert resp.json()["score"] == 1
    # re-voting the other way flips, doesn't stack
    resp = api.post(f"/api/v1/mnemonics/{m.id}/vote", {"value": -1}, format="json")
    assert resp.json()["score"] == -1


def test_reports_auto_hide_after_threshold(seeded, settings):
    settings.MNEMONIC_AUTO_HIDE_REPORTS = 2
    from rest_framework.test import APIClient

    m = Mnemonic.objects.filter(character="く", language="en").first()
    for i in range(2):
        u = User.objects.create_user(email=f"r{i}@example.com", password="pw-test-12345")
        c = APIClient()
        c.force_authenticate(user=u)
        c.post(f"/api/v1/mnemonics/{m.id}/report", {"reason": "offensive"}, format="json")
    m.refresh_from_db()
    assert m.status == MnemonicStatus.HIDDEN


def test_create_mnemonic_with_image_reencodes_to_webp(seeded, api, settings, tmp_path):
    import io

    from django.core.files.uploadedfile import SimpleUploadedFile
    from PIL import Image

    settings.MEDIA_ROOT = str(tmp_path)  # keep uploads out of the repo tree
    buf = io.BytesIO()
    Image.new("RGB", (400, 300), (200, 120, 80)).save(buf, format="PNG")
    upload = SimpleUploadedFile("m.png", buf.getvalue(), content_type="image/png")

    resp = api.post(
        "/api/v1/mnemonics/create",
        {
            "character": "そ",
            "kind": "kana",
            "language": "en",
            "story": "an image mnemonic",
            "image": upload,
        },
        format="multipart",
    )
    assert resp.status_code == 201, resp.content
    data = resp.json()
    assert data["image_src"].endswith(".webp")  # re-encoded (strips EXIF/GPS)
    assert data["image_width"] > 0 and data["image_height"] > 0


def test_rejects_non_image_upload(seeded, api, settings, tmp_path):
    from django.core.files.uploadedfile import SimpleUploadedFile

    settings.MEDIA_ROOT = str(tmp_path)
    bogus = SimpleUploadedFile("evil.png", b"not really an image", content_type="image/png")
    resp = api.post(
        "/api/v1/mnemonics/create",
        {"character": "ぬ", "kind": "kana", "language": "en", "story": "x", "image": bogus},
        format="multipart",
    )
    assert resp.status_code == 400


def test_create_requires_auth(seeded, client):
    resp = client.post(
        "/api/v1/mnemonics/create",
        {"character": "そ", "kind": "kana", "language": "en", "story": "x"},
        format="json",
    )
    assert resp.status_code in (401, 403)


def test_author_sees_own_pending_mnemonic_in_feed_others_do_not(seeded, api):
    # A low-trust author's post is held pending...
    created = api.post(
        "/api/v1/mnemonics/create",
        {"character": "ふ", "kind": "kana", "language": "en", "story": "ふ looks like Mount Fuji (fu)."},
        format="json",
    )
    assert created.status_code == 201
    assert created.json()["status"] == "pending"

    # ...but the author still sees it (badged), so their work never vanishes.
    mine = api.get("/api/v1/mnemonics/", {"character": "ふ", "language": "en", "kind": "kana"}).json()
    my_pending = [m for m in mine["results"] if m["status"] == "pending"]
    assert len(my_pending) == 1

    # Another signed-in user does NOT see the pending submission.
    from rest_framework.test import APIClient

    other = User.objects.create_user(email="other@example.com", password="pw-test-12345")
    oc = APIClient()
    oc.force_authenticate(user=other)
    theirs = oc.get("/api/v1/mnemonics/", {"character": "ふ", "language": "en", "kind": "kana"}).json()
    assert all(m["status"] == "visible" for m in theirs["results"])
