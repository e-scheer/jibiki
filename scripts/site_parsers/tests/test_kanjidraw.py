"""Tests for the kanjidraw parser, run against the real mirrored files.

No invented HTML: every assertion reads a file under
``var/site_mirror/kanjidraw/mirror``. Each test names the defect it pins down,
so a regression says what broke rather than only that something changed.

Run with ``python -m pytest scripts/site_parsers/tests/test_kanjidraw.py`` from
the repo root, or directly with ``python scripts/site_parsers/tests/test_kanjidraw.py``
after putting ``scripts`` on ``PYTHONPATH``. Always set
``PYTHONIOENCODING=utf-8``: the console is cp1252 and dies on Japanese.
"""

from __future__ import annotations

import sys
import urllib.parse
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = REPO_ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from site_parsers import kanjidraw as kd  # noqa: E402
from site_parsers.common import parse_document  # noqa: E402

MIRROR = REPO_ROOT / "var" / "site_mirror" / "kanjidraw" / "mirror" / "kanjidraw.com"


def _load(url: str):
    """Tree for a mirrored url, using the crawler's own path layout."""
    path = urllib.parse.urlsplit(url).path.strip("/")
    file_path = MIRROR.joinpath(*path.split("/")) / "index.html" if path else MIRROR / "index.html"
    return parse_document(file_path.read_text(encoding="utf-8"))


def _dictionary_url(slug: str) -> str:
    return "https://kanjidraw.com/dictionary/" + urllib.parse.quote(slug) + "/"


def _record(url: str):
    tree = _load(url)
    page_type = kd.infer_page_type(url)
    assert not kd.is_shell(tree, url), f"{url} unexpectedly classified as a shell"
    return kd.parse(tree, url, page_type)


# --- routing ------------------------------------------------------------------


def test_page_types_distinguish_kanji_word_and_kana():
    # Every multi character slug used to be typed "kanji" and fed to a kanji
    # only parser, which filed a kana reading as an on reading.
    assert kd.infer_page_type(_dictionary_url("段")) == kd.PAGE_KANJI
    assert kd.infer_page_type(_dictionary_url("生け花")) == kd.PAGE_WORD
    assert kd.infer_page_type(_dictionary_url("あいかわらず")) == kd.PAGE_WORD
    assert kd.infer_page_type(_dictionary_url("あ")) == kd.PAGE_DICTIONARY_KANA
    assert kd.infer_page_type("https://kanjidraw.com/dictionary/") == kd.PAGE_DICTIONARY_INDEX
    assert kd.infer_page_type("https://kanjidraw.com/kana/") == kd.PAGE_KANA_INDEX
    assert kd.infer_page_type("https://kanjidraw.com/kana/hiragana-ba/") == kd.PAGE_KANA
    assert kd.infer_page_type("https://kanjidraw.com/radicals/") == kd.PAGE_RADICAL_INDEX
    assert kd.infer_page_type("https://kanjidraw.com/radicals/61/") == kd.PAGE_RADICAL
    assert kd.infer_page_type("https://kanjidraw.com/collections/") == kd.PAGE_COLLECTION_INDEX
    assert kd.infer_page_type("https://kanjidraw.com/collections/jlpt-n5/") == kd.PAGE_COLLECTION
    assert kd.infer_page_type("https://kanjidraw.com/worksheets/") == kd.PAGE_OTHER
    assert kd.EXTRACTABLE >= {kd.PAGE_KANJI, kd.PAGE_WORD, kd.PAGE_KANA, kd.PAGE_RADICAL}


def test_dedupe_key_ignores_query_and_encoding():
    plain = kd.dedupe_key(_dictionary_url("段"), kd.PAGE_KANJI)
    with_query = kd.dedupe_key(_dictionary_url("段") + "?q=x", kd.PAGE_KANJI)
    unencoded = kd.dedupe_key("https://kanjidraw.com/dictionary/段/", kd.PAGE_KANJI)
    assert plain == with_query == unencoded
    assert kd.dedupe_key("https://kanjidraw.com/radicals/061/", kd.PAGE_RADICAL) == kd.dedupe_key(
        "https://kanjidraw.com/radicals/61/", kd.PAGE_RADICAL
    )


# --- shell detection ----------------------------------------------------------


