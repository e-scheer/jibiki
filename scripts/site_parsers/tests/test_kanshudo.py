"""Tests for the kanshudo parser, run against real mirrored files.

No hand-written HTML: every fixture is a file under
``var/site_mirror/kanshudo/mirror``, so a test failing means the parser
disagrees with the actual snapshot rather than with an invented one.

Run with ``python -m pytest scripts/site_parsers/tests/test_kanshudo.py`` from
the repository root, or directly with
``python scripts/site_parsers/tests/test_kanshudo.py``.
"""

from __future__ import annotations

import os
import sys
import urllib.parse
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[2]
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from site_parsers import kanshudo  # noqa: E402
from site_parsers.common import parse_document  # noqa: E402

MIRROR = SCRIPTS.parent / "var" / "site_mirror" / "kanshudo" / "mirror" / "www.kanshudo.com"


def _load(relative: str):
    path = MIRROR / relative
    if path.is_dir():
        files = sorted(item for item in path.iterdir() if item.is_file())
        assert files, f"no mirrored file under {path}"
        path = files[0]
    return parse_document(path.read_text(encoding="utf-8"))


def _character(character: str):
    slug = urllib.parse.quote(character)
    url = f"https://www.kanshudo.com/kanji/{slug}"
    return _load(f"kanji/{slug}"), url


def _parse_character(character: str):
    tree, url = _character(character)
    page_type = kanshudo.infer_page_type(url)
    assert not kanshudo.is_shell(tree, url)
    return kanshudo.parse(tree, url, page_type)


def _readings(record, reading_type, key="common_readings"):
    return [item for item in record[key] if item["type"] == reading_type]


def _texts(values):
    """Plain strings of a list of json RichText values."""
    return [None if value is None else value["text"] for value in values]


# --- routing ------------------------------------------------------------------


def test_infer_page_type_separates_kana_radicals_and_kanji():
    assert kanshudo.infer_page_type("https://www.kanshudo.com/kanji/%E6%9C%AC") == "kanji"
    assert kanshudo.infer_page_type("https://www.kanshudo.com/kanji/%E3%81%82") == "kana"
    assert kanshudo.infer_page_type("https://www.kanshudo.com/kanji/%E3%82%B9") == "kana"
    # CJK Radicals Supplement and Kangxi Radicals were previously typed "kana".
    assert kanshudo.infer_page_type("https://www.kanshudo.com/kanji/%E2%BA%97") == "radical"
    assert kanshudo.infer_page_type("https://www.kanshudo.com/kanji/%E2%BC%80") == "radical"
    # Beyond the BMP is still a kanji.
    assert kanshudo.infer_page_type("https://www.kanshudo.com/kanji/%F0%A0%82%8A") == "kanji"


def test_hyogaiji_pages_outside_the_kanji_blocks_are_still_routed():
    # Kanshudo serves a full character page for Bopomofo letters used as kanji
    # variants, for halfwidth katakana, for enclosed and squared ideographs and
    # for one private-use glyph. All of them were routed to "other" and dropped.
    for slug, page_type in [
        ("%E3%84%8B", "kanji"),  # ㄋ
        ("%E3%88%B1", "kanji"),  # ㈱
        ("%F0%9F%88%9A", "kanji"),  # 🈚
        ("%EF%BE%80", "kana"),  # ﾀ, halfwidth katakana
    ]:
        url = f"https://www.kanshudo.com/kanji/{slug}"
        assert kanshudo.infer_page_type(url) == page_type, slug

    record = _parse_character("ㄋ")
    assert record["script"] == "bopomofo"
    assert record["stroke_count"] == 1
    assert record["headline"]["text"].startswith("ㄋ means 'three'")
    assert record["stroke_order_svg_url"].endswith("/0310b.svg")
    halfwidth = _parse_character("ﾀ")
    assert halfwidth["script"] == "katakana"
    assert halfwidth["variant_of"]["surface"] == "タ"


def test_infer_page_type_rejects_utility_routes():
    for url in [
        "https://www.kanshudo.com/kanji/mastery?ufn=1",
        "https://www.kanshudo.com/kanji/studyset",
        "https://www.kanshudo.com/kanji/draw/%E6%9C%AC",
        "https://www.kanshudo.com/kanji/%E6%97%A7%20(kyujitai)",
        "https://www.kanshudo.com/word/addcard?vid=",
        "https://www.kanshudo.com/word/search_advanced",
    ]:
        assert kanshudo.infer_page_type(url) == "other", url


