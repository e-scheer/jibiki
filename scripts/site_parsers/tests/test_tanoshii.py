"""Tests for the tanoshii_japanese parser, run against real mirrored files.

Every assertion here is anchored on a snapshot that actually sits in
``var/site_mirror/tanoshii_japanese/mirror``, because the defects this parser
replaces were all invisible to invented html: the plural
``Dictionary Entries for`` heading, the second reading line after a ``<br/>``,
the decorative middot ruby, the leading ``0em`` sprite frame. Run with
``python -m pytest scripts/site_parsers/tests/test_tanoshii.py`` or directly.
"""

from __future__ import annotations

import json
import random
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = REPO_ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from site_parsers import common  # noqa: E402
from site_parsers import tanoshii  # noqa: E402

MIRROR = REPO_ROOT / "var/site_mirror/tanoshii_japanese/mirror/www.tanoshiijapanese.com/dictionary"
FETCH_LOG = REPO_ROOT / "var/site_mirror/tanoshii_japanese/fetch_log.jsonl"
BASE = "https://www.tanoshiijapanese.com/dictionary/"


def load(filename: str, url: str):
    path = MIRROR / filename
    assert path.exists(), f"missing mirrored snapshot {path}"
    tree = common.parse_document(path.read_text(encoding="utf-8", errors="replace"))
    page_type = tanoshii.infer_page_type(url)
    assert not tanoshii.is_shell(tree, url), url
    return tanoshii.parse(tree, url, page_type), page_type


# --- routing ------------------------------------------------------------------


def test_routing_covers_every_content_route():
    cases = {
        "kanji_details.cfm?character_id=26716": "kanji",
        "kanji_stroke_order_details.cfm?character_id=27005": "kanji_strokes",
        "kanji.cfm?k=%E6%A1%9C": "kanji_card_list",
        "entry_details.cfm?entry_id=57284": "word",
        "stroke_order_details.cfm?entry_id=19621": "word_strokes",
        "conjugation_details.cfm?entry_id=19621": "word_conjugation",
        "sentence_details.cfm?sentence_id=180404": "sentence",
        "browse.cfm?p=2": "word_card_list",
        "index.cfm?word_definition_id=1": "word_card_list",
        "sentences.cfm?j=%E3%81%A7": "sentence_card_list",
        "kanji_browse.cfm": "kanji_browse",
        "multi_search.cfm": "search_form",
        "entry_comments.cfm?entry_id=1": "comments",
    }
    for suffix, expected in cases.items():
        assert tanoshii.infer_page_type(BASE + suffix) == expected, suffix
    # kanji.cfm carries full cards, so it must not be routed out of extraction.
    assert "kanji_card_list" in tanoshii.EXTRACTABLE
    assert "sentence_card_list" in tanoshii.EXTRACTABLE
    assert "word_card_list" in tanoshii.EXTRACTABLE
    assert tanoshii.infer_page_type("https://www.tanoshiijapanese.com/home/register.cfm") == "other"


def test_dedupe_key_keeps_materially_different_variants_apart():
    # element_id and conjugation_type_id change the rendered headword, so they
    # are part of the identity: 512 different pages used to share word:56851.
    plain = BASE + "conjugation_details.cfm?entry_id=30193"
    inflected = BASE + "conjugation_details.cfm?entry_id=30193&element_id=41310&conjugation_type_id=28"
    other = BASE + "conjugation_details.cfm?entry_id=30193&element_id=41310&conjugation_type_id=50"
    keys = [tanoshii.dedupe_key(url, "word_conjugation") for url in (plain, inflected, other)]
    assert len(set(keys)) == 3, keys
    assert keys[0] == "word_conjugation:30193"
    assert keys[1] == "word_conjugation:30193:element=41310:conjugation=28"
    written_variant = BASE + "stroke_order_details.cfm?entry_id=52516&element_id=67064"
    assert tanoshii.dedupe_key(written_variant, "word_strokes") == "word_strokes:52516:element=67064"

    # A parameter whose name carries the escaped separator never reached the
    # server, which is why that url renders the entry's default view. It must
    # therefore collapse onto the plain entry rather than claim a selection.
    escaped = BASE + "entry_details.cfm?entry_id=57284&amp%3Belement_id=74973&amp%3Bconjugation_type_id=1"
    assert tanoshii.dedupe_key(escaped, "word") == "word:57284"
    assert tanoshii.dedupe_key(BASE + "entry_details.cfm?entry_id=57284", "word") == "word:57284"

    # List routes keep their query, because the query is what selects the list.
    assert tanoshii.dedupe_key(BASE + "browse.cfm?p=2", "word_card_list") != tanoshii.dedupe_key(
        BASE + "browse.cfm?p=3", "word_card_list"
    )