def test_homepage_shell_is_detected():
    # 駻 is one of the roughly 74 percent of dictionary files that are a byte
    # copy of the homepage: canonical points at the site root and no preload
    # json is present.
    url = _dictionary_url("駻")
    tree = _load(url)
    assert kd.is_shell(tree, url) is True
    assert kd.preload_names(tree) == []


def test_real_pages_are_not_shells():
    for slug in ("段", "煌", "法", "生け花", "あ", "あいかわらず"):
        url = _dictionary_url(slug)
        assert kd.is_shell(_load(url), url) is False, slug
    for url in (
        "https://kanjidraw.com/kana/",
        "https://kanjidraw.com/kana/hiragana-ba/",
        "https://kanjidraw.com/radicals/",
        "https://kanjidraw.com/radicals/61/",
        "https://kanjidraw.com/collections/jlpt-n5/",
        "https://kanjidraw.com/collections/",
        "https://kanjidraw.com/dictionary/",
    ):
        assert kd.is_shell(_load(url), url) is False, url


def test_loading_placeholder_is_a_shell():
    # A client rendered placeholder has the right canonical but no entry.
    url = _dictionary_url("東京都")
    tree = _load(url)
    assert kd.is_shell(tree, url) is True


# --- kanji entries ------------------------------------------------------------


def test_kanji_record_reads_every_preload():
    record = _record(_dictionary_url("段"))
    assert record["character"] == "段"
    assert record["stroke_count"] == 9
    assert record["jlpt_level"] == "N2"
    assert record["on_readings"] == ["ダン", "タン"]
    assert record["meanings"][:3] == ["grade", "steps", "stairs"]

    # KanjiVG pointers, previously dropped entirely.
    assert record["codepoint_hex"] == "06bb5"
    assert record["stroke_svg_default"] == "06bb5.svg"
    assert {"file": "06bb5.svg", "label": "Base"} in record["stroke_svg_variants"]
    assert record["in_study_set"] is True

    # The five preloads the old parser never opened.
    assert len(record["senses"]) == 12
    assert {"g": None} != record["senses"][3]
    assert record["senses"][3]["pos"] == ["n", "ctr"]
    assert any(sense["info"] == ["as ...の段"] for sense in record["senses"])
    assert len(record["jmdict_compounds"]) == 16
    assert [item["word"] for item in record["jmdict_compounds"]][:2] == ["階段", "手段"]
    assert len(record["example_sentences"]) == 7
    first = record["example_sentences"][0]
    assert first["japanese"] == "彼は並みの大学生より一段上だ。"
    assert first["english"] == "He is a cut above the average college student."
    assert {"text": "並み", "is_content": True} in first["tokens"]
    assert any(token.get("base_form") == "捜す" for ex in record["example_sentences"] for token in ex["tokens"])
    assert record["sense_examples"][0] == {
        "sense_index": 0,
        "japanese": "彼は階段を一度に三段ずつかけあがった。",
        "english": "He jumped up the steps three at a time.",
    }


def test_kanji_badges_are_element_scoped_and_notes_are_separated():
    # The old regex closed on </a>, so span badges swallowed hundreds of
    # characters of raw markup up to the next anchor.
    record = _record(_dictionary_url("煌"))
    labels = [badge["label"] for badge in record["badges"]]
    assert labels == ["Grade 9", "KANJIDIC"]
    for badge in record["badges"]:
        assert "<" not in badge["label"]
        # The tooltip prose is not nested inside the factual badge.
        assert "note" not in badge
        assert set(badge) == {"label", "kind", "href"}
    notes = record["badge_notes"]
    assert [note["label"] for note in notes] == ["Grade 9", "KANJIDIC"]
    assert notes[1]["note"].startswith("Source: the KANJIDIC database")
    for note in notes:
        assert "&#x27;" not in note["note"]

    joyo = _record(_dictionary_url("段"))
    assert [badge["label"] for badge in joyo["badges"]] == ["Jōyō", "Grade 6"]
    assert joyo["badges"][0]["href"] == "/collections/joyo-kanji/"


