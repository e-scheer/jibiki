"""SQLite content packs: build_packs output + the v2 manifest/file endpoints."""

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
    gloss_q = Gloss.objects.filter(lang__in=["en", "fr"], sense__word__in=word_q)
    assert count("glosses") == gloss_q.count() > 0

    meta = dict(conn.execute("SELECT key, value FROM meta"))
    assert meta["pack_id"] == "dict-base"
    assert meta["schema_version"] == "1"
    assert json.loads(meta["languages"]) == ["en", "fr"]
    assert "JMdict" in json.loads(meta["attribution"])["words"]

    # words.id must be the server Word id - the SRS item_ref invariant.
    assert {r[0] for r in conn.execute("SELECT id FROM words")} == set(
        word_q.values_list("id", flat=True)
    )

    # FTS finds a known seed gloss (学生 → "student").
    hits = conn.execute("SELECT rowid FROM gloss_fts WHERE gloss_fts MATCH 'student'").fetchall()
    assert hits


def test_build_core_and_gloss_packs(seeded, tmp_path):
    from dictionary.models import Gloss, Word

    _build(tmp_path, "--packs", "core,gloss-en")
    manifest = json.loads((tmp_path / "packs_manifest.json").read_text(encoding="utf-8"))
    assert manifest["schema"] == "jibiki-packs/2"
    packs = {p["id"]: p for p in manifest["packs"]}
    assert set(packs) == {"dict-core", "gloss-en"}
    assert packs["dict-core"]["requires"] == []
    assert packs["gloss-en"]["requires"] == [{"id": "dict-core", "version": VERSION}]

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
    gloss = _connect(tmp_path, packs["gloss-en"]["file"])
    word = Word.objects.get(forms__text="食べる")
    got = [
        text
        for (text,) in gloss.execute(
            "SELECT text FROM glosses WHERE word_id = ? AND lang = 'en' ORDER BY ord", (word.id,)
        )
    ]
    expected = list(
        Gloss.objects.filter(sense__word=word, lang="en")
        .order_by("sense__order", "order")
        .values_list("text", flat=True)
    )
    assert got == expected == ["to eat"]


def test_packs_manifest_and_file_endpoints(seeded, tmp_path, client, settings):
    _build(tmp_path / "packs", "--packs", "core")
    settings.CONTENT_PACK_DIR = str(tmp_path)

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
