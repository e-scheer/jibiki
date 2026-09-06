"""Tests for the the_kanji_map parser, run against real mirrored snapshots.

Every assertion below is anchored on a file under
``var/site_mirror/the_kanji_map/mirror``, never on hand written HTML. The
defects this parser replaces were all invisible to synthetic fixtures: they came
from a page embedding a full data record for every neighbour in the kanji graph,
which only real snapshots reproduce.

Run with ``python -m pytest scripts/site_parsers/tests/test_the_kanji_map.py``
from the repository root, or directly with
``python scripts/site_parsers/tests/test_the_kanji_map.py``. Set
``PYTHONIOENCODING=utf-8`` on Windows, the console is cp1252 and dies on
Japanese output.
"""

from __future__ import annotations

import sys
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from site_parsers import the_kanji_map as tkm  # noqa: E402
from site_parsers.common import parse_document  # noqa: E402

MIRROR = ROOT / "var" / "site_mirror" / "the_kanji_map" / "mirror" / "thekanjimap.com"


def snapshot_path(character: str) -> Path:
    return MIRROR / urllib.parse.quote(character) / "index.html"


def load(character: str):
    path = snapshot_path(character)
    assert path.exists(), f"missing mirrored snapshot for {character}: {path}"
    tree = parse_document(path.read_text(encoding="utf-8"))
    url = f"https://thekanjimap.com/{urllib.parse.quote(character)}"
    return tree, url


def parse(character: str) -> dict:
    tree, url = load(character)
    page_type = tkm.infer_page_type(url)
    assert page_type == "kanji"
    assert not tkm.is_shell(tree, url)
    return tkm.parse(tree, url, page_type)


# --- routing ------------------------------------------------------------------


def test_infer_page_type_routes_single_character_paths_only():
    assert tkm.infer_page_type("https://thekanjimap.com/%E4%B8%8B") == "kanji"
    assert tkm.infer_page_type("https://thekanjimap.com/about") == "about"
    assert tkm.infer_page_type("https://thekanjimap.com/") == "home"
    # Asset urls share the single-segment shape of a kanji url. The old
    # infer_page_type called these kanji pages.
    assert tkm.infer_page_type("https://thekanjimap.com/manifest.json") == "asset"
    assert tkm.infer_page_type("https://thekanjimap.com/favicon.ico") == "asset"
    assert tkm.infer_page_type("https://thekanjimap.com/favicon.ico%5C") == "asset"
    assert tkm.infer_page_type("https://thekanjimap.com/apple-touch-icon.png") == "asset"
    assert tkm.infer_page_type("https://thekanjimap.com/a/b") == "other"


def test_dedupe_key_ignores_query_and_encoding():
    left = tkm.dedupe_key("https://thekanjimap.com/%E4%B8%8B", "kanji")
    right = tkm.dedupe_key("https://thekanjimap.com/%E4%B8%8B?theme=dark", "kanji")
    assert left == right == "kanji:下"


# --- payload scoping: the contamination the old parser suffered ---------------


def test_component_page_keeps_its_own_data_not_a_neighbours():
    """彐 has no grade, JLPT, taught-in or frequency of its own.

    The old whole-document regexes returned 争's values (stroke_count 6,
    grade 4, N3, frequency 271, on ソウ, kun あらそう) because 争 is a
    descendant node embedded in the same page.
    """
    record = parse("彐")
    assert record["character"] == "彐"
    assert record["stroke_count"] == 3
    assert record["grade"] is None
    assert record["jlpt_level"] is None
    assert record["taught_in"] is None
    assert record["frequency_rank"] is None
    assert [entry["reading"] for entry in record["on_readings"]] == ["ケイ"]
    assert record["kun_readings"] == []
    assert record["entry_kind"] == "radical_component"
    assert record["radical"]["symbol"] == "彐"
    assert record["radical"]["forms"] == ["彑"]
    assert record["radical"]["meaning"] == "pig snout"


