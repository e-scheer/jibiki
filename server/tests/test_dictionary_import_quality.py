import gzip
import json

import pytest
from django.core.management import call_command
from django.core.management.base import CommandError

from dictionary.models import (
    ExampleSenseLink,
    ExampleSentence,
    ExampleTranslation,
    Gloss,
    Kanji,
    KanjiMeaning,
    Name,
    NameTranslation,
    Word,
    WordForm,
)
from srs.models import Card

pytestmark = pytest.mark.django_db


def source(tmp_path, body, root="JMdict", filename="source.xml", compressed=False):
    text = f'<!DOCTYPE {root} [<!ENTITY n "noun (common)">]><{root}>{body}</{root}>'
    path = tmp_path / (filename + ".gz" if compressed else filename)
    if compressed:
        path.write_bytes(gzip.compress(text.encode()))
    else:
        path.write_text(text, encoding="utf-8")
    return path


def word_xml(senses, seq=123):
    return f"""<entry><ent_seq>{seq}</ent_seq><k_ele><keb>水</keb><ke_pri>ichi1</ke_pri></k_ele>
    <r_ele><reb>みず</reb><re_restr>水</re_restr><re_inf>rare</re_inf></r_ele>{senses}</entry>"""


def test_jmdict_is_lossless_repeatable_and_preserves_personal_identity(tmp_path, user):
    long_gloss = "a" * 1500
    path = source(
        tmp_path,
        word_xml(f"""<sense><pos>&n;</pos><stagk>水</stagk>
    <stagr>みず</stagr><xref>川</xref><s_inf>Scope note</s_inf>
    <gloss g_type="lit">{long_gloss}</gloss><gloss xml:lang="fre">eau</gloss></sense>
    <sense><gloss>second sense</gloss></sense>"""),
        compressed=True,
    )
    call_command("import_jmdict", str(path), langs="all")
    word = Word.objects.get(seq=123)
    card = Card.objects.create(user=user, item_type="word", word=word, reps=42, stability=31)
    reading = word.forms.get(kind="kana")
    reading.pitch = "0"
    reading.metadata["pitch_provenance"] = {"source": "kept_pitch_source"}
    reading.save()
    senses = list(word.senses.all())
    assert [s.pos for s in senses] == [["n"], ["n"]]
    assert senses[0].metadata["restricted_readings"] == ["みず"]
    assert senses[0].glosses.get(language="en").text == long_gloss
    assert senses[0].glosses.get(language="en").metadata["g_type"] == "lit"
    assert reading.metadata["restricted_kanji"] == ["水"]
    assert len(word.provenance["jmdict"]["sha256"]) == 64
    call_command("import_jmdict", str(path), langs="en")
    card.refresh_from_db()
    reading.refresh_from_db()
    assert card.word_id == word.pk and card.reps == 42 and card.stability == 31
    assert reading.pitch == "0"
    assert reading.metadata["pitch_provenance"]["source"] == "kept_pitch_source"
    assert Word.objects.count() == 1 and WordForm.objects.count() == 2
    assert list(word.senses.values_list("pk", flat=True)) == [s.pk for s in senses]
    assert Gloss.objects.filter(language="fr", text="eau").count() == 1


def test_jmdict_failed_source_rolls_back_prior_batches(tmp_path):
    path = source(
        tmp_path,
        word_xml("<sense><gloss>water</gloss></sense>") + "<entry><ent_seq>124</ent_seq></entry>",
    )
    with pytest.raises(CommandError):
        call_command("import_jmdict", str(path), batch_size=1)
    assert not Word.objects.exists()


def test_jmdict_does_not_drop_catalogue_outside_limited_import(tmp_path):
    untouched = Word.objects.create(seq=999)
    path = source(tmp_path, word_xml("<sense><gloss>water</gloss></sense>"))
    call_command("import_jmdict", str(path), limit=1)
    assert Word.objects.filter(pk=untouched.pk).exists()


