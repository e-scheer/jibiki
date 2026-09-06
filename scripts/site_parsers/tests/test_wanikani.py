"""Tests for the WaniKani parser, run against real mirrored files.

Every assertion here is anchored on a page in ``var/site_mirror/wanikani``, and
most of them encode a specific defect of the previous parser generation so it
cannot come back. Run with ``python -m pytest`` from ``scripts/``, or directly
with ``python site_parsers/tests/test_wanikani.py``.
"""

from __future__ import annotations

import os
import random
import sys
import urllib.parse
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = REPO_ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from site_parsers import wanikani  # noqa: E402
from site_parsers.common import parse_document  # noqa: E402

MIRROR = REPO_ROOT / "var" / "site_mirror" / "wanikani" / "mirror" / "www.wanikani.com"


def mirror_path(kind: str, slug: str) -> Path:
    return MIRROR / kind / urllib.parse.quote(slug, safe="") / "index.html"


def load(kind: str, slug: str):
    path = mirror_path(kind, slug)
    url = f"https://www.wanikani.com/{kind}/{urllib.parse.quote(slug, safe='')}"
    tree = parse_document(path.read_text(encoding="utf-8"))
    page_type = wanikani.infer_page_type(url)
    return wanikani.parse(tree, url, page_type), url


def mnemonic(record, kind: str):
    for entry in record["mnemonics"]:
        if entry["kind"] == kind:
            return entry
    return None


def text_of(payload) -> str:
    return (payload or {}).get("text", "")


def test_routing_and_dedupe():
    assert wanikani.infer_page_type("https://www.wanikani.com/kanji/%E6%A1%9C") == "kanji"
    assert wanikani.infer_page_type("https://www.wanikani.com/vocabulary/%E6%A1%9C") == "vocabulary"
    assert wanikani.infer_page_type("https://www.wanikani.com/radicals/tree") == "radicals"
    assert wanikani.infer_page_type("https://www.wanikani.com/kanji") == "subject_index"
    assert wanikani.infer_page_type("https://www.wanikani.com/level/32") == "other"
    assert wanikani.infer_page_type("https://www.wanikani.com/") == "other"

    # Percent-encoding, trailing slash and query variants are one entity.
    encoded = wanikani.dedupe_key("https://www.wanikani.com/kanji/%E6%A1%9C", "kanji")
    decoded = wanikani.dedupe_key("https://www.wanikani.com/kanji/桜/?utm=1", "kanji")
    assert encoded == decoded == "wanikani:kanji:桜"
    # Same slug under a different page type is a different entity.
    assert wanikani.dedupe_key("https://www.wanikani.com/vocabulary/桜", "vocabulary") != encoded


def test_real_pages_are_not_shells():
    for kind, slug in (("kanji", "桜"), ("vocabulary", "ホテル"), ("radicals", "think")):
        path = mirror_path(kind, slug)
        url = f"https://www.wanikani.com/{kind}/{urllib.parse.quote(slug, safe='')}"
        tree = parse_document(path.read_text(encoding="utf-8"))
        # "Sign up" is on 100% of pages: it is sitemap chrome, not a login wall.
        assert "Sign up" in path.read_text(encoding="utf-8")
        assert wanikani.is_shell(tree, url) is False


def test_kanji_header_and_level():
    record, _ = load("kanji", "桜")
    assert record["character"] == "桜"
    assert record["subject_name"] == "Sakura"
    # The document h1 is the site logo; the subject name must come from the
    # page header, not from //h1.
    assert record["subject_name"] != "WaniKani"
    assert record["level"] == 32
    assert record["primary_meaning"] == "Sakura"
    assert record["alternative_meanings"] == ["Cherry Tree", "Cherry Blossom"]