def test_radical_page_keeps_its_own_readings_and_forms():
    """氵 must yield さんずい, not 水's みず / スイ."""
    record = parse("氵")
    assert record["stroke_count"] == 3
    assert [entry["reading"] for entry in record["kun_readings"]] == ["さんずい"]
    assert record["on_readings"] == []
    assert record["grade"] is None
    assert record["jlpt_level"] is None
    assert record["frequency_rank"] is None
    assert record["entry_kind"] == "radical_component"
    assert record["radical"]["symbol"] == "水"
    assert record["radical"]["forms"] == ["氵", "氺"]
    assert record["radical"]["kangxi_character"] == "⽔"
    assert record["radical"]["name_ja"] == "みず"
    assert record["radical"]["name_romaji"] == "mizu"
    # The gloss list must not present the Kangxi table index as a meaning.
    assert record["meanings"] == ["water"]
    assert record["radical_index_label"] == "water radical (no. 85)"


def test_parts_is_the_requested_kanjis_own_decomposition():
    """下's decomposition is three parts, not the 18 the old findall produced."""
    record = parse("下")
    assert record["parts"] == ["一", "卜", "｜"]
    # ｜ is not a graph node at all, and that disagreement is recorded rather
    # than hidden.
    assert record["parts_without_direct_edge"] == ["｜"]
    assert record["parts_not_in_graph"] == ["｜"]


def test_parts_and_graph_granularity_difference_is_recorded():
    """混 decomposes as 氵 + 昆 in the graph but jisho lists atomic parts."""
    record = parse("混")
    assert record["parts"] == ["日", "比", "汁"]
    assert [entry["character"] for entry in record["components"]] == ["氵", "昆"]
    # 日 and 比 are in the graph, one level deeper, via 昆.
    assert record["parts_without_direct_edge"] == ["日", "比", "汁"]
    assert record["parts_not_in_graph"] == ["汁"]
    deeper = {entry["character"]: entry["depth"] for entry in record["decomposition"]}
    assert deeper["氵"] == 1 and deeper["昆"] == 1
    assert deeper["水"] == 2 and deeper["日"] == 2 and deeper["比"] == 2
    assert record["detached_edge_count"] == 0


def test_empty_parts_stay_empty():
    assert parse("刂")["parts"] == []
    assert parse("氵")["parts"] == []


def test_radical_block_is_null_when_the_character_has_none():
    """コ inherited 火 / "fire" from the 炊 node under the old parser."""
    record = parse("コ")
    assert record["radical"] is None
    assert record["meanings"] == []
    assert record["meaning_primary"] is None
    assert record["meaning_jisho"] is None  # '' normalised to null
    assert record["entry_kind"] == "kana_component"
    assert record["stroke_count"] is None


# --- graph --------------------------------------------------------------------


def test_graph_is_explicit_parent_child_edges_with_labels():
    record = parse("下")
    assert record["graph_variant"] == "withOutLinks"
    assert record["node_count"] == 14
    assert record["edge_count"] == 13
    assert record["detached_edge_count"] == 0
    components = {entry["character"] for entry in record["components"]}
    assert components == {"一", "卜"}
    used_in = {entry["character"] for entry in record["used_in"]}
    assert used_in == {"丐", "卞", "圷", "垰", "峠", "梺", "裃", "閇", "雫", "鞐", "颪"}
    beggar = next(entry for entry in record["used_in"] if entry["character"] == "丐")
    assert beggar["meaning"] == "beggar, beg, give"
    assert beggar["stroke_count"] == 4
    assert {"source": "一", "target": "下"} in record["edges"]
    assert {"source": "下", "target": "丐"} in record["edges"]


def test_large_graph_is_fully_captured():
    record = parse("氵")
    assert record["edge_count"] == 332
    assert len(record["components"]) == 1
    assert len(record["used_in"]) == 331


# --- meanings -----------------------------------------------------------------


def test_meanings_are_the_full_jisho_gloss_list_with_kanjialive_kept_apart():
    record = parse("下")
    assert record["meanings"] == ["below", "down", "descend", "give", "low", "inferior"]
    assert record["meaning_primary"] == "below"
    assert record["meaning_kanjialive"] == "down"
    assert record["radical_index_label"] is None


def test_radical_variant_label_is_lifted_out_of_the_gloss_list():
    record = parse("覀")
    # "variant of radical 146" is nothing but the index, so no meaning survives.
    assert record["meanings"] == []
    assert record["radical_index_label"] == "variant of radical 146"
    assert record["radical_index"] == 146
    assert record["radical_index_name"] is None
    assert record["entry_kind"] == "radical_component"


