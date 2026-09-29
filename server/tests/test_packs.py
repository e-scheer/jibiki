"""SQLite content packs: build output and v3 manifest/file endpoints."""

import gzip
import hashlib
import json
import sqlite3

import pytest
from django.core.management import call_command
from django.db.models import Q

pytestmark = pytest.mark.django_db

VERSION = "2026.01.01"


def _build(out, *args):
    call_command("build_packs", "--out", str(out), "--version", VERSION, *args)


def _connect(out, gz_name):
    raw = gzip.decompress((out / gz_name).read_bytes())
    db = out / gz_name.removesuffix(".gz")
    db.write_bytes(raw)
    return sqlite3.connect(db)


def test_build_base_pack(seeded, tmp_path):
    from dictionary.models import Gloss, Kana, Kanji, Radical, Word

    _build(tmp_path, "--base")
    manifest = json.loads((tmp_path / "base_manifest.json").read_text(encoding="utf-8"))
    raw = gzip.decompress((tmp_path / "base.db.gz").read_bytes())
    assert manifest["sha256_db"] == hashlib.sha256(raw).hexdigest()
    assert manifest["installed_bytes"] == len(raw)
    conn = _connect(tmp_path, "base.db.gz")

    def count(table):
        return conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]

    word_q = Word.objects.filter(Q(is_common=True) | Q(jlpt__isnull=False))
    assert count("words") == word_q.count() > 0
    assert count("kanji") == Kanji.objects.filter(jlpt__isnull=False).count() > 0
    assert count("kana") == Kana.objects.count() > 0
    assert count("radicals") == Radical.objects.count() > 0
    gloss_q = Gloss.objects.filter(language__in=["en", "fr"], sense__word__in=word_q)
    assert count("glosses") == gloss_q.count() > 0

    meta = dict(conn.execute("SELECT key, value FROM meta"))
    assert meta["pack_id"] == "dict-base"
    assert meta["schema_version"] == "2"
    assert meta["content_type"] == "dictionary_base"
    assert json.loads(meta["languages"]) == ["en", "fr"]
    assert "JMdict" in json.loads(meta["attribution"])["words"]

    # words.id must be the server Word id - the SRS item_ref invariant.
    assert {r[0] for r in conn.execute("SELECT id FROM words")} == set(
        word_q.values_list("id", flat=True)
    )

    # FTS finds a known seed gloss (学生 → "student").
    hits = conn.execute("SELECT rowid FROM gloss_fts WHERE gloss_fts MATCH 'student'").fetchall()
    assert hits


def test_build_core_and_locale_packs(seeded, tmp_path):
    from dictionary.models import Gloss, Word

    _build(tmp_path, "--packs", "core,locale-en")
    manifest = json.loads((tmp_path / "packs_manifest.json").read_text(encoding="utf-8"))
    assert manifest["schema"] == "jibiki-packs/3"
    packs = {p["id"]: p for p in manifest["packs"]}
    assert set(packs) == {"dict-core", "dict-locale-en"}
    assert packs["dict-core"]["requires"] == []
    assert packs["dict-locale-en"]["requires"] == [{"id": "dict-core", "version": VERSION}]

    # kanji_words: dense ranks from 0, capped at 12, ordered by the words' own
    # ranking (is_common DESC, freq_rank ASC - the build-time precomputation).
    core = _connect(tmp_path, packs["dict-core"]["file"])
    linked = core.execute(
        "SELECT kw.kanji, kw.rank, w.is_common, COALESCE(w.freq_rank, 99999999), w.id"
        " FROM kanji_words kw JOIN words w ON w.id = kw.word_id ORDER BY kw.kanji, kw.rank"
    ).fetchall()
    assert linked
    by_kanji = {}
    for literal, rank, common, freq, wid in linked:
        by_kanji.setdefault(literal, []).append((rank, (-common, freq, wid)))
    for rows in by_kanji.values():
        assert len(rows) <= 12
        assert [rank for rank, _ in rows] == list(range(len(rows)))
        keys = [key for _, key in rows]
        assert keys == sorted(keys)

    # gloss pack rows join back onto core word ids: spot-check 食べる.
    gloss = _connect(tmp_path, packs["dict-locale-en"]["file"])
    word = Word.objects.get(forms__text="食べる")
    got = [
        text
        for (text,) in gloss.execute(
            "SELECT text FROM glosses WHERE word_id = ? AND language = 'en' ORDER BY ord",
            (word.id,),
        )
    ]
    expected = list(
        Gloss.objects.filter(sense__word=word, language="en")
        .order_by("sense__order", "order")
        .values_list("text", flat=True)
    )
    assert got == expected == ["to eat"]