def test_mark_roles_survive_with_offsets():
    record, _ = load("kanji", "桜")
    meaning = mnemonic(record, "meaning")
    spans = meaning["text"]["spans"]
    radicals = [span["text"] for span in spans if span["role"] == "radical"]
    assert radicals == ["tree", "grass", "woman"]
    assert [span["text"] for span in spans if span["role"] == "kanji"] == ["sakura", "cherry tree"]
    body = meaning["text"]["text"]
    for span in spans:
        assert body[span["start"] : span["end"]] == span["text"]

    # 桜's reading mnemonic contains "Sakura" twice with different roles, which
    # is why offsets are part of the model.
    reading = mnemonic(record, "reading")
    roles = [(span["text"], span["role"]) for span in reading["text"]["spans"]]
    assert ("Sakura", "reading") in roles
    assert ("Sakura", "kanji") in roles
    assert ("さくら", "ja") in roles


def test_no_spurious_spaces_around_punctuation():
    record, _ = load("kanji", "桜")
    meaning = text_of(mnemonic(record, "meaning")["text"])
    assert "loves sakura, or cherry tree, if" in meaning
    assert " ," not in meaning and " ." not in meaning
    reading = text_of(mnemonic(record, "reading")["text"])
    assert "Sakura (さくら)." in reading
    assert "( さくら )" not in reading

    forest, _ = load("kanji", "林")
    assert "yourself a forest!" in text_of(mnemonic(forest, "meaning")["text"])

    random_kanji, _ = load("kanji", "雑")
    assert " ." not in text_of(mnemonic(random_kanji, "meaning")["text"])

    think, _ = load("radicals", "think")
    assert text_of(mnemonic(think, "meaning")["text"]).endswith("It means think.")


def test_inline_tags_do_not_split_words():
    manga, _ = load("kanji", "万")
    reading = text_of(mnemonic(manga, "reading")["text"])
    assert "into a manga (まん)!" in reading
    assert "man ga" not in reading

    seven, _ = load("kanji", "七")
    assert "she cheated (しち)" in text_of(mnemonic(seven, "reading")["text"])

    repeater, _ = load("kanji", "々")
    assert "drops of water" in text_of(mnemonic(repeater, "meaning")["text"])
    assert "drop s of water" not in text_of(mnemonic(repeater, "meaning")["text"])


def test_multi_paragraph_mnemonics_and_hints_are_complete():
    seven, _ = load("kanji", "七")
    reading = text_of(mnemonic(seven, "reading")["text"])
    # The old parser stopped at the dangling colon that ends paragraph one.
    assert reading.rstrip().endswith("on it.")
    assert "isn't so good:" in reading
    assert "\n\n" in reading

    joe, _ = load("kanji", "上")
    hint = text_of(mnemonic(joe, "reading")["hint"])
    assert "He is a very big man" in hint

    yogurt, _ = load("vocabulary", "〜の様に")
    explanation = text_of(mnemonic(yogurt, "reading")["text"])
    assert "here's a mnemonic to help you out:" in explanation
    assert "yogurt" in explanation


def test_readings_keep_type_and_primary_flag():
    record, _ = load("kanji", "桜")
    assert record["readings"] == [
        {"reading": "おう", "type": "onyomi", "primary": False},
        {"reading": "よう", "type": "onyomi", "primary": False},
        {"reading": "さくら", "type": "kunyomi", "primary": True},
    ]
    assert record["on_readings"] == ["おう", "よう"]
    assert record["kun_readings"] == ["さくら"]
    # "None" is WaniKani's empty placeholder, not a reading.
    assert record["nanori"] == []
    assert record["primary_reading_type"] == "kunyomi"
    # The reading mnemonic is anchored on the primary reading.
    assert mnemonic(record, "reading")["reading"] == "さくら"

    onyomi_primary, _ = load("kanji", "亜")
    assert onyomi_primary["primary_reading_type"] == "onyomi"