def test_dedupe_key_collapses_query_variants():
    keys = {
        kanshudo.dedupe_key(url, "kanji")
        for url in [
            "https://www.kanshudo.com/kanji/%E6%9C%AC",
            "https://www.kanshudo.com/kanji/%E6%9C%AC?section=readings",
            "https://www.kanshudo.com/kanji/%E6%9C%AC/",
            "https://www.kanshudo.com/kanji/%E6%9C%AC?oq=&st=",
            "https://www.kanshudo.com/kanji/%E6%9C%AC?oq=&amp%3Bst=",
        ]
    }
    assert keys == {"kanshudo:kanji:/kanji/本"}


def test_dedupe_key_aliases_the_default_component_collection():
    # Both urls serve the same document; only the csrf token differs.
    assert kanshudo.dedupe_key(
        "https://www.kanshudo.com/component_details", "component_index"
    ) == kanshudo.dedupe_key(
        "https://www.kanshudo.com/component_details/joyo_components", "component_index"
    )
    assert kanshudo.dedupe_key(
        "https://www.kanshudo.com/component_details/all_components", "component_index"
    ) != kanshudo.dedupe_key("https://www.kanshudo.com/component_details", "component_index")


def test_is_shell_flags_entity_shaped_pages_without_an_entity():
    # /collections/names matches the collection index shape but carries neither a
    # kanji roster nor set links, and /collections/jok/playmenu matches the set
    # shape with no rows at all.
    tree = _load("collections/names")
    assert kanshudo.is_shell(tree, "https://www.kanshudo.com/collections/names")
    tree = _load("collections/jok/playmenu")
    assert kanshudo.is_shell(tree, "https://www.kanshudo.com/collections/jok/playmenu/")
    # A real detail page is not a shell.
    tree = _load("kanji/%E6%9C%AC")
    assert not kanshudo.is_shell(tree, "https://www.kanshudo.com/kanji/%E6%9C%AC")


# --- kanji pages --------------------------------------------------------------


def test_kanji_page_scalar_fields():
    record = _parse_character("本")
    assert record["character"] == "本"
    assert record["meanings"] == ["book"]
    assert record["stroke_count"] == 5
    assert record["frequency_rank"] == 7
    assert record["jlpt_level"] == "N5"
    assert record["grade"] == 1
    assert record["character_type"] == "Jōyō (常用)"
    assert record["usefulness_level"] == 1
    assert record["study_set"] == "1-1"
    assert record["beginner_lesson"] == 2
    assert record["intermediate_lesson"] == 1
    assert record["words_starting_with"] == 326
    assert record["words_containing"] == 1040
    assert record["names_containing"] == 8383
    assert record["component_in_kanji"] == 10
    assert record["component_in_joyo_kanji"] == 2
    assert record["references"] == {
        "henshall": 76,
        "henshall_original": 70,
        "joy_o_kanji": 70,
        "key_to_kanji": 979,
    }


def test_stroke_order_svg_is_captured_and_matches_the_character():
    record = _parse_character("本")
    assert record["stroke_order_svg_url"] == "https://kanshudo.s3.amazonaws.com/svg/0672c.svg"
    assert record["stroke_order_codepoint"] == "U+672C"
    kana = _parse_character("あ")
    assert kana["stroke_order_svg_url"].endswith("/03042.svg")


def test_singular_stroke_label_is_read():
    # One-stroke characters use the singular label "Stroke :".
    assert _parse_character("く")["stroke_count"] == 1


def test_every_on_reading_is_kept():
    record = _parse_character("重")
    assert [item["reading"] for item in _readings(record, "on")] == ["ジュウ", "チョウ"]
    assert [item["reading"] for item in _readings(_parse_character("木"), "on")] == ["モク", "ボク"]


def test_kun_readings_are_one_record_each_with_okurigana():
    record = _parse_character("重")
    kun = _readings(record, "kun")
    assert [(item["reading"], item["okurigana"], item["gloss"]) for item in kun] == [
        ("おも", "い", "heavy"),
        ("かさ", "なる", "to be piled up"),
        ("かさ", "ねる", "to pile up"),
        ("え", None, "-fold, -ply"),
    ]
    # The dictionary form disambiguates the two かさ readings.
    assert [item["dictionary_form"] for item in kun] == ["重い", "重なる", "重ねる", "え"]


