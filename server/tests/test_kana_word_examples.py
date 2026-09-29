import json

import pytest
from django.core.management import call_command
from rest_framework.test import APIClient

from dictionary.models import Gloss, Kana, KanaWordExample, Sense, Word, WordForm

pytestmark = pytest.mark.django_db


def word(seq, reading, source="jmdict"):
    item = Word.objects.create(
        seq=seq, provenance={source: {"source": source, "sha256": "canonical-hash"}}
    )
    WordForm.objects.create(word=item, text=reading, kind="kana")
    meaning = Sense.objects.create(word=item)
    Gloss.objects.create(sense=meaning, language="en", text="canonical definition")
    return item


def run(tmp_path, rows, dry=False):
    source, report = tmp_path / "candidates.jsonl", tmp_path / "report.json"
    source.write_text("\n".join(json.dumps(row) for row in rows), encoding="utf8")
    call_command("import_kana_word_examples", str(source), report=report, dry_run=dry)
    return json.loads(report.read_text(encoding="utf8"))


def candidate(reading="いぬ", target="い"):
    return {
        "character": target,
        "japanese": reading,
        "translation": "SCRAPED DEFINITION MUST NOT SHIP",
        "source_url": "https://example.test/kana/i",
        "source_file_sha256": "source-hash",
        "validation_errors": [],
    }


def test_unique_canonical_reading_import_is_idempotent_and_uses_canonical_glosses(tmp_path):
    kana = Kana.objects.create(char="い", romaji="i", script="hiragana")
    item = word(101, "いぬ")
    rows = [candidate(), candidate()]
    dry = run(tmp_path, rows, dry=True)
    assert dry["counts"]["accepted"] == 1
    assert dry["counts"]["duplicate_candidates"] == 1
    assert KanaWordExample.objects.count() == 0
    run(tmp_path, rows)
    original = KanaWordExample.objects.get()
    run(tmp_path, rows)
    linked = KanaWordExample.objects.get()
    assert linked.pk == original.pk and linked.word_id == item.pk and linked.kana_id == kana.pk
    assert linked.provenance["review_status"] == "structural_match"
    assert "SCRAPED" not in json.dumps(linked.provenance)
    response = APIClient().get("/api/v1/dict/kana/い", {"lang": "fr"})
    assert response.status_code == 200
    example = response.json()["word_examples"][0]
    assert example["reading"] == "いぬ"
    assert example["glosses"] == [{"language": "en", "text": "canonical definition"}]
    assert response.json()["usage_examples"] == []
    assert "SCRAPED" not in response.content.decode()


def test_ambiguity_and_untraced_or_wrong_script_readings_are_quarantined(tmp_path):
    Kana.objects.create(char="あ", romaji="a", script="hiragana")
    word(101, "あめ")
    word(102, "あめ")
    word(103, "あか", source="demo")
    word(104, "アオ")
    report = run(
        tmp_path,
        [
            candidate("あめ", "あ"),
            candidate("あか", "あ"),
            candidate("あお", "あ"),
            candidate("犬", "あ"),
            candidate("いぬ", "あ"),
        ],
    )
    assert report["counts"]["quarantined"] == 5
    assert report["quarantine_reasons"]["ambiguous_dictionary_entries"] == 1
    assert KanaWordExample.objects.count() == 0


def test_new_ambiguity_withdraws_only_managed_lexical_links(tmp_path):
    kana = Kana.objects.create(char="あ", romaji="a", script="hiragana")
    first = word(101, "あめ")
    run(tmp_path, [candidate("あめ", "あ")])
    other = word(102, "あめ")
    custom = KanaWordExample.objects.create(
        kana=kana, word=other, reading="あめ", provenance={"source": "editorial"}
    )
    report = run(tmp_path, [candidate("あめ", "あ")])
    assert report["counts"]["withdrawn"] == 1
    assert not KanaWordExample.objects.filter(word=first).exists()
    assert KanaWordExample.objects.filter(pk=custom.pk).exists()


def test_alias_row_cannot_supply_a_canonical_reading(tmp_path):
    Kana.objects.create(char="い", romaji="i", script="hiragana")
    canonical = word(101, "いえ")
    alias = word(102, "いぬ")
    alias.canonical_word = canonical
    alias.save(update_fields=["canonical_word"])
    report = run(tmp_path, [candidate()])
    assert report["quarantine_reasons"] == {"no_exact_canonical_reading": 1}
    assert KanaWordExample.objects.count() == 0