def test_is_shell_flags_the_fragment_route():
    path = MIRROR / "word_type_select.cfm"
    assert path.exists(), f"missing mirrored snapshot {path}"
    tree = common.parse_document(path.read_text(encoding="utf-8", errors="replace"))
    assert tanoshii.is_shell(tree, BASE + "word_type_select.cfm") is True


def test_is_shell_flags_the_sites_own_soft_error_page():
    # A status 200 page with a title and a non-empty content body that says the
    # id could not be resolved. It is refetchable, not parser breakage, and it
    # used to raise TanoshiiParseError.
    path = MIRROR / "kanji_details__q_3ebf17163e.cfm"
    assert path.exists(), f"missing mirrored snapshot {path}"
    url = BASE + "kanji_details.cfm?character_id=131490&k=%F0%A0%86%A2"
    tree = common.parse_document(path.read_text(encoding="utf-8", errors="replace"))
    assert tanoshii.infer_page_type(url) == "kanji"
    assert tree.xpath("//div[@id='cncontentbody']")
    assert common.plain_text(tree.xpath("//div[@id='cncontentbody']")[0])
    assert tanoshii.is_shell(tree, url) is True


# --- kanji pages --------------------------------------------------------------


def test_kanji_details_sakura_has_every_field_the_page_shows():
    record, page_type = load(
        "kanji_details__q_3c22b89150.cfm",
        BASE + "kanji_details.cfm?character_id=26716&k=%E6%A1%9C",
    )
    assert page_type == "kanji"
    assert record["record_type"] == "kanji"
    assert record["character"] == "桜"
    assert record["character_id"] == 26716
    assert record["stroke_count"] == 10
    assert record["jlpt_level"] == "N1"
    assert record["grade"] == 5
    assert record["is_jouyou"] is True

    # radical_summary used to be null on 100 percent of kanji records because the
    # regex looked for <b>Radical:</b>, which this site never emits.
    assert record["radical"] == "木"
    assert record["radical_residual_strokes"] == 6
    assert record["radical_summary"] == "木 + 6 Strokes"

    # stroke_order_count used to be 0 on 100 percent of kanji records.
    assert record["stroke_order_count"] == 10
    assert record["stroke_order_groups"][0]["sprite_url"].endswith("/j/26716.png")
    assert len(record["stroke_order_groups"][0]["stroke_offsets_em"]) == 10

    # english meanings are split, paren-aware.
    assert record["english_meanings"] == ["cherry"]

    # No injected space before the ideographic full stop, and no ''' wiki markup.
    assert record["japanese_meanings"][0]["text"] == "さくら。"
    assert record["origin"]["text"] == "形声。元字櫻は、木+音符「嬰」。"
    assert "'''" not in record["origin"]["text"]
    assert record["origin_formation_type"] == "形声文字"
    assert record["origin_terms"] == ["形声", "櫻", "嬰"]
    # The minidictionary term boundaries survive as role spans.
    assert [span["text"] for span in record["origin"]["spans"]] == ["形声", "櫻", "嬰"]

    assert record["construction"][0] == {
        "symbol": "木",
        "character_id": 26408,
        "role": "Radical",
        "meaning": "tree, wood",
    }
    assert {variant["symbol"] for variant in record["variants"]} == {"櫻", "樱"}

    # The jouyou flag and the labelled related-kanji groups used to be dropped.
    labels = {group["label"] for group in record["related_groups"]}
    assert "Kanji for plants and trees" in labels
    group = next(g for g in record["related_groups"] if g["kind"] == "group_id")
    assert group["characters"] and all(len(ch) == 1 for ch in group["characters"])

    # Language-scoped glosses keep their language.
    languages = {block["language"]: block["glosses"] for block in record["other_language_meanings"]}
    assert languages["French"] == ["cerisier du Japon"]
    assert languages["Spanish"] == ["cerezo", "flor de cerezo"]

    assert record["content_licence"]["licence_url"].endswith("edrdg/licence.html")