def test_subject_cards_are_not_duplicated():
    think, _ = load("radicals", "think")
    # One grid card used to produce three rows, two of them partial.
    assert len(think["found_in_kanji"]) == 1
    assert think["found_in_kanji"][0] == {
        "character": "慮",
        "character_image": None,
        "character_image_label": None,
        "kind": "kanji",
        "reading": "りょ",
        "meaning": "Consider",
        "slug": "慮",
        "url": "https://www.wanikani.com/kanji/%E6%85%AE",
    }

    # radicals/tree has 114 grid cards. Before the fix it produced 3 rows per
    # card, two of them with a null character or a null href.
    tree_radical, _ = load("radicals", "tree")
    rows = tree_radical["found_in_kanji"]
    raw = mirror_path("radicals", "tree").read_text(encoding="utf-8")
    assert len(rows) == raw.count('class="subject-character-grid__item"') == 114
    assert all(row["url"] and row["character"] for row in rows)
    assert len({row["url"] for row in rows}) == len(rows)

    sakura_word, _ = load("vocabulary", "桜")
    assert len(sakura_word["component_subjects"]) == 1


def test_visually_similar_kanji_are_captured():
    record, _ = load("kanji", "丁")
    assert [(row["character"], row["reading"], row["meaning"]) for row in record["visually_similar_kanji"]] == [
        ("子", "し", "Child"),
        ("了", "りょう", "Finish"),
    ]
    # The section is absent on about a third of kanji pages: empty, not a failure.
    assert load("kanji", "桜")[0]["visually_similar_kanji"] == []


def test_image_only_radicals_keep_glyph_url():
    beggar, _ = load("radicals", "beggar")
    assert beggar["character"] is None
    assert beggar["character_image"] == "https://files.wanikani.com/8v0hjy2gh2dnmh1cgbcg8cedpd58"
    assert beggar["character_image_label"] == "Beggar"
    assert mnemonic(beggar, "meaning")["image"]["url"].startswith("https://files.wanikani.com/")

    # The illustration is still captured on the kanji page, but as WaniKani
    # artwork on the authored side, joined to the decomposition by position.
    give, _ = load("kanji", "与")
    component = give["radical_combination"][0]
    assert component == {"position": 1, "character": None, "presence": "image_only"}
    assert give["radical_component_names"][0] == {
        "position": 1,
        "slug": "beggar",
        "name": "Beggar",
        "url": "https://www.wanikani.com/radicals/beggar",
        "character_image": "https://files.wanikani.com/8v0hjy2gh2dnmh1cgbcg8cedpd58",
    }
    assert [row["position"] for row in give["radical_combination"]] == [
        row["position"] for row in give["radical_component_names"]
    ]


def test_factual_decomposition_carries_no_coinage():
    """A factual row must not be reconstructible into a WaniKani name.

    radical_combination used to carry slug and url, which spell "Beggar" and
    "Death Star" as a path, so filtering on ship=allowed re-imported the exact
    coinage that radical_component_names exists to isolate.
    """
    for kind, slug in (("kanji", "与"), ("kanji", "桜"), ("kanji", "雑")):
        record, _ = load(kind, slug)
        assert record["_provenance"]["radical_combination"]["ship"] == "allowed"
        for row in record["radical_combination"]:
            assert set(row) == {"position", "character", "presence"}
        names = " ".join(str(row["name"]) for row in record["radical_component_names"])
        assert names, f"{kind}/{slug} has no component names to keep on the authored side"


def test_out_of_bmp_radical_glyph():
    record, _ = load("kanji", "桜")
    position = [row["position"] for row in record["radical_component_names"] if row["slug"] == "grass"][0]
    grass = [row for row in record["radical_combination"] if row["position"] == position][0]
    assert grass["character"] == "\U0002d544"


def test_vocabulary_audio_and_voices():
    record, _ = load("vocabulary", "ホテル")
    assert record["readings"] == ["ホテル"]
    audio = record["reading_audio"]
    assert len(audio) == 1
    voices = audio[0]["voices"]
    # The <ul> container class contains the <li> class as a substring, which
    # used to add a phantom leading duplicate voice.
    assert [voice["name"] for voice in voices] == ["Kyoko", "Kenichi"]
    assert voices[0]["sources"] == [
        {"url": "https://files.wanikani.com/rzkl70cr1io8ngp7phofmwyvcc9f", "content_type": "audio/webm"},
        {"url": "https://files.wanikani.com/xskv4hvqktrnd1mfok7d4xonu7yq", "content_type": "audio/mpeg"},
    ]

    sakura_word, _ = load("vocabulary", "桜")
    assert [voice["name"] for voice in sakura_word["reading_audio"][0]["voices"]] == ["Kyoko", "Kenichi"]


