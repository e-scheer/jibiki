"""Fill the kana learning-context fields from the bundled static tables.

Two kinds of context, both static and tiny, so we seed them rather than scrape:
  • writing origin - the man'yōgana kanji (or base kana) each glyph grew out of;
  • grammatical role - the job the particle kana do in a sentence (は topic,
    を object, の possessive, か question …).

Idempotent and touches only the Kana table, so it is safe to run over a full
production database without re-running the whole ``seed_demo``.

    python manage.py seed_kana_context
"""

from __future__ import annotations

from django.core.management.base import BaseCommand

from dictionary.models import (
    Kana,
    KanaExplanation,
    KanaUsage,
    KanaUsageExample,
    KanaUsageExampleTranslation,
    KanaUsageTranslation,
)
from dictionary.seed_data import kana_origin, kana_usage, kana_usage_examples


class Command(BaseCommand):
    help = "Populate Kana origin + grammatical-role fields from the bundled tables."

    def handle(self, *args, **opts):
        updated = 0
        for kana in Kana.objects.all():
            origin, note = kana_origin(kana.romaji, kana.script, kana.kind)
            label, usage = kana_usage(kana.romaji, kana.script)
            examples = kana_usage_examples(kana.romaji, kana.script)
            Kana.objects.filter(pk=kana.pk).update(origin=origin)
            kana.explanations.all().delete()
            if note:
                KanaExplanation.objects.create(
                    kana=kana, language="en", origin_note=note
                )
            KanaUsage.objects.filter(kana=kana).delete()
            if label or usage or examples:
                role = KanaUsage.objects.create(kana=kana)
                if label or usage:
                    KanaUsageTranslation.objects.create(
                        usage=role, language="en", label=label, explanation=usage
                    )
                for order, item in enumerate(examples):
                    example = KanaUsageExample.objects.create(
                        usage=role,
                        order=order,
                        before=item.get("before", ""),
                        particle=item.get("particle", ""),
                        after=item.get("after", ""),
                        pronunciation=item.get("romaji", ""),
                    )
                    if item.get("en"):
                        KanaUsageExampleTranslation.objects.create(
                            example=example, language="en", text=item["en"]
                        )
            updated += 1
        self.stdout.write(
            self.style.SUCCESS(f"Kana context set - {updated} updated / {Kana.objects.count()} total.")
        )