def test_kanjidic_retains_extra_sources_and_does_not_relabel_legacy_jlpt(tmp_path):
    kanji = Kanji.objects.create(
        literal="水", jlpt=5, components=["水"], provenance={"kanjivg": {"sha256": "kept"}}
    )
    KanjiMeaning.objects.create(kanji=kanji, language="fr", text="eau")
    path = source(
        tmp_path,
        """<character><literal>水</literal><misc><stroke_count>4</stroke_count>
    <jlpt>4</jlpt></misc><reading_meaning><rmgroup><reading r_type="ja_on">スイ</reading>
    <reading r_type="pinyin">shui3</reading><meaning>water</meaning>
    <meaning m_lang="fr">eau nouvelle</meaning></rmgroup><nanori>み</nanori>
    </reading_meaning></character>""",
        root="kanjidic2",
    )
    call_command("import_kanjidic", str(path), langs="eng")
    kanji.refresh_from_db()
    assert kanji.jlpt == 5 and kanji.metadata["legacy_jlpt"] == 4
    assert kanji.components == ["水"] and "kanjivg" in kanji.provenance
    assert kanji.meanings.get(language="fr").text == "eau"
    assert "shui3" in json.dumps(kanji.metadata)


def test_names_keep_all_variants_language_scope_and_ids(tmp_path):
    name = Name.objects.create(seq=123, reading="ふるい", provenance={"other": True})
    NameTranslation.objects.create(name=name, language="fr", text="autre")
    path = source(
        tmp_path,
        """<entry><ent_seq>123</ent_seq><k_ele><keb>東京</keb></k_ele>
    <k_ele><keb>東亰</keb></k_ele><r_ele><reb>とうきょう</reb></r_ele><trans>
    <name_type>&n;</name_type><trans_det>Tokyo</trans_det></trans></entry>""",
        root="JMnedict",
    )
    call_command("import_jmnedict", str(path), langs="en")
    name.refresh_from_db()
    assert name.metadata["kanji"] == ["東京", "東亰"]
    assert name.name_types == ["n"] and name.provenance["other"] is True
    assert name.localized_names.get(language="fr").text == "autre"
    assert Name.objects.count() == 1


EXAMPLE = """<example><ex_srce exsrc_type="tat">12345</ex_srce><ex_text>水</ex_text>
<ex_sent xml:lang="jpn">水を飲む。</ex_sent><ex_sent xml:lang="eng">I drink water.</ex_sent></example>"""


def test_examples_match_exact_sense_across_multilingual_order_and_repeat(tmp_path, client):
    canonical = source(
        tmp_path,
        word_xml("""<sense><gloss xml:lang="fre">eau</gloss></sense>
    <sense><pos>&n;</pos><gloss>water</gloss></sense>"""),
    )
    call_command("import_jmdict", str(canonical), langs="all")
    source_path = source(
        tmp_path,
        word_xml(f"<sense><pos>&n;</pos><gloss>water</gloss>{EXAMPLE}</sense>"),
        filename="examples.xml",
    )
    unrelated = ExampleSentence.objects.create(japanese="水曜日。")
    ExampleTranslation.objects.create(example=unrelated, text="Wednesday.")
    call_command("import_jmdict_examples", str(source_path))
    example = ExampleSentence.objects.exclude(pk=unrelated.pk).get()
    link = ExampleSenseLink.objects.get()
    assert link.sense.order == 1 and link.source_sense_order == 0
    assert link.provenance["raw"]["children"][0]["text"] == "12345"
    call_command("import_jmdict_examples", str(source_path))
    assert ExampleSenseLink.objects.count() == 1 and ExampleSentence.objects.count() == 2
    word = Word.objects.get(seq=123)
    response = client.get(f"/api/v1/dict/words/{word.pk}", {"lang": "fr"})
    assert response.status_code == 200
    assert [e["japanese"] for e in response.json()["examples"]] == [example.japanese]
    assert response.json()["examples"][0]["language"] == "en"
    assert word.senses.count() == 2 and Gloss.objects.filter(language="fr").exists()


def test_examples_never_guess_mismatched_sense_or_replace_multilingual_dictionary(tmp_path):
    canonical = source(tmp_path, word_xml("<sense><gloss>Wednesday</gloss></sense>"))
    call_command("import_jmdict", str(canonical))
    example_path = source(
        tmp_path, word_xml(f"<sense><gloss>water</gloss>{EXAMPLE}</sense>"), filename="examples.xml"
    )
    report_path = tmp_path / "report.json"
    call_command("import_jmdict_examples", str(example_path), report=str(report_path))
    assert not ExampleSenseLink.objects.exists()
    assert json.loads(report_path.read_text())["unmatched"][0]["reason"] == "different_sense"
    with pytest.raises(CommandError, match="import_jmdict_examples"):
        call_command("import_jmdict", str(example_path))
    assert Gloss.objects.get().text == "Wednesday"