def test_export_preserves_source_metadata_and_explicit_example_links(tmp_path):
    from dictionary.models import (
        ExampleSenseLink,
        ExampleSentence,
        ExampleTranslation,
        Gloss,
        Kana,
        KanaWordExample,
        Kanji,
        Name,
        Radical,
        Sense,
        Word,
        WordForm,
    )

    # Artificial fixtures verify transport, not linguistic correctness.
    evidence = {"source": "fixture", "snapshot": "test"}
    Radical.objects.create(literal="日", provenance=evidence)
    word = Word.objects.create(seq=123, is_common=True, provenance=evidence)
    form = WordForm.objects.create(word=word, text="かな", kind="kana", metadata={"no_kanji": True})
    sense = Sense.objects.create(
        word=word,
        metadata={"restricted_readings": ["かな"], "raw": {"gloss": "all source languages"}},
    )
    kana = Kana.objects.create(char="か", romaji="ka", script="hiragana")
    KanaWordExample.objects.create(kana=kana, word=word, reading="かな", provenance=evidence)
    excluded_word = Word.objects.create()
    KanaWordExample.objects.create(kana=kana, word=excluded_word, reading="fixture")
    gloss = Gloss.objects.create(
        sense=sense, language="fr", text="fixture gloss", metadata={"type": "literal"}
    )
    kanji = Kanji.objects.create(
        literal="日", jlpt=5, provenance=evidence, metadata={"legacy_jlpt": 4}
    )
    name = Name.objects.create(
        reading="かな", provenance=evidence, metadata={"references": ["fixture"]}
    )
    sentence = ExampleSentence.objects.create(
        japanese="fixture sentence", source_key="test:1", provenance=evidence
    )
    ExampleTranslation.objects.create(example=sentence, language="fr", text="fixture translation")
    ExampleSenseLink.objects.create(
        example=sentence,
        sense=sense,
        source="fixture",
        source_sense_order=0,
        text="かな",
        provenance=evidence,
    )
    unlinked = ExampleSentence.objects.create(japanese="かな unlinked substring")
    ExampleTranslation.objects.create(example=unlinked, language="fr", text="unlinked")
    _build(tmp_path, "--base")
    base = _connect(tmp_path, "base.db.gz")
    assert (
        json.loads(base.execute("SELECT provenance FROM words WHERE id=?", [word.id]).fetchone()[0])
        == evidence
    )
    assert (
        json.loads(
            base.execute("SELECT metadata FROM word_forms WHERE id=?", [form.id]).fetchone()[0]
        )
        == form.metadata
    )
    assert json.loads(
        base.execute("SELECT metadata FROM senses WHERE id=?", [sense.id]).fetchone()[0]
    ) == {"restricted_readings": ["かな"]}
    assert (
        json.loads(
            base.execute("SELECT metadata FROM glosses WHERE id=?", [gloss.id]).fetchone()[0]
        )
        == gloss.metadata
    )
    assert (
        json.loads(
            base.execute("SELECT metadata FROM kanji WHERE literal=?", [kanji.literal]).fetchone()[
                0
            ]
        )
        == kanji.metadata
    )
    assert base.execute("SELECT source_key FROM examples").fetchall() == [("test:1",)]
    assert base.execute(
        "SELECT example_id, sense_id, word_id FROM example_sense_links"
    ).fetchall() == [(sentence.id, sense.id, word.id)]
    assert json.loads(base.execute("SELECT provenance FROM examples").fetchone()[0]) == evidence
    assert (
        json.loads(base.execute("SELECT provenance FROM radicals WHERE literal='日'").fetchone()[0])
        == evidence
    )
    sense.refresh_from_db()
    assert "raw" in sense.metadata
    assert base.execute("SELECT kana, word_id, reading FROM kana_word_examples").fetchall() == [
        ("か", word.id, "かな")
    ]
    _build(tmp_path, "--packs", "names,examples-fr")
    manifest = json.loads((tmp_path / "packs_manifest.json").read_text(encoding="utf-8"))
    entries = {entry["id"]: entry for entry in manifest["packs"]}
    names = _connect(tmp_path, entries["names"]["file"])
    assert (
        json.loads(names.execute("SELECT metadata FROM names WHERE id=?", [name.id]).fetchone()[0])
        == name.metadata
    )
    examples = _connect(tmp_path, entries["examples-fr"]["file"])
    assert examples.execute("SELECT COUNT(*) FROM examples").fetchone()[0] == 2
    assert examples.execute("SELECT example_id FROM example_sense_links").fetchall() == [
        (sentence.id,)
    ]


