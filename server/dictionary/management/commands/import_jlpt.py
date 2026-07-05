"""Set modern JLPT (N5–N1) levels on kanji from a community mapping.

KANJIDIC2 only carries the *old* 4-level JLPT (now largely absent), and there is
no official modern N5–N1 kanji list — so we import a community-standard mapping
(davidluzgouveia/kanji-data, field ``jlpt_new``). Only updates kanji already in
the DB; run AFTER import_kanjidic.

    python manage.py import_jlpt /path/to/kanji.json
"""

from __future__ import annotations

import json
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from dictionary.models import Kanji


class Command(BaseCommand):
    help = "Set kanji JLPT (new N5–N1) levels from a community mapping."

    def add_arguments(self, parser):
        parser.add_argument("path", help="Path to kanji-data kanji.json")

    def handle(self, *args, **opts):
        path = Path(opts["path"])
        if not path.exists():
            raise CommandError(f"file not found: {path}")
        data = json.loads(path.read_text(encoding="utf-8"))

        existing = {k.literal: k for k in Kanji.objects.all()}
        to_update = []
        for literal, info in data.items():
            level = info.get("jlpt_new") if isinstance(info, dict) else None
            kanji = existing.get(literal)
            if kanji is not None and level and kanji.jlpt != level:
                kanji.jlpt = level
                to_update.append(kanji)

        with transaction.atomic():
            Kanji.objects.bulk_update(to_update, ["jlpt"], batch_size=500)
        self.stdout.write(self.style.SUCCESS(f"Done — JLPT (new) set on {len(to_update)} kanji."))
