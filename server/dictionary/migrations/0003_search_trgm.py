"""Trigram GIN indexes for dictionary search.

Search filters `text__icontains` / `text__istartswith` on WordForm, Gloss and
KanjiMeaning. On PostgreSQL those are `LIKE '%q%'` - unindexable by a plain
B-tree, so they seq-scan the (potentially ~1M-row) tables three times per query.
pg_trgm + a GIN(gin_trgm_ops) index makes them index-backed.

This is a pure DB optimization, kept out of model state (Postgres-only).
"""

from django.db import migrations

# (table, column, index name)
_TRGM = [
    ("dict_word_forms", "text", "dict_word_forms_text_trgm"),
    ("dict_glosses", "text", "dict_glosses_text_trgm"),
    ("dict_kanji_meanings", "text", "dict_kanji_meanings_text_trgm"),
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
        ("dictionary", "0002_kanji_stroke_paths_kanji_stroke_viewbox"),
    ]

    operations = [migrations.RunPython(create_trgm, drop_trgm)]
