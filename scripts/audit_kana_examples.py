"""Audit mirrored kana examples without publishing or translating them.

Only structurally consistent rows become candidates. Candidate is not a claim
of linguistic or editorial review; failing rows remain in a separate quarantine.
"""

import argparse
import hashlib
import json
import unicodedata
from collections import Counter
from pathlib import Path


def audit_example(character, example):
    reasons = []
    word = example.get("word")
    if not isinstance(word, str) or not word.strip():
        reasons.append("missing_japanese_word")
    elif unicodedata.normalize("NFC", character) not in unicodedata.normalize(
        "NFC", word
    ):
        reasons.append("target_kana_not_in_word")
    meaning = example.get("meaning")
    if not isinstance(meaning, str) or not meaning.strip():
        reasons.append("missing_translation")
    highlight = example.get("highlight")
    if highlight and highlight != character:
        reasons.append("highlight_mismatches_target")
    return reasons


def run(source, output):
    output.mkdir(parents=True, exist_ok=True)
    counts = Counter()
    reasons = Counter()
    targets = set()
    digest = hashlib.sha256()
    with source.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    with (
        source.open(encoding="utf-8") as stream,
        (output / "candidates.jsonl").open("w", encoding="utf-8") as candidates,
        (output / "quarantine.jsonl").open("w", encoding="utf-8") as quarantine,
    ):
        for line_number, line in enumerate(stream, 1):
            row = json.loads(line)
            if row.get("page_type") != "kana":
                continue
            fields = row["site_fields"]
            character = fields["character"]
            targets.add(character)
            counts["kana_pages"] += 1
            for example in fields.get("examples", []):
                problems = audit_example(character, example)
                record = {
                    "character": character,
                    "script": fields.get("script"),
                    "japanese": example.get("word"),
                    "translation": example.get("meaning"),
                    "language": "en",
                    "source_url": row["url"],
                    "source_site": row["site"],
                    "source_line": line_number,
                    "source_file_sha256": digest.hexdigest(),
                    "source_field": "site_fields.examples",
                    "review_status": "unverified",
                    "extraction_method": "dom_parser",
                    "source_provenance": row.get("provenance", {}).get("examples", {}),
                    "validation_errors": problems,
                }
                target = quarantine if problems else candidates
                target.write(json.dumps(record, ensure_ascii=False) + "\n")
                counts["quarantined" if problems else "candidates"] += 1
                reasons.update(problems)
    summary = {
        "source": str(source),
        "source_sha256": digest.hexdigest(),
        "counts": dict(counts),
        "unique_targets": len(targets),
        "quarantine_reasons": dict(reasons),
        "publication": "none; structural candidates still require source and linguistic review",
    }
    (output / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source", type=Path, default=Path("var/site_extract/kanjidraw/pages.jsonl")
    )
    parser.add_argument(
        "--output", type=Path, default=Path("var/quality_audit/kana_examples")
    )
    args = parser.parse_args()
    print(json.dumps(run(args.source, args.output), ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()
