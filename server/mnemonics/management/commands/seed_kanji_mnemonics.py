"""Seed the bundled kanji MEANING mnemonics (kind='kanji') from the generated
content briefs, one seed row per (kanji, language).

Each source file ``content_sources/mnemonics/kanji_meaning_briefs.<level>.json`` holds entries
shaped ``{literal, meaning, components, kind, en, fr}``. Every non-empty
language story becomes one seed ``Mnemonic``: the ``en`` sentence under
language='en', the ``fr`` sentence under 'fr', and so on for any future
language key. ``meaning``/``components``/``kind`` are grounding metadata used to
author the story; the dictionary already carries the kanji's meaning, so only
the story text is stored.

Idempotent: upserts by (character, kind='kanji', language) among seed rows
(author is null, is_seed), so regenerating a brief updates the story in place
instead of piling up duplicates. Touches only seed mnemonics, so it is safe to
run over a production database without re-running the whole ``seed_demo``.

Seeded rows are VISIBLE + is_seed, so ``build_packs`` picks them up into the
offline packs automatically (same path as the kana seeds).

    python manage.py seed_kanji_mnemonics                # every level found
    python manage.py seed_kanji_mnemonics --levels n5 n4 # a subset
    python manage.py seed_kanji_mnemonics --dry-run      # report, write nothing
"""

from __future__ import annotations

import json
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from mnemonics.models import Mnemonic, MnemonicStatus

# JLPT levels, easiest first. A level is seeded only if its brief file exists.
ALL_LEVELS = ("n5", "n4", "n3", "n2", "n1")
class Command(BaseCommand):
    help = "Seed kanji meaning mnemonics (kind='kanji') from the content briefs."

    def add_arguments(self, parser):
        parser.add_argument(
            "--levels",
            nargs="+",
            choices=ALL_LEVELS,
            help="JLPT levels to seed (default: every brief file present).",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Report what would change without writing.",
        )

    def _brief_path(self, level: str) -> Path:
        return Path(settings.CONTENT_SOURCE_DIR) / "mnemonics" / (
            f"kanji_meaning_briefs.{level}.json"
        )

    def _load(self, level: str) -> tuple[list[dict], tuple[str, ...]]:
        path = self._brief_path(level)
        doc = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(doc, dict) or doc.get("strategy") != "visual_meaning":
            raise CommandError(f"{path.name}: expected visual_meaning strategy")
        entries = doc["kanji"] if isinstance(doc, dict) else doc
        languages = tuple(doc.get("languages", ())) if isinstance(doc, dict) else ()
        if not languages:
            raise CommandError(f"{path.name}: missing languages list")
        for e in entries:
            lit = e.get("literal", "")
            if not lit:
                raise CommandError(f"{path.name}: entry with empty literal")
            for key in languages:
                story = e.get(key, "")
                if not story.strip():
                    raise CommandError(f"{path.name}: missing {key} story for {lit!r}")
                if story and ("—" in story or "–" in story):
                    raise CommandError(f"{path.name}: dash in {key} story for {lit!r}")
        return entries, languages

    def handle(self, *args, **opts):
        levels = opts.get("levels") or [
            lvl for lvl in ALL_LEVELS if self._brief_path(lvl).exists()
        ]
        if not levels:
            raise CommandError(
                "No kanji meaning sources found in "
                f"{Path(settings.CONTENT_SOURCE_DIR) / 'mnemonics'}"
            )

        created = updated = unchanged = 0
        per_lang: dict[str, int] = {}
        dry = opts.get("dry_run", False)

        with transaction.atomic():
            for level in levels:
                entries, languages = self._load(level)
                for e in entries:
                    char = e["literal"]
                    for lang in languages:
                        story = (e.get(lang) or "").strip()
                        if not story:
                            continue
                        per_lang[lang] = per_lang.get(lang, 0) + 1
                        existing = Mnemonic.objects.filter(
                            character=char,
                            kind=Mnemonic.Kind.KANJI,
                            language=lang,
                            is_seed=True,
                            author__isnull=True,
                        ).first()
                        if existing is None:
                            created += 1
                            if not dry:
                                Mnemonic.objects.create(
                                    character=char,
                                    kind=Mnemonic.Kind.KANJI,
                                    language=lang,
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
            kind=Mnemonic.Kind.KANJI, is_seed=True
        ).count()
        prefix = "[dry-run] " if dry else ""
        lang_summary = ", ".join(f"{k}={v}" for k, v in sorted(per_lang.items()))
        self.stdout.write(
            self.style.SUCCESS(
                f"{prefix}kanji mnemonics: {created} created, {updated} updated, "
                f"{unchanged} unchanged (levels: {' '.join(levels)}; {lang_summary}). "
                f"Seed kanji rows now: {total}."
            )
        )