def test_only_the_index_is_metadata_not_the_radical_name_in_front_of_it():
    """丿's gloss list is the index annotation alone, so lifting all of it left
    the page with no meaning at all and ``meaning_primary`` null."""
    for character, name, index in (
        ("丿", "katakana no radical", 4),
        ("亠", "kettle lid radical", 8),
        ("儿", "legs radical", 10),
        ("禾", "two-branch tree radical", 115),
        ("鬥", "broken gate radical", 191),
        ("氺", "water radical variant", 85),
    ):
        record = parse(character)
        assert record["radical_index"] == index, character
        assert record["radical_index_name"] == name, character
        assert record["meanings"] == [name], character
        assert record["meaning_primary"] == name, character


def test_a_radical_name_never_displaces_a_real_gloss():
    """刂 lost "standing sword" when the whole gloss was lifted into the label."""
    knife = parse("刂")
    assert knife["meanings"] == ["knife"]
    assert knife["radical_index_name"] == "standing sword radical"
    assert knife["radical_index"] == 18
    # A kanji that happens to be a Kangxi radical keeps its own gloss list and
    # does not gain the radical name as a meaning.
    heart = parse("心")
    assert heart["meanings"] == ["heart", "mind", "spirit"]
    assert heart["radical_index_name"] == "heart radical"
    water = parse("氵")
    assert water["meanings"] == ["water"]
    assert water["radical_index_name"] == "water radical"


def test_an_index_only_label_yields_no_invented_name():
    record = parse("亻")
    assert record["radical_index_label"] == "radical number 9"
    assert record["radical_index"] == 9
    assert record["radical_index_name"] is None
    assert record["meanings"] == []


def test_a_kanji_that_is_also_a_kangxi_radical_stays_a_kanji():
    """心 and 小 are grade 1 jouyou kanji and appear in navigableRadicalIds."""
    for character, grade, jlpt in (("心", 2, "N4"), ("小", 1, "N5")):
        record = parse(character)
        assert record["entry_kind"] == "kanji", character
        assert record["is_navigable_radical"] is True, character
        assert record["grade"] == grade, character
        assert record["jlpt_level"] == jlpt, character
    heart = parse("心")
    # The Kangxi table index must not sit in the gloss list.
    assert heart["meanings"] == ["heart", "mind", "spirit"]
    assert heart["radical_index_label"] == "heart radical (no. 61)"


# --- readings -----------------------------------------------------------------


def test_kanjidic_okurigana_and_affix_markers_survive():
    record = parse("小")
    raws = [entry["raw"] for entry in record["kun_readings"]]
    assert raws == ["ちい.さい", "こ-", "お-", "さ-"]
    first = record["kun_readings"][0]
    assert first == {
        "raw": "ちい.さい",
        "reading": "ちいさい",
        "stem": "ちい",
        "okurigana": "さい",
        "affix": None,
    }
    prefix = record["kun_readings"][1]
    assert prefix["reading"] == "こ" and prefix["affix"] == "prefix"


def test_suffix_marker_survives():
    record = parse("心")
    raws = [entry["raw"] for entry in record["kun_readings"]]
    assert raws == ["こころ", "-ごころ"]
    assert record["kun_readings"][1]["affix"] == "suffix"


def test_no_reading_is_dropped():
    record = parse("西")
    assert [entry["reading"] for entry in record["on_readings"]] == ["セイ", "サイ", "ス"]
    assert record["on_readings_romaji"] == ["sei", "sai"]
    assert record["nanori"] is None


def test_placeholder_romaji_is_not_emitted_as_a_reading():
    """予 carried kun_readings_romaji == ["n/a"] beside あらかじ.め."""
    record = parse("予")
    assert record["kun_readings_romaji"] == []
    assert record["on_readings_romaji"] == ["yo"]
    assert [entry["raw"] for entry in record["kun_readings"]] == ["あらかじ.め"]
    assert any("placeholder" in note for note in record["parse_notes"])


def test_na_is_kept_because_it_is_a_real_romaji_syllable():
    """The placeholder filter must not eat 並's nami / na / naraberu list."""
    record = parse("並")
    assert record["kun_readings_romaji"] == [
        "nami",
        "na",
        "naraberu",
        "nara",
        "narabu",
        "narabini",
        "narabi",
    ]
    assert not any("placeholder" in note for note in record["parse_notes"])


# --- mnemonic hint ------------------------------------------------------------


