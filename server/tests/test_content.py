from pathlib import Path


def test_sources_and_generated_packs_are_separate(settings):
    source = Path(settings.CONTENT_SOURCE_DIR).resolve()
    packs = Path(settings.CONTENT_PACK_DIR).resolve()

    assert source != packs
    assert source not in packs.parents
    assert packs not in source.parents


def test_legacy_json_pack_endpoints_are_gone(client):
    assert client.get("/api/v1/content/manifest").status_code == 404
    assert client.get("/api/v1/content/file/kanji.json").status_code == 404
