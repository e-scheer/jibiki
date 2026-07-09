"""Import KRADFILE (EDRDG / krad-unicode) decomposition into Kanji.components.

One-shot batch command. Accepts the classic ``kanji : comp comp …`` text format
(UTF-8, or legacy EUC-JP as a fallback). Only sets components for kanji already
present, so run it AFTER import_kanjidic.

    python manage.py import_kradfile /path/to/kradfile
"""

from __future__ import annotations

from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from dictionary.models import Kanji


class Command(BaseCommand):
    help = "Import KRADFILE kanji→component decomposition."

    def add_arguments(self, parser):
        parser.add_argument("path", help="Path to kradfile")

    def handle(self, *args, **opts):
        path = Path(opts["path"])
        if not path.exists():
            raise CommandError(f"file not found: {path}")

        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            lines = path.read_text(encoding="euc-jp").splitlines()

        existing = {k.literal: k for k in Kanji.objects.all()}
        updated = 0
        for line in lines:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if " : " not in line:
                continue
            head, comps = line.split(" : ", 1)
            literal = head.strip()
            kanji = existing.get(literal)
            if kanji is None:
                continue
            kanji.components = [c for c in comps.split() if c]
            kanji.save(update_fields=["components"])
            updated += 1
        self.stdout.write(self.style.SUCCESS(f"Done - components set on {updated} kanji."))