def test_badge_notes_are_authored_prose_and_lose_the_ui_instruction():
    # A tooltip is a whole authored sentence about the list, not a fact about
    # the character, so it may not ship as factual data.
    record = _record(_dictionary_url("段"))
    provenance = record["_provenance"]
    assert provenance["badge_notes"]["license_class"] == "authored-third-party"
    assert provenance["badge_notes"]["ship"] == "reference-only"
    assert provenance["badges"]["ship"] == "allowed"
    joyo = [note for note in record["badge_notes"] if note["kind"] == "joyo"][0]
    assert joyo["note"].startswith("Jōyō kanji: the 2,136")
    # "Click to see the full list." is interface chrome and is dropped.
    assert "Click" not in joyo["note"]
    assert joyo["note"].endswith("curriculum.")
    assert kd._strip_ui_call_to_action("A fact. Tap the badge for more!") == "A fact."
    # Only a whole trailing sentence goes, never a clause that merely contains
    # one of those verbs.
    assert kd._strip_ui_call_to_action("Clicking noise is a fact.") == "Clicking noise is a fact."
    assert (
        kd._strip_ui_call_to_action("Used since the printing press was invented.")
        == "Used since the printing press was invented."
    )
    assert kd._strip_ui_call_to_action("Click to see the list.") is None


def test_grade_codes_are_decoded_not_passed_through():
    # 9 is jinmeiyō and 8 is junior high, neither is a school year.
    jinmeiyo = _record(_dictionary_url("煌"))
    assert jinmeiyo["grade_code"] == 9
    assert "jinmeiyō" in jinmeiyo["grade_label"]
    junior_high = _record(_dictionary_url("与"))
    assert junior_high["grade_code"] == 8
    assert "junior high" in junior_high["grade_label"]
    elementary = _record(_dictionary_url("段"))
    assert elementary["grade_code"] == 6
    assert "elementary grade 6" in elementary["grade_label"]
    # Code 0 must survive rather than collapsing to None like a falsy value.
    assert kd._grade_fields(0)["grade_code"] == 0
    assert kd._grade_fields(0)["grade_label"] == "outside the jōyō and jinmeiyō sets"
    assert kd._grade_fields(None)["grade_code"] is None


def test_components_are_mapped_and_russian_is_locale_scoped():
    record = _record(_dictionary_url("段"))
    assert [item["character"] for item in record["components"]] == ["几", "丿", "又"]
    for item in record["components"]:
        assert set(item) <= {"character", "meaning", "nested", "meanings_by_lang"}
        assert "char" not in item and "meaningRu" not in item
        russian = (item.get("meanings_by_lang") or {}).get("ru")
        assert russian, item
    # No cyrillic outside an explicitly ru scoped key.
    assert not _cyrillic_outside_ru_keys(record), _cyrillic_outside_ru_keys(record)


def _cyrillic_outside_ru_keys(value, key=None, path="") -> list[str]:
    hits: list[str] = []
    if isinstance(value, dict):
        for name, item in value.items():
            hits.extend(_cyrillic_outside_ru_keys(item, name, f"{path}.{name}"))
    elif isinstance(value, list):
        for index, item in enumerate(value):
            hits.extend(_cyrillic_outside_ru_keys(item, key, f"{path}[{index}]"))
    elif isinstance(value, str) and key != "ru":
        if any("Ѐ" <= char <= "ӿ" for char in value):
            hits.append(path)
    return hits


def test_kanji_radical_is_identity_only_and_never_claims_variants():
    # The page's variant chips contradict the radical record under the same
    # field name: for radical 32 they say 士, which is radical 33, while
    # /radicals/32/ says the variant set is empty. The kanji record therefore
    # carries the radical number and nothing else, and a consumer joins the
    # authoritative variant set from the radical record.
    record = _record(_dictionary_url("煌"))
    assert record["radical"] == {
        "number": 86,
        "character": "火",
        "meaning": "fire",
        "stroke_count": 4,
    }
    assert "灬" not in [item["character"] for item in record["components"]]

    for slug, number in (("増", 32), ("絃", 120), ("惜", 61), ("法", 85)):
        kanji = _record(_dictionary_url(slug))
        assert "variant_forms" not in kanji["radical"], slug
        assert kanji["radical"]["number"] == number, slug

    # The one authoritative answer, keyed by radical number.
    assert _record("https://kanjidraw.com/radicals/32/")["variant_forms"] == []
    assert _record("https://kanjidraw.com/radicals/120/")["variant_forms"] == ["糹"]
    assert _record("https://kanjidraw.com/radicals/85/")["variant_forms"] == ["氵", "氺"]


