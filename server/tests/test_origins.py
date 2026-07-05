"""Kanji glyph-origin (Wiktionary) + kana man'yōgana origin enrichment.

The Wiktionary importer itself is network-bound, so we exercise only its pure
parser (`_extract`) against fixed HTML, plus the static kana-origin table and the
serializer surfaces — all offline.
"""

import pytest

pytestmark = pytest.mark.django_db


# ── Kana origins (static man'yōgana table) ─────────────────────────────────────


def test_kana_origin_gojuon_points_at_manyogana():
    from dictionary.seed_data import kana_origin

    origin, note = kana_origin("a", "hiragana", "gojuon")
    assert origin == "安"
    assert "安" in note and "cursive" in note.lower()

    origin_k, _ = kana_origin("a", "katakana", "gojuon")
    assert origin_k == "阿"  # katakana derives from a different kanji


def test_kana_origin_dakuten_points_at_base_kana():
    from dictionary.seed_data import kana_origin

    origin, note = kana_origin("ga", "hiragana", "dakuten")
    assert origin == "か"  # a base kana, not a kanji
    assert "dakuten" in note.lower()

    origin_p, note_p = kana_origin("pa", "hiragana", "handakuten")
    assert origin_p == "は"
    assert "handakuten" in note_p.lower()


def test_kana_origin_unknown_sound_is_empty():
    from dictionary.seed_data import kana_origin

    assert kana_origin("kya", "hiragana", "yoon") == ("", "")


# ── Kana grammatical role (particles) ──────────────────────────────────────────


def test_kana_usage_particle_hiragana_only():
    from dictionary.seed_data import kana_usage

    label, desc = kana_usage("ha", "hiragana")
    assert label == "Topic particle"
    assert "topic" in desc.lower()
    # The katakana twin is purely phonetic — no grammatical role.
    assert kana_usage("ha", "katakana") == ("", "")


def test_kana_usage_absent_for_plain_syllable():
    from dictionary.seed_data import kana_usage

    assert kana_usage("ki", "hiragana") == ("", "")


def test_seed_and_serializer_expose_kana_usage(seeded, client):
    from dictionary.models import Kana

    ha = Kana.objects.get(char="は")
    assert ha.usage_label == "Topic particle"
    assert ha.usage
    # purely phonetic kana carry nothing
    assert Kana.objects.get(char="き").usage == ""

    data = client.get("/api/v1/dict/kana/は").json()
    assert data["usage_label"] == "Topic particle"
    assert data["usage"]


def test_seed_populates_kana_origin_and_serializer(seeded, client):
    from dictionary.models import Kana

    a = Kana.objects.get(char="あ")
    assert a.origin == "安"
    assert a.origin_note

    resp = client.get("/api/v1/dict/kana/あ")
    assert resp.status_code == 200
    data = resp.json()
    assert data["origin"] == "安"
    assert data["origin_note"]


# ── Kanji glyph origin (serializer surface + Wiktionary parser) ────────────────


def test_kanji_detail_exposes_origin_fields(seeded, client):
    from dictionary.models import Kanji

    Kanji.objects.filter(literal="語").update(
        origin="Phono-semantic compound: semantic 言 + phonetic 吾.",
        formation="phono-semantic",
        phonetic="吾",
    )
    data = client.get("/api/v1/dict/kanji/語").json()
    assert data["formation"] == "phono-semantic"
    assert data["phonetic"] == "吾"
    assert "phonetic" in data["origin"].lower()


def test_wiktionary_extract_phono_semantic():
    from dictionary.management.commands.import_wiktionary import _extract

    html = (
        '<h3 id="Glyph_origin">Glyph origin</h3>'
        "<table>Historical forms of the character junk table</table>"
        "<p>Phono-semantic compound (形聲 / 形声, OC *l'iːns): "
        "semantic <b>雨</b> (&#8220;rain&#8221;) + phonetic <b>申</b> (OC *hlin).</p>"
        "<h2>Chinese</h2>"
    )
    prose, formation, phonetic = _extract(html)
    assert formation == "phono-semantic"
    assert phonetic == "申"  # pulled the 音符, not the "phonetic series" table
    assert prose.startswith("Phono-semantic compound")
    assert "junk table" not in prose  # leading reconstruction tables dropped


def test_wiktionary_extract_pictogram_has_no_phonetic():
    from dictionary.management.commands.import_wiktionary import _extract

    html = (
        '<h4 id="Glyph_origin">Glyph origin</h4>'
        "<p>Pictogram (象形) – a cloud with drops of rain falling from it.</p>"
        '<div class="mw-heading">Etymology</div>'
    )
    prose, formation, phonetic = _extract(html)
    assert formation == "pictogram"
    assert phonetic == ""
    assert "cloud" in prose


def test_wiktionary_extract_missing_section_is_none():
    from dictionary.management.commands.import_wiktionary import _extract

    assert _extract("<p>No glyph origin section here.</p>") is None