def test_vocabulary_collocations_keep_pattern_labels():
    record, _ = load("vocabulary", "ホテル")
    patterns = [group["pattern"] for group in record["collocations"]]
    assert patterns == ["ホテルの〜", "ホテルに〜", "〜ホテル", "ホテルを〜"]
    assert record["collocations"][0]["items"][0] == {
        "japanese": "ホテルのロビー",
        "english": "hotel lobby",
    }


def test_vocabulary_context_sentences_are_split():
    record, _ = load("vocabulary", "ホテル")
    assert record["context_sentences"][0] == {
        "japanese": "ホテル、もうとった？",
        "english": "Did you book a hotel already?",
    }
    # A context sentence must never be glued into the mnemonic bucket.
    for entry in record["mnemonics"]:
        assert "Did you book a hotel already?" not in text_of(entry["text"])


def test_vocabulary_word_type():
    record, _ = load("vocabulary", "ホテル")
    assert record["word_type"] == "noun"
    assert record["word_types"] == ["noun"]


def test_singular_alternative_label_is_read():
    # The label is "Alternative" for one alternative and "Alternatives" for
    # several. A fixed-string regex on the plural silently lost the singular.
    record, _ = load("kanji", "亜")
    assert record["alternative_meanings"]


def test_mnemonic_identity_and_language_scope():
    record, _ = load("kanji", "雑")
    kinds = [(entry["kind"], entry["language"], entry["presence"]) for entry in record["mnemonics"]]
    assert kinds == [("meaning", "en", "present"), ("reading", "en", "present")]
    reading = mnemonic(record, "reading")
    assert reading["reading"] == "ざつ"
    assert reading["origin"] == "extracted"
    # Hint and mnemonic are disjoint by construction, never split on the word.
    assert "Hints" not in text_of(reading["text"])
    assert text_of(reading["hint"]).startswith("Look at Zazu")


def test_provenance_marks_authored_prose_reference_only():
    record, _ = load("kanji", "桜")
    provenance = record["_provenance"]
    assert provenance["mnemonics"]["license_class"] == "authored-third-party"
    assert provenance["mnemonics"]["ship"] == "reference-only"
    assert provenance["readings"]["ship"] == "allowed"
    assert provenance["level"]["ship"] == "allowed"
    assert provenance["radical_combination"]["ship"] == "allowed"
    # WaniKani radical names are WaniKani coinages, not dictionary facts.
    assert provenance["radical_component_names"]["ship"] == "reference-only"

    word, _ = load("vocabulary", "ホテル")
    assert word["_provenance"]["context_sentences"]["ship"] == "reference-only"
    assert word["_provenance"]["collocations"]["ship"] == "reference-only"
    assert word["_provenance"]["reading_audio"]["ship"] == "reference-only"
    assert word["_provenance"]["readings"]["ship"] == "allowed"

    radical, _ = load("radicals", "beggar")
    assert radical["_provenance"]["primary_meaning"]["ship"] == "reference-only"
    # The illustration is WaniKani artwork of a WaniKani coinage, and its
    # aria-label is byte-identical to the coined name, so neither may ship.
    assert radical["_provenance"]["character_image"]["ship"] == "reference-only"
    assert radical["_provenance"]["character_image_label"]["ship"] == "reference-only"
    assert radical["character_image_label"] == radical["subject_name"] == "Beggar"
    assert radical["_provenance"]["character"]["ship"] == "allowed"


def test_the_same_string_is_never_both_shippable_and_reference_only():
    """No coinage may appear under a ship=allowed field on any page type."""
    for kind, slug in (
        ("radicals", "death-star"),
        ("radicals", "beggar"),
        ("radicals", "think"),
        ("kanji", "与"),
    ):
        record, _ = load(kind, slug)
        provenance = record["_provenance"]
        reference_only = {
            str(record[field])
            for field, stamp in provenance.items()
            if stamp["ship"] == "reference-only" and isinstance(record[field], str)
        }
        shippable = {
            str(record[field])
            for field, stamp in provenance.items()
            if stamp["ship"] == "allowed" and isinstance(record[field], str)
        }
        # source_url is a citation, not content: it is allowed to name the slug.
        shippable -= {record["source_url"], record["slug"], record["page_type"], record["subject_type"]}
        assert not (reference_only & shippable), f"{kind}/{slug}: {reference_only & shippable}"