def test_mnemonic_hint_is_captured_with_its_role_spans():
    record = parse("内")
    hint = record["mnemonic_hint"]
    assert hint is not None
    assert hint["text"] == 'Person 人 in his clothes/house 冂 (orig. "enclosure").'
    roles = {(span["role"], span["text"]) for span in hint["spans"]}
    assert ("etymology_note", '(orig. "enclosure")') in roles
    assert record["mnemonic_etymology_notes"] == ['(orig. "enclosure")']
    assert record["mnemonic_hint_kind"] == "authored"
    assert record["mnemonic_hint_group"] == 1


def test_mnemonic_hint_is_not_truncated_at_an_escaped_quote():
    """The old ``(.*?)\\"`` idiom yielded ``Rising very 十 (orig. \\`` for 早."""
    record = parse("早")
    assert record["mnemonic_hint"]["text"] == (
        'Rising very 十 (orig. "many") early with the sun 日.'
    )


def test_inline_kanjialive_indices_are_extracted():
    record = parse("西")
    assert record["mnemonic_kanji_refs"] == [176]
    assert record["mnemonic_hint"]["text"] == (
        "Dissident speaking 口 on a podium [176] in the west."
    )
    roles = {span["role"] for span in record["mnemonic_hint"]["spans"]}
    assert "kanjialive_ref" in roles


def test_ui_boilerplate_is_not_stored_as_a_mnemonic():
    record = parse("小")
    assert record["mnemonic_hint"] is None
    assert record["mnemonic_hint_kind"] == "ui_boilerplate"
    assert record["mnemonic_hint_raw"] == (
        "Please view the animation in the radical field to the left."
    )


def test_boilerplate_hybrid_keeps_only_the_authored_continuation():
    parsed = tkm.parse_mnemonic_hint(
        "Please view the radical animation on the left; pointing at the nose to "
        "indicate the self."
    )
    assert parsed["kind"] == "authored"
    assert parsed["boilerplate_prefix_removed"] is True
    assert parsed["hint"]["text"] == "Pointing at the nose to indicate the self."


def test_placeholder_and_stroke_description_hints_are_classified():
    assert tkm.parse_mnemonic_hint("n/a")["kind"] == "placeholder"
    assert tkm.parse_mnemonic_hint("One line.")["kind"] == "stroke_description"
    assert tkm.parse_mnemonic_hint(None)["kind"] == "absent"


def test_every_ui_chrome_wording_is_caught_not_just_the_common_one():
    """力 shipped "Please see the movie in the radical fields above." as authored."""
    movie = parse("力")
    assert movie["mnemonic_hint_kind"] == "ui_boilerplate"
    assert movie["mnemonic_hint"] is None
    assert movie["mnemonic_hint_raw"] == "Please see the movie in the radical fields above."


def test_no_hint_is_a_placeholder_not_a_mnemonic():
    record = parse("四")
    assert record["mnemonic_hint_kind"] == "placeholder"
    assert record["mnemonic_hint"] is None
    assert record["mnemonic_hint_raw"] == "No hint."


# --- example words ------------------------------------------------------------


def test_kanjialive_example_words_are_captured_with_audio():
    record = parse("下")
    examples = record["example_words_kanjialive"]
    assert len(examples) == 11
    first = examples[0]
    assert first["surface"] == "地下鉄"
    assert first["reading"] == "ちかてつ"
    assert first["gloss"] == "subway"
    assert first["irregular"] is False
    assert first["audio_mp3"].endswith("ge-shita_06_a.mp3")


def test_irregular_marker_becomes_a_flag_not_a_stray_asterisk():
    record = parse("下")
    irregular = [entry for entry in record["example_words_kanjialive"] if entry["irregular"]]
    assert irregular, "下 carries at least one asterisk-marked irregular reading"
    for entry in irregular:
        assert not entry["surface"].startswith("*")


def test_reading_scoped_compound_words_are_captured():
    record = parse("下")
    on_examples = record["example_words_on"]
    kun_examples = record["example_words_kun"]
    assert len(on_examples) == 8
    assert len(kun_examples) == 20
    rank = next(entry for entry in on_examples if entry["surface"] == "下位")
    assert rank["reading"] == "カイ"
    assert rank["reading_type"] == "on"
    assert rank["glosses"][0] == "low rank"
    assert rank["kana_headword"] is False
    assert all(entry["reading_type"] == "kun" for entry in kun_examples)


