"""Set modern JLPT (N5-N1) levels on WORDS from a community vocab list.

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

from dictionary.importing import source_provenance
from dictionary.models import Word, WordForm


class Command(BaseCommand):
    help = "Set word JLPT (new N5-N1) levels from a community vocab list."

    def add_arguments(self, parser):
        parser.add_argument("dir", help="Directory containing n5.csv … n1.csv")

    def handle(self, *args, **opts):
        directory = Path(opts["dir"])
        if not directory.is_dir():
            raise CommandError(f"not a directory: {directory}")

        updated, unmatched, ambiguous = 0, 0, 0
        with transaction.atomic():
            for level in (5, 4, 3, 2, 1):  # easiest first - N5 wins ties
                path = directory / f"n{level}.csv"
                if not path.exists():
                    continue
                evidence = {
                    **source_provenance(path, "community_jlpt_vocab"),
                    "transformation": "deterministic_tabular_import",
                    "level": level,
                }
                with path.open(encoding="utf-8-sig") as fh:
                    reader = csv.DictReader(fh)
                    if not {"expression", "reading"}.issubset(reader.fieldnames or []):
                        raise CommandError(f"Missing expression/reading columns in {path.name}.")
                    for row in reader:
                        expr = (row.get("expression") or "").strip()
                        reading = (row.get("reading") or "").strip()
                        if not expr or not reading:
                            unmatched += 1
                            continue
                        ids = set(
                            WordForm.objects.filter(
                                text=expr, word__canonical_word__isnull=True
                            ).values_list("word_id", flat=True)
                        )
                        readings = WordForm.objects.filter(
                            text=reading, kind=WordForm.Kind.KANA, word_id__in=ids
                        )
                        rids = {
                            form.word_id
                            for form in readings
                            if (
                                expr == reading
                                or (
                                    not form.metadata.get("no_kanji")
                                    and (
                                        not form.metadata.get("restricted_kanji")
                                        or expr in form.metadata["restricted_kanji"]
                                    )
                                )
                            )
                        }
                        ids &= rids
                        if not ids:
                            unmatched += 1
                            continue
                        if len(ids) != 1:
                            ambiguous += 1
                            continue
                        word = Word.objects.get(pk=next(iter(ids)))
                        if word.jlpt is None:
                            word.jlpt = level
                            word.provenance = {
                                **word.provenance,
                                "jlpt_vocab": {**evidence, "expression": expr, "reading": reading},
                            }
                            word.save(update_fields=["jlpt", "provenance"])
                            updated += 1
        self.stdout.write(
            self.style.SUCCESS(
                f"Done: JLPT set on {updated} words; "
                f"{unmatched} unmatched and {ambiguous} ambiguous rows skipped."
            )
        )