def test_every_emitted_field_has_a_provenance_entry():
    for kind, slug in (("kanji", "桜"), ("vocabulary", "ホテル"), ("radicals", "death-star")):
        record, _ = load(kind, slug)
        emitted = set(record) - {"_provenance"}
        assert emitted == set(record["_provenance"]), kind


def test_mnemonic_and_hint_stay_disjoint():
    # The old pipeline captured the Hints aside as a second mnemonic paragraph
    # and then emitted the same prose again as the hint.
    for kind, slug in (("kanji", "桜"), ("kanji", "林"), ("kanji", "雑"), ("radicals", "think")):
        record, _ = load(kind, slug)
        for entry in record["mnemonics"]:
            body = text_of(entry["text"])
            hint = text_of(entry["hint"])
            assert "Hints" not in body
            if hint:
                assert hint not in body


def test_values_that_look_like_section_labels_are_kept():
    """A prefix check against known label strings would reject real values.

    釈 and 解釈 have the primary meaning "Explanation", which is also the
    vocabulary section subtitle, and the reading mnemonic of 治 opens with
    "Alternative ways to cure yourself ...". The guard is structural (no heading
    element inside the block) precisely so these three parse.
    """
    assert load("kanji", "釈")[0]["primary_meaning"] == "Explanation"
    assert load("vocabulary", "解釈")[0]["primary_meaning"] == "Explanation"
    cure, _ = load("kanji", "治")
    assert "Alternative ways to cure yourself" in text_of(mnemonic(cure, "reading")["text"])
    assert cure["primary_meaning"] == "Cure"


def test_subject_index_emits_one_record_per_card():
    """The only synthetic fixture here: the mirror holds no index page.

    All 9374 mirrored files are subject pages, so this path cannot be tested
    against real bytes. The markup below is the subject-card markup copied from
    a real kanji page, which is what an index grid is built from.
    """
    html = """
    <html><body>
      <h2>Level 1</h2>
      <a class="subject-character subject-character--kanji subject-character--grid"
         title="いち" href="https://www.wanikani.com/kanji/%E4%B8%80">
        <div class="subject-character__content">
          <span class="subject-character__characters">
            <span class="subject-character__characters-text" lang="ja">一</span>
          </span>
          <div class="subject-character__info">
            <span class="subject-character__reading">いち</span>
            <span class="subject-character__meaning">One</span>
          </div>
        </div>
      </a>
      <h2>Level 2</h2>
      <a class="subject-character subject-character--kanji subject-character--grid"
         title="ちょう" href="https://www.wanikani.com/kanji/%E4%B8%81">
        <div class="subject-character__content">
          <span class="subject-character__characters">
            <span class="subject-character__characters-text" lang="ja">丁</span>
          </span>
          <div class="subject-character__info">
            <span class="subject-character__meaning">Street</span>
          </div>
        </div>
      </a>
    </body></html>
    """
    url = "https://www.wanikani.com/kanji"
    tree = parse_document(html)
    assert wanikani.infer_page_type(url) == "subject_index"
    assert wanikani.dedupe_key(url, "subject_index") == "wanikani:index:kanji"
    assert wanikani.is_shell(tree, url) is False
    records = wanikani.parse(tree, url, "subject_index")
    assert isinstance(records, list) and len(records) == 2
    assert [(row["character"], row["level"], row["meaning"]) for row in records] == [
        ("一", 1, "One"),
        ("丁", 2, "Street"),
    ]
    assert records[1]["reading"] == "ちょう"
    assert all(row["_provenance"]["character"]["ship"] == "allowed" for row in records)
    # 'kind' used to be written into the row and left out of the provenance map,
    # so it shipped with no licence at all.
    for row in records:
        assert row["kind"] == "kanji"
        assert set(row) - {"_provenance"} == set(row["_provenance"])
        assert row["_provenance"]["kind"]["ship"] == "allowed"
        assert row["_provenance"]["meaning"]["ship"] == "allowed"

    empty = parse_document("<html><body><p>nothing here</p></body></html>")
    assert wanikani.is_shell(empty, url) is True


