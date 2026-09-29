"""Import Tanaka A/B records without deleting other corpora or inferring links."""

from __future__ import annotations

import hashlib
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from dictionary.importing import source_provenance
from dictionary.models import ExampleSentence, ExampleTranslation


class Command(BaseCommand):
    help = (
        "Import Tanaka examples safely; preserve B-line indexing evidence without guessing senses."
    )

    def add_arguments(self, parser):
        parser.add_argument("path", help="Path to UTF-8 examples.utf")

    def handle(self, *args, **opts):
        path = Path(opts["path"])
        if not path.is_file():
            raise CommandError(f"File not found: {path}")
        provenance = source_provenance(path, "tanaka")
        batch, pending, total = [], None, 0
        with transaction.atomic(), path.open(encoding="utf-8-sig") as stream:
            for number, line in enumerate(stream, 1):
                if line.startswith("B: "):
                    if pending is not None:
                        pending["provenance"]["index_line"] = line[3:].rstrip("\r\n")
                    continue
                if not line.startswith("A: "):
                    continue
                if pending is not None:
                    batch.append(pending)
                    if len(batch) >= 2000:
                        self._flush(batch)
                        total += len(batch)
                        batch = []
                japanese, separator, rest = line[3:].rstrip("\r\n").partition("\t")
                if not separator or not japanese.strip():
                    raise CommandError(f"Malformed Tanaka A record at line {number}.")
                english, _, source_id = rest.partition("#ID=")
                japanese, english = japanese.strip(), english.strip()
                digest = hashlib.sha256((japanese + "\0" + english).encode("utf-8")).hexdigest()
                pending = dict(
                    source_key="tanaka:" + digest,
                    japanese=japanese,
                    english=english,
                    provenance={**provenance, "source_id": source_id.strip(), "line": number},
                )
            if pending is not None:
                batch.append(pending)
            if batch:
                self._flush(batch)
                total += len(batch)
        self.stdout.write(self.style.SUCCESS(f"Done: {total} Tanaka records processed."))

    @staticmethod
    def _flush(batch):
        known = set(
            ExampleSentence.objects.filter(
                source_key__in=[row["source_key"] for row in batch]
            ).values_list("source_key", flat=True)
        )
        rows, translations = [], []
        for row in batch:
            if row["source_key"] in known:
                continue
            known.add(row["source_key"])
            example = ExampleSentence(
                **{key: row[key] for key in ("source_key", "japanese", "provenance")}
            )
            rows.append(example)
            if row["english"]:
                translations.append((example, row["english"]))
        ExampleSentence.objects.bulk_create(rows)
        ExampleTranslation.objects.bulk_create(
            [
                ExampleTranslation(example=example, language="en", text=text)
                for example, text in translations
            ]
        )