def test_kanji_readings_keep_every_line_and_split_off_the_classification():
    record, _ = load(
        "kanji_stroke_order_details__q_ae48c16518.cfm",
        BASE + "kanji_stroke_order_details.cfm?character_id=27005&k=%E6%A5%BD",
    )
    assert record["character"] == "楽"
    # The old parser stopped at the first <br/> and returned
    # kun == ["たの.しい", "たの.しむ。 ( Jouyou Reading )"].
    kun = [entry["reading"] for entry in record["kun_readings"]]
    assert kun == ["たの.しい", "たの.しむ", "かな.でる", "この.む"]
    on = [entry["reading"] for entry in record["on_readings"]]
    assert on == ["ガク", "ラク", "ゴウ"]
    # The note is a classification, not a reading, and its ASCII comma must not
    # tear it into two bogus entries.
    assert record["on_readings"][0]["classification"] == "Go-on, Kan-on Readings"
    assert record["on_readings"][0]["classification_key"] == "onyomi_classifications"
    assert record["on_readings"][2]["classification"] is None
    assert record["kun_readings"][0]["classification"] == "Jouyou Reading"
    for entry in record["kun_readings"] + record["on_readings"]:
        assert "(" not in entry["reading"]
        assert not any("a" <= ch.lower() <= "z" for ch in entry["reading"])
    # KANJIDIC okurigana dots are normalised rather than left fused.
    assert record["kun_readings"][0]["stem"] == "たの"
    assert record["kun_readings"][0]["okurigana"] == "しい"
    assert record["kun_readings"][0]["kana"] == "たのしい"

    # Both kanji page types report the same stroke count for the same character,
    # and both carry character_id, so the orchestrator can join them.
    assert record["character_id"] == 27005
    assert record["stroke_count"] == 13
    assert record["stroke_order_count"] == 13


def test_non_kana_reading_tokens_are_quarantined_not_shipped_as_readings():
    # The source itself serves garbage inside the reading spans of these kanji.
    # It must not reach on_readings / kun_readings, which ship as factual.
    record, _ = load(
        "kanji_details__q_70afa90464.cfm", BASE + "kanji_details.cfm?character_id=34892&k=%E8%A1%8C"
    )
    assert record["character"] == "行"
    assert record["jlpt_level"] == "N5"
    on = [entry["reading"] for entry in record["on_readings"]]
    assert on == ["ゴウ", "コウ", "アン", "ヒン", "ギョウ"]
    assert "C" not in on and "A" not in on
    kun = [entry["reading"] for entry in record["kun_readings"]]
    assert "C" not in kun
    assert all(common.is_kana(entry["kana"]) for entry in record["on_readings"] + record["kun_readings"])
    rejected = {(item["field"], item["raw"]) for item in record["rejected_readings"]}
    assert ("on_readings", "C") in rejected
    assert ("on_readings", "A") in rejected
    assert ("kun_readings", "C") in rejected
    assert all(item["reason"] == "not_kana" for item in record["rejected_readings"])

    # Pitch-accent arrows are an annotation, so they leave the kana and keep
    # their own field instead of corrupting the reading.
    pitched, _ = load(
        "kanji_details__q_f2e877d08c.cfm", BASE + "kanji_details.cfm?character_id=22320&k=%E5%9C%B0"
    )
    assert pitched["character"] == "地"
    assert [entry["reading"] for entry in pitched["on_readings"]] == ["ジ", "チ", "ジ", "チ"]
    assert pitched["on_readings"][0]["raw"] == "ジ↗"
    assert pitched["on_readings"][0]["pitch_accent"] == "ジ↗"
    assert pitched["kun_readings"][0]["kana"] == "つち"
    assert pitched["kun_readings"][0]["pitch_accent"] == "つ↗ち↘"

    # KANJIDIC optional okurigana keeps its parentheses out of the kana.
    optional, _ = load(
        "kanji_details__q_a2e0e123c8.cfm", BASE + "kanji_details.cfm?character_id=20195&k=%E4%BB%A3"
    )
    entry = next(item for item in optional["kun_readings"] if item["raw"] == "か.(わ)る")
    assert entry["kana"] == "かわる"
    assert entry["reading"] == "か.わる"
    assert entry["optional_okurigana"] == "わ"


def test_kanji_details_with_plural_heading_still_yields_example_words():
    # 164 of 312 kanji records lost their whole example-word list because the
    # heading regex only matched the singular "Dictionary Entry for".
    record, _ = load(
        "kanji_details__q_27f976d1ce.cfm",
        BASE + "kanji_details.cfm?character_id=22899&k=%E5%A5%B3",
    )
    assert record["character"] == "女"
    assert len(record["example_words"]) == 3
    entry_ids = [word["entry_id"] for word in record["example_words"]]
    assert entry_ids == [33071, 33072, 166511]
    readings = {element["reading"] for element in record["example_words"][0]["elements"]}
    assert {"おんな", "おみな", "おうな"} <= readings
    # Japanese prose must not gain word-internal spaces.
    texts = [block["text"] for block in record["japanese_meanings"]]
    assert "おんな、をとめ（＞おとめ）、ヒトの雌" in texts