def test_heisig_is_tagged_and_classified_reference_only():
    record = _record(_dictionary_url("段"))
    rtk = record["rtk_mnemonic"]
    assert rtk["keyword"] == "grade"
    assert [item["name"] for item in rtk["primitives"]][:2] == ["staple gun", "cruise missile"]
    assert {"name": "wind", "character": "風"} in rtk["primitives"]
    assert rtk["source"] == "Remembering the Kanji, James Heisig"
    assert rtk["redistributable"] is False
    assert record["rtk_frame"] == 2003
    provenance = record["_provenance"]
    assert provenance["rtk_mnemonic"]["ship"] == "reference-only"
    assert provenance["rtk_mnemonic"]["license_class"] == "authored-third-party"
    # A frame number is a factual index and may ship.
    assert provenance["rtk_frame"]["ship"] == "allowed"
    assert provenance["stroke_count"]["ship"] == "allowed"
    assert provenance["example_sentences"]["ship"] == "reference-only"


def test_kanji_details_preload_is_merged():
    record = _record(_dictionary_url("法"))
    assert record["grade_code"] == 4
    assert "method" in record["meanings"]
    assert record["meanings_by_lang"]["ru"] == ["закон"]


# --- word entries -------------------------------------------------------------


def test_word_record_keeps_reading_senses_and_jlpt():
    record = _record(_dictionary_url("生け花"))
    assert record["entry_kind"] == "word"
    assert record["surface"] == "生け花"
    # The kana reading is a reading, not an on reading.
    assert record["reading"] == "いけばな"
    assert "on_readings" not in record
    assert record["jlpt_level"] == "N2"
    assert [sense["glosses"] for sense in record["senses"]] == [
        ["ikebana", "Japanese art of flower arrangement"],
        ["fresh flower", "natural flower"],
    ]
    # The two constituent kanji are components, not "popular usage".
    assert [chip["text"] for chip in record["component_kanji"]] == ["生", "花"]
    assert "popular_usage" not in record
    assert record["sense_examples"][0]["japanese"] == "生け花は日本では伝統的な芸道である。"
    # React splice markers must not survive into a badge label.
    assert {badge["label"] for badge in record["badges"]} == {"N2 Vocab", "JLPT N2"}


def test_kana_word_entry_reads_the_augment_preload():
    record = _record(_dictionary_url("あいかわらず"))
    assert record["surface"] == "あいかわらず"
    assert record["jmdict_entry"]["word"] == "相変わらず"
    assert record["jmdict_entry"]["reading"] == "あいかわらず"
    assert "as ever" in record["jmdict_entry"]["glosses"]


def test_verb_group_badge_does_not_become_a_jlpt_level():
    record = _record(_dictionary_url("すすめる"))
    assert record["verb_group"] == "Ichidan · Group 2"
    assert record["jlpt_level"] is None
    # The explanation of what an ichidan verb is stays with the authored notes.
    ichidan = [note for note in record["badge_notes"] if note["kind"] == "verb-group"][0]
    assert ichidan["note"].startswith("Ichidan verbs")
    assert record["_provenance"]["verb_group"]["ship"] == "allowed"
    assert record["parse_notes"] == [
        "no preload json on this page, values came from the dom only"
    ]


def test_russian_glosses_keep_their_numbers():
    # The English splitter cuts on every comma, but Russian uses the comma as a
    # decimal separator, so 10,6 became "10" and "6" as two separate glosses.
    record = _record(_dictionary_url("段"))
    russian = record["jmdict_entry"]["meanings_by_lang"]["ru"]
    assert russian == [
        "тан (мера длины для тканей = 10,6 м)",
        "тан (см.) たんぶ",
        "= 10 сэ = 0,0992 га",
        "= 10,6 м (для измерения тканей).)",
    ]
    numbered = _record(_dictionary_url("号"))["jmdict_entry"]["meanings_by_lang"]["ru"]
    assert "(суф. названий иностранных торговых судов; ср.) ごう【号】 1, 3, 5" in numbered
    assert "3" not in numbered and "5" not in numbered
    # An ordinary Russian enumeration still splits.
    assert numbered[-3:] == ["пункт", "рубрика", "псевдоним"]
    assert numbered[-4].endswith("параграф")
    assert kd._split_russian_glosses("большой, огромный") == ["большой", "огромный"]


