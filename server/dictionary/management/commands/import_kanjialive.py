"""Add source-scoped radical facts without overwriting KANJIDIC or KRADFILE."""

import hashlib
import json
import re
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from dictionary.models import Kanji, Radical, RadicalMeaning

SOURCE_URL = "https://github.com/kanjialive/kanji-data-media"


def normalized_meaning(text):
    # The two CSVs differ around Japanese parentheses, not between English words.
    return re.sub(r"\s*([（）()])\s*", r"\1", " ".join(text.split()))


def private_glyph(text):
    return any(unicodedata.category(char) == "Co" for char in text)


def load_snapshot(path, manifest_path):
    try:
        raw = path.read_bytes()
        document = json.loads(raw)
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))["sources"]["kanjialive"]
    except (OSError, ValueError, KeyError) as error:
        raise CommandError(f"Cannot read Kanji alive source: {error}") from error
    digest = hashlib.sha256(raw).hexdigest()
    records = [
        entry
        for entry in manifest["files"]
        if entry["path"].replace("\\", "/").rsplit("/", 1)[-1] == path.name
    ]
    if len(records) != 1 or records[0]["sha256"] != digest:
        raise CommandError("Normalized source SHA-256 does not match the harvest manifest.")
    if (
        document.get("schema") != "jibiki-kanji-alive-open-data/1"
        or document.get("source", {}).get("license") != "CC BY 4.0"
        or manifest.get("license") != "CC BY 4.0"
    ):
        raise CommandError("Unsupported Kanji alive schema or source license.")
    for name in ("radicals", "kanji"):
        if not isinstance(document.get(name), list) or document.get("counts", {}).get(name) != len(
            document[name]
        ):
            raise CommandError(f"Invalid {name} catalogue count.")
    return document, digest