def test_kanji_card_list_emits_one_record_per_card():
    records, page_type = load(
        "kanji__q_015e12451b.cfm", BASE + "kanji.cfm?group_id=105"
    )
    assert page_type == "kanji_card_list"
    assert isinstance(records, list)
    assert len(records) == 20
    characters = [record["character"] for record in records]
    assert len(set(characters)) == 20
    card = next(record for record in records if record["character"] == "案")
    assert card["character_id"] == 26696
    assert card["stroke_count"] == 10
    assert card["jlpt_level"] == "N1"
    assert card["is_jouyou"] is True
    assert card["grade"] == 4
    assert card["english_meanings"][:2] == ["plan", "suggestion"]
    assert [entry["reading"] for entry in card["kun_readings"]] == ["つくえ"]
    assert [entry["reading"] for entry in card["on_readings"]] == ["アン"]
    # The links used to collapse into one label-only string with no hrefs.
    hrefs = [link["href"] for link in card["entry_links"]]
    assert any("kanji_details.cfm?character_id=26696" in href for href in hrefs)
    assert card["list_kind"] == "group_id"
    assert card["list_rank"] == characters.index("案") + 1

    single, _ = load("kanji__q_17abb4ab97.cfm", BASE + "kanji.cfm?k=%E6%A1%9C")
    assert len(single) == 1
    assert single[0]["character_id"] == 26716


# --- word pages ---------------------------------------------------------------


def test_word_page_exposes_headword_alternates_and_per_sense_pos():
    record, page_type = load(
        "entry_details__q_9e27d3ab40.cfm", BASE + "entry_details.cfm?entry_id=57284"
    )
    assert page_type == "word"
    assert record["entry_id"] == 57284
    # There used to be no clean headword surface or reading anywhere.
    assert record["surface"] == "桜"
    assert record["reading"] == "さくら"
    assert record["romaji"] == "sakura"
    assert record["headword_part_of_speech"] == "noun"

    # forms was built from div.furigana only, so the katakana alternate was
    # dropped, the [ ] chrome kept and the annotation lost.
    surfaces = [element["surface"] for element in record["elements"]]
    assert surfaces == ["桜", "櫻", "サクラ"]
    assert all("[" not in (surface or "") for surface in surfaces)
    outdated = next(element for element in record["elements"] if element["surface"] == "櫻")
    assert outdated["annotation"] == "Outdated Kanji"
    assert outdated["is_alternate"] is True
    assert outdated["element_id"] == 74972
    katakana = next(element for element in record["elements"] if element["surface"] == "サクラ")
    assert katakana["reading"] == "サクラ"

    # A nested span.partofspeech is a sense note, not a part of speech.
    sense = record["senses"][0]
    assert sense["part_of_speech"] == "noun"
    shill = next(g for g in sense["glosses"] if g["gloss"].startswith("fake buyer"))
    assert shill["notes"] == ["also as 偽客"]
    assert "(also as" not in shill["gloss"]
    assert record["sense_parts_of_speech"] == ["noun"]

    # kanji_meanings is typed, and keeps the character_id that was in the href.
    assert record["kanji_meanings"] == [
        {"character": "桜", "character_id": 26716, "meaning": "cherry"}
    ]

    # hyponyms used to be six unrelated cell arrays with the category id lost.
    assert len(record["hyponyms"]) == 2
    assert record["hyponyms"][0]["en"] == "Spectral Colour"
    assert record["hyponyms"][0]["jp"] == "有彩色"
    assert record["hyponyms"][0]["category_id"] == 31996
    synonyms = record["synonym_senses"][0]["synonyms"]
    assert {"surface": "ロゼ", "entry_id": 13738} in synonyms
    assert all(entry["surface"] and "," not in entry["surface"] for entry in synonyms)

    assert len(record["sample_sentences"]) == 5
    assert record["sample_sentences"][0]["sentence_id"] == 91504
    # Marked-up prose is a RichText payload on this route too, not a bare string.
    assert record["sample_sentences"][0]["japanese"]["text"] == "桜の花は今が満開である。"

    # No "Hide" toggle label anywhere in a romaji field.
    assert record["romaji"] != "Hide"
    assert all(element["romaji"] != "Hide" for element in record["elements"])

    assert record["stroke_order_total"] == 10
    assert record["character_ids"] == [26716]


