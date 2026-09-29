"""Build a lossless, searchable staging catalogue and audit every extracted row.

The catalogue does not promote scraped prose into published dictionary facts.
Each source assertion keeps its own identity, provenance, original payload and
review state. Cross-source disagreements are review candidates, not majority
votes. Run after extract_mirrored_content.py, then import authoritative upstream
datasets through the Django commands.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
import unicodedata
import zlib
from collections import Counter
from datetime import UTC, datetime
from pathlib import Path

ENVELOPE_FIELDS = {"page_type", "entity_key", "dedupe_key", "source_url", "parse_notes"}

def encode(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def content_issues(value, path=""):
    if isinstance(value, dict):
        if isinstance(value.get("text"), str) and isinstance(value.get("spans"), list):
            text = value["text"]
            for index, span in enumerate(value["spans"]):
                if not isinstance(span, dict):
                    yield f"{path}.spans[{index}]", "invalid_span"
                    continue
                start, end = span.get("start"), span.get("end")
                if (type(start) is not int or type(end) is not int
                        or not 0 <= start <= end <= len(text)
                        or text[start:end] != span.get("text")):
                    yield f"{path}.spans[{index}]", "invalid_span"
        for key, child in value.items():
            yield from content_issues(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from content_issues(child, f"{path}[{index}]")
    elif isinstance(value, str) and "\ufffd" in value:
        yield path, "replacement_character"


def entity_identity(record):
    fields = record["site_fields"]
    kind = str(fields.get("record_type") or fields.get("entry_kind") or record.get("page_type") or "unknown")
    character = fields.get("character")
    if isinstance(character, str) and len(character) == 1 and "kanji" in kind:
        return "kanji", unicodedata.normalize("NFC", character)
    if isinstance(character, str) and "kana" in kind:
        return "kana", unicodedata.normalize("NFC", character)
    # Website IDs are not JMdict sequence IDs. Do not merge homographs by their
    # written form or confuse site-local IDs with canonical dictionary identity.
    return kind, f'{record["site"]}:{record["url"]}#{record.get("record_index", 0)}'


def build_catalogue(extract_root: Path, output: Path):
    output.mkdir(parents=True, exist_ok=True)
    database = output / "corpus.sqlite"
    temporary = output / "corpus.building.sqlite"
    if temporary.exists():
        raise ValueError(f"Unfinished catalogue exists: {temporary}. Use another output directory.")
    report = {"schema": "jibiki-source-quality/1", "generated_at": datetime.now(UTC).isoformat(),
              "extract_root": str(extract_root.resolve()), "sites": {},
              "policy": "staging_only; preserved source assertions are not verified facts"}
    db = sqlite3.connect(temporary)
    db.executescript('''
      CREATE TABLE records(id INTEGER PRIMARY KEY, site TEXT NOT NULL, url TEXT NOT NULL,
        record_index INTEGER NOT NULL, kind TEXT NOT NULL, entity_key TEXT NOT NULL,
        source_file TEXT NOT NULL, source_line INTEGER NOT NULL, sha256 TEXT NOT NULL,
        review_status TEXT NOT NULL DEFAULT 'unverified', payload_zlib BLOB NOT NULL);
      CREATE INDEX record_entity ON records(kind,entity_key);
      CREATE INDEX record_source ON records(site,url,record_index);
      CREATE TABLE fields(record_id INTEGER NOT NULL, name TEXT NOT NULL, populated INTEGER NOT NULL,
        license_class TEXT, ship TEXT NOT NULL, method TEXT, source_url TEXT);
      CREATE INDEX field_review ON fields(ship,name);
      CREATE TABLE assertions(record_id INTEGER NOT NULL, entity_key TEXT NOT NULL,
        name TEXT NOT NULL, value TEXT NOT NULL);
      CREATE INDEX assertion_entity ON assertions(entity_key,name);
    ''')
    issue_path = output / "issues.jsonl"
    try:
        with issue_path.open("w", encoding="utf-8") as issues:
            for source in sorted(extract_root.glob("*/pages.jsonl")):
                counts, defects, types, field_counts = Counter(), Counter(), Counter(), Counter()
                digest = hashlib.sha256()
                with source.open("rb") as handle:
                    for line_number, raw in enumerate(handle, 1):
                        digest.update(raw)
                        if not raw.strip():
                            continue
                        counts["rows"] += 1

                        def issue(code, path="", url=None):
                            defects[code] += 1
                            issues.write(encode({"source": str(source), "line": line_number,
                                                 "url": url, "code": code, "path": path}) + "\n")

                        try:
                            record = json.loads(raw)
                            fields = record["site_fields"]
                            if not isinstance(fields, dict) or not record.get("site") or not record.get("url"):
                                raise ValueError("Missing record identity or field object")
                        except (ValueError, KeyError, TypeError) as error:
                            issue("invalid_record", str(error))
                            continue
                        kind, key = entity_identity(record)
                        types[kind] += 1
                        cursor = db.execute("INSERT INTO records(site,url,record_index,kind,entity_key,"
                                            "source_file,source_line,sha256,payload_zlib) VALUES (?,?,?,?,?,?,?,?,?)",
                                            (record["site"], record["url"], record.get("record_index", 0),
                                             kind, key, str(source.resolve()), line_number,
                                             hashlib.sha256(raw).hexdigest(), zlib.compress(raw, level=1)))
                        record_id = cursor.lastrowid
                        stamps = record.get("provenance") or {}
                        for name, value in fields.items():
                            stamp = stamps.get(name) or {}
                            structural = name in ENVELOPE_FIELDS
                            populated = value is not None and value != "" and value != [] and value != {}
                            field_counts[f"{name}:present" if populated else f"{name}:empty"] += 1
                            if not stamp and not structural:
                                issue("missing_field_provenance", name, record["url"])
                            # Missing provenance is never interpreted as permission.
                            ship = stamp.get("ship", "reference-only")
                            db.execute("INSERT INTO fields VALUES (?,?,?,?,?,?,?)", (record_id, name,
                                       int(populated), stamp.get("license_class"), ship,
                                       stamp.get("method"), stamp.get("source_url")))
                            if ship == "reference-only" and populated and not structural:
                                counts["reference_only_fields"] += 1
                        for path, code in content_issues(fields):
                            issue(code, path, record["url"])
                        if kind == "kanji":
                            for name in ("stroke_count", "jlpt_level"):
                                value = fields.get(name)
                                if value is not None:
                                    db.execute("INSERT INTO assertions VALUES (?,?,?,?)",
                                               (record_id, key, name, encode(value)))
                        counts["catalogued"] += 1
                        if counts["rows"] % 5000 == 0:
                            db.commit()
                            print(f"{source.parent.name}: {counts['rows']} rows", flush=True)
                report["sites"][source.parent.name] = {"counts": dict(counts), "issues": dict(defects),
                    "types": dict(types), "field_coverage": dict(field_counts),
                    "sha256": digest.hexdigest(), "bytes": source.stat().st_size}
        disagreements = []
        for entity, name, variants in db.execute('''SELECT entity_key,name,count(DISTINCT value)
              FROM assertions GROUP BY entity_key,name HAVING count(DISTINCT value)>1'''):
            evidence = [dict(zip(("site", "url", "value"), row)) for row in db.execute('''
              SELECT r.site,r.url,a.value FROM assertions a JOIN records r ON r.id=a.record_id
              WHERE a.entity_key=? AND a.name=?''', (entity, name))]
            disagreements.append({"entity": entity, "field": name, "variants": variants, "evidence": evidence})
        (output / "disagreements.json").write_text(encode(disagreements) + "\n", encoding="utf-8")
        report["disagreements"] = dict(Counter(item["field"] for item in disagreements))
        report["record_count"] = db.execute("SELECT count(*) FROM records").fetchone()[0]
        report["entity_count"] = db.execute("SELECT count(*) FROM (SELECT kind,entity_key FROM records GROUP BY kind,entity_key)").fetchone()[0]
        db.commit()
        report["sqlite_integrity"] = db.execute("PRAGMA integrity_check").fetchone()[0]
    finally:
        db.close()
    if report["sqlite_integrity"] != "ok":
        raise ValueError("Catalogue integrity check failed")
    temporary.replace(database)
    (output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--extract-root", type=Path, default=Path("var/site_extract"))
    parser.add_argument("--out", type=Path, default=Path("var/audit/source-corpus"))
    args = parser.parse_args()
    print(encode(build_catalogue(args.extract_root, args.out)))


if __name__ == "__main__":
    main()
