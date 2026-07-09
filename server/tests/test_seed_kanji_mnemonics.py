"""seed_kanji_mnemonics: turns the generated meaning briefs into per-language
seed Mnemonic rows, idempotently."""

import json

import pytest
from django.core.management import call_command

from mnemonics.models import Mnemonic, MnemonicStatus


def _write_brief(content_dir, level, entries):
    doc = {
        "schema": "jibiki-kanji-meaning-briefs/1",
        "count": len(entries),
        "kanji": entries,
    }
    (content_dir / f"kanji_meaning_briefs.{level}.json").write_text(
        json.dumps(doc, ensure_ascii=False), encoding="utf-8"
    )


@pytest.fixture
def brief_dir(tmp_path, settings):
    settings.CONTENT_PACK_DIR = str(tmp_path)
    return tmp_path


def test_seeds_one_visible_row_per_language(db, brief_dir):
    _write_brief(
        brief_dir,
        "n5",
        [
            {"literal": "日", "meaning": "sun", "components": ["日"], "kind": "pictogram",
             "en": "A round sun: the day.", "fr": "Un soleil rond : le jour."},
        ],
    )
    call_command("seed_kanji_mnemonics", "--levels", "n5")

    rows = Mnemonic.objects.filter(character="日", kind="kanji", is_seed=True)
    assert rows.count() == 2
    en = rows.get(language="en")
    fr = rows.get(language="fr")
    assert en.story == "A round sun: the day."
    assert fr.story == "Un soleil rond : le jour."
    assert en.status == MnemonicStatus.VISIBLE
    assert en.author_id is None


def test_idempotent_and_updates_in_place(db, brief_dir):
    _write_brief(
        brief_dir, "n5",
        [{"literal": "山", "meaning": "mountain", "components": ["山"], "kind": "pictogram",
          "en": "Three peaks: a mountain.", "fr": "Trois pics : une montagne."}],
    )
    call_command("seed_kanji_mnemonics", "--levels", "n5")
    call_command("seed_kanji_mnemonics", "--levels", "n5")  # re-run: no dup
    assert Mnemonic.objects.filter(character="山", kind="kanji", is_seed=True).count() == 2

    # Regenerating the brief with a new story updates the same row.
    _write_brief(
        brief_dir, "n5",
        [{"literal": "山", "meaning": "mountain", "components": ["山"], "kind": "pictogram",
          "en": "A ridge of three summits: mountain.", "fr": "Trois sommets : la montagne."}],
    )
    call_command("seed_kanji_mnemonics", "--levels", "n5")
    rows = Mnemonic.objects.filter(character="山", kind="kanji", is_seed=True)
    assert rows.count() == 2
    assert rows.get(language="en").story == "A ridge of three summits: mountain."


def test_dry_run_writes_nothing(db, brief_dir):
    _write_brief(
        brief_dir, "n5",
        [{"literal": "川", "meaning": "river", "components": ["川"], "kind": "pictogram",
          "en": "Three flowing lines: a river.", "fr": "Trois lignes qui coulent : une riviere."}],
    )
    call_command("seed_kanji_mnemonics", "--levels", "n5", "--dry-run")
    assert Mnemonic.objects.filter(kind="kanji", is_seed=True).count() == 0


def test_rejects_dash_in_story(db, brief_dir):
    from django.core.management.base import CommandError

    em_dash = chr(0x2014)  # the forbidden em dash, built from its code point
    _write_brief(
        brief_dir, "n5",
        [{"literal": "水", "meaning": "water", "components": ["水"], "kind": "pictogram",
          "en": f"Water flowing {em_dash} everywhere.", "fr": "L'eau qui coule."}],
    )
    with pytest.raises(CommandError):
        call_command("seed_kanji_mnemonics", "--levels", "n5")
