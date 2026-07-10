"""seed_kanji_readings: reading briefs become per-language kind='kanji_reading'
seed Mnemonic rows carrying the on-yomi they anchor."""

import json

import pytest
from django.core.management import call_command

from mnemonics.models import Mnemonic, MnemonicStatus


def _write_brief(content_dir, level, entries):
    doc = {"schema": "jibiki-kanji-reading-briefs/1", "count": len(entries), "kanji": entries}
    (content_dir / f"kanji_reading_briefs.{level}.json").write_text(
        json.dumps(doc, ensure_ascii=False), encoding="utf-8"
    )


@pytest.fixture
def brief_dir(tmp_path, settings):
    settings.CONTENT_PACK_DIR = str(tmp_path)
    return tmp_path


def test_seeds_reading_rows_with_reading_field(db, brief_dir):
    _write_brief(
        brief_dir, "n5",
        [{"literal": "山", "reading": "サン", "meaning": "mountain",
          "en": "The sun (サン) behind the mountain.", "fr": "Le soleil sans (サン) nuage sur la montagne."}],
    )
    call_command("seed_kanji_readings", "--levels", "n5")

    rows = Mnemonic.objects.filter(character="山", kind="kanji_reading", is_seed=True)
    assert rows.count() == 2
    en = rows.get(language="en")
    assert en.reading == "サン"
    assert en.status == MnemonicStatus.VISIBLE
    assert en.author_id is None
    # A reading mnemonic never collides with the meaning mnemonic for 山.
    assert not Mnemonic.objects.filter(character="山", kind="kanji").exists()


def test_idempotent_and_updates_in_place(db, brief_dir):
    _write_brief(
        brief_dir, "n5",
        [{"literal": "人", "reading": "ジン", "meaning": "person",
          "en": "A person with gin (ジン).", "fr": "Une personne, un djinn (ジン)."}],
    )
    call_command("seed_kanji_readings", "--levels", "n5")
    call_command("seed_kanji_readings", "--levels", "n5")
    assert Mnemonic.objects.filter(character="人", kind="kanji_reading", is_seed=True).count() == 2

    _write_brief(
        brief_dir, "n5",
        [{"literal": "人", "reading": "ジン", "meaning": "person",
          "en": "Down a cold gin (ジン): a person unwinds.", "fr": "Une personne, un djinn (ジン)."}],
    )
    call_command("seed_kanji_readings", "--levels", "n5")
    rows = Mnemonic.objects.filter(character="人", kind="kanji_reading", is_seed=True)
    assert rows.count() == 2
    assert rows.get(language="en").story.startswith("Down a cold gin")


def test_serializer_exposes_reading(db):
    from mnemonics.serializers import MnemonicSerializer

    m = Mnemonic.objects.create(
        character="日", kind="kanji_reading", language="en", reading="ニチ",
        story="A dog in its niche (ニチ).", status=MnemonicStatus.VISIBLE, is_seed=True,
    )
    data = MnemonicSerializer(m).data
    assert data["reading"] == "ニチ"
    assert data["kind"] == "kanji_reading"
