"""Correct import evidence in place without rebuilding content or personal IDs."""

import json
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import connection, transaction

from dictionary.importing import source_provenance
from dictionary.models import ExampleSenseLink, ExampleSentence, Kanji, Name, Word


class Command(BaseCommand):
    help = "Refresh provenance only for rows matching this exact source file SHA-256."

    def add_arguments(self, parser):
        parser.add_argument(
            "source", choices=["jmdict", "kanjidic2", "jmnedict", "jmdict_examples", "tanaka"]
        )
        parser.add_argument("path")

    def handle(self, *args, **opts):
        path, source = Path(opts["path"]), opts["source"]
        if not path.is_file():
            raise CommandError(f"File not found: {path}")
        provenance = source_provenance(path, source)
        nested = {"jmdict": Word, "kanjidic2": Kanji, "jmnedict": Name}.get(source)
        models = [nested] if nested else [ExampleSentence, ExampleSenseLink]
        total = 0
        with transaction.atomic(), connection.cursor() as cursor:
            for model in models:
                table = connection.ops.quote_name(model._meta.db_table)
                if nested:
                    cursor.execute(
                        f"UPDATE {table} SET provenance = jsonb_set(provenance, %s, %s::jsonb) "
                        "WHERE provenance -> %s ->> 'sha256' = %s",
                        [[source], json.dumps(provenance), source, provenance["sha256"]],
                    )
                else:
                    cursor.execute(
                        f"UPDATE {table} SET provenance = "
                        "(provenance - 'generated_by_ai' - 'source_url') || %s::jsonb "
                        "WHERE provenance ->> 'source' = %s AND provenance ->> 'sha256' = %s",
                        [json.dumps(provenance), source, provenance["sha256"]],
                    )
                total += cursor.rowcount
        self.stdout.write(self.style.SUCCESS(f"Refreshed provenance on {total} rows."))
