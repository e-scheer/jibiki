import pytest

pytestmark = pytest.mark.django_db


def test_seed_populates_kana_kanji_words(seeded):
    from dictionary.models import Kana, Kanji, Word

    assert Kana.objects.filter(script="hiragana").count() >= 46
    assert Kana.objects.filter(script="katakana").count() >= 46
    assert Kanji.objects.count() >= 30
    assert Word.objects.count() >= 25


def test_search_japanese_exact(seeded, client):
    resp = client.get("/api/v1/dict/search", {"q": "日本語"})
    assert resp.status_code == 200
    results = resp.json()["results"]
    assert any(r["headword"] == "日本語" for r in results)


def test_search_by_reading(seeded, client):
    resp = client.get("/api/v1/dict/search", {"q": "たべる"})
    assert resp.status_code == 200
    heads = [r["headword"] for r in resp.json()["results"]]
    assert "食べる" in heads


def test_search_by_english_gloss(seeded, client):
    resp = client.get("/api/v1/dict/search", {"q": "water", "lang": "en"})
    heads = [r["headword"] for r in resp.json()["results"]]
    assert "水" in heads


def test_search_by_french_gloss(seeded, client):
    resp = client.get("/api/v1/dict/search", {"q": "manger", "lang": "fr"})
    heads = [r["headword"] for r in resp.json()["results"]]
    assert "食べる" in heads


def test_kanji_detail_has_breakdown_and_words(seeded, client):
    resp = client.get("/api/v1/dict/kanji/語")
    assert resp.status_code == 200
    data = resp.json()
    assert data["literal"] == "語"
    assert data["stroke_count"] == 14
    # 語 decomposes into 言 + 口 (seed components)
    comps = {c["literal"] for c in data["component_details"]}
    assert "言" in comps
    # words containing 語 (日本語)
    assert any("語" in w["headword"] for w in data["words"])


def test_kanji_detail_has_kanjivg_strokes(seeded, client):
    resp = client.get("/api/v1/dict/kanji/水")  # 水 = 4 strokes, seeded from KanjiVG
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data["stroke_paths"], list) and len(data["stroke_paths"]) >= 1
    assert data["stroke_viewbox"] == "0 0 109 109"
    assert all(p.startswith("M") or p.startswith("m") for p in data["stroke_paths"])


def test_kana_list_is_public(seeded, client):
    resp = client.get("/api/v1/dict/kana", {"script": "hiragana"})
    assert resp.status_code == 200
    chars = {k["char"] for k in resp.json()}
    assert {"あ", "く", "ん"} <= chars


def test_word_detail_kanji_breakdown(seeded, client):
    from dictionary.models import Word

    word = Word.objects.filter(forms__text="日本語").first()
    resp = client.get(f"/api/v1/dict/words/{word.pk}")
    assert resp.status_code == 200
    data = resp.json()
    breakdown = {k["literal"] for k in data["kanji_breakdown"]}
    assert {"日", "本", "語"} <= breakdown
