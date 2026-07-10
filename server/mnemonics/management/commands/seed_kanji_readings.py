"""Seed the bundled kanji READING mnemonics (kind='kanji_reading') from the
generated reading briefs, one seed row per (kanji, reading, language).

Each brief file ``content/kanji_reading_briefs.<level>.json`` holds entries
shaped ``{literal, reading, meaning, en, fr}``. Every non-empty language story
becomes one seed ``Mnemonic`` with ``kind='kanji_reading'`` and ``reading`` set
to the on-yomi it anchors: the ``en`` sentence under language='en', the ``fr``
sentence under 'fr'.

Idempotent: upserts by (character, kind, language, reading) among seed rows, so
regenerating a brief updates the story in place and a kanji can carry more than
one reading mnemonic later without collision. Touches only seed reading
mnemonics; safe to run over production.

Seeded rows are VISIBLE + is_seed, so ``build_packs`` bundles them into the
offline packs automatically.

    python manage.py seed_kanji_readings                 # every level found
    python manage.py seed_kanji_readings --levels n5 n4
    python manage.py seed_kanji_readings --dry-run
"""

from __future__ import annotations

import json
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from mnemonics.models import Mnemonic, MnemonicStatus

ALL_LEVELS = ("n5", "n4", "n3", "n2", "n1")
LANG_KEYS = ("en", "fr")


class Command(BaseCommand):
    help = "Seed kanji reading mnemonics (kind='kanji_reading') from the content briefs."

    def add_arguments(self, parser):
        parser.add_argument("--levels", nargs="+", choices=ALL_LEVELS)
        parser.add_argument("--dry-run", action="store_true")

    def _brief_path(self, level: str) -> Path:
        return Path(settings.CONTENT_PACK_DIR) / f"kanji_reading_briefs.{level}.json"

    def _load(self, level: str) -> list[dict]:
        path = self._brief_path(level)
        doc = json.loads(path.read_text(encoding="utf-8"))
        entries = doc["kanji"] if isinstance(doc, dict) else doc
        for e in entries:
            if not e.get("literal") or not e.get("reading"):
                raise CommandError(f"{path.name}: entry missing literal/reading: {e!r}")
            for key in LANG_KEYS:
                story = e.get(key, "")
                if story and ("—" in story or "–" in story):
                    raise CommandError(f"{path.name}: dash in {key} story for {e['literal']!r}")
        return entries

    def handle(self, *args, **opts):
        levels = opts.get("levels") or [
            lvl for lvl in ALL_LEVELS if self._brief_path(lvl).exists()
        ]
        if not levels:
            raise CommandError(
                f"No kanji_reading_briefs.<level>.json found in {settings.CONTENT_PACK_DIR}"
            )

        created = updated = unchanged = 0
        per_lang: dict[str, int] = {}
        dry = opts.get("dry_run", False)

        with transaction.atomic():
            for level in levels:
                for e in self._load(level):
                    char, reading = e["literal"], e["reading"]
                    for lang in LANG_KEYS:
                        story = (e.get(lang) or "").strip()
                        if not story:
                            continue
                        per_lang[lang] = per_lang.get(lang, 0) + 1
                        existing = Mnemonic.objects.filter(
                            character=char,
                            kind=Mnemonic.Kind.KANJI_READING,
                            language=lang,
                            reading=reading,
                            is_seed=True,
                            author__isnull=True,
                        ).first()
                        if existing is None:
                            created += 1
                            if not dry:
                                Mnemonic.objects.create(
                                    character=char,
                                    kind=Mnemonic.Kind.KANJI_READING,
                                    language=lang,
                                    reading=reading,
                                    author=None,
                                    is_seed=True,
                                    status=MnemonicStatus.VISIBLE,
                                    story=story,
                                )
                        elif existing.story != story or existing.status != MnemonicStatus.VISIBLE:
                            updated += 1
                            if not dry:
                                existing.story = story
                                existing.status = MnemonicStatus.VISIBLE
                                existing.save(update_fields=["story", "status", "updated_at"])
                        else:
                            unchanged += 1
            if dry:
                transaction.set_rollback(True)

        total = Mnemonic.objects.filter(
            kind=Mnemonic.Kind.KANJI_READING, is_seed=True
        ).count()
        prefix = "[dry-run] " if dry else ""
        lang_summary = ", ".join(f"{k}={v}" for k, v in sorted(per_lang.items()))
        self.stdout.write(
            self.style.SUCCESS(
                f"{prefix}kanji reading mnemonics: {created} created, {updated} updated, "
                f"{unchanged} unchanged (levels: {' '.join(levels)}; {lang_summary}). "
                f"Seed reading rows now: {total}."
            )
        )