def test_additional_kun_row_is_not_dropped():
    record = _parse_character("重")
    kun = _readings(record, "kun", "additional_readings")
    assert [(item["reading"], item["okurigana"]) for item in kun] == [
        ("おも", "り"),
        ("おも", "なう"),
        ("おも", None),
    ]
    assert [item["reading"] for item in _readings(record, "name", "additional_readings")] == [
        "さね",
        "しげる",
    ]


def test_reading_help_panel_text_is_not_harvested():
    record = _parse_character("重")
    readings = {item["reading"] for item in record["common_readings"]}
    # The Kun help panel explains itself with 行く / いく; neither may appear.
    assert "いく" not in readings
    assert all("読" not in (item["reading"] or "") for item in record["common_readings"])


def test_components_keep_repeats_aliases_and_pattern():
    record = _parse_character("歌")
    assert record["composition_pattern"] == "⿰⿱"
    assert [(item["symbol"], item["meaning"]) for item in record["components"]] == [
        ("可", "good; possible"),
        ("可", "good; possible"),
        ("欠", "lack"),
    ]
    smile = _parse_character("笑")
    assert smile["components"][0]["symbol"] == "⺮"
    assert smile["components"][0]["canonical_form"]["surface"] == "竹"
    assert smile["components"][0]["meaning"] == "bamboo"


def test_variants_survive_without_a_following_notes_row():
    record = _parse_character("ク")
    assert [item["character"] for item in record["variants"]] == ["ㇰ", "⺈", "𠂊"]
    assert record["variants"][0]["href"] == "/kanji/ㇰ"


def test_see_also_row_is_captured():
    record = _parse_character("ク")
    assert record["see_also"][0] == {
        "character": "角",
        "href": "/kanji/角",
        "meaning": "corner; horn",
    }


def test_notes_and_variant_relation_are_structured():
    record = _parse_character("⺗")
    assert record["variant_of"]["surface"] == "心"
    assert record["radical_number"] == 61
    assert record["notes"][0]["text"]["text"] == "This is the radical form of 心 (heart)."
    assert record["notes"][0]["links"][0]["surface"] == "心"
    assert record["notes_attribution"]["text"].startswith("Synopsis of")
    chinese = _parse_character("⼀")
    assert chinese["variant_kind"] == "chinese"
    assert chinese["variant_of"]["surface"] == "一"


def test_kana_pages_expose_script_and_romaji():
    for character, script, romaji in [("く", "hiragana", "ku"), ("ス", "katakana", "su")]:
        record = _parse_character(character)
        assert record["script"] == script
        assert record["romaji"] == romaji
        assert record["meanings"] == []
    combined = _parse_character("ク")
    assert (combined["script"], combined["romaji"], combined["meanings"]) == (
        "katakana",
        "ku",
        ["corner"],
    )


def test_mnemonic_flag_is_not_inverted():
    assert _parse_character("本")["mnemonic_exists"] is True
    # 重 carries no mnemonic markup at all.
    assert _parse_character("重")["mnemonic_exists"] is False
    assert _parse_character("本")["mnemonic_text"] is None


def test_example_words_are_extracted_with_senses_and_groups():
    record = _parse_character("本")
    words = record["example_words"]
    assert [item["surface"] for item in words[:2]] == ["本", "一本"]
    first = words[0]
    assert first["word_id"] == 135031
    assert first["reading"] == "ほん"
    assert first["jlpt_level"] == "N5"
    assert first["usefulness_level"] == 1
    assert first["reading_group"] == {
        "label": "ホン",
        "reading": "ホン",
        "variant_reading": None,
        "word_count": 854,
    }
    assert _texts(first["senses"][0]["glosses"]) == ["book", "volume", "script"]
    assert first["senses"][0]["parts_of_speech"] == ["noun"]
    assert first["senses"][0]["cross_references"][0]["surface"] == "ご本・ごほん"
    assert words[1]["reading_group"]["variant_reading"] == "ぽん"
    # The part-of-speech wrapper is optional: 一本 sense 2 has none of its own.
    assert _texts(words[1]["senses"][1]["glosses"]) == ["one version"]