def test_kana_only_word_page_still_has_a_surface():
    # 821 records had no Japanese headword at all, because kana-only headwords
    # emit no div.furigana.
    record, _ = load("entry_details__q_4ef8f42833.cfm", BASE + "entry_details.cfm?entry_id=1228")
    assert record["surface"]
    assert record["reading"] == record["surface"]
    assert record["elements"]


def test_word_strokes_page_groups_strokes_per_character():
    record, page_type = load(
        "stroke_order_details__q_7c0fab73d0.cfm", BASE + "stroke_order_details.cfm?entry_id=19621"
    )
    assert page_type == "word_strokes"
    assert record["surface"] == "楽しい"
    assert record["reading"] == "たのしい"
    groups = record["stroke_order_groups"]
    # One integer for the page over-counted by one per group: 19 instead of 16.
    assert [group["character"] for group in groups] == ["楽", "し", "い"]
    assert [group["stroke_count"] for group in groups] == [13, 1, 2]
    assert [group["frame_count"] for group in groups] == [14, 2, 3]
    assert record["stroke_order_total"] == 16
    assert [group["element_kind"] for group in groups] == ["kanji", "hiragana", "hiragana"]
    assert record["character_ids"] == [27005]
    assert record["kana_stroke_characters"] == ["し", "い"]
    assert groups[1]["sprite_url"].endswith("/h/12375.png")


def test_conjugation_page_keeps_groups_and_drops_middot_separators():
    record, page_type = load(
        "conjugation_details__q_7c0fab73d0.cfm", BASE + "conjugation_details.cfm?entry_id=19621"
    )
    assert page_type == "word_conjugation"
    assert record["surface"] == "楽しい"
    conjugations = record["conjugations"]
    assert len(conjugations) == 14
    te_form = next(row for row in conjugations if row["label"] == "te-form")
    # Was "楽(たの)·し·く·て".
    assert te_form["surface"] == "楽しくて"
    assert te_form["reading"] == "たのしくて"
    assert te_form["romaji"] == "tanoshikute"
    assert te_form["conjugation_type_id"] == 9
    assert te_form["part_of_speech"] == "adj-i"
    assert all("·" not in row["surface"] for row in conjugations)
    assert {row["group"] for row in conjugations} >= {"Plain Form", "Conditional Form"}
    past = next(row for row in conjugations if row["group"] == "Plain Form" and "Past Indicative Form" == row["label"])
    assert past["surface"] == "楽しかった"

    # Every row is identified, including the ones whose id only exists in their
    # own detail href: this row carries no conjugation_type_id attribute.
    assert all(row["conjugation_type_id"] for row in conjugations), [
        row["label"] for row in conjugations if not row["conjugation_type_id"]
    ]
    present = next(row for row in conjugations if row["label"] == "Present Indicative Form")
    assert present["conjugation_type_id"] == 1
    assert "conjugation_type_id=1" in present["detail_href"]
    assert all(row["element_id"] for row in conjugations)


def test_multi_sense_word_pairs_each_pos_with_its_own_senses():
    record, _ = load(
        "conjugation_details__q_64e6da4a01.cfm", BASE + "conjugation_details.cfm?entry_id=30725"
    )
    senses = record["senses"]
    assert [sense["sense_no_start"] for sense in senses] == [1, 2, 3, 4]
    assert [sense["sense_no_end"] for sense in senses] == [1, 2, 3, 4]
    assert [sense["part_of_speech"] for sense in senses] == [
        "noun, no adjective",
        "noun",
        "adverb",
        "noun",
    ]
    assert senses[3]["glosses"][0]["gloss"] == "bhutakoti (limit of reality)"


