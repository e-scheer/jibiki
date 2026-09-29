"""Archive empty source records and identify legacy entries missing from a snapshot."""

import json
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from dictionary.importing import entries, source_provenance
from dictionary.management.commands.import_jmdict import Command as JMdictCommand
from dictionary.models import Word


class Command(BaseCommand):
    help = "Reconcile source anomalies without dropping word IDs or personal history."

    def add_arguments(self, parser):
        parser.add_argument("path")
        parser.add_argument("--report", required=True)
        parser.add_argument("--mark-missing", action="store_true")
        parser.add_argument("--dry-run", action="store_true")

    def handle(self, *args, **opts):
        path = Path(opts["path"])
        if not path.is_file():
            raise CommandError(f"File not found: {path}")
        evidence = source_provenance(path, "jmdict")
        if opts["mark_missing"] and not evidence["verified_download"]:
            raise CommandError(
                "Marking missing entries requires a matching official download sidecar."
            )
        sequences, anomalies = set(), []
        for entry in entries(path, "JMdict", "entry"):
            sequences.add(int(entry.findtext("ent_seq")))
            if any(
                not sense.findall("gloss")
                or any(not (g.text or "").strip() for g in sense.findall("gloss"))
                for sense in entry.findall("sense")
            ):
                anomalies.append(JMdictCommand._parse(entry, {"all"}))
        missing = [
            pk
            for pk, seq in Word.objects.filter(seq__gt=0).values_list("pk", "seq")
            if seq not in sequences
        ]
        report = dict(
            source=evidence,
            source_entries=len(sequences),
            source_anomalies=[
                dict(
                    seq=r["seq"],
                    senses=[
                        dict(order=s["order"], raw=s["metadata"]["raw"])
                        for s in r["senses"]
                        if not s["has_source_glosses"] or s["empty_gloss_count"]
                    ],
                )
                for r in anomalies
            ],
            missing_word_ids=missing,
            mark_missing=opts["mark_missing"],
            dry_run=opts["dry_run"],
        )
        if not opts["dry_run"]:
            with transaction.atomic():
                if anomalies:
                    JMdictCommand._store(anomalies, {"all"}, evidence)
                if opts["mark_missing"]:
                    for word in Word.objects.filter(pk__in=missing):
                        empty = list(
                            word.senses.filter(glosses__isnull=True).values(
                                "id", "order", "pos", "misc", "field", "metadata"
                            )
                        )
                        word.provenance = {
                            **word.provenance,
                            "source_status": "upstream_not_in_snapshot",
                            "absence_evidence": evidence,
                        }
                        if empty:
                            word.provenance["legacy_empty_senses"] = empty
                        word.save(update_fields=["provenance"])
                        word.senses.filter(glosses__isnull=True).delete()
        report_path = Path(opts["report"])
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        self.stdout.write(
            self.style.SUCCESS(
                f"{len(anomalies)} entries with source anomalies; {len(missing)} legacy entries absent."
            )
        )
