"""Download and normalize Kanji Alive's openly licensed CSV data.

Kanji Alive publishes a CC BY 4.0 GitHub repository with kanji/radical data and
media mappings. This script intentionally targets the public repository instead
of scraping rendered site pages.

Outputs are written under ``var/sources/kanjialive/`` by default:

- ``raw/ka_data.csv``
- ``raw/japanese-radicals.csv``
- ``kanji_alive.json``
"""

from __future__ import annotations

import argparse
import csv
import json
import urllib.request
from pathlib import Path
from typing import Any

KANJI_ALIVE_BASE = (
    "https://raw.githubusercontent.com/kanjialive/kanji-data-media/master/language-data"
)
USER_AGENT = "jibiki-source-fetcher/0.1 (+personal educational project)"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--out-dir",
        default="var/sources/kanjialive",
        help="Directory to write raw and normalized files into.",
    )
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    raw_dir = out_dir / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)

    ka_csv = raw_dir / "ka_data.csv"
    radicals_csv = raw_dir / "japanese-radicals.csv"

    download(f"{KANJI_ALIVE_BASE}/ka_data.csv", ka_csv)
    download(f"{KANJI_ALIVE_BASE}/japanese-radicals.csv", radicals_csv)

    radicals = load_radicals(radicals_csv)
    kanji = load_kanji(ka_csv, radicals)

    payload = {
        "schema": "jibiki-kanji-alive-open-data/1",
        "source": {
            "id": "kanjialive_repo",
            "name": "Kanji Alive GitHub data repository",
            "license": "CC BY 4.0",
            "base_url": "https://github.com/kanjialive/kanji-data-media",
            "notes": [
                "Published data excludes mnemonic hints for copyright reasons.",
                "Use this as structured enrichment, not as a substitute for proprietary editorials.",
            ],
        },
        "counts": {
            "kanji": len(kanji),
            "radicals": len(radicals),
        },
        "radicals": radicals,
        "kanji": kanji,
    }

    out_path = out_dir / "kanji_alive.json"
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {out_path}")
    return 0


def download(url: str, destination: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request) as response:
        destination.write_bytes(response.read())
    print(f"Downloaded {url} -> {destination}")


def load_radicals(path: Path) -> list[dict[str, Any]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        radicals = []
        for row in reader:
            radicals.append(
                {
                    "id": to_int(row["Radical ID#"]),
                    "stroke_count": to_int(row["Stroke#"]),
                    "literal": clean(row["Radical"]),
                    "meaning": clean(row["Meaning"]),
                    "reading_ja": clean(row["Reading-J"]),
                    "reading_romaji": clean(row["Reading-R"]),
                    "radical_filename": clean(row["R-Filename"]),
                    "animation_filename": clean(row["Anim-Filename"]),
                    "position_ja": clean(row["Position-J"]),
                    "position_romaji": clean(row["Position-R"]),
                }
            )
    return radicals


def load_kanji(path: Path, radicals: list[dict[str, Any]]) -> list[dict[str, Any]]:
    radical_by_literal = {rad["literal"]: rad for rad in radicals if rad["literal"]}
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        entries = []
        for row in reader:
            radical_literal = clean(row["radical"])
            entries.append(
                {
                    "literal": clean(row["kanji"]),
                    "slug": clean(row["kname"]),
                    "stroke_count": to_int(row["kstroke"]),
                    "meaning_keywords": split_keywords(row["kmeaning"]),
                    "grade": to_int(row["kgrade"]),
                    "readings": {
                        "kun": pair_readings(row["kunyomi_ja"], row["kunyomi"]),
                        "on": pair_readings(row["onyomi_ja"], row["onyomi"]),
                    },
                    "examples": parse_examples(row["examples"]),
                    "radical": {
                        "literal": radical_literal,
                        "id": to_int(row["rad_order"]),
                        "stroke_count": to_int(row["rad_stroke"]),
                        "name_ja": clean(row["rad_name_ja"]),
                        "name_romaji": clean(row["rad_name"]),
                        "meaning": clean(row["rad_meaning"]),
                        "position_ja": clean(row["rad_position_ja"]),
                        "position_romaji": clean(row["rad_position"]),
                        "catalog_entry": radical_by_literal.get(radical_literal),
                    },
                }
            )
    return entries


def pair_readings(japanese: str, romaji: str) -> list[dict[str, str]]:
    ja_parts = split_variants(japanese)
    ro_parts = split_variants(romaji)
    if not ja_parts and not ro_parts:
        return []
    pairs = []
    for index in range(max(len(ja_parts), len(ro_parts))):
        pairs.append(
            {
                "ja": ja_parts[index] if index < len(ja_parts) else "",
                "romaji": ro_parts[index] if index < len(ro_parts) else "",
            }
        )
    return pairs


def split_variants(value: str) -> list[str]:
    text = clean(value)
    if not text:
        return []
    normalized = text.replace("／", "/").replace("、", ",")
    parts = [part.strip() for part in normalized.split(",")]
    return [part for part in parts if part]


def split_keywords(value: str) -> list[str]:
    text = clean(value)
    if not text:
        return []
    return [part.strip() for part in text.split(",") if part.strip()]


def parse_examples(value: str) -> list[dict[str, str]]:
    text = clean(value)
    if not text:
        return []
    try:
        raw_examples = json.loads(text)
    except json.JSONDecodeError:
        return [{"expression": text, "meaning": ""}]
    examples = []
    for item in raw_examples:
        if isinstance(item, list) and len(item) >= 2:
            examples.append(
                {
                    "expression": str(item[0]).strip(),
                    "meaning": str(item[1]).strip(),
                }
            )
    return examples


def clean(value: str | None) -> str:
    return (value or "").strip()


def to_int(value: str | None) -> int | None:
    text = clean(value)
    if not text:
        return None
    try:
        return int(text)
    except ValueError:
        return None


if __name__ == "__main__":
    raise SystemExit(main())