def test_a_kana_only_headword_keeps_its_gloss_out_of_the_reading_field():
    """呉 stored English prose in `reading` and lost the gloss entirely.

    jisho ships ``{"example": "【アイゴ】", "reading": "mottled spinefoot ...",
    "meaning": ""}`` for a headword with no kanji surface.
    """
    record = parse("呉")
    entry = next(
        item for item in record["example_words_on"] if item["surface"] == "アイゴ"
    )
    assert entry["kana_headword"] is True
    assert entry["reading"] == "アイゴ"
    assert entry["gloss"] == (
        "mottled spinefoot (Siganus fuscescens), dusky rabbitfish, sandy spinefoot"
    )
    assert entry["glosses"] == [
        "mottled spinefoot (Siganus fuscescens)",
        "dusky rabbitfish",
        "sandy spinefoot",
    ]
    thailand = next(
        item for item in parse("泰")["example_words_on"] if item["kana_headword"]
    )
    assert thailand["surface"] == "タイ" and thailand["gloss"] == "Thailand"


def test_html_entities_in_a_jisho_gloss_are_resolved():
    record = parse("乃")
    entry = next(item for item in record["example_words_on"] if item["kana_headword"])
    assert "&quot;" not in entry["gloss"]
    assert 'substitutes for "ga" in subordinate phrases' in entry["glosses"]


# --- radical merge ------------------------------------------------------------


def test_a_private_use_radical_glyph_is_not_emitted_as_the_kangxi_character():
    """Kanji Alive stores 地's radical glyph as U+E723, a webfont codepoint.

    266 pages emitted an unrenderable private-use character in a field declared
    factual, which would have reached the app and drawn as tofu.
    """
    for character, symbol in (("地", "土"), ("叫", "口"), ("計", "言"), ("紀", "糸")):
        radical = parse(character)["radical"]
        assert radical["kangxi_character"] is None, character
        assert radical["kangxi_character_private_use"] is True, character
        assert radical["glyph_agreement"] == "unverified", character
        assert radical["glyph_agreement_reason"] == "kanjialive_glyph_is_private_use"
        assert radical["symbol"] == symbol, character
    assert any(
        "private-use codepoint" in note for note in parse("地")["parse_notes"]
    )


def test_a_renderable_kangxi_glyph_is_still_emitted():
    radical = parse("氵")["radical"]
    assert radical["kangxi_character"] == "⽔"
    assert radical["kangxi_character_private_use"] is False
    assert radical["glyph_agreement"] == "agree"


def test_two_upstreams_naming_different_radicals_are_flagged():
    """問 merged jisho's 口 with Kanji Alive's 門 / もんがまえ silently."""
    record = parse("問")
    radical = record["radical"]
    assert radical["symbol"] == "口"
    assert radical["kangxi_character"] == "⾨"
    assert radical["name_ja"] == "もんがまえ"
    assert radical["glyph_agreement"] == "conflict"
    assert radical["glyph_agreement_reason"] == "kanjialive_kangxi_glyph_names_another_radical"
    assert any("radical conflict" in note for note in record["parse_notes"])
    for character in ("聞", "字", "肯", "灰", "画", "巨", "冒", "事"):
        assert parse(character)["radical"]["glyph_agreement"] == "conflict", character


def test_a_variant_form_is_not_claimed_to_agree_or_to_conflict():
    """⺅ is the 人 hand form and 𠆢 the ひとやね form, but no mapping proves it.

    Neither glyph has a canonical unified equivalent, so the merge states that it
    could not reconcile the two blocks rather than asserting either answer.
    """
    for character in ("仁", "今", "単", "歯"):
        radical = parse(character)["radical"]
        assert radical["glyph_agreement"] == "unverified", character
        assert (
            radical["glyph_agreement_reason"] == "kanjialive_glyph_has_no_canonical_equivalent"
        ), character


def test_a_jisho_only_radical_claims_no_verdict():
    radical = parse("彐")["radical"]
    assert radical["kangxi_character"] is None
    assert radical["glyph_agreement"] is None
    assert radical["glyph_agreement_reason"] is None


# --- textbooks and parts ------------------------------------------------------