def test_records_do_not_assert_upstream_sources_they_did_not_parse():
    # A hardcoded seven-name constant stamped factual claimed a Heisig source on
    # word pages that carry no Heisig block at all.
    word = _record(_dictionary_url("生け花"))
    assert "upstream_sources" not in word
    assert word.get("rtk_mnemonic") is None
    for url in (
        _dictionary_url("段"),
        _dictionary_url("あ"),
        "https://kanjidraw.com/dictionary/",
    ):
        assert "upstream_sources" not in _record(url), url
    # The credits that are genuinely on the page are still parsed from it.
    index = _record("https://kanjidraw.com/dictionary/")
    assert [item["name"] for item in index["upstream_credits"]][:2] == ["KanjiVG", "KANJIDIC"]


# --- kana ---------------------------------------------------------------------


def test_kana_detail_character_is_the_bare_character():
    record = _record("https://kanjidraw.com/kana/hiragana-ba/")
    assert record["character"] == "ば"
    assert record["character_label"] == "(ba) — Hiragana"
    assert record["romaji"] == "ba"
    assert record["script"] == "hiragana"
    assert record["stroke_count"] == 5
    assert record["stroke_step_count"] == 5
    # The highlighted target kana inside each example survives.
    assert record["examples"] == [
        {"word": "ばす", "meaning": "bus", "highlight": "ば"},
        {"word": "ばんごはん", "meaning": "dinner", "highlight": "ば"},
    ]
    # The gojuon navigation grid is not repeated on detail pages.
    assert "kana_cells" not in record
    assert record["_provenance"]["practice_hint"]["ship"] == "reference-only"


def test_katakana_detail_script_comes_from_the_page():
    record = _record("https://kanjidraw.com/kana/katakana-a/")
    assert record["character"] == "ア"
    assert record["script"] == "katakana"


def test_kana_index_keeps_the_grid_and_the_romanization_table():
    record = _record("https://kanjidraw.com/kana/")
    assert len(record["kana_cells"]) >= 46
    assert {"character": "あ", "romaji": "a", "script": "hiragana", "href": "/kana/hiragana-a/"} in record["kana_cells"]
    # The Hepburn versus Kunrei-shiki table was dropped entirely before.
    assert {"kana": "し", "hepburn": "shi", "kunrei_shiki": "si"} in record["romaji_variants"]
    assert {"kana": "ん", "hepburn": "n / m", "kunrei_shiki": "n"} in record["romaji_variants"]
    assert len(record["romaji_variants"]) == 10
    # Emphasis markup in the prose survives as role annotated spans.
    romaji_section = [
        section for section in record["guide_sections"] if "Hepburn" in (section["heading"] or "")
    ][0]
    spans = romaji_section["paragraphs"][0]["spans"]
    assert {"rōmaji", "Hepburn", "Kunrei-shiki"} <= {span["text"] for span in spans}
    for span in spans:
        text = romaji_section["paragraphs"][0]["text"]
        assert text[span["start"] : span["end"]] == span["text"]


def test_dictionary_kana_entry():
    record = _record(_dictionary_url("あ"))
    assert record["character"] == "あ"
    assert record["romaji"] == "a"
    assert record["script"] == "hiragana"
    assert record["stroke_count"] == 3
    assert record["codepoint_hex"] == "03042"
    assert record["stroke_svg_default"] == "03042.svg"


# --- radicals -----------------------------------------------------------------


def test_radical_keeps_variants_sample_and_decoded_grades():
    record = _record("https://kanjidraw.com/radicals/61/")
    assert record["radical_number"] == 61
    assert record["character"] == "心"
    assert record["meaning"] == "heart"
    assert record["meanings_by_lang"]["ru"] == ["сердце"]
    assert record["stroke_count"] == 4
    assert record["joyo_count"] == 76
    assert record["other_count"] == 143
    # Variant forms and the sample kanji were dropped before.
    assert record["variant_forms"] == ["忄", "㣺", "⺗"]
    assert record["sample_kanji"] == ["心"]
    assert len(record["joyo_members"]) == 76
    assert len(record["other_members"]) == 143
    heart = record["joyo_members"][0]
    assert heart["character"] == "心" and heart["grade_code"] == 2
    assert "elementary grade 2" in heart["grade_label"]
    outside = record["other_members"][0]
    assert outside["grade_code"] == 0
    assert outside["grade_label"] == "outside the jōyō and jinmeiyō sets"