def test_tanaka_import_preserves_unrelated_sources_and_raw_index(tmp_path):
    existing = ExampleSentence.objects.create(japanese="既存の文。")
    ExampleTranslation.objects.create(example=existing, language="fr", text="Phrase conservée.")
    path = tmp_path / "examples.utf"
    path.write_text(
        "A: 水を飲む。\tI drink water.#ID=123_456\nB: 水(みず)[1] 飲む\n", encoding="utf-8"
    )
    call_command("import_examples", str(path))
    call_command("import_examples", str(path))
    assert ExampleSentence.objects.count() == 2
    imported = ExampleSentence.objects.exclude(pk=existing.pk).get()
    assert imported.provenance["index_line"] == "水(みず)[1] 飲む"
    assert imported.provenance["source_id"] == "123_456"
    assert not ExampleSenseLink.objects.exists()
    assert existing.translations.get(language="fr").text == "Phrase conservée."


def test_tanaka_rejects_invalid_encoding_instead_of_silent_replacement(tmp_path):
    path = tmp_path / "examples.utf"
    path.write_bytes(b"A: bad\xff\ttext\n")
    with pytest.raises(UnicodeDecodeError):
        call_command("import_examples", str(path))
    assert not ExampleSentence.objects.exists()


def test_kana_api_identifies_actual_fallback_language(client):
    from dictionary.models import (
        Kana,
        KanaExplanation,
        KanaUsage,
        KanaUsageExample,
        KanaUsageExampleTranslation,
        KanaUsageTranslation,
    )

    kana = Kana.objects.create(char="は", romaji="ha", script="hiragana")
    KanaExplanation.objects.create(kana=kana, language="en", origin_note="Shape origin.")
    role = KanaUsage.objects.create(kana=kana)
    KanaUsageTranslation.objects.create(
        usage=role, language="en", label="Topic", explanation="Topic marker."
    )
    example = KanaUsageExample.objects.create(
        usage=role, before="これ", particle="は", after="本です。"
    )
    KanaUsageExampleTranslation.objects.create(
        example=example, language="en", text="This is a book."
    )
    response = client.get("/api/v1/dict/kana/は", {"lang": "fr"})
    assert response.status_code == 200
    data = response.json()
    assert data["origin_language"] == data["usage_language"] == "en"
    assert data["usage_examples"][0]["language"] == "en"


def test_provenance_requires_matching_download_evidence_and_never_claims_authorship(tmp_path):
    from dictionary.importing import source_provenance

    path = source(tmp_path, word_xml("<sense><gloss>water</gloss></sense>"), filename="JMdict")
    unknown = source_provenance(path, "jmdict")
    assert unknown["verified_download"] is False and "generated_by_ai" not in unknown
    assert unknown["authoring_method"] == "upstream_unspecified"
    record = {
        "url": "ftp://ftp.edrdg.org/pub/Nihongo/JMdict.gz",
        "sha256_xml": unknown["sha256"],
        "fetched_at": "2026-09-09T00:00:00Z",
    }
    sidecar = tmp_path / "JMdict.gz.download.json"
    sidecar.write_text(json.dumps(record))
    assert source_provenance(path, "jmdict")["verified_download"] is True
    record["url"] = "https://untrusted.example/pub/Nihongo/JMdict.gz"
    sidecar.write_text(json.dumps(record))
    assert source_provenance(path, "jmdict")["verified_download"] is False
    record["url"] = "ftp://ftp.edrdg.org/pub/Nihongo/JMdict.gz"
    record["sha256_xml"] = "wrong"
    sidecar.write_text(json.dumps(record))
    assert source_provenance(path, "jmdict")["verified_download"] is False


def test_provenance_refresh_updates_only_exact_file_and_preserves_other_sources(tmp_path):
    from dictionary.importing import source_provenance

    path = source(tmp_path, word_xml("<sense><gloss>water</gloss></sense>"))
    evidence = source_provenance(path, "jmdict")
    word = Word.objects.create(
        seq=123,
        provenance={
            "jmdict": {"sha256": evidence["sha256"], "generated_by_ai": False},
            "other": {"keep": True},
        },
    )
    untouched = Word.objects.create(seq=456, provenance={"jmdict": {"sha256": "other_snapshot"}})
    call_command("refresh_dictionary_provenance", "jmdict", str(path))
    word.refresh_from_db()
    untouched.refresh_from_db()
    assert word.provenance == {"jmdict": evidence, "other": {"keep": True}}
    assert untouched.provenance == {"jmdict": {"sha256": "other_snapshot"}}


