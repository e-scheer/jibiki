"""Language-native kana seed catalogue and installer."""

import json
from pathlib import Path

import pytest
from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.management import call_command

from mnemonics.models import Mnemonic, MnemonicDeck
from mnemonics.seeds import load_kana_entries

pytestmark = pytest.mark.django_db


def _source() -> Path:
    return Path(settings.CONTENT_SOURCE_DIR) / "mnemonics" / "kana_stories.json"


def test_catalogue_covers_each_basic_glyph_in_both_languages():
    entries = load_kana_entries(_source())
    assert len(entries) == 92
    assert len({entry["character"] for entry in entries}) == 92
    assert all(entry["en"] != entry["fr"] for entry in entries)


def test_catalogue_rejects_a_story_reused_across_languages(tmp_path):
    data = json.loads(_source().read_text(encoding="utf-8"))
    data["entries"][0]["fr"] = data["entries"][0]["en"]
    path = tmp_path / "invalid.json"
    path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")

    with pytest.raises(ValidationError, match="reuses the same story"):
        load_kana_entries(path)


def test_seed_creates_distinct_hiragana_and_katakana_stories():
    call_command("seed_kana_mnemonics")

    assert Mnemonic.objects.filter(kind="kana", is_seed=True).count() == 184
    assert MnemonicDeck.objects.filter(kind="kana", is_seed=True).count() == 2
    assert all(deck.items.count() == 92 for deck in MnemonicDeck.objects.all())

    hira_fr = Mnemonic.objects.get(character="き", language="fr", is_seed=True)
    kata_fr = Mnemonic.objects.get(character="キ", language="fr", is_seed=True)
    assert "quilles" in hira_fr.story
    assert hira_fr.story != kata_fr.story
    assert "き" in hira_fr.story
    assert "キ" in kata_fr.story


def test_seed_is_idempotent_and_dry_run_does_not_write():
    call_command("seed_kana_mnemonics", "--dry-run")
    assert not Mnemonic.objects.exists()

    call_command("seed_kana_mnemonics")
    call_command("seed_kana_mnemonics")
    assert Mnemonic.objects.filter(kind="kana", is_seed=True).count() == 184
