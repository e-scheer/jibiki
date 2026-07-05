"""Trigram GIN indexes for example-sentence and name lookup (both use
``__icontains``). Postgres-only; a no-op on SQLite (dev/tests)."""

from django.db import migrations

_TRGM = [
    ("dict_examples", "japanese", "dict_examples_jp_trgm"),
    ("dict_names", "reading", "dict_names_reading_trgm"),
    ("dict_names", "kanji", "dict_names_kanji_trgm"),
]


def create_trgm(apps, schema_editor):
    if schema_editor.connection.vendor != "postgresql":
        return
    with schema_editor.connection.cursor() as cur:
        cur.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm;")
        for table, col, name in _TRGM:
            cur.execute(
                f"CREATE INDEX IF NOT EXISTS {name} ON {table} USING gin ({col} gin_trgm_ops);"
            )


def drop_trgm(apps, schema_editor):
    if schema_editor.connection.vendor != "postgresql":
        return
    with schema_editor.connection.cursor() as cur:
        for _table, _col, name in _TRGM:
            cur.execute(f"DROP INDEX IF EXISTS {name};")


class Migration(migrations.Migration):
    dependencies = [
        ("dictionary", "0004_examplesentence_wordform_pitch_name"),
    ]

    operations = [migrations.RunPython(create_trgm, drop_trgm)]
