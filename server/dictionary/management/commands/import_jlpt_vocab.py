"""Set modern JLPT (N5–N1) levels on WORDS from a community vocab list.

Reads n5.csv … n1.csv (elzup/jlpt-word-list; columns expression,reading,meaning,
tags). Matches each entry to a Word by its forms (expression + reading) and sets
``Word.jlpt``. The easiest level wins (N5 processed first, only fills nulls). Run
AFTER import_jmdict.

    python manage.py import_jlpt_vocab /path/to/jlpt_vocab_dir
"""

from __future__ import annotations

import csv
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from dictionary.models import Word, WordForm


class Command(BaseCommand):
    help = "Set word JLPT (new N5–N1) levels from a community vocab list."

    def add_arguments(self, parser):
        parser.add_argument("dir", help="Directory containing n5.csv … n1.csv")

    def handle(self, *args, **opts):
        directory = Path(opts["dir"])
        if not directory.is_dir():
            raise CommandError(f"not a directory: {directory}")

        updated = 0
        with transaction.atomic():
            for level in (5, 4, 3, 2, 1):  # easiest first — N5 wins ties
                path = directory / f"n{level}.csv"
                if not path.exists():
                    continue
                with path.open(encoding="utf-8") as fh:
                    for row in csv.DictReader(fh):
                        expr = (row.get("expression") or "").strip()
                        reading = (row.get("reading") or "").strip()
                        if not expr:
                            continue
                        ids = set(
                            WordForm.objects.filter(text=expr).values_list("word_id", flat=True)
                        )
                        if reading and reading != expr:
                            rids = set(
                                WordForm.objects.filter(
                                    text=reading, kind=WordForm.Kind.KANA
                                ).values_list("word_id", flat=True)
                            )
                            ids = (ids & rids) or ids
                        if not ids:
                            continue
                        updated += Word.objects.filter(id__in=ids, jlpt__isnull=True).update(
                            jlpt=level
                        )
        self.stdout.write(self.style.SUCCESS(f"Done — JLPT set on {updated} words."))