def test_conjugated_view_says_that_its_headword_is_not_the_lemma():
    # Entry 30193 is 持つ. Three of its mirrored pages render three different
    # headwords, and the record has to say which one it is showing, otherwise a
    # consumer joining on entry_id reads 持たなければ as the dictionary form.
    inflected, _ = load(
        "conjugation_details__q_53e13ed7cc.cfm",
        BASE + "conjugation_details.cfm?entry_id=30193&element_id=41310&conjugation_type_id=28",
    )
    assert inflected["entry_id"] == 30193
    assert inflected["surface"] == "持たなければ"
    assert inflected["headword_is_inflected"] is True
    assert inflected["headword_is_entry_default_view"] is False
    assert inflected["headword_conjugation_type_id"] == 28
    assert inflected["headword_conjugation_label"] == "Provisional Present Indicative Negative Form"
    assert inflected["requested_element_id"] == 41310
    assert inflected["requested_conjugation_type_id"] == 28
    assert inflected["matched_conjugations"][0]["surface"] == "持たなければ"

    plain, _ = load(
        "conjugation_details__q_b0224874d8.cfm", BASE + "conjugation_details.cfm?entry_id=30193"
    )
    assert plain["surface"] == "持つ"
    assert plain["headword_is_inflected"] is False
    assert plain["headword_is_entry_default_view"] is True
    assert plain["headword_conjugation_type_id"] is None
    assert plain["matched_conjugations"] == []


def test_written_form_selection_is_recorded_on_the_record():
    # Entry 52516 renders 余 by default and 餘 when an element is selected, and
    # the stroke total follows the rendered form (7 against 16).
    default, _ = load(
        "stroke_order_details__q_d540feaf86.cfm", BASE + "stroke_order_details.cfm?entry_id=52516"
    )
    assert default["surface"] == "余"
    assert default["headword_element_id"] == 67065
    assert default["requested_element_id"] is None
    assert default["headword_is_entry_default_view"] is True
    assert default["stroke_order_total"] == 7

    variant, _ = load(
        "stroke_order_details__q_1e0fbd4c2e.cfm",
        BASE + "stroke_order_details.cfm?entry_id=52516&element_id=67064",
    )
    assert variant["surface"] == "餘"
    assert variant["headword_element_id"] == 67064
    assert variant["requested_element_id"] == 67064
    assert variant["headword_is_entry_default_view"] is False
    assert variant["stroke_order_total"] == 16


def test_escaped_selection_parameters_are_not_reported_as_a_selection():
    # The server never received a parameter called element_id on these urls, so
    # the page it returned is the entry's default view.
    record, _ = load(
        "entry_details__q_f5241e4ec2.cfm",
        BASE + "entry_details.cfm?entry_id=57284&amp%3Belement_id=74973&amp%3Bconjugation_type_id=1",
    )
    assert record["surface"] == "桜"
    assert record["requested_element_id"] is None
    assert record["requested_conjugation_type_id"] is None
    assert record["headword_is_entry_default_view"] is True


def test_entry_links_never_carry_the_add_to_widget():
    # href="#" is the add-to-list popup. It used to survive on card records and
    # be filtered on detail records, so one field carried two kinds of thing.
    records, _ = load("browse__q_008fcca734.cfm", BASE + "browse.cfm?p=1")
    links = [link for record in records for link in record["entry_links"]]
    assert links
    assert all(link["href"] != "#" for link in links)
    assert all(not (link["href"] or "").lower().startswith("javascript:") for link in links)
    assert any("entry_details.cfm" in link["href"] for link in links)

    sentence, _ = load(
        "sentence_details__q_3a51aa3829.cfm",
        BASE + "sentence_details.cfm?sentence_id=180404&entry_id=19621&j=%E6%A5%BD%E3%81%97%E3%81%84",
    )
    nested = [link for word in sentence["sentence_words"] for link in word["entry_links"]]
    assert nested
    assert all(link["href"] != "#" for link in nested)


def test_word_card_list_emits_one_record_per_card():
    records, page_type = load("browse__q_008fcca734.cfm", BASE + "browse.cfm?p=1")
    assert page_type == "word_card_list"
    assert isinstance(records, list)
    assert len(records) == 20
    first = records[0]
    assert first["entry_id"]
    assert first["surface"]
    assert first["reading"]
    assert first["senses"]
    assert first["list_rank"] == 1
    assert first["page_number"] == 1
    assert all(record["record_type"] == "word" for record in records)
    assert all("Hide" not in (record["romaji"] or "") for record in records)


# --- sentence pages -----------------------------------------------------------


