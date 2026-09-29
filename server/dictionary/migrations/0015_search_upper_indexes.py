"""Index the UPPER expressions Django actually uses for insensitive searches."""

from django.db import migrations


INDEXES = [
    ("dict_forms_upper_trgm", "dict_word_forms", "gin (UPPER(text) gin_trgm_ops)"),
    ("dict_glosses_upper_trgm", "dict_glosses", "gin (UPPER(text) gin_trgm_ops)"),
    ("dict_names_kanji_upper_trgm", "dict_names", "gin (UPPER(kanji) gin_trgm_ops)"),
    ("dict_names_reading_upper_trgm", "dict_names", "gin (UPPER(reading) gin_trgm_ops)"),
    ("dict_name_trans_upper_trgm", "dict_name_translations", "gin (UPPER(text) gin_trgm_ops)"),
    ("dict_forms_upper_prefix", "dict_word_forms", "btree (UPPER(text) text_pattern_ops)"),
    ("dict_glosses_upper_prefix", "dict_glosses", "btree (UPPER(text) text_pattern_ops)"),
]


def create_indexes(apps, schema_editor):
    if schema_editor.connection.vendor != "postgresql":
        return
    with schema_editor.connection.cursor() as cursor:
        for name, table, expression in INDEXES:
            # An interrupted concurrent build leaves an unusable index behind.
            cursor.execute(
                "SELECT indisvalid FROM pg_index WHERE indexrelid = to_regclass(%s)", [name]
            )
            state = cursor.fetchone()
            if state and not state[0]:
                cursor.execute(f"DROP INDEX CONCURRENTLY {name}")
            cursor.execute(
                f"CREATE INDEX CONCURRENTLY IF NOT EXISTS {name} ON {table} USING {expression}"
            )


def drop_indexes(apps, schema_editor):
    if schema_editor.connection.vendor != "postgresql":
        return
    with schema_editor.connection.cursor() as cursor:
        for name, _, _ in reversed(INDEXES):
            cursor.execute(f"DROP INDEX CONCURRENTLY IF EXISTS {name}")


class Migration(migrations.Migration):
    atomic = False
    dependencies = [("dictionary", "0014_radical_provenance")]
    operations = [migrations.RunPython(create_indexes, drop_indexes)]
