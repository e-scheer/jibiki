"""Extract useful normalized files from Kanjium's kanjidb.sqlite.

This is intentionally downstream-facing: it produces files that are immediately
useful for the current repo, including an ``accents.txt`` compatible with
``python manage.py import_pitch``.

Outputs:

- ``accents.txt``: ``term<TAB>reading<TAB>pitch``
- ``edict_headwords.jsonl``
- ``kanjidict.jsonl``
- ``elements.jsonl``
- ``summary.json``
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--db",
        default="var/source_harvest/upstreams/kanjium/data/kanjidb.sqlite",
        help="Path to Kanjium's SQLite database.",
    )
    parser.add_argument(
        "--out-dir",
        default="var/source_harvest/upstreams/kanjium/normalized",
        help="Directory to write normalized exports into.",
    )
    args = parser.parse_args()

    db_path = Path(args.db)
    if not db_path.exists():
        raise SystemExit(f"missing db: {db_path}")

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(db_path.resolve().as_uri() + "?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row

    accents_count = export_accents(conn, out_dir / "accents.txt")
    edict_count = export_jsonl(
        conn,
        "select kanji, reading, okurigana, acc_pos, meaning, grade, jlpt, frequency, wanikani, particles, type from edict",
        out_dir / "edict_headwords.jsonl",
    )
    kanjidict_count = export_jsonl(
        conn,
        (
            "select kanji, radical, radvar, phonetic, idc, type, reg_on, reg_kun, onyomi, kunyomi, "
            "nanori, strokes, grade, jlpt, kanken, frequency, meaning, compact_meaning, "
            "rtk1_3_old, rtk1_3_new, ko2001, ko2301, wrp_jkf, wanikani from kanjidict"
        ),
        out_dir / "kanjidict.jsonl",
    )
    elements_count = export_jsonl(
        conn,
        "select kanji, strokes, grade, idc, elements, extra_elements, kanji_parts, part_of, compact_meaning from elements",
        out_dir / "elements.jsonl",
    )

    summary = {
        "schema": "jibiki-kanjium-normalized/2",
        "source_db": str(db_path.resolve()),
        "source_sha256": hashlib.sha256(db_path.read_bytes()).hexdigest(),
        "extractor_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "output_sha256": {
            name: hashlib.sha256((out_dir / name).read_bytes()).hexdigest()
            for name in (
                "accents.txt",
                "edict_headwords.jsonl",
                "kanjidict.jsonl",
                "elements.jsonl",
            )
        },
        "outputs": {
            "accents.txt": accents_count,
            "edict_headwords.jsonl": edict_count,
            "kanjidict.jsonl": kanjidict_count,
            "elements.jsonl": elements_count,
        },
    }
    (out_dir / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {out_dir}")
    return 0


def export_accents(conn: sqlite3.Connection, path: Path) -> int:
    seen: set[tuple[str, str, str]] = set()
    count = 0
    with path.open("w", encoding="utf-8", newline="") as handle:
        for kanji, reading, surface, pitch in conn.execute(
            "select kanji, reading, okurigana, acc_pos from edict where acc_pos is not null and acc_pos != ''"
        ):
            # Despite its name, `okurigana` contains the complete written word
            # (e.g. 上げる). `kanji` alone is only 上 for that record.
            row = (surface or kanji or reading or "", reading or "", pitch or "")
            if row in seen or not row[1] or not row[2]:
                continue
            seen.add(row)
            handle.write(f"{row[0]}\t{row[1]}\t{row[2]}\n")
            count += 1
    return count


def export_jsonl(conn: sqlite3.Connection, query: str, path: Path) -> int:
    count = 0
    with path.open("w", encoding="utf-8", newline="") as handle:
        for row in conn.execute(query):
            payload = {key: row[key] for key in row.keys()}
            handle.write(json.dumps(payload, ensure_ascii=False) + "\n")
            count += 1
    return count


if __name__ == "__main__":
    raise SystemExit(main())