def test_radical_neighbors_are_one_entry_per_link():
    # contains(@class,'radical-neighbor') also matched the nav wrapper and the
    # three child spans, producing five entries with a glued label.
    record = _record("https://kanjidraw.com/radicals/1/")
    assert len(record["neighbors"]) == 1
    neighbor = record["neighbors"][0]
    assert neighbor["direction"] == "next"
    assert neighbor["radical_number"] == 2
    assert neighbor["character"] == "丨"
    assert neighbor["meaning"] == "line"
    assert neighbor["href"] == "/radicals/2/"
    both = _record("https://kanjidraw.com/radicals/61/")
    assert [item["direction"] for item in both["neighbors"]] == ["prev", "next"]
    assert [item["character"] for item in both["neighbors"]] == ["彳", "戈"]


def test_radical_index_lists_all_214():
    record = _record("https://kanjidraw.com/radicals/")
    assert len(record["radicals"]) == 214
    assert record["radicals"][0]["character"] == "一"
    assert record["radicals"][1]["sample_kanji"] == ["中"]
    assert record["radicals"][4]["variant_forms"] == ["乚", "⺄"]


# --- collections --------------------------------------------------------------


def test_collection_items_modes_and_see_also():
    record = _record("https://kanjidraw.com/collections/jlpt-n5/")
    assert record["name"] == "JLPT N5 Kanji"
    assert record["item_count"] == 79
    assert len(record["items"]) == 79
    assert record["items"][0] == {
        "kind": "kanji",
        "surface": "一",
        "reading": "いち",
        "meaning": "one",
        "href": "/dictionary/%E4%B8%80/",
    }
    assert record["page_number"] == 1
    # The decorative emoji is its own field and the bolded mode name is not
    # welded onto the description.
    flashcards = record["practice_modes"][0]
    assert flashcards["emoji"] == "🎴"
    assert flashcards["name"] == "Flashcards"
    assert flashcards["description"].startswith("flip through the set")
    # One entry per see also link, no null href head entry.
    assert len(record["see_also"]) == 2
    assert all(item["href"] for item in record["see_also"])
    assert record["see_also"][0]["href"] == "/collections/jlpt-n4/"


def test_verb_collection_uses_the_other_card_layout():
    # Verb, adjective and vocabulary collections render collection-verb-card,
    # so reading only collection-kanji-card left their grids empty.
    record = _record("https://kanjidraw.com/collections/verbs-n5/")
    assert len(record["items"]) >= 100
    first = record["items"][0]
    assert first["kind"] == "word"
    assert first["surface"] == "する"
    assert first["reading"] == "する"
    assert first["meaning"] == "to do"
    assert first["jlpt_level"] == "N5"
    assert first["verb_group"] == "Gr. 3"


def test_collection_item_badges_are_read_from_their_own_card():
    # Asserting items[0] alone hid an absolute XPath: every item took the first
    # card's badges, so 103 of 119 verbs carried the wrong conjugation group and
    # 9 got a JLPT level they have no badge for.
    import collections as _collections

    url = "https://kanjidraw.com/collections/verbs-n5/"
    record = _record(url)
    groups = _collections.Counter(item["verb_group"] for item in record["items"])
    assert groups == {"Gr. 1": 75, "Gr. 2": 28, "Gr. 3": 16}

    # Counted straight off the raw markup, per card, as the ground truth.
    tree = kd._prepare(_load(url))
    cards = kd._by_class(tree, "collection-verb-card")
    expected_groups = _collections.Counter()
    expected_levels = _collections.Counter()
    for card in cards:
        for badge in kd._by_class(card, "dict-badge"):
            kind = kd._class_suffix(badge, "dict-badge--") or ""
            if kind == "verb-group":
                expected_groups[kd._node_text(badge)] += 1
            elif kind.startswith("jlpt-"):
                expected_levels[kind[len("jlpt-") :].upper()] += 1
    assert groups == expected_groups
    levels = _collections.Counter(
        item["jlpt_level"] for item in record["items"] if item["jlpt_level"]
    )
    assert levels == expected_levels
    assert sum(levels.values()) == 110 < len(record["items"])

    by_surface = {item["surface"]: item for item in record["items"]}
    assert by_surface["ある"]["verb_group"] == "Gr. 1"
    assert by_surface["できる"]["verb_group"] == "Gr. 2"
    # A card with no JLPT badge must not inherit one from another card.
    missing = [item for item in record["items"] if item["jlpt_level"] is None]
    assert len(missing) == 9