def test_sentence_page_has_japanese_english_and_a_word_breakdown():
    record, page_type = load(
        "sentence_details__q_3a51aa3829.cfm",
        BASE + "sentence_details.cfm?sentence_id=180404&entry_id=19621&j=%E6%A5%BD%E3%81%97%E3%81%84",
    )
    assert page_type == "sentence"
    assert record["sentence_id"] == 180404
    # Was "実(じっ)際(さい)のところ·私(わたし)·が·..." with the readings inlined.
    assert record["sentence_japanese"]["text"] == "実際のところ私が思っていたよりもずっと楽しかった。"
    assert "·" not in record["sentence_japanese"]["text"]
    assert "(" not in record["sentence_japanese"]["text"]
    # The English translation was null on 100 percent of sentence records.
    assert record["sentence_english"] == "It was actually a lot more fun than I expected."
    # Furigana is kept, beside the text rather than inside it.
    assert {"base": "実", "reading": "じっ"} in record["sentence_furigana"]
    # Tatoeba credit was absent from the whole record.
    assert record["source_attribution"]["name"] == "Tatoeba Project"
    assert record["source_attribution"]["href"].startswith("https://tatoeba.org")

    words = record["sentence_words"]
    # The breakdown iterated div.entrylinks, so every word lost pos, meanings,
    # entry_id and links.
    assert len(words) == 13
    assert all(word["entry_id"] for word in words)
    assert all(word["senses"] for word in words)
    first = words[0]
    assert first["entry_id"] == 178556
    assert first["surface"] == "実際のところ"
    assert first["reading"] == "じっさいのところ"
    assert first["romaji"] == "jissainotokoro"
    assert first["senses"][0]["part_of_speech"] == "expression, adverb"
    assert first["senses"][0]["glosses"][0]["gloss"] == "actually; in fact; as a matter of fact"
    assert any("entry_details.cfm?entry_id=178556" in (link["href"] or "") for link in first["entry_links"])
    assert 19621 in record["word_entry_ids"]


def test_every_gloss_carries_the_sites_own_sense_number():
    # Entry 32894 (ところ) numbers its glosses 1 to 11 in three part-of-speech
    # groups whose <ol start> values are 1, 2 and 9, so a group number alone
    # leaves senses 3 to 8 without one.
    record, _ = load(
        "sentence_details__q_3a51aa3829.cfm", BASE + "sentence_details.cfm?sentence_id=180404"
    )
    word = next(item for item in record["sentence_words"] if item["entry_id"] == 32894)
    assert [(sense["sense_no_start"], sense["sense_no_end"]) for sense in word["senses"]] == [
        (1, 1),
        (2, 8),
        (9, 11),
    ]
    numbers = [gloss["sense_no"] for sense in word["senses"] for gloss in sense["glosses"]]
    assert numbers == list(range(1, 12))


def test_sentence_card_keeps_its_term_role_spans():
    # sentence_card_list used to emit {"text": ...} with no spans, dropping the
    # span.relword boundaries that the sentence detail route preserves.
    records, _ = load(
        "sentences__q_ead5c49fc2.cfm",
        BASE + "sentences.cfm?j=%22%E6%A5%BD%E3%81%97%E3%81%8F%E3%81%A6%22&element_id=28795&conjugation_type_id=9",
    )
    card = records[0]
    assert card["sentence_id"] == 1920
    payload = card["sentence_japanese"]
    assert payload["text"] == "自分のやってることが楽しくてまわり見えてないんですよね。"
    assert payload["spans"], "the relword markup of this card must survive"
    assert {"text": "楽しくて", "role": "vocabulary", "start": 10, "end": 14} in payload["spans"]
    for span in payload["spans"]:
        assert payload["text"][span["start"] : span["end"]] == span["text"]


def test_sentence_card_list_emits_one_record_per_pair():
    records, page_type = load(
        "sentences__q_00576b6de7.cfm", BASE + "sentences.cfm?j=%E3%81%A7&element_id=122215"
    )
    assert page_type == "sentence_card_list"
    assert isinstance(records, list)
    assert records
    for record in records:
        assert record["record_type"] == "sentence"
        assert record["sentence_id"]
        assert record["sentence_japanese"]["text"]
        assert record["sentence_english"]


# --- provenance and licensing -------------------------------------------------


