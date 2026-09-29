import json
import sqlite3
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from audit_source_corpus import build_catalogue, content_issues, entity_identity


def test_catalogue_preserves_conflicting_evidence_without_merging_it(tmp_path):
    root, out = tmp_path / "extract", tmp_path / "audit"
    records = []
    for site, strokes in (("a", 3), ("b", 4)):
        folder = root / site
        folder.mkdir(parents=True)
        record = {"site": site, "url": f"https://example.test/{site}", "page_type": "kanji",
                  "record_index": 0, "site_fields": {"character": "下", "stroke_count": strokes},
                  "provenance": {"character": {"license_class": "factual", "ship": "allowed"}}}
        raw = (json.dumps(record, ensure_ascii=False) + "\n").encode()
        (folder / "pages.jsonl").write_bytes(raw)
        records.append(raw)
    report = build_catalogue(root, out)
    assert report["record_count"] == 2
    assert report["entity_count"] == 1
    assert report["disagreements"] == {"stroke_count": 1}
    db = sqlite3.connect(out / "corpus.sqlite")
    try:
        assert [zlib.decompress(row[0]) for row in db.execute("SELECT payload_zlib FROM records ORDER BY id")] == records
        assert db.execute("SELECT DISTINCT ship FROM fields WHERE name='stroke_count'").fetchall() == [("reference-only",)]
        assert db.execute("SELECT DISTINCT review_status FROM records").fetchall() == [("unverified",)]
    finally:
        db.close()


def test_catalogue_rejects_invalid_spans_and_keeps_homographs_source_scoped():
    assert list(content_issues({"text": "same same", "spans": [{"text": "same", "start": 3, "end": 7}]}))
    first = {"site": "a", "url": "https://example.test/1", "page_type": "word",
             "site_fields": {"character": "生", "word_id": 1}}
    second = {**first, "url": "https://example.test/2"}
    assert entity_identity(first) != entity_identity(second)
