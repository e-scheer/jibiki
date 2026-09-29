"""Seed the bundled kanji READING mnemonics (kind='kanji_reading') from the
generated reading briefs, one seed row per (kanji, reading, language).

Each source file ``content_sources/mnemonics/kanji_reading_briefs.<level>.json`` holds entries
shaped ``{literal, reading, meaning, en, fr}``. Every non-empty language story
becomes one seed ``Mnemonic`` with ``kind='kanji_reading'`` and ``reading`` set
to the on-yomi it anchors: the ``en`` sentence under language='en', the ``fr``
sentence under 'fr'.

Idempotent: upserts by (character, kind, language, reading) among seed rows, so
regenerating a brief updates the story in place and a kanji can carry more than
one reading mnemonic later without collision. Touches only seed reading
mnemonics; safe to run over production.

Unverified new rows are PENDING + is_seed. Verified sources may be public, so ``build_packs`` bundles them into the
offline packs only after publication.

    python manage.py seed_kanji_readings                 # every level found
    python manage.py seed_kanji_readings --levels n5 n4
    python manage.py seed_kanji_readings --dry-run
"""

from __future__ import annotations

from pathlib import Path

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from mnemonics.models import Mnemonic, MnemonicStatus
from mnemonics.source_validation import load_kanji_brief

ALL_LEVELS = ("n5", "n4", "n3", "n2", "n1")


class Command(BaseCommand):
    help = "Seed kanji reading mnemonics (kind='kanji_reading') from the content briefs."

    def add_arguments(self, parser):
        parser.add_argument("--levels", nargs="+", choices=ALL_LEVELS)
        parser.add_argument("--dry-run", action="store_true")

    def _brief_path(self, level: str) -> Path:
        return (
            Path(settings.CONTENT_SOURCE_DIR) / "mnemonics" / (f"kanji_reading_briefs.{level}.json")
        )

    def _load(self, level: str) -> tuple[list[dict], tuple[str, ...]]:
        try:
            return load_kanji_brief(self._brief_path(level), reading=True)
        except ValidationError as error:
            raise CommandError(str(error)) from error

    def handle(self, *args, **opts):
        levels = opts.get("levels") or [lvl for lvl in ALL_LEVELS if self._brief_path(lvl).exists()]
        if not levels:
            raise CommandError(
                "No kanji reading sources found in "
                f"{Path(settings.CONTENT_SOURCE_DIR) / 'mnemonics'}"
            )

        created = updated = unchanged = 0
        per_lang: dict[str, int] = {}
        dry = opts.get("dry_run", False)

        with transaction.atomic():
            for level in levels:
                entries, languages = self._load(level)
                for e in entries:
                    char, reading = e["literal"], e["reading"]
                    for lang in languages:
                        story = (e.get(lang) or "").strip()
                        if not story:
                            continue
                        provenance = e["_provenance"][lang]
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
                                    status=(
                                        MnemonicStatus.VISIBLE
                                        if provenance["review_status"] == "verified"
                                        else MnemonicStatus.PENDING
                                    ),
                                    provenance=provenance,
                                    story=story,
                                )
                        elif existing.story != story or existing.provenance != provenance:
                            updated += 1
                            if not dry:
                                if (
                                    existing.story != story
                                    and existing.status == MnemonicStatus.VISIBLE
                                    and provenance["review_status"] != "verified"
                                ):
                                    existing.status = MnemonicStatus.PENDING
                                existing.story = story
                                existing.provenance = provenance
                                existing.save(
                                    update_fields=["story", "provenance", "status", "updated_at"]
                                )
                        else:
                            unchanged += 1
            if dry:
                transaction.set_rollback(True)

        total = Mnemonic.objects.filter(kind=Mnemonic.Kind.KANJI_READING, is_seed=True).count()
        prefix = "[dry-run] " if dry else ""
        lang_summary = ", ".join(f"{k}={v}" for k, v in sorted(per_lang.items()))
        self.stdout.write(
            self.style.SUCCESS(
                f"{prefix}kanji reading mnemonics: {created} created, {updated} updated, "
                f"{unchanged} unchanged (levels: {' '.join(levels)}; {lang_summary}). "
                f"Seed reading rows now: {total}."
            )
        )
