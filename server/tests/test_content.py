import pytest
from django.core.management import call_command

pytestmark = pytest.mark.django_db


def test_load_pack_hydrates_db_from_committed_pack(db):
    call_command("load_pack")  # uses settings.CONTENT_PACK_DIR (the committed seed pack)
    from dictionary.models import Kana, Kanji, Word

    assert Kana.objects.count() >= 100
    k = Kanji.objects.get(literal="水")
    assert len(k.stroke_paths) >= 1  # KanjiVG strokes carried through the pack
    assert {m.lang for m in k.meanings.all()} >= {"en", "fr"}  # language-map preserved
    assert Word.objects.filter(forms__text="日本語").exists()


def test_content_manifest_endpoint(client):
    resp = client.get("/api/v1/content/manifest")
    assert resp.status_code == 200
    data = resp.json()
    assert data["schema"].startswith("jibiki-content/")
    assert "kanji.json" in [f["name"] for f in data["files"]]


def test_content_file_download_and_guard(client):
    ok = client.get("/api/v1/content/file/kanji.json")
    assert ok.status_code == 200
    # A file not declared in the manifest is rejected (no arbitrary reads).
    assert client.get("/api/v1/content/file/secret.json").status_code == 404