def test_singular_group_header_is_not_attributed_to_the_previous_reading():
    # "ハク (read as ぱく) : 1 word" counts in the singular, so the plural-only
    # pattern skipped it and 万博 was filed under the preceding バク group.
    record = _parse_character("博")
    groups = {
        item["surface"]: item["reading_group"] for item in record["example_words"]
    }
    assert groups["万博"] == {
        "label": "ハク (read as ぱく)",
        "reading": "ハク",
        "variant_reading": "ぱく",
        "word_count": 1,
    }
    # Every row of the page is attributed, and no row inherits a stale group.
    assert all(group is not None for group in groups.values())
    # A group that is not a reading keeps its label and reports no reading.
    ten = {item["surface"]: item["reading_group"] for item in _parse_character("十")["example_words"]}
    assert ten["二十日"] == {
        "label": "Part of a non-standard reading",
        "reading": None,
        "variant_reading": None,
        "word_count": 1,
    }
    # Both leading headers of 柴 are singular; neither may come out null.
    shiba = _parse_character("柴")["example_words"]
    assert [item["reading_group"]["reading"] for item in shiba[:2]] == ["サイ", "シ"]


def test_bare_text_jukugo_gloss_is_kept():
    # 住友 puts its meaning straight into div#jk_abbr_<id> with no div.vm, and it
    # used to be dropped: senses was [] and no other field carried it.
    record = _parse_character("住")
    sumitomo = next(item for item in record["example_words"] if item["surface"] == "住友")
    assert _texts(sumitomo["senses"][0]["glosses"]) == ["Sumitomo (company)"]


def test_jukugo_click_prompt_becomes_counts_not_interface_copy():
    words = _parse_character("本")["example_words"]
    detail = {item["surface"]: item["withheld_detail"] for item in words}
    for value in detail.values():
        assert value is None or set(value) == {
            "additional_forms",
            "additional_readings",
            "additional_meanings",
            "has_useful_expressions",
        }
    # Nothing withheld means no container at all, rather than the UI sentence
    # "(click the word for examples and links)" stamped as factual data.
    assert any(value is None for value in detail.values())
    assert any(value is not None for value in detail.values())


def test_cascading_components_are_a_tree_without_login_prose():
    record = _parse_character("歌")
    rows = record["cascading_components"]
    assert rows[0]["character"] == "歌"
    assert rows[0]["depth"] == 0
    assert rows[0]["parent"] is None
    assert rows[1]["parent"] == "歌"
    assert rows[2]["parent"] == rows[1]["character"]
    for row in rows:
        for meaning in row["meanings"]:
            assert "LOG IN" not in meaning
    assert rows[0]["kun_readings"][0] == {
        "reading": "うた",
        "okurigana": "う",
        "gloss": "to sing",
    }


def test_usage_counts_are_parsed():
    record = _parse_character("本")
    assert record["usage"]["useful_words"] == {"uses": 63, "readings": 2}
    assert record["usage"]["all_words"] == {"uses": 1009, "readings": 2}
    assert record["usage"]["summary"][0]["text"].startswith("In the")


def test_empty_containers_are_null_so_a_fill_rate_means_something():
    # A radical page carries neither reference numbers nor usage counts, and the
    # empty dicts used to make both fields look 100% filled.
    radical = _parse_character("⺗")
    assert radical["references"] is None
    assert radical["usage"] is None
    # The page character is itself the root cascading row, so a character with no
    # decomposition must report no components rather than a list holding itself.
    assert radical["cascading_components"] == []
    assert _parse_character("本")["references"] is not None
    assert _parse_character("歌")["cascading_components"]


def test_notes_drop_the_joy_o_kanji_navigation_and_bundle_advert():
    # 仙 emitted 6 notes of which 5 were chrome: a download prompt, two link rows,
    # a lead-in sentence and a whole thematic bundle advert.
    record = _parse_character("仙")
    assert len(record["notes"]) == 1
    text = record["notes"][0]["text"]["text"]
    assert text.startswith("Coming from an ancient Taoist context")
    for note in record["notes"]:
        body = note["text"]["text"]
        for chrome in (
            "View in the essay collection",
            "All Joy o'",
            "Thematic Bundles",
            "VIEW ESSAYS",
            "click the badge to download",
        ):
            assert chrome not in body, chrome
        for link in note["links"]:
            assert not (link["href"] or "").startswith("/jok/"), link


def test_kanji_provenance_marks_authored_fields_reference_only():
    record = _parse_character("本")
    provenance = record["_provenance"]
    assert provenance["stroke_count"]["ship"] == "allowed"
    assert provenance["common_readings"]["ship"] == "allowed"
    assert provenance["usefulness_level"]["ship"] == "reference-only"
    assert provenance["notes"]["ship"] == "reference-only"
    assert provenance["mnemonic_text"]["license_class"] == "authored-third-party"
    for key in record:
        if key != "_provenance":
            assert key in provenance, key


