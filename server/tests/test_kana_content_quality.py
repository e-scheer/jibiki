import hashlib
import json
from pathlib import Path

import pytest
from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.management import call_command

from dictionary.kana_seeding import set_kana_content
from dictionary.models import (
    Kana,
    KanaExplanation,
    KanaUsage,
    KanaUsageExample,
    KanaUsageExampleTranslation,
    KanaUsageTranslation,
)
from mnemonics.models import Mnemonic, MnemonicStatus
from mnemonics.seeds import load_kana_entries
from mnemonics.source_validation import load_kanji_brief

pytestmark = pytest.mark.django_db


def test_context_seed_preserves_other_languages_and_custom_examples():
    kana = Kana.objects.create(char="は", romaji="ha", script="hiragana", kind="gojuon")
    KanaExplanation.objects.create(kana=kana, language="fr", origin_note="Explication relue.")
    usage = KanaUsage.objects.create(kana=kana)
    KanaUsageTranslation.objects.create(
        usage=usage, language="fr", label="Thème", explanation="Texte français."
    )
    custom = KanaUsageExample.objects.create(
        usage=usage, order=0, before="山", particle="は", after="高い。"
    )
    KanaUsageExampleTranslation.objects.create(
        example=custom, language="fr", text="La montagne est haute."
    )
    call_command("seed_kana_context")
    call_command("seed_kana_context")
    assert kana.explanations.get(language="fr").origin_note == "Explication relue."
    assert usage.translations.get(language="fr").label == "Thème"
    custom.refresh_from_db()
    assert custom.before == "山"
    assert usage.examples.count() == 3
    assert custom.translations.get(language="fr").text == "La montagne est haute."


def test_same_japanese_example_keeps_identity_and_translations():
    kana = Kana.objects.create(char="を", romaji="wo", script="hiragana")
    usage = KanaUsage.objects.create(kana=kana)
    example = KanaUsageExample.objects.create(
        usage=usage, order=2, before="水", particle="を", after="飲む。"
    )
    KanaUsageExampleTranslation.objects.create(
        example=example, language="fr", text="Boire de l’eau."
    )
    item = {
        "before": "水",
        "particle": "を",
        "after": "飲む。",
        "romaji": "Mizu o nomu.",
        "en": "Drink water.",
    }
    set_kana_content(kana, "", "Object", "Object marker", [item])
    assert usage.examples.count() == 1
    assert example.translations.count() == 2


def _kana_source(tmp_path):
    source = Path(settings.CONTENT_SOURCE_DIR) / "mnemonics/kana_stories.json"
    data = json.loads(source.read_text(encoding="utf-8"))
    path = tmp_path / "kana.json"
    return data, path


@pytest.mark.parametrize(
    "change", ["wrong_romaji", "small_kana", "fake_language", "duplicate_language"]
)
def test_kana_catalogue_rejects_false_completeness(tmp_path, change):
    data, path = _kana_source(tmp_path)
    if change == "wrong_romaji":
        data["entries"][0]["romaji"] = "wrong"
    elif change == "small_kana":
        data["entries"][0]["character"] = "ぁ"
    elif change == "fake_language":
        data["languages"] = ["zz"]
    else:
        data["languages"] = ["en", "en"]
    path.write_text(json.dumps(data), encoding="utf-8")
    with pytest.raises(ValidationError):
        load_kana_entries(path)


def test_review_claim_requires_evidence_for_exact_language_and_story(tmp_path):
    data, path = _kana_source(tmp_path)
    data["entries"][0]["reviews"] = {"en": {"status": "verified"}}
    path.write_text(json.dumps(data), encoding="utf-8")
    with pytest.raises(ValidationError, match="reviewer"):
        load_kana_entries(path)
    story = data["entries"][0]["en"]
    data["entries"][0]["reviews"]["en"].update(
        {
            "reviewer": "test-reviewer",
            "reviewed_at": "2026-09-06",
            "story_sha256": hashlib.sha256(story.encode()).hexdigest(),
        }
    )
    path.write_text(json.dumps(data), encoding="utf-8")
    entry = load_kana_entries(path)[0]
    assert entry["_provenance"]["en"]["review_status"] == "verified"
    assert entry["_provenance"]["fr"]["review_status"] == "unverified"
    data["entries"][0]["en"] += " Changed."
    path.write_text(json.dumps(data), encoding="utf-8")
    with pytest.raises(ValidationError, match="checksum"):
        load_kana_entries(path)


def test_seed_rerun_preserves_hidden_status_and_anonymized_user_content():
    personal = Mnemonic.objects.create(
        character="あ", kind="kana", language="en", story="Personal", author=None, is_seed=False
    )
    call_command("seed_kana_mnemonics")
    seed = Mnemonic.objects.get(character="あ", kind="kana", language="en", is_seed=True)
    assert seed.status == MnemonicStatus.PENDING
    seed.status = MnemonicStatus.HIDDEN
    seed.save()
    call_command("seed_kana_mnemonics")
    seed.refresh_from_db()
    personal.refresh_from_db()
    assert seed.status == MnemonicStatus.HIDDEN
    assert personal.story == "Personal"
    assert seed.provenance["story_sha256"] == hashlib.sha256(seed.story.encode()).hexdigest()


@pytest.mark.parametrize("problem", ["count", "duplicate", "reading", "language"])
def test_kanji_briefs_validate_targets_and_counts(tmp_path, problem):
    entry = {
        "literal": "山",
        "reading": "サン",
        "en": "Sun by the mountain.",
        "fr": "Sans la montagne.",
    }
    data = {
        "schema": "jibiki-kanji-reading-briefs/1",
        "strategy": "phonetic_reading",
        "languages": ["en", "fr"],
        "count": 1,
        "kanji": [entry],
    }
    if problem == "count":
        data["count"] = 2
    elif problem == "duplicate":
        data["kanji"] *= 2
        data["count"] = 2
    elif problem == "reading":
        entry["reading"] = "sun"
    else:
        data["languages"] = ["xx"]
    path = tmp_path / "reading.json"
    path.write_text(json.dumps(data), encoding="utf-8")
    with pytest.raises(ValidationError):
        load_kanji_brief(path, reading=True)


def test_changed_visible_seed_requires_review_but_unchanged_legacy_stays_visible():
    from mnemonics.seeds import install_kana_entries

    source = Path(settings.CONTENT_SOURCE_DIR) / "mnemonics/kana_stories.json"
    entries = load_kana_entries(source)
    install_kana_entries(entries)
    seed = Mnemonic.objects.get(character="あ", language="en", is_seed=True)
    seed.status = MnemonicStatus.VISIBLE
    seed.save()
    install_kana_entries(entries)
    seed.refresh_from_db()
    assert seed.status == MnemonicStatus.VISIBLE
    seed.story = "Earlier published story."
    seed.save()
    install_kana_entries(entries)
    seed.refresh_from_db()
    assert seed.status == MnemonicStatus.PENDING
