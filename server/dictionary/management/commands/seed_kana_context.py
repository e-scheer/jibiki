"""Fill the kana learning-context fields from the bundled static tables.

Two kinds of context, both static and tiny, so we seed them rather than scrape:
  • writing origin - the man'yōgana kanji (or base kana) each glyph grew out of;
  • grammatical role - the job the particle kana do in a sentence (は topic,
    を object, の possessive, か question …).

Idempotent: updates bundled English context and adds missing examples while
preserving translations and custom examples in every language.

    python manage.py seed_kana_context
"""

from __future__ import annotations

from django.core.management.base import BaseCommand

from dictionary.kana_seeding import set_kana_content
from dictionary.models import Kana
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
            set_kana_content(kana, note, label, usage, examples)
            updated += 1
        self.stdout.write(
            self.style.SUCCESS(
                f"Kana context set - {updated} updated / {Kana.objects.count()} total."
            )
        )