def test_the_kanjialive_lesson_key_is_not_a_textbook():
    """Kanji Alive files its own lesson number in txt_books under "lesson"."""
    for character, lesson in (("下", 7), ("四", 6), ("自", 19)):
        record = parse(character)
        assert record["kanjialive_lesson"] == lesson, character
        assert "lesson" not in {entry["textbook"] for entry in record["textbooks"]}
        assert record["textbooks"], character
    basic = next(
        entry for entry in parse("下")["textbooks"] if entry["textbook"] == "txtBasicKanji"
    )
    assert basic["chapter"] == "4"


def test_a_character_is_not_one_of_its_own_parts():
    """西 -> parts ["西"] landed in parts_without_direct_edge as a fake defect."""
    for character in ("西", "小", "心"):
        record = parse(character)
        assert record["parts"] == [], character
        assert record["parts_lists_self"] is True, character
        assert record["parts_without_direct_edge"] == [], character
        assert record["parts_not_in_graph"] == [], character
    origin = parse("元")
    assert origin["parts"] == ["二", "儿"]
    assert origin["parts_lists_self"] is True
    assert parse("下")["parts_lists_self"] is False


def test_references_is_null_rather_than_a_dict_of_nulls():
    """A fill rate on this field must count data, not the container."""
    assert parse("下")["references"] == {"kodansha": "2115", "classic_nelson": "9"}
    assert parse("氵")["references"] is None


# --- stroke order assets ------------------------------------------------------


def test_stroke_order_assets_are_captured():
    record = parse("下")
    stroke_order = record["stroke_order"]
    assert stroke_order["svg_uri"].endswith("04e0b.svg")
    assert stroke_order["diagram_uri"].endswith("19979_frames.png")
    assert stroke_order["gif_uri"].endswith("4e0b.gif")
    assert len(stroke_order["per_stroke_images"]) == 3
    assert stroke_order["timings"] == [1.038, 1.799, 2.866, 4]
    assert stroke_order["video_mp4"].endswith("ge-shita_00.mp4")
    # props.strokeAnimation is null on every mirrored page, so the vector path
    # data must come from another source. Recorded, not silently missing.
    assert stroke_order["stroke_animation_available"] is False


# --- provenance and licensing -------------------------------------------------


def test_authored_prose_is_reference_only_and_facts_ship():
    record = parse("内")
    provenance = record["_provenance"]
    assert provenance["mnemonic_hint"]["ship"] == "reference-only"
    assert provenance["mnemonic_hint"]["license_class"] == "authored-third-party"
    assert provenance["example_words_kanjialive"]["ship"] == "reference-only"
    assert provenance["stroke_count"]["ship"] == "allowed"
    assert provenance["on_readings"]["ship"] == "allowed"
    assert provenance["parts"]["ship"] == "allowed"
    assert provenance["character"]["source"] == "the_kanji_map"


def test_every_emitted_field_declares_provenance():
    record = parse("下")
    declared = set(record["_provenance"])
    emitted = {key for key in record if key != "_provenance"}
    assert emitted - declared == set(), f"undeclared fields: {sorted(emitted - declared)}"


# --- failure signalling -------------------------------------------------------


def test_parse_raises_on_a_payload_free_page():
    tree = parse_document("<html><body><h1>The Kanji Map</h1></body></html>")
    url = "https://thekanjimap.com/%E4%B8%8B"
    assert tkm.is_shell(tree, url) is True
    try:
        tkm.parse(tree, url, "kanji")
    except tkm.UnexpectedMarkup:
        pass
    else:  # pragma: no cover
        raise AssertionError("a payload-free page must raise, not return a dict of nulls")


def test_parse_raises_when_the_payload_disagrees_with_the_url():
    tree, _url = load("下")
    try:
        tkm.parse(tree, "https://thekanjimap.com/%E5%B0%8F", "kanji")
    except tkm.UnexpectedMarkup:
        pass
    else:  # pragma: no cover
        raise AssertionError("character/url mismatch must raise")


def test_real_snapshots_are_not_shells():
    for character in ("下", "小", "心", "西", "氵", "彐", "刂", "コ"):
        tree, url = load(character)
        assert tkm.is_shell(tree, url) is False


if __name__ == "__main__":
    failures = 0
    for name, function in sorted(globals().items()):
        if not name.startswith("test_") or not callable(function):
            continue
        try:
            function()
        except Exception as exc:  # noqa: BLE001
            failures += 1
            print(f"FAIL {name}: {type(exc).__name__}: {exc}")
        else:
            print(f"ok   {name}")
    print("failures:", failures)
    sys.exit(1 if failures else 0)