class Command(BaseCommand):
    help = "Import traced Kanji alive radical enrichment, preserving existing canonical fields."

    def add_arguments(self, parser):
        parser.add_argument("path", type=Path)
        parser.add_argument("--manifest", type=Path, required=True)
        parser.add_argument("--report", type=Path, required=True)
        parser.add_argument("--dry-run", action="store_true")

    def handle(self, *args, **options):
        document, digest = load_snapshot(options["path"], options["manifest"])
        dry = options["dry_run"]
        catalogue, groups = {}, defaultdict(list)
        counts, held, conflicts = Counter(), [], []
        for row in document["radicals"]:
            if (
                not isinstance(row, dict)
                or not isinstance(row.get("id"), int)
                or row["id"] in catalogue
            ):
                raise CommandError("Invalid or duplicate radical catalogue ID.")
            if row.get("stroke_count") is None or row.get("meaning", "").strip().lower() == "n/a":
                held.append(
                    {
                        "radical_catalogue_id": row["id"],
                        "literal": row.get("literal"),
                        "reason": "source_has_no_radical_definition_or_strokes",
                    }
                )
                continue
            if (
                not isinstance(row.get("literal"), str)
                or len(row["literal"]) != 1
                or not isinstance(row.get("meaning"), str)
                or not row["meaning"].strip()
                or len(row["meaning"].strip()) > 64
                or not isinstance(row.get("reading_ja"), str)
                or len(row["reading_ja"]) > 32
                or not isinstance(row.get("stroke_count"), int)
            ):
                raise CommandError(f"Invalid radical data for catalogue ID {row['id']}.")
            catalogue[row["id"]] = row
            if private_glyph(row["literal"]):
                counts["radical_private_glyph_rows"] += 1
                continue
            glyph = unicodedata.normalize("NFKC", row["literal"])
            if len(glyph) != 1:
                raise CommandError("Radical normalization must preserve a single glyph.")
            groups[glyph].append(row)
        source = {
            "source": "kanjialive",
            "source_url": SOURCE_URL,
            "license": "CC BY 4.0",
            "sha256": digest,
            "license_url": "https://creativecommons.org/licenses/by/4.0/",
            "attribution": "Kanji alive",
            "normalization": "Unicode NFKC for standard radical glyphs; private glyphs retained only as source references",
        }
        with transaction.atomic():
            for glyph, rows in groups.items():
                radical = Radical.objects.filter(literal=glyph).first()
                if radical is None:
                    radical = Radical(literal=glyph)
                    counts["radicals_created"] += 1
                evidence = {
                    **source,
                    "catalogue_ids": [r["id"] for r in rows],
                    "source_literals": [r["literal"] for r in rows],
                    "language": "en",
                }
                field_sources = dict(radical.provenance.get("field_sources", {}))
                for field, source_field in (("strokes", "stroke_count"), ("reading", "reading_ja")):
                    values = {r[source_field] for r in rows}
                    if len(values) != 1:
                        conflicts.append(
                            {"radical": glyph, "field": field, "source_values": sorted(values)}
                        )
                    elif not getattr(radical, field):
                        setattr(radical, field, next(iter(values)))
                        field_sources[field] = "kanjialive"
                        counts[f"radical_{field}_filled"] += 1
                english = radical.meanings.filter(language="en").first() if radical.pk else None
                meanings = {r["meaning"].strip() for r in rows}
                new_meaning = None
                if len(meanings) == 1:
                    value = next(iter(meanings))
                    if english is None:
                        new_meaning = value
                        field_sources["meaning_en"] = "kanjialive"
                        counts["english_meanings_created"] += 1
                    elif english.text != value:
                        counts["existing_english_meanings_preserved"] += 1
                        conflicts.append(
                            {
                                "radical": glyph,
                                "field": "meaning_en",
                                "existing": english.text,
                                "source": value,
                            }
                        )
                else:
                    conflicts.append(
                        {"radical": glyph, "field": "meaning_en", "source_values": sorted(meanings)}
                    )
                radical.provenance = {
                    **radical.provenance,
                    "kanjialive": evidence,
                    "field_sources": field_sources,
                }
                if not dry:
                    radical.save()
                    if new_meaning:
                        RadicalMeaning.objects.create(
                            radical=radical, language="en", text=new_meaning
                        )
            seen = set()
            for row in document["kanji"]:
                literal = row.get("literal")
                if not isinstance(literal, str) or len(literal) != 1 or literal in seen:
                    raise CommandError("Invalid or duplicate kanji literal.")
                seen.add(literal)
                radical = row.get("radical", {})
                matched = radical.get("catalog_entry", {})
                # The two CSVs use different ID namespaces. Never join on rad_order.
                original = catalogue.get(matched.get("id"))
                if (
                    original != matched
                    or original is None
                    or radical.get("literal") != original["literal"]
                    or normalized_meaning(radical.get("meaning", ""))
                    != normalized_meaning(original["meaning"])
                    or radical.get("name_ja") != original["reading_ja"]
                ):
                    held.append({"kanji": literal, "reason": "radical_catalogue_mismatch"})
                    continue
                kanji = Kanji.objects.filter(literal=literal).first()
                if kanji is None:
                    held.append({"kanji": literal, "reason": "unknown_canonical_kanji"})
                    continue
                source_glyph = radical["literal"]
                has_glyph = not private_glyph(source_glyph)
                detail = {
                    "literal": unicodedata.normalize("NFKC", source_glyph) if has_glyph else "",
                    "source_literal": source_glyph,
                    "glyph_available": has_glyph,
                    "reading": radical["name_ja"],
                    "meaning": radical["meaning"].strip(),
                    "meaning_language": "en",
                    "position": radical.get("position_ja", ""),
                    "source_kanji_radical_order": radical.get("id"),
                    "source_radical_catalogue_id": original["id"],
                }
                payload = {"radical": detail, "source_url": SOURCE_URL, "license": "CC BY 4.0"}
                counts["kanji_relations"] += 1
                if not has_glyph:
                    counts["kanji_relations_without_portable_glyph"] += 1
                if radical.get("stroke_count") != original["stroke_count"]:
                    conflicts.append(
                        {
                            "kanji": literal,
                            "field": "radical_strokes",
                            "kanji_csv": radical.get("stroke_count"),
                            "radical_csv": original["stroke_count"],
                        }
                    )
                if not dry:
                    kanji.metadata = {**kanji.metadata, "kanjialive": payload}
                    kanji.provenance = {**kanji.provenance, "kanjialive": source}
                    kanji.save(update_fields=["metadata", "provenance"])
        report = {
            "dry_run": dry,
            "source": source,
            "source_counts": document["counts"],
            "portable_radical_glyphs": len(groups),
            "counts": dict(counts),
            "quarantine": held,
            "preserved_conflicts": conflicts,
            "untouched": [
                "KANJIDIC meanings/readings/grades/radical_number",
                "KRADFILE components",
                "existing localized radical meanings",
                "glyph-origin explanations",
                "mnemonic stories",
            ],
        }
        target = options["report"]
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        self.stdout.write(
            json.dumps(
                {"counts": dict(counts), "quarantined": len(held), "conflicts": len(conflicts)}
            )
        )
