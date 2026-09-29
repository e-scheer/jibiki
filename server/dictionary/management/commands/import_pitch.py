"""Import pitch-accent patterns (Kanjium accents.txt) onto reading WordForms.

accents.txt is ``term<TAB>reading<TAB>pitch`` (pitch e.g. "0" or "0,2"). We set
the pattern on each kana reading form, matching by (a surface/kanji form of the
word, reading) and falling back to (reading, reading) for kana-only words. Run
AFTER import_jmdict.

    python manage.py import_pitch /path/to/accents.txt
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from dictionary.importing import source_provenance
from dictionary.models import Word, WordForm


class Command(BaseCommand):
    help = "Import Kanjium pitch-accent patterns onto reading forms."

    def add_arguments(self, parser):
        parser.add_argument("path", help="Path to accents.txt")

    def handle(self, *args, **opts):
        path = Path(opts["path"])
        if not path.is_file():
            raise CommandError(f"file not found: {path}")

        acc: dict[tuple[str, str], set[int]] = {}
        for number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
            if not line.strip() or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) != 3:
                raise CommandError(f"Malformed pitch record at line {number}.")
            term, reading, pitch = parts[0], parts[1], parts[2].strip()
            if not term or not reading or not re.fullmatch(r"\d+(?:,\d+)*", pitch):
                raise CommandError(f"Invalid pitch pattern at line {number}.")
            acc.setdefault((term, reading), set()).update(map(int, pitch.split(",")))

        to_update: list[WordForm] = []
        total = 0
        evidence = {
            **source_provenance(path, "kanjium"),
            "transformation": "deterministic_tabular_import",
        }
        summary_path = path.parent / "summary.json"
        if summary_path.is_file():
            summary = json.loads(summary_path.read_text(encoding="utf-8"))
            raw_path = Path(summary.get("source_db", ""))
            if (
                summary.get("schema") == "jibiki-kanjium-normalized/2"
                and summary.get("output_sha256", {}).get(path.name) == evidence["sha256"]
                and raw_path.is_file()
                and hashlib.sha256(raw_path.read_bytes()).hexdigest()
                == summary.get("source_sha256")
            ):
                evidence["derivation"] = {
                    "source_file": raw_path.name,
                    "source_sha256": summary["source_sha256"],
                    "extractor_sha256": summary["extractor_sha256"],
                    "schema": summary["schema"],
                    "verification": "raw_and_normalized_file_checksums",
                }
        with transaction.atomic():
            qs = (
                Word.objects.filter(
                    canonical_word__isnull=True,
                    forms__kind=WordForm.Kind.KANA,
                    forms__text__in={reading for _, reading in acc},
                )
                .distinct()
                .prefetch_related("forms")
                .iterator(chunk_size=1000)
            )
            for w in qs:
                forms = list(w.forms.all())
                kanji_forms = [f.text for f in forms if f.kind == WordForm.Kind.KANJI]
                for r in forms:
                    if r.kind != WordForm.Kind.KANA:
                        continue
                    terms = [] if r.metadata.get("no_kanji") else kanji_forms
                    restrictions = r.metadata.get("restricted_kanji")
                    if restrictions:
                        terms = [term for term in terms if term in restrictions]
                    if not kanji_forms or r.metadata.get("no_kanji"):
                        terms = [r.text]
                    matches = {
                        term: sorted(acc[(term, r.text)]) for term in terms if (term, r.text) in acc
                    }
                    if not matches:
                        continue
                    pitch = ",".join(
                        map(str, sorted({value for values in matches.values() for value in values}))
                    )
                    if len(pitch) > WordForm._meta.get_field("pitch").max_length:
                        raise CommandError(f"Pitch variants exceed storage for word {w.pk}.")
                    metadata = {**r.metadata, "pitch_provenance": {**evidence, "matches": matches}}
                    if r.pitch != pitch or r.metadata != metadata:
                        r.pitch, r.metadata = pitch, metadata
                        to_update.append(r)
                        if len(to_update) >= 2000:
                            WordForm.objects.bulk_update(to_update, ["pitch", "metadata"])
                            total += len(to_update)
                            to_update = []
            if to_update:
                WordForm.objects.bulk_update(to_update, ["pitch", "metadata"])
                total += len(to_update)
        self.stdout.write(self.style.SUCCESS(f"Done - pitch set on {total} readings."))