# --- word pages ---------------------------------------------------------------


def _parse_word(surface: str):
    slug = urllib.parse.quote(surface)
    url = f"https://www.kanshudo.com/word/{slug}"
    tree = _load(f"word/{slug}")
    assert not kanshudo.is_shell(tree, url)
    return kanshudo.parse(tree, url, kanshudo.infer_page_type(url))


def test_word_plural_reading_label_is_matched():
    record = _parse_word("行く")
    primary = record["forms"][0]
    assert [item["reading"] for item in primary["readings"]] == ["いく", "ゆく"]
    assert primary["reading_distribution"]["text"] == (
        "行く can be read in 2 ways: いく (almost always used), ゆく (rare)."
    )


def test_word_forms_are_all_emitted_with_their_own_readings():
    record = _parse_word("行く")
    assert [item["form"] for item in record["forms"]] == ["行く", "いく", "ゆく", "逝く", "往く"]
    kana_form = record["forms"][1]
    assert kana_form["readings"] == []  # legitimately empty, never borrowed
    assert record["forms"][3]["readings"][0]["reading"] == "いく"

    katakana = _parse_word("片仮名")
    assert [item["form"] for item in katakana["forms"]] == ["カタカナ", "かたかな", "片仮名"]
    assert katakana["surface"] == "片仮名"
    assert katakana["headword"] == "カタカナ"


def test_word_senses_are_separate_records_with_carried_pos():
    record = _parse_word("行く")
    senses = record["senses"]
    assert len(senses) == 10
    assert senses[0]["index"] == 1
    assert _texts(senses[0]["glosses"])[0] == "to go"
    assert senses[7]["parts_of_speech"] == ["auxiliary verb"]
    assert senses[8]["parts_of_speech"] == [
        "irregular godan verb 'iku/yuku'",
        "intransitive verb",
    ]
    assert senses[2]["parts_of_speech"] == senses[0]["parts_of_speech"]
    assert _texts(senses[4]["usage_notes"]) == ["this meaning is restricted to form 逝く"]
    assert senses[1]["cross_references"][0]["surface"] == "旨く行く"


def test_word_example_sentence_is_readable():
    record = _parse_word("行く")
    sentence = record["example_sentences"][0]
    assert sentence["jp"] == "週末は、病院に行きました。"
    assert sentence["jp_reading"] == "しゅうまつは、びょういんにいきました。"
    assert sentence["en"]["text"] == "I went to the hospital over the weekend."
    assert sentence["sentence_id"] == 164455
    surfaces = [token["surface"] for token in sentence["tokens"]]
    assert surfaces == ["週末", "は", "、", "病院", "に", "行きました", "。"]
    assert sentence["tokens"][5]["reading"] == "いきました"
    assert sentence["tokens"][5]["lemma"] == "行きました"
    assert sentence["tokens"][1]["is_stop"] is True

    katakana = _parse_word("片仮名")
    assert katakana["example_sentences"][0]["jp"].startswith("半角カタカナをインターネット上の色んな所で")


def test_word_form_usage_is_attached_per_form():
    record = _parse_word("片仮名")
    forms = {item["form"]: item["form_usage"] for item in record["forms"]}
    assert forms["カタカナ"]["share_pct"] == 80
    assert forms["カタカナ"]["jlpt_level"] is None
    assert forms["片仮名"]["jlpt_level"] == "N2"
    assert forms["かたかな"]["jlpt_level"] == "N5"
    assert record["usefulness"]["level"] == 2
    assert record["usefulness"]["rank"] == 674
    assert record["usefulness"]["collection"]["href"].startswith("/collections/")


def test_word_component_kanji_is_a_tree_without_chrome():
    record = _parse_word("片仮名")
    rows = record["component_kanji"]
    roots = [row["character"] for row in rows if row["depth"] == 0]
    assert roots == ["片", "仮", "名"]
    kata = rows[0]
    assert kata["on_readings"] == [{"reading": "ヘン", "gloss": None}]
    assert kata["kun_readings"][0]["reading"] == "かた-"
    assert kata["meanings"] == ["right side"]
    assert kata["mnemonic_available"] is True
    for row in rows:
        assert all("LOG IN" not in meaning for meaning in row["meanings"])


