"""Import the Tanaka corpus (EDRDG examples.utf) into ExampleSentence.

The file alternates A/B lines::

    A: 日本語の文。\tThe English translation.#ID=…
    B: word(reading)[sense] … index (ignored)

We keep the A lines (Japanese + English). One-shot; clears the table first.

    python manage.py import_examples /path/to/examples.utf
"""

from __future__ import annotations

from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from dictionary.models import ExampleSentence


class Command(BaseCommand):
    help = "Import Tanaka corpus example sentences (EDRDG examples.utf)."

    def add_arguments(self, parser):
        parser.add_argument("path", help="Path to examples.utf")

    def handle(self, *args, **opts):
        path = Path(opts["path"])
        if not path.exists():
            raise CommandError(f"file not found: {path}")

        ExampleSentence.objects.all().delete()
        batch: list[ExampleSentence] = []
        total = 0
        with path.open(encoding="utf-8", errors="replace") as fh:
            for line in fh:
                if not line.startswith("A: "):
                    continue
                body = line[3:].rstrip("\n")
                jp, _, rest = body.partition("\t")
                english = rest.split("#ID=")[0].strip()
                jp = jp.strip()
                if not jp:
                    continue
                batch.append(ExampleSentence(japanese=jp, english=english))
                if len(batch) >= 2000:
                    ExampleSentence.objects.bulk_create(batch)
                    total += len(batch)
                    batch = []
        if batch:
            ExampleSentence.objects.bulk_create(batch)
            total += len(batch)
        self.stdout.write(self.style.SUCCESS(f"Done — {total} example sentences imported."))
