"""Restore missing reference rows from a verified Jibiki base pack.

This reconciles a demo server with its shipped desktop corpus. Word identities
are preserved verbatim because personal study cards refer to these integer IDs.
Existing content and personal tables are never replaced. Conflicting identities
abort the entire transaction. This is recovery of an existing snapshot, not a
claim that its editorial content has been independently reviewed.
"""

import gzip
import hashlib
import json
import sqlite3
from contextlib import closing
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.core.management.color import no_style
from django.db import connection, transaction
from django.utils.translation import gettext as _

from dictionary import models as m


class Command(BaseCommand):
    help = _("Restore missing dictionary rows from a verified base pack without changing IDs.")

    def add_arguments(self, parser):
        parser.add_argument("pack", type=Path)
        parser.add_argument("--manifest", type=Path, required=True)
        parser.add_argument(
            "--apply", action="store_true", help=_("Apply after all identity checks.")
        )

    def handle(self, *args, **options):
        manifest = json.loads(options["manifest"].read_text(encoding="utf-8"))
        compressed = options["pack"].read_bytes()
        if hashlib.sha256(compressed).hexdigest() != manifest.get("sha256"):
            raise CommandError(_("Pack checksum does not match its manifest."))
        raw = gzip.decompress(compressed)
        if hashlib.sha256(raw).hexdigest() != manifest.get("sha256_db"):
            raise CommandError(_("Database checksum does not match its manifest."))
        with closing(sqlite3.connect(":memory:")) as source:
            source.deserialize(raw)
            source.row_factory = sqlite3.Row
            if source.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
                raise CommandError(_("The source database failed its integrity check."))
            with transaction.atomic():
                counts = self.restore(source)
                if not options["apply"]:
                    transaction.set_rollback(True)
        self.stdout.write(json.dumps({"applied": options["apply"], "created": counts}))

    def restore(self, source):
        counts = {}
        touched = []

        def insert(model, rows, identity=("id",), compare=()):
            """Validate primary and natural identity before adding any missing row."""
            fields = tuple(dict.fromkeys((*identity, *compare)))
            existing = {
                tuple(row[f] for f in identity): row for row in model.objects.values(*fields)
            }
            pending = []
            created = 0
            for values in rows:
                key = tuple(values[f] for f in identity)
                old = existing.get(key)
                if old is not None:
                    if any(old[f] != values[f] for f in compare):
                        raise CommandError(
                            _("Reference identity conflict in %(table)s: %(key)s")
                            % {"table": model._meta.db_table, "key": key}
                        )
                    continue
                existing[key] = {f: values[f] for f in fields}
                pending.append(model(**values))
                if len(pending) >= 2000:
                    model.objects.bulk_create(pending, batch_size=1000)
                    created += len(pending)
                    pending.clear()
            model.objects.bulk_create(pending, batch_size=1000)
            counts[model._meta.db_table] = created + len(pending)
            touched.append(model)

        def rows(table, fields, rename=None, json_fields=(), convert=None):
            rename = rename or {}
            for row in source.execute(f'SELECT * FROM "{table}"'):
                value = {rename.get(f, f): row[f] for f in fields}
                for field in json_fields:
                    value[field] = json.loads(value[field])
                if convert:
                    value = convert(value)
                yield value

        insert(
            m.Word, rows("words", ("id", "seq", "is_common", "jlpt", "freq_rank")), compare=("seq",)
        )
        insert(
            m.WordForm,
            rows(
                "word_forms",
                ("word_id", "text", "kind", "is_common", "ord", "pitch"),
                {"ord": "order"},
                convert=lambda v: {**v, "kind": "kanji" if v["kind"] == 0 else "kana"},
            ),
            identity=("word_id", "kind", "text", "order"),
        )
        insert(
            m.Sense,
            rows(
                "senses",
                ("word_id", "ord", "pos", "misc", "field"),
                {"ord": "order"},
                json_fields=("pos", "misc", "field"),
            ),
            identity=("word_id", "order"),
        )
        sense_ids = {
            (word, order): pk
            for word, order, pk in m.Sense.objects.values_list("word_id", "order", "id")
        }
        sense_map = {
            row["id"]: sense_ids[(row["word_id"], row["ord"])]
            for row in source.execute("SELECT id,word_id,ord FROM senses")
        }
        insert(
            m.Gloss,
            rows(
                "glosses",
                ("sense_id", "language", "ord", "text"),
                {"ord": "order"},
                convert=lambda v: {**v, "sense_id": sense_map[v["sense_id"]]},
            ),
            identity=("sense_id", "language", "order"),
        )
        insert(
            m.SenseNote,
            rows(
                "sense_notes",
                ("sense_id", "language", "text"),
                convert=lambda v: {**v, "sense_id": sense_map[v["sense_id"]]},
            ),
            identity=("sense_id", "language"),
        )

        kanji_fields = (
            "literal",
            "grade",
            "stroke_count",
            "jlpt",
            "freq_rank",
            "radical_number",
            "on_readings",
            "kun_readings",
            "nanori",
            "components",
            "formation",
            "phonetic",
            "stroke_paths",
            "stroke_viewbox",
        )
        insert(
            m.Kanji,
            rows(
                "kanji",
                kanji_fields,
                json_fields=("on_readings", "kun_readings", "nanori", "components", "stroke_paths"),
            ),
            identity=("literal",),
        )
        kanji_ids = dict(m.Kanji.objects.values_list("literal", "id"))
        insert(
            m.KanjiMeaning,
            rows(
                "kanji_meanings",
                ("kanji", "language", "ord", "text"),
                {"kanji": "kanji_id", "ord": "order"},
                convert=lambda v: {**v, "kanji_id": kanji_ids[v["kanji_id"]]},
            ),
            identity=("kanji_id", "language", "order"),
        )
        insert(
            m.KanjiExplanation,
            rows(
                "kanji_explanations",
                ("kanji", "language", "origin"),
                {"kanji": "kanji_id"},
                convert=lambda v: {**v, "kanji_id": kanji_ids[v["kanji_id"]]},
            ),
            identity=("kanji_id", "language"),
        )
        insert(
            m.Radical, rows("radicals", ("literal", "strokes", "reading")), identity=("literal",)
        )
        radical_ids = dict(m.Radical.objects.values_list("literal", "id"))
        insert(
            m.RadicalMeaning,
            rows(
                "radical_meanings",
                ("radical", "language", "text"),
                {"radical": "radical_id"},
                convert=lambda v: {**v, "radical_id": radical_ids[v["radical_id"]]},
            ),
            identity=("radical_id", "language"),
        )
        insert(
            m.Kana,
            rows(
                "kana",
                ("char", "romaji", "script", "kind", "row", "ord", "origin"),
                {"ord": "order"},
            ),
            identity=("char",),
        )
        kana_ids = dict(m.Kana.objects.values_list("char", "id"))
        insert(
            m.KanaExplanation,
            rows(
                "kana_explanations",
                ("kana", "language", "origin_note"),
                {"kana": "kana_id"},
                convert=lambda v: {**v, "kana_id": kana_ids[v["kana_id"]]},
            ),
            identity=("kana_id", "language"),
        )
        # The demo already contains richer grammatical examples than this old
        # snapshot. Restore usage labels by natural identity, never old row IDs.
        for row in source.execute("SELECT * FROM kana_usages"):
            usage, _created = m.KanaUsage.objects.get_or_create(kana_id=kana_ids[row["kana"]])
            for translation in source.execute(
                "SELECT * FROM kana_usage_translations WHERE usage_id=?", (row["id"],)
            ):
                m.KanaUsageTranslation.objects.get_or_create(
                    usage=usage,
                    language=translation["language"],
                    defaults={
                        "label": translation["label"],
                        "explanation": translation["explanation"],
                    },
                )
        # Explicit restored IDs must not collide with the next server allocation.
        with connection.cursor() as cursor:
            for sql in connection.ops.sequence_reset_sql(no_style(), touched):
                cursor.execute(sql)
        return counts
