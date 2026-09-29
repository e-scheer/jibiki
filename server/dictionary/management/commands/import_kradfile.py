"""Import KRADFILE (EDRDG / krad-unicode) decomposition into Kanji.components.

One-shot batch command. Accepts the classic ``kanji : comp comp …`` text format
(UTF-8, or legacy EUC-JP as a fallback). Only sets components for kanji already
present, so run it AFTER import_kanjidic.

    python manage.py import_kradfile /path/to/kradfile
"""

from __future__ import annotations

from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from dictionary.importing import source_provenance
from dictionary.models import Kanji


class Command(BaseCommand):
    help = "Import KRADFILE kanji→component decomposition."

    def add_arguments(self, parser):
        parser.add_argument("path", help="Path to kradfile")
        parser.add_argument(
            "--source-url", default="", help="Download URL recorded as source evidence"
        )

    @transaction.atomic
    def handle(self, *args, **opts):
        path = Path(opts["path"])
        if not path.exists():
            raise CommandError(f"file not found: {path}")

        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            lines = path.read_text(encoding="euc-jp").splitlines()

        existing = {k.literal: k for k in Kanji.objects.all()}
        evidence = {
            **source_provenance(path, "kradfile"),
            "source_url": opts["source_url"],
            "transformation": "deterministic_component_import",
        }
        updated = 0
        for number, line in enumerate(lines, 1):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if " : " not in line:
                raise CommandError(f"Malformed KRADFILE line {number}")
            head, comps = line.split(" : ", 1)
            literal = head.strip()
            components = comps.split()
            if len(literal) != 1 or not components or any(len(c) != 1 for c in components):
                raise CommandError(f"Invalid KRADFILE components at line {number}")
            kanji = existing.get(literal)
            if kanji is None:
                continue
            kanji.components = list(dict.fromkeys(components))
            kanji.provenance = {**kanji.provenance, "kradfile": evidence}
            kanji.save(update_fields=["components", "provenance"])
            updated += 1
        self.stdout.write(self.style.SUCCESS(f"Done - components set on {updated} kanji."))