def test_provenance_marks_authored_prose_reference_only():
    record, _ = load(
        "entry_details__q_9e27d3ab40.cfm", BASE + "entry_details.cfm?entry_id=57284"
    )
    provenance = record["_provenance"]
    assert provenance["sample_sentences"]["ship"] == "reference-only"
    assert provenance["sample_sentences"]["license_class"] == "authored-third-party"
    assert provenance["hyponyms"]["ship"] == "reference-only"
    assert provenance["surface"]["ship"] == "allowed"
    assert provenance["entry_id"]["ship"] == "allowed"
    assert provenance["surface"]["source"] == "tanoshii_japanese"
    assert provenance["surface"]["source_url"].endswith("entry_id=57284")
    assert set(provenance) == {name for name in record if name != "_provenance"}

    kanji, _ = load(
        "kanji_details__q_3c22b89150.cfm",
        BASE + "kanji_details.cfm?character_id=26716&k=%E6%A1%9C",
    )
    assert kanji["_provenance"]["origin"]["ship"] == "reference-only"
    assert kanji["_provenance"]["japanese_meanings"]["ship"] == "reference-only"
    assert kanji["_provenance"]["stroke_count"]["ship"] == "allowed"
    assert kanji["_provenance"]["kun_readings"]["ship"] == "allowed"

    sentence, _ = load(
        "sentence_details__q_3a51aa3829.cfm", BASE + "sentence_details.cfm?sentence_id=180404"
    )
    assert sentence["_provenance"]["sentence_japanese"]["ship"] == "reference-only"
    assert sentence["_provenance"]["sentence_english"]["ship"] == "reference-only"


def test_unsupported_page_type_raises_instead_of_returning_empty():
    path = MIRROR / "kanji_browse.cfm"
    tree = common.parse_document(path.read_text(encoding="utf-8", errors="replace"))
    try:
        tanoshii.parse(tree, BASE + "kanji_browse.cfm", "kanji_browse")
    except tanoshii.TanoshiiParseError:
        pass
    else:  # pragma: no cover - the point of the test
        raise AssertionError("parse must raise for a non extractable page type")


# --- broad smoke test over the real mirror ------------------------------------


def _fetch_log_pages():
    """Real crawled urls with the file each one produced.

    Reading the fetch log rather than globbing the mirror matters: the mirror
    filename is a hash, so a test built from filenames routes every page through
    a query-less url and never exercises the ``character_id`` fallbacks, the
    selection parameters or the ``list_kind`` / ``list_key`` path.
    """
    rows: list[tuple[str, Path]] = []
    if not FETCH_LOG.exists():  # pragma: no cover - depends on the local mirror
        return rows
    with FETCH_LOG.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            entry = json.loads(line)
            if entry.get("status") != 200 or "html" not in (entry.get("content_type") or ""):
                continue
            rows.append((entry["url"], Path(entry["saved_path"])))
    return rows


def test_random_mirror_sample_parses_without_raising():
    """Real crawled urls of every extractable route must all parse.

    The previous generation hid breakage behind ``except Exception: return {}``,
    so a route could be broken across thousands of pages without anyone
    noticing.
    """
    pages = _fetch_log_pages()
    assert pages, f"missing fetch log {FETCH_LOG}"
    by_type: dict[str, list[tuple[str, Path]]] = {}
    for url, path in pages:
        page_type = tanoshii.infer_page_type(url)
        if page_type in tanoshii.EXTRACTABLE:
            by_type.setdefault(page_type, []).append((url, path))
    assert set(by_type) == set(tanoshii.EXTRACTABLE), sorted(set(tanoshii.EXTRACTABLE) - set(by_type))

    rng = random.Random(4242)
    checked = shells = 0
    for page_type, rows in sorted(by_type.items()):
        for url, path in rng.sample(rows, min(40, len(rows))):
            tree = common.parse_document(path.read_text(encoding="utf-8", errors="replace"))
            if tanoshii.is_shell(tree, url):
                shells += 1
                continue
            out = tanoshii.parse(tree, url, page_type)
            records = out if isinstance(out, list) else [out]
            for record in records:
                assert record["record_type"] in {"kanji", "word", "sentence"}
                assert set(record["_provenance"]) == {
                    name for name in record if not name.startswith("_")
                }
                for name, stamp in record["_provenance"].items():
                    assert stamp["source"] == "tanoshii_japanese"
                    if name in tanoshii.MODULE_CONSTANT_FIELDS:
                        assert stamp["method"] == "module_constant"
                    elif name in tanoshii.URL_DERIVED_FIELDS:
                        assert stamp["method"] == "url_route"
                for links in [record.get("entry_links") or []]:
                    assert all(link["href"] != "#" for link in links)
            checked += 1
    assert checked >= 300, checked


if __name__ == "__main__":
    failures = 0
    for name, function in sorted(globals().items()):
        if not name.startswith("test_") or not callable(function):
            continue
        try:
            function()
        except Exception as exc:  # noqa: BLE001 - standalone runner
            failures += 1
            print(f"FAIL {name}: {exc!r}")
        else:
            print(f"ok   {name}")
    raise SystemExit(1 if failures else 0)