def test_full_snapshot_prunes_removed_source_children_without_replacing_word(tmp_path):
    first = source(
        tmp_path,
        word_xml("<sense><gloss>water</gloss></sense><sense><gloss>obsolete</gloss></sense>"),
    )
    call_command("import_jmdict", str(first), langs="all")
    word = Word.objects.get(seq=123)
    removed = WordForm.objects.create(word=word, kind="kana", text="obsolete")
    second = source(
        tmp_path, word_xml("<sense><gloss>water</gloss></sense>"), filename="second.xml"
    )
    call_command("import_jmdict", str(second), langs="all")
    assert Word.objects.get(seq=123).pk == word.pk
    assert word.senses.count() == 1
    assert not WordForm.objects.filter(pk=removed.pk).exists()


def test_demo_alias_hides_duplicate_but_preserves_card_id_and_resolves_detail(
    tmp_path, user, client
):
    from dictionary.search import search_words
    from srs.decks import _universe, deck_by_id

    path = source(tmp_path, word_xml("<sense><gloss>canonical water</gloss></sense>"))
    call_command("import_jmdict", str(path))
    canonical = Word.objects.get(seq=123)
    demo = Word.objects.create(seq=-1, is_common=True)
    WordForm.objects.create(word=demo, kind="kanji", text="水")
    WordForm.objects.create(word=demo, kind="kana", text="みず")
    card = Card.objects.create(user=user, item_type="word", word=demo, reps=17)
    call_command("reconcile_demo_aliases")
    demo.refresh_from_db()
    card.refresh_from_db()
    assert demo.canonical_word_id == canonical.pk
    assert card.word_id == demo.pk and card.reps == 17
    assert [w.pk for w in search_words("水")] == [canonical.pk]
    assert list(_universe(deck_by_id("words_all")).values_list("pk", flat=True)) == [canonical.pk]
    data = client.get(f"/api/v1/dict/words/{demo.pk}").json()
    assert data["id"] == demo.pk and data["canonical_id"] == canonical.pk
    assert data["senses"][0]["glosses"][0]["text"] == "canonical water"
    assert "raw" not in data["senses"][0]["metadata"]
    assert "raw" not in data["readings"][0]["metadata"]
    call_command("reconcile_demo_aliases")
    assert Word.objects.count() == 2 and Card.objects.count() == 1


def test_demo_alias_never_guesses_ambiguous_homograph(tmp_path):
    path = source(
        tmp_path,
        word_xml("<sense><gloss>first meaning</gloss></sense>", seq=123)
        + word_xml("<sense><gloss>other meaning</gloss></sense>", seq=124),
    )
    call_command("import_jmdict", str(path))
    demo = Word.objects.create(seq=-1)
    WordForm.objects.create(word=demo, kind="kanji", text="水")
    WordForm.objects.create(word=demo, kind="kana", text="みず")
    report = tmp_path / "aliases.json"
    call_command("reconcile_demo_aliases", report=str(report))
    demo.refresh_from_db()
    assert demo.canonical_word_id is None
    assert json.loads(report.read_text())["unresolved"][0]["reason"] == "ambiguous"


def test_pitch_retains_variants_and_respects_written_reading_restrictions(tmp_path):
    path = source(tmp_path, word_xml("<sense><gloss>water</gloss></sense>"))
    call_command("import_jmdict", str(path))
    word = Word.objects.get(seq=123)
    WordForm.objects.create(word=word, kind="kanji", text="異表記")
    other = Word.objects.create(seq=124)
    WordForm.objects.create(word=other, kind="kanji", text="見ず")
    other_reading = WordForm.objects.create(word=other, kind="kana", text="みず")
    accents = tmp_path / "accents.txt"
    accents.write_text(
        "水\tみず\t0\n水\tみず\t2\n異表記\tみず\t1\nみず\tみず\t3\n", encoding="utf-8"
    )
    call_command("import_pitch", str(accents))
    reading = word.forms.get(kind="kana")
    assert reading.pitch == "0,2"
    assert reading.metadata["pitch_provenance"]["matches"] == {"水": [0, 2]}
    assert "raw" in reading.metadata
    other_reading.refresh_from_db()
    assert other_reading.pitch == ""


def test_pitch_invalid_input_does_not_partially_overwrite_readings(tmp_path):
    word = Word.objects.create(seq=123)
    reading = WordForm.objects.create(word=word, kind="kana", text="みず", pitch="2")
    accents = tmp_path / "accents.txt"
    accents.write_text("みず\tみず\t0\ninvalid row\n", encoding="utf-8")
    with pytest.raises(CommandError, match="Malformed"):
        call_command("import_pitch", str(accents))
    reading.refresh_from_db()
    assert reading.pitch == "2"