def test_word_useful_expressions_are_kept():
    # The "Useful expressions:" section carries no div.ent_w, so walking only the
    # surface-form blocks dropped it entirely.
    record = _parse_word("行く")
    expressions = record["useful_expressions"]
    assert [item["surface"] for item in expressions] == ["地で行く", "先を行く"]
    assert expressions[0]["reading"] == "じでいく"
    assert expressions[0]["expression_id"] == 268231
    assert _texts(expressions[0]["glosses"]) == ["to do for real", "to do in real life"]
    assert _parse_word("片仮名")["useful_expressions"] == []


def test_usefulness_notes_drop_the_button_label():
    for surface in ("行く", "片仮名"):
        record = _parse_word(surface)
        notes = _texts(record["usefulness"]["notes"])
        assert notes, surface
        for note in notes:
            assert "VIEW COLLECTION" not in note, note
        assert any(note.endswith("most useful words in Japanese") for note in notes)
        # The button target itself is still kept, as a link.
        assert record["usefulness"]["collection"]["href"].startswith("/collections/")


def test_word_provenance_marks_curated_content_reference_only():
    record = _parse_word("行く")
    provenance = record["_provenance"]
    assert provenance["senses"]["ship"] == "allowed"
    assert provenance["example_sentences"]["ship"] == "reference-only"
    assert provenance["usefulness"]["ship"] == "reference-only"
    for key in record:
        if key != "_provenance":
            assert key in provenance, key


def test_rich_text_helpers_keep_span_offsets():
    # Kanshudo carries no role markup inside its prose today, so this exercises
    # the offset arithmetic directly: a collapsed or sliced RichText whose spans
    # no longer point at their own text would silently corrupt any site that does.
    from site_parsers.common import RichText, TextSpan

    source = RichText(
        "  a  reading\nnote ; and more  ",
        [TextSpan(text="reading", role="reading", start=5, end=12)],
    )
    flat = kanshudo._collapsed(source)
    assert flat.text == "a reading note ; and more"
    assert flat.text[flat.spans[0].start : flat.spans[0].end] == "reading"
    segments = kanshudo._rich_segments(flat)
    assert [item.text for item in segments] == ["a reading note", "and more"]
    assert segments[0].text[segments[0].spans[0].start : segments[0].spans[0].end] == "reading"
    assert segments[1].spans == []
    joined = kanshudo._joined_rich([item.to_json() for item in segments])
    assert joined["text"] == "a reading note; and more"
    span = joined["spans"][0]
    assert joined["text"][span["start"] : span["end"]] == "reading"


def test_marked_up_prose_is_emitted_as_rich_text():
    record = _parse_character("本")
    word = _parse_word("行く")
    radical = _parse_character("⺗")
    values = [
        record["headline"],
        record["usage"]["summary"][0],
        record["example_words"][0]["senses"][0]["glosses"][0],
        word["primary_gloss"],
        word["head_note"],
        word["senses"][4]["usage_notes"][0],
        word["forms"][0]["reading_distribution"],
        word["forms"][0]["form_usage"]["share_text"],
        word["forms"][0]["form_usage"]["wordlists"][0],
        word["example_sentences"][0]["en"],
        word["usefulness"]["notes"][0],
        word["useful_expressions"][0]["glosses"][0],
        radical["notes"][0]["text"],
        radical["notes_attribution"],
    ]
    for value in values:
        assert isinstance(value, dict) and value["text"], value
        for span in value.get("spans") or []:
            assert value["text"][span["start"] : span["end"]] == span["text"]


# --- component and collection pages ------------------------------------------


def test_component_index_keeps_names_numbers_strokes_and_variants():
    url = "https://www.kanshudo.com/component_details"
    tree = _load("component_details")
    record = kanshudo.parse(tree, url, kanshudo.infer_page_type(url))
    assert record["collection"] == "joyo_components"
    assert record["component_count"] == 420
    first = record["components"][0]
    assert first == {
        "character": "一",
        "href": "/kanji/一",
        "radical_number": 1,
        "name": "one",
        "stroke_count": 1,
        "variants": [],
    }
    second = record["components"][1]
    assert second["radical_number"] is None
    assert second["name"] == "whereupon"
    assert [item["surface"] for item in second["variants"]] == ["乃", "⼃", "ノ"]
    assert {item["stroke_count"] for item in record["components"]} >= {1, 2, 3}