def test_paginated_collection_keeps_its_page_identity():
    page_two = "https://kanjidraw.com/collections/joyo-kanji/page/2/"
    assert kd.infer_page_type(page_two) == kd.PAGE_COLLECTION
    first = kd.dedupe_key("https://kanjidraw.com/collections/joyo-kanji/", kd.PAGE_COLLECTION)
    second = kd.dedupe_key(page_two, kd.PAGE_COLLECTION)
    assert first != second
    record = _record(page_two)
    assert record["slug"] == "joyo-kanji"
    assert record["page_number"] == 2
    assert record["page_indicator"] == "Page 2 of 18"
    assert record["next_page_href"] == "/collections/joyo-kanji/page/3/"
    assert record["item_count"] == 2136
    assert 100 <= len(record["items"]) <= 200


def test_client_rendered_grid_is_flagged_not_silently_empty():
    record = _record("https://kanjidraw.com/collections/rtk-1-100/")
    assert record["items"] == []
    assert record["parse_notes"] == [
        "item grid was client rendered and is absent from this snapshot"
    ]
    assert record["name"] == "Kanji 1–100: Remembering the Kanji"


def test_collection_index_lists_every_collection():
    record = _record("https://kanjidraw.com/collections/")
    assert len(record["collections"]) >= 30
    assert all(card["href"] for card in record["collections"])


# --- dictionary index and provenance ------------------------------------------


def test_dictionary_index_captures_upstream_attribution():
    record = _record("https://kanjidraw.com/dictionary/")
    names = [item["name"] for item in record["upstream_credits"]]
    assert names == ["KanjiVG", "KANJIDIC", "JMdict", "Tanos", "Tatoeba", "Wiki Corpus"]
    assert record["upstream_credits"][0]["url"] == "https://kanjivg.tagaini.net"


def test_every_record_declares_provenance_for_every_field():
    urls = [
        _dictionary_url("段"),
        _dictionary_url("生け花"),
        _dictionary_url("あ"),
        "https://kanjidraw.com/kana/hiragana-ba/",
        "https://kanjidraw.com/kana/",
        "https://kanjidraw.com/radicals/61/",
        "https://kanjidraw.com/radicals/",
        "https://kanjidraw.com/collections/jlpt-n5/",
        "https://kanjidraw.com/collections/",
        "https://kanjidraw.com/dictionary/",
    ]
    reserved = {"page_type", "entity_key", "dedupe_key", "source_url", "parse_notes", "_provenance"}
    for url in urls:
        record = _record(url)
        expected = {name for name in record if name not in reserved}
        assert set(record["_provenance"]) == expected, url
        for stamp in record["_provenance"].values():
            assert stamp["source"] == "kanjidraw"
            assert stamp["source_url"] == url


def test_malformed_preload_raises_instead_of_being_swallowed():
    tree = parse_document(
        "<html><head><link rel='canonical' href='https://kanjidraw.com/dictionary/x/'/></head>"
        "<body><script>window.__PRELOAD_KANJI__={\"char\":</script></body></html>"
    )
    try:
        kd.extract_preloads(tree)
    except ValueError:
        pass
    except Exception as error:  # pragma: no cover - json errors are acceptable too
        assert "Expecting" in str(error), error
    else:  # pragma: no cover
        raise AssertionError("a truncated preload must not parse silently")


def test_unknown_page_type_raises():
    url = _dictionary_url("段")
    try:
        kd.parse(_load(url), url, "not_a_page_type")
    except ValueError:
        return
    raise AssertionError("an unknown page type must raise")


def _main() -> int:
    failures = 0
    for name, function in sorted(globals().items()):
        if not name.startswith("test_") or not callable(function):
            continue
        try:
            function()
        except Exception as error:  # noqa: BLE001
            failures += 1
            print(f"FAIL {name}: {type(error).__name__}: {error}")
        else:
            print(f"ok   {name}")
    print(f"{failures} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(_main())
