"""Hide exact, unambiguous legacy demo duplicates without moving personal IDs."""

import json
from pathlib import Path

from django.core.management.base import BaseCommand
from django.db import transaction

from dictionary.models import Word, WordForm


class Command(BaseCommand):
    help = "Map negative demo sequences to a unique official entry by exact forms and readings."

    def add_arguments(self, parser):
        parser.add_argument("--report", help="JSON reconciliation evidence and unresolved entries")
        parser.add_argument("--dry-run", action="store_true")

    def handle(self, *args, **opts):
        mappings, unresolved = [], []
        with transaction.atomic():
            for demo in Word.objects.filter(
                seq__lt=0, canonical_word__isnull=True
            ).prefetch_related("forms"):
                forms = list(demo.forms.all())
                readings = [f for f in forms if f.kind == "kana"]
                written = [f.text for f in forms if f.kind == "kanji"]
                candidates = None
                if readings:
                    for form in forms:
                        ids = set(
                            WordForm.objects.filter(
                                word__seq__gt=0,
                                word__canonical_word__isnull=True,
                                word__provenance__jmdict__source="jmdict",
                                kind=form.kind,
                                text=form.text,
                            ).values_list("word_id", flat=True)
                        )
                        candidates = ids if candidates is None else candidates & ids
                valid = []
                for candidate in Word.objects.filter(pk__in=candidates or []).prefetch_related(
                    "forms"
                ):
                    canonical_readings = {
                        f.text: f for f in candidate.forms.all() if f.kind == "kana"
                    }
                    if any(
                        written
                        and (
                            canonical_readings[r.text].metadata.get("no_kanji")
                            or (
                                canonical_readings[r.text].metadata.get("restricted_kanji")
                                and not set(written).intersection(
                                    canonical_readings[r.text].metadata["restricted_kanji"]
                                )
                            )
                        )
                        for r in readings
                    ):
                        continue
                    valid.append(candidate)
                if len(valid) != 1:
                    partition = []
                    if not valid and written and len(readings) > 1:
                        for reading in readings:
                            candidates_for_reading = set(
                                WordForm.objects.filter(
                                    word__seq__gt=0,
                                    word__canonical_word__isnull=True,
                                    word__provenance__jmdict__source="jmdict",
                                    kind="kana",
                                    text=reading.text,
                                ).values_list("word_id", flat=True)
                            )
                            for text in written:
                                candidates_for_reading &= set(
                                    WordForm.objects.filter(
                                        word_id__in=candidates_for_reading,
                                        kind="kanji",
                                        text=text,
                                    ).values_list("word_id", flat=True)
                                )
                            if len(candidates_for_reading) != 1:
                                partition = []
                                break
                            target_id = next(iter(candidates_for_reading))
                            target_reading = WordForm.objects.get(
                                word_id=target_id, kind="kana", text=reading.text
                            )
                            if target_reading.metadata.get("no_kanji") or (
                                target_reading.metadata.get("restricted_kanji")
                                and not set(written).intersection(
                                    target_reading.metadata["restricted_kanji"]
                                )
                            ):
                                partition = []
                                break
                            partition.append(dict(word_id=target_id, reading=reading.text))
                    merged = len({p["word_id"] for p in partition}) > 1
                    if merged and not opts["dry_run"]:
                        demo.provenance = {
                            **demo.provenance,
                            "source_status": "legacy_merged_entry",
                            "canonical_candidates": partition,
                        }
                        demo.save(update_fields=["provenance"])
                    unresolved.append(
                        dict(
                            id=demo.pk,
                            seq=demo.seq,
                            reason="legacy_merged_entry"
                            if merged
                            else "ambiguous"
                            if valid
                            else "no_exact_match",
                            candidates=partition if merged else [w.pk for w in valid],
                        )
                    )
                    continue
                canonical = valid[0]
                evidence = dict(
                    method="unique_exact_written_forms_and_readings",
                    canonical_word_id=canonical.pk,
                    canonical_seq=canonical.seq,
                )
                mappings.append(dict(id=demo.pk, seq=demo.seq, **evidence))
                if not opts["dry_run"]:
                    demo.canonical_word = canonical
                    demo.provenance = {**demo.provenance, "canonical_alias": evidence}
                    demo.save(update_fields=["canonical_word", "provenance"])
        report = dict(dry_run=opts["dry_run"], mappings=mappings, unresolved=unresolved)
        if opts["report"]:
            path = Path(opts["report"])
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        self.stdout.write(
            self.style.SUCCESS(
                f"{len(mappings)} exact aliases; {len(unresolved)} unresolved entries."
            )
        )