def _collection_index(slug: str):
    url = f"https://www.kanshudo.com/collections/{slug}"
    tree = _load(f"collections/{slug}")
    return kanshudo.parse(tree, url, kanshudo.infer_page_type(url))


def test_collection_index_is_a_kanji_roster():
    record = _collection_index("joyo_kanji")
    assert record["kanji_count"] == 2136
    assert record["kanji_groups"][0]["characters"][0]["surface"] == "人"
    assert record["kanji_groups"][0]["title"].startswith("Jōyō Kanji 1-100")


def test_every_collection_subsection_keeps_its_own_title_and_roster():
    # One div.infopanel holds several h4 subsections. Taking the first h4 and
    # fusing every roster under it labelled 170 characters "N4 1-100 (100 kanji)"
    # and 1,136 characters "N1 1-100 (100 kanji)".
    record = _collection_index("jlpt_kanji")
    assert len(record["kanji_groups"]) == 22
    for group in record["kanji_groups"]:
        assert group["declared_count"] == len(group["characters"]), group["title"]
    titles = [group["title"] for group in record["kanji_groups"]]
    assert titles[1] == "JLPT Kanji N4 1-100 (100 kanji)"
    assert titles[2] == "JLPT Kanji N4 101-170 (70 kanji)"
    # The variant panels of jinmeiyo relist characters the main panels list, so
    # summing the rosters claimed 1,782 kanji for a page that lists 1,074.
    jinmeiyo = _collection_index("jinmeiyo_kanji")
    assert jinmeiyo["kanji_count"] == 1074
    assert sum(len(group["characters"]) for group in jinmeiyo["kanji_groups"]) == 1782


def test_usefulness_collection_keeps_its_band_labels():
    # This page heads its subsections with div.title_h4 rather than h4, so every
    # title came out None and the 2,136 kanji could not be attributed to a level.
    record = _collection_index("usefulness_kanji")
    assert all(group["title"] for group in record["kanji_groups"])
    bands = {
        group["parent_title"] or group["title"]: sum(
            len(item["characters"])
            for item in record["kanji_groups"]
            if (item["parent_title"] or item["title"]) == (group["parent_title"] or group["title"])
        )
        for group in record["kanji_groups"]
    }
    assert bands["Kanji Usefulness Level 1 (80 kanji)"] == 80
    assert bands["Kanji Usefulness Level 2 (170 kanji)"] == 170
    assert bands["Kanji Usefulness Level 5 (1136 kanji)"] == 1136


def test_collection_word_set_emits_one_record_per_word():
    url = "https://www.kanshudo.com/collections/vocab_usefulness2021/UFN2021-1-1"
    tree = _load("collections/vocab_usefulness2021/UFN2021-1-1")
    records = kanshudo.parse(tree, url, kanshudo.infer_page_type(url))
    assert isinstance(records, list)
    assert len(records) == 100
    first = records[0]
    assert first["record_type"] == "word"
    assert first["surface"] == "時間"
    assert first["reading"] == "じかん"
    assert first["collection"] == "vocab_usefulness2021"
    assert first["set_id"] == "UFN2021-1-1"
    assert _texts(first["senses"][0]["glosses"]) == ["time"]
    assert first["set_size"] == 100
    assert first["set_size_note"]["text"] == "This collection contains 100 words."
    assert first["_provenance"]["usefulness_level"]["ship"] == "reference-only"
    for key in first:
        if key != "_provenance":
            assert key in first["_provenance"], key


def test_collection_kanji_set_emits_kanji_records():
    url = "https://www.kanshudo.com/collections/genki/1-4"
    tree = _load("collections/genki/1-4")
    records = kanshudo.parse(tree, url, kanshudo.infer_page_type(url))
    assert len(records) == 14
    assert {record["record_type"] for record in records} == {"kanji"}
    sun = records[0]
    assert sun["character"] == "日"
    assert [item["reading"] for item in sun["on_readings"]] == ["ニチ", "ジツ"]
    assert sun["meanings"] == ["sun", "day"]


def test_parse_raises_on_a_page_type_it_does_not_own():
    tree = _load("kanji/%E6%9C%AC")
    try:
        kanshudo.parse(tree, "https://www.kanshudo.com/kanji/mastery", "other")
    except ValueError:
        pass
    else:  # pragma: no cover
        raise AssertionError("parse must raise for an unsupported page type")


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
    sys.exit(_main())
