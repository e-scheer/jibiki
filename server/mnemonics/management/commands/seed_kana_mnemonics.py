"""Seed reviewed kana mnemonics from the canonical content source."""

from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand

from mnemonics.seeds import install_kana_entries, load_kana_entries


class Command(BaseCommand):
    help = "Seed language-native hiragana and katakana mnemonics."

    def add_arguments(self, parser):
        parser.add_argument("--dry-run", action="store_true")

    def handle(self, *args, **options):
        path = Path(settings.CONTENT_SOURCE_DIR) / "mnemonics" / "kana_stories.json"
        entries = load_kana_entries(path)
        if options["dry_run"]:
            languages = sorted({key for entry in entries for key in entry if len(key) == 2})
            self.stdout.write(
                self.style.SUCCESS(
                    f"[dry run] {len(entries)} kana, {len(languages)} languages, no writes"
                )
            )
            return
        created, updated, decks = install_kana_entries(entries)
        self.stdout.write(
            self.style.SUCCESS(
                f"Kana mnemonics: {created} created, {updated} updated, {decks} decks"
            )
        )
