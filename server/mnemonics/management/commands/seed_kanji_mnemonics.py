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

Unverified new rows are PENDING + is_seed. Verified sources may be public, so ``build_packs`` picks them up into the
offline packs only after publication (same path as the kana seeds).

    python manage.py seed_kanji_mnemonics                # every level found
    python manage.py seed_kanji_mnemonics --levels n5 n4 # a subset
    python manage.py seed_kanji_mnemonics --dry-run      # report, write nothing
"""

from __future__ import annotations

from pathlib import Path

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from mnemonics.models import Mnemonic, MnemonicStatus
from mnemonics.source_validation import load_kanji_brief

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
        return (
            Path(settings.CONTENT_SOURCE_DIR) / "mnemonics" / (f"kanji_meaning_briefs.{level}.json")
        )

    def _load(self, level: str) -> tuple[list[dict], tuple[str, ...]]:
        try:
            return load_kanji_brief(self._brief_path(level), reading=False)
        except ValidationError as error:
            raise CommandError(str(error)) from error

    def handle(self, *args, **opts):
        levels = opts.get("levels") or [lvl for lvl in ALL_LEVELS if self._brief_path(lvl).exists()]
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
                        provenance = e["_provenance"][lang]
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

        total = Mnemonic.objects.filter(kind=Mnemonic.Kind.KANJI, is_seed=True).count()
        prefix = "[dry-run] " if dry else ""
        lang_summary = ", ".join(f"{k}={v}" for k, v in sorted(per_lang.items()))
        self.stdout.write(
            self.style.SUCCESS(
                f"{prefix}kanji mnemonics: {created} created, {updated} updated, "
                f"{unchanged} unchanged (levels: {' '.join(levels)}; {lang_summary}). "
                f"Seed kanji rows now: {total}."
            )
        )