def test_jlpt_does_not_fall_back_when_reading_disagrees(tmp_path):
    path = source(tmp_path, word_xml("<sense><gloss>water</gloss></sense>"))
    call_command("import_jmdict", str(path))
    mapping = tmp_path / "n5.csv"
    mapping.write_text("expression,reading,meaning\n水,すい,water\n", encoding="utf-8")
    call_command("import_jlpt_vocab", str(tmp_path))
    word = Word.objects.get(seq=123)
    assert word.jlpt is None
    mapping.write_text("expression,reading,meaning\n水,みず,water\n", encoding="utf-8")
    call_command("import_jlpt_vocab", str(tmp_path))
    word.refresh_from_db()
    assert word.jlpt == 5
    assert word.provenance["jlpt_vocab"]["reading"] == "みず"


def test_jlpt_leaves_ambiguous_homographs_unassigned(tmp_path):
    path = source(
        tmp_path,
        word_xml("<sense><gloss>first</gloss></sense>", seq=123)
        + word_xml("<sense><gloss>second</gloss></sense>", seq=124),
    )
    call_command("import_jmdict", str(path))
    (tmp_path / "n5.csv").write_text("expression,reading\n水,みず\n", encoding="utf-8")
    call_command("import_jlpt_vocab", str(tmp_path))
    assert not Word.objects.filter(jlpt__isnull=False).exists()


def test_empty_source_senses_are_archived_without_renumbering_valid_senses(tmp_path):
    path = source(
        tmp_path,
        word_xml(
            "<sense><gloss>water</gloss></sense><sense/>"
            '<sense><gloss xml:lang="spa"/></sense><sense><gloss>another sense</gloss></sense>'
        ),
    )
    call_command("import_jmdict", str(path), langs="all")
    word = Word.objects.get(seq=123)
    assert list(word.senses.values_list("order", flat=True)) == [0, 3]
    assert not Gloss.objects.filter(text="").exists()
    assert [a["order"] for a in word.provenance["jmdict_source_anomalies"]] == [1, 2]


def test_snapshot_marks_missing_entry_but_preserves_personal_card_and_details(
    tmp_path, user, client
):
    from dictionary.importing import source_provenance
    from dictionary.search import search_words

    current = source(tmp_path, word_xml("<sense><gloss>water</gloss></sense>"), filename="JMdict")
    evidence = source_provenance(current, "jmdict")
    (tmp_path / "JMdict.gz.download.json").write_text(
        json.dumps(
            {
                "url": "ftp://ftp.edrdg.org/pub/Nihongo/JMdict.gz",
                "sha256_xml": evidence["sha256"],
            }
        )
    )
    legacy = Word.objects.create(seq=124)
    WordForm.objects.create(word=legacy, kind="kanji", text="古")
    card = Card.objects.create(user=user, item_type="word", word=legacy, reps=12)
    call_command(
        "reconcile_dictionary_snapshot",
        str(current),
        mark_missing=True,
        report=str(tmp_path / "reconciliation.json"),
    )
    card.refresh_from_db()
    assert card.word_id == legacy.pk and card.reps == 12
    assert not search_words("古")
    data = client.get(f"/api/v1/dict/words/{legacy.pk}").json()
    assert data["id"] == legacy.pk and data["source_status"] == "upstream_not_in_snapshot"


def test_split_demo_readings_are_retained_as_nonpublic_legacy_group(tmp_path, client):
    from dictionary.search import search_words

    first = word_xml("<sense><gloss>first</gloss></sense>", seq=123)
    second = word_xml("<sense><gloss>second</gloss></sense>", seq=124).replace("みず", "すい")
    path = source(tmp_path, first + second)
    call_command("import_jmdict", str(path))
    legacy = Word.objects.create(seq=-1)
    WordForm.objects.create(word=legacy, kind="kanji", text="水")
    WordForm.objects.create(word=legacy, kind="kana", text="みず")
    WordForm.objects.create(word=legacy, kind="kana", text="すい")
    call_command("reconcile_demo_aliases")
    legacy.refresh_from_db()
    assert legacy.canonical_word_id is None
    assert legacy.provenance["source_status"] == "legacy_merged_entry"
    assert len(legacy.provenance["canonical_candidates"]) == 2
    assert legacy.pk not in [w.pk for w in search_words("水")]
    data = client.get(f"/api/v1/dict/words/{legacy.pk}").json()
    assert data["source_status"] == "legacy_merged_entry"
