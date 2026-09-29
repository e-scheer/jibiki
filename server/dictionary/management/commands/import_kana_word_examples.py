"""Link audited kana-only source spellings to unique, traced JMdict readings."""

import hashlib
import json
import re
import unicodedata
from collections import Counter
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from dictionary.models import Kana, KanaWordExample, WordForm


class Command(BaseCommand):
    help = "Import unambiguous kana lexical examples; no source translations are copied."

    def add_arguments(self, parser):
        parser.add_argument("path", type=Path)
        parser.add_argument("--dry-run", action="store_true")
        parser.add_argument("--report", type=Path, required=True)

    def handle(self, *args, **options):
        path = options["path"]
        try:
            raw = path.read_bytes()
            rows = [json.loads(line) for line in raw.decode("utf-8").splitlines() if line.strip()]
        except (OSError, ValueError) as error:
            raise CommandError(f"Cannot read candidates: {error}") from error
        digest = hashlib.sha256(raw).hexdigest()
        kana_by_char = {k.char: k for k in Kana.objects.all()}
        counts, reasons = Counter(), Counter()
        accepted, quarantine, seen = [], [], set()
        with transaction.atomic():
            for position, row in enumerate(rows):
                if not isinstance(row, dict):
                    raise CommandError(f"Candidate {position + 1} must be an object")
                character, reading = row.get("character", ""), row.get("japanese", "")
                errors = []
                if not isinstance(character, str) or character not in kana_by_char:
                    errors.append("unknown_kana_target")
                if not isinstance(reading, str) or not re.fullmatch(r"[ぁ-ゖァ-ヺー]+", reading):
                    errors.append("kana_only_reading_required")
                elif reading != unicodedata.normalize("NFC", reading):
                    errors.append("noncanonical_unicode")
                elif not isinstance(character, str) or character not in reading:
                    errors.append("target_not_in_reading")
                if row.get("validation_errors"):
                    errors.append("source_audit_failed")
                if not row.get("source_url") or not row.get("source_file_sha256"):
                    errors.append("source_evidence_missing")
                words = {}
                if not errors:
                    matches = WordForm.objects.filter(
                        text=reading,
                        kind=WordForm.Kind.KANA,
                        word__seq__gt=0,
                        word__provenance__jmdict__source="jmdict",
                        word__canonical_word__isnull=True,
                    ).select_related("word")
                    words = {form.word_id: form.word for form in matches}
                    if not words:
                        errors.append("no_exact_canonical_reading")
                    elif len(words) != 1:
                        errors.append("ambiguous_dictionary_entries")
                evidence = {
                    "character": character,
                    "reading": reading,
                    "source_url": row.get("source_url"),
                    "candidate_line": position + 1,
                }
                if errors:
                    counts["quarantined"] += 1
                    reasons.update(errors)
                    quarantine.append(
                        {
                            **evidence,
                            "reasons": errors,
                            "canonical_sequences": sorted(word.seq for word in words.values()),
                        }
                    )
                    if isinstance(character, str) and isinstance(reading, str):
                        stale = KanaWordExample.objects.filter(
                            kana__char=character,
                            reading=reading,
                            provenance__source="kanjidraw_kana_example",
                        )
                        counts["withdrawn"] += stale.count()
                        if not options["dry_run"]:
                            stale.delete()
                    continue
                word = next(iter(words.values()))
                key = (character, word.pk, reading)
                if key in seen:
                    counts["duplicate_candidates"] += 1
                    continue
                seen.add(key)
                provenance = {
                    "source": "kanjidraw_kana_example",
                    "source_url": row["source_url"],
                    "source_file_sha256": row["source_file_sha256"],
                    "source_line": row.get("source_line"),
                    "candidate_file_sha256": digest,
                    "candidate_line": position + 1,
                    "matching_method": "unique_exact_kana_reading",
                    "canonical_source": "jmdict",
                    "canonical_seq": word.seq,
                    "canonical_sha256": word.provenance["jmdict"].get("sha256", ""),
                    "review_status": "structural_match",
                    "translation_source": "canonical_dictionary",
                }
                accepted.append({**evidence, "word_id": word.pk, "canonical_seq": word.seq})
                counts["accepted"] += 1
                lookup = {"kana": kana_by_char[character], "word": word, "reading": reading}
                if options["dry_run"]:
                    created = not KanaWordExample.objects.filter(**lookup).exists()
                else:
                    _, created = KanaWordExample.objects.update_or_create(
                        **lookup,
                        defaults={"order": position, "provenance": provenance},
                    )
                counts["created" if created else "updated"] += 1
            if options["dry_run"]:
                transaction.set_rollback(True)
        report = {
            "source": str(path),
            "source_sha256": digest,
            "dry_run": options["dry_run"],
            "input_rows": len(rows),
            "counts": dict(counts),
            "quarantine_reasons": dict(reasons),
            "accepted": accepted,
            "quarantine": quarantine,
        }
        target = options["report"]
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        self.stdout.write(
            json.dumps(
                {"counts": dict(counts), "quarantine_reasons": dict(reasons)}, ensure_ascii=False
            )
        )
