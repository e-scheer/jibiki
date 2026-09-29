import gzip
import hashlib
import json
import sqlite3

import pytest
from django.core.management import call_command
from django.core.management.base import CommandError

from contentpacks.schema import CORE_TABLES, LOCALIZED_TABLES
from dictionary.models import Gloss, Sense, Word, WordForm


@pytest.fixture
def snapshot(tmp_path):
    path = tmp_path / "base.db"
    db = sqlite3.connect(path)
    for sql in [*CORE_TABLES, *LOCALIZED_TABLES]:
        db.execute(sql)
    db.execute("INSERT INTO words(id,seq,headword,primary_reading) VALUES (20,100,'水','みず')")
    db.execute("INSERT INTO word_forms(id,word_id,text,kind) VALUES (1,20,'みず',1)")
    db.execute("INSERT INTO senses(id,word_id,ord) VALUES (1,20,0)")
    db.execute(
        "INSERT INTO glosses(id,sense_id,word_id,language,ord,text,word_rank,word_common) "
        "VALUES (1,1,20,'en',0,'water',0,0)"
    )
    db.commit()
    db.close()
    raw = path.read_bytes()
    data = gzip.compress(raw)
    pack = tmp_path / "base.db.gz"
    pack.write_bytes(data)
    manifest = tmp_path / "manifest.json"
    manifest.write_text(
        json.dumps(
            {
                "sha256": hashlib.sha256(data).hexdigest(),
                "sha256_db": hashlib.sha256(raw).hexdigest(),
            }
        )
    )
    return pack, manifest


@pytest.mark.django_db
def test_restore_preserves_word_id_and_handles_unrelated_child_ids(snapshot):
    existing = Word.objects.create(id=1, seq=-1)
    WordForm.objects.create(id=1, word=existing, kind="kana", text="ねこ")
    sense = Sense.objects.create(id=1, word=existing)
    Gloss.objects.create(id=1, sense=sense, text="cat")
    pack, manifest = snapshot
    call_command("restore_base_pack", pack, manifest=manifest, apply=True)
    assert Word.objects.get(id=20).seq == 100
    assert Gloss.objects.get(sense__word_id=20).text == "water"
    assert WordForm.objects.get(id=1).text == "ねこ"
    call_command("restore_base_pack", pack, manifest=manifest, apply=True)
    assert Word.objects.count() == 2
    assert Gloss.objects.count() == 2


@pytest.mark.django_db
def test_restore_dry_run_and_identity_conflict_leave_database_unchanged(snapshot):
    pack, manifest = snapshot
    call_command("restore_base_pack", pack, manifest=manifest)
    assert not Word.objects.exists()
    Word.objects.create(id=20, seq=999)
    with pytest.raises(CommandError, match="identity conflict"):
        call_command("restore_base_pack", pack, manifest=manifest, apply=True)
    assert Word.objects.get(id=20).seq == 999
    assert not Gloss.objects.exists()


@pytest.mark.django_db
def test_restore_refuses_tampered_pack(snapshot):
    pack, manifest = snapshot
    pack.write_bytes(pack.read_bytes() + b"tamper")
    with pytest.raises(CommandError, match="checksum"):
        call_command("restore_base_pack", pack, manifest=manifest, apply=True)
    assert not Word.objects.exists()
