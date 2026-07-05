"""Fill the kana learning-context fields from the bundled static tables.

Two kinds of context, both static and tiny, so we seed them rather than scrape:
  • writing origin — the man'yōgana kanji (or base kana) each glyph grew out of;
  • grammatical role — the job the particle kana do in a sentence (は topic,
    を object, の possessive, か question …).

Idempotent and touches only the Kana table, so it is safe to run over a full
production database without re-running the whole ``seed_demo``.

    python manage.py seed_kana_context
"""

from __future__ import annotations

from django.core.management.base import BaseCommand

from dictionary.models import Kana
from dictionary.seed_data import kana_origin, kana_usage


class Command(BaseCommand):
    help = "Populate Kana origin + grammatical-role fields from the bundled tables."

    def handle(self, *args, **opts):
        updated = 0
        for kana in Kana.objects.all():
            origin, note = kana_origin(kana.romaji, kana.script, kana.kind)
            label, usage = kana_usage(kana.romaji, kana.script)
            changed = (
                kana.origin != origin
                or kana.origin_note != note
                or kana.usage_label != label
                or kana.usage != usage
            )
            if not changed:
                continue
            Kana.objects.filter(pk=kana.pk).update(
                origin=origin, origin_note=note, usage_label=label, usage=usage
            )
            updated += 1
        self.stdout.write(
            self.style.SUCCESS(f"Kana context set — {updated} updated / {Kana.objects.count()} total.")
        )
