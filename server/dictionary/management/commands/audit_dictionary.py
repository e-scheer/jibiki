"""Measure the canonical database without changing content or user data."""

import json
from datetime import UTC, datetime
from pathlib import Path

from django.core.management.base import BaseCommand
from django.db.models import Count, Exists, OuterRef, Q

from dictionary import models as m
from mnemonics.models import Mnemonic


class Command(BaseCommand):
    help = "Export measured dictionary coverage and structural issues as JSON."

    def add_arguments(self, parser):
        parser.add_argument("--out", type=Path, required=True)

    def handle(self, *args, **options):
        def distribution(queryset, field):
            return {
                str(row[field]): row["n"]
                for row in queryset.values(field).annotate(n=Count("pk")).order_by(field)
            }

        def missing(model, related_model, key):
            return (
                model.objects.annotate(
                    has_child=Exists(related_model.objects.filter(**{key: OuterRef("pk")}))
                )
                .filter(has_child=False)
                .count()
            )

        models = [
            m.Word,
            m.WordForm,
            m.Sense,
            m.Gloss,
            m.SenseNote,
            m.Kanji,
            m.KanjiMeaning,
            m.KanjiExplanation,
            m.Kana,
            m.KanaExplanation,
            m.KanaUsage,
            m.KanaUsageExample,
            m.KanaUsageExampleTranslation,
            m.Radical,
            m.RadicalMeaning,
            m.Name,
            m.NameTranslation,
            m.ExampleSentence,
            m.ExampleTranslation,
            m.ExampleSenseLink,
        ]
        if hasattr(m, "KanaWordExample"):
            models.append(m.KanaWordExample)
        issue_counts = {
            "words_without_forms": missing(m.Word, m.WordForm, "word_id"),
            "words_without_senses": missing(m.Word, m.Sense, "word_id"),
            "senses_without_glosses": missing(m.Sense, m.Gloss, "sense_id"),
            "empty_glosses": m.Gloss.objects.filter(text="").count(),
            "invalid_word_jlpt": m.Word.objects.filter(Q(jlpt__lt=1) | Q(jlpt__gt=5)).count(),
            "invalid_kanji_jlpt": m.Kanji.objects.filter(Q(jlpt__lt=1) | Q(jlpt__gt=5)).count(),
            "duplicate_form_identity_groups": m.WordForm.objects.values("word_id", "kind", "text")
            .annotate(n=Count("pk"))
            .filter(n__gt=1)
            .count(),
            "duplicate_sense_order_groups": m.Sense.objects.values("word_id", "order")
            .annotate(n=Count("pk"))
            .filter(n__gt=1)
            .count(),
        }
        word_languages = {
            row["language"]: row["n"]
            for row in m.Gloss.objects.values("language")
            .annotate(n=Count("sense__word_id", distinct=True))
            .order_by("language")
        }
        payload = {
            "schema": "jibiki-dictionary-quality/1",
            "generated_at": datetime.now(UTC).isoformat(),
            "counts": {model._meta.db_table: model.objects.count() for model in models},
            "structural_issues": issue_counts,
            "coverage": {
                "words_with_gloss_by_language": word_languages,
                "glosses_by_language": distribution(m.Gloss.objects, "language"),
                "kanji_meanings_by_language": distribution(m.KanjiMeaning.objects, "language"),
                "kana_origins_by_language": distribution(m.KanaExplanation.objects, "language"),
                "kana_examples_by_language": distribution(
                    m.KanaUsageExampleTranslation.objects, "language"
                ),
                "example_translations_by_language": distribution(
                    m.ExampleTranslation.objects, "language"
                ),
                "kanji_with_strokes": m.Kanji.objects.exclude(stroke_paths=[]).count(),
                "word_readings_with_pitch": m.WordForm.objects.exclude(pitch="").count(),
                "words_without_provenance": m.Word.objects.filter(provenance={}).count(),
                "kanji_without_provenance": m.Kanji.objects.filter(provenance={}).count(),
                "kana_by_kind": distribution(m.Kana.objects, "kind"),
                "mnemonics_by_language": distribution(
                    Mnemonic.objects.filter(is_seed=True), "language"
                ),
                "mnemonics_by_moderation": distribution(
                    Mnemonic.objects.filter(is_seed=True), "status"
                ),
            },
            "interpretation": "Counts measure source coverage and structure, not independent linguistic review.",
        }
        options["out"].parent.mkdir(parents=True, exist_ok=True)
        options["out"].write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        self.stdout.write(json.dumps(payload["structural_issues"]))