def test_radicals_index_card_name_is_not_shippable():
    """A radicals index card meaning is the coinage, same as on its own page."""
    html = """
    <html><body>
      <h2>Level 1</h2>
      <a class="subject-character subject-character--radical subject-character--grid"
         title="Beggar" href="https://www.wanikani.com/radicals/beggar">
        <div class="subject-character__content">
          <span class="subject-character__characters">
            <wk-character-image src="https://files.wanikani.com/8v0hjy2gh2dnmh1cgbcg8cedpd58"
                                aria-label="Beggar"></wk-character-image>
          </span>
          <div class="subject-character__info">
            <span class="subject-character__meaning">Beggar</span>
          </div>
        </div>
      </a>
    </body></html>
    """
    records = wanikani.parse(parse_document(html), "https://www.wanikani.com/radicals", "subject_index")
    assert len(records) == 1
    row = records[0]
    assert row["meaning"] == "Beggar" and row["kind"] == "radical"
    assert row["_provenance"]["meaning"]["ship"] == "reference-only"
    assert row["_provenance"]["character_image"]["ship"] == "reference-only"
    assert row["_provenance"]["character_image_label"]["ship"] == "reference-only"
    assert set(row) - {"_provenance"} == set(row["_provenance"])


def test_title_substring_never_outranks_page_structure():
    """A weak title signal must not discard a page that has a subject header."""
    soft_404 = parse_document("<html><head><title>Page not found</title></head><body></body></html>")
    assert wanikani.is_shell(soft_404, "https://www.wanikani.com/kanji/%E6%A1%9C") is True

    raw = mirror_path("vocabulary", "ホテル").read_text(encoding="utf-8")
    # A real page whose title happens to contain "404" is still a real page.
    tree = parse_document(raw.replace("<title>", "<title>404 ", 1))
    assert wanikani.is_shell(tree, "https://www.wanikani.com/vocabulary/%E3%83%9B%E3%83%86%E3%83%AB") is False


def test_unexpected_page_type_raises():
    tree = parse_document("<html><body></body></html>")
    try:
        wanikani.parse(tree, "https://www.wanikani.com/level/32", "other")
    except wanikani.WanikaniParseError:
        pass
    else:  # pragma: no cover
        raise AssertionError("parse must raise on a non-extractable page type")


def test_missing_markup_raises_instead_of_returning_empty():
    tree = parse_document(
        "<html><body><div class='subject-page-header'>"
        "<span class='page-header__title-text'>Sakura</span></div></body></html>"
    )
    try:
        wanikani.parse(tree, "https://www.wanikani.com/kanji/%E6%A1%9C", "kanji")
    except wanikani.WanikaniParseError:
        pass
    else:  # pragma: no cover
        raise AssertionError("parse must raise when the level block is missing")


def test_sample_of_real_pages_parses():
    """Smoke run over a random slice of every page type in the mirror."""
    random.seed(4242)
    parsed = 0
    for kind in ("kanji", "vocabulary", "radicals"):
        slugs = sorted(os.listdir(MIRROR / kind))
        random.shuffle(slugs)
        for encoded in slugs[:40]:
            path = MIRROR / kind / encoded / "index.html"
            url = f"https://www.wanikani.com/{kind}/{encoded}"
            tree = parse_document(path.read_text(encoding="utf-8"))
            assert wanikani.is_shell(tree, url) is False
            record = wanikani.parse(tree, url, wanikani.infer_page_type(url))
            assert record["level"] >= 1
            assert record["primary_meaning"]
            assert record["character"] or record["character_image"]
            parsed += 1
    assert parsed == 120


def main() -> int:
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
    print("failures:", failures)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