def test_base_preserves_alias_ids_and_includes_uncommon_canonical_target(tmp_path):
    from dictionary.models import Gloss, Sense, Word, WordForm

    canonical = Word.objects.create(seq=999, is_common=False)
    WordForm.objects.create(word=canonical, text="fixture", kind="kana")
    sense = Sense.objects.create(word=canonical)
    Gloss.objects.create(sense=sense, language="en", text="canonical fixture")
    alias = Word.objects.create(seq=-999, is_common=True, canonical_word=canonical)
    WordForm.objects.create(word=alias, text="fixture", kind="kana")
    _build(tmp_path, "--base")
    base = _connect(tmp_path, "base.db.gz")
    assert base.execute("SELECT id, canonical_word_id FROM words ORDER BY id").fetchall() == [
        (canonical.id, None),
        (alias.id, canonical.id),
    ]
    assert base.execute("SELECT text FROM glosses WHERE word_id=?", [canonical.id]).fetchone() == (
        "canonical fixture",
    )


def test_build_french_mnemonic_pack_is_language_native(seeded, tmp_path):
    _build(tmp_path, "--packs", "mnemonics-fr")
    manifest = json.loads((tmp_path / "packs_manifest.json").read_text(encoding="utf-8"))
    entry = manifest["packs"][0]
    assert entry["id"] == "mnemonics-fr"
    assert entry["languages"] == ["fr"]

    conn = _connect(tmp_path, entry["file"])
    rows = conn.execute("SELECT character, language, story FROM mnemonics ORDER BY id").fetchall()
    assert len(rows) == 92
    assert {language for _, language, _ in rows} == {"fr"}
    stories = {character: story for character, _, story in rows}
    assert "quilles" in stories["き"]
    assert stories["き"] != stories["キ"]


def test_packs_manifest_and_file_endpoints(seeded, tmp_path, client, settings):
    _build(tmp_path / "packs", "--packs", "core")
    settings.CONTENT_PACK_DIR = str(tmp_path / "packs")

    resp = client.get("/api/v1/content/packs/manifest")
    assert resp.status_code == 200
    entry = resp.json()["packs"][0]
    name = entry["file"]
    blob = (tmp_path / "packs" / name).read_bytes()
    url = f"/api/v1/content/packs/file/{name}"

    full = client.get(url)
    assert full.status_code == 200
    assert full["Accept-Ranges"] == "bytes"
    assert b"".join(full.streaming_content) == blob

    part = client.get(url, HTTP_RANGE="bytes=0-99")
    assert part.status_code == 206
    assert part["Content-Range"] == f"bytes 0-99/{len(blob)}"
    assert part["Content-Length"] == "100"
    assert b"".join(part.streaming_content) == blob[:100]

    tail = client.get(url, HTTP_RANGE=f"bytes={len(blob) - 5}-")
    assert tail.status_code == 206
    assert b"".join(tail.streaming_content) == blob[-5:]

    assert client.get(url, HTTP_RANGE=f"bytes={len(blob)}-").status_code == 416
    # Multi/malformed ranges degrade to a full 200 body.
    weird = client.get(url, HTTP_RANGE="bytes=0-1,5-9")
    assert weird.status_code == 200
    assert b"".join(weird.streaming_content) == blob

    assert client.get("/api/v1/content/packs/file/nope.db.gz").status_code == 404


def test_invalid_manifest_is_not_served(tmp_path, client, settings):
    packs = tmp_path / "packs"
    packs.mkdir()
    settings.CONTENT_PACK_DIR = str(packs)
    (packs / "secret.db.gz").write_bytes(b"secret")
    (packs / "packs_manifest.json").write_text(
        json.dumps(
            {
                "schema": "jibiki-packs/3",
                "packs": [
                    {"id": "unsafe", "file": "../secret.db.gz", "requires": []},
                ],
            }
        ),
        encoding="utf-8",
    )

    assert client.get("/api/v1/content/packs/manifest").status_code == 503
    assert client.get("/api/v1/content/packs/file/secret.db.gz").status_code == 404
