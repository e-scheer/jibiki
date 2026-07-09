"""Import pitch-accent patterns (Kanjium accents.txt) onto reading WordForms.

accents.txt is ``term<TAB>reading<TAB>pitch`` (pitch e.g. "0" or "0,2"). We set
the pattern on each kana reading form, matching by (a surface/kanji form of the
word, reading) and falling back to (reading, reading) for kana-only words. Run
AFTER import_jmdict.

    python manage.py import_pitch /path/to/accents.txt
"""

from __future__ import annotations

from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from dictionary.models import Word, WordForm


class Command(BaseCommand):
    help = "Import Kanjium pitch-accent patterns onto reading forms."

    def add_arguments(self, parser):
        parser.add_argument("path", help="Path to accents.txt")

    def handle(self, *args, **opts):
        path = Path(opts["path"])
        if not path.exists():
            raise CommandError(f"file not found: {path}")

        acc: dict[tuple[str, str], str] = {}
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            parts = line.split("\t")
            if len(parts) < 3:
                continue
            term, reading, pitch = parts[0], parts[1], parts[2].strip()
            if pitch:
                acc.setdefault((term, reading), pitch)

        to_update: list[WordForm] = []
        total = 0
        qs = Word.objects.prefetch_related("forms").iterator(chunk_size=1000)
        for w in qs:
            forms = list(w.forms.all())
            kanji_forms = [f.text for f in forms if f.kind == WordForm.Kind.KANJI]
            for r in forms:
                if r.kind != WordForm.Kind.KANA:
                    continue
                pitch = None
                for kf in kanji_forms:
                    pitch = acc.get((kf, r.text))
                    if pitch:
                        break
                pitch = pitch or acc.get((r.text, r.text))
                if pitch and r.pitch != pitch:
                    r.pitch = pitch
                    to_update.append(r)
                    if len(to_update) >= 2000:
                        WordForm.objects.bulk_update(to_update, ["pitch"])
                        total += len(to_update)
                        to_update = []
        if to_update:
            WordForm.objects.bulk_update(to_update, ["pitch"])
            total += len(to_update)
        self.stdout.write(self.style.SUCCESS(f"Done - pitch set on {total} readings."))
