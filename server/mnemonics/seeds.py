"""Load language-scoped source files without inventing editorial review."""

from __future__ import annotations

import json
from pathlib import Path

from django.core.exceptions import ValidationError
from django.db import transaction

from dictionary.seed_data import KANA

from .models import (
    DeckStatus,
    Mnemonic,
    MnemonicDeck,
    MnemonicDeckItem,
    MnemonicStatus,
)
from .source_validation import language_catalogue, story_provenance

KANA_SCHEMA = "jibiki-kana-mnemonics/1"


def load_kana_entries(path: Path) -> list[dict[str, str]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or data.get("schema") != KANA_SCHEMA:
        raise ValidationError(f"Expected {KANA_SCHEMA} in {path}")
    if data.get("strategy") != "shape_plus_native_sound_anchor":
        raise ValidationError(f"Unexpected kana mnemonic strategy in {path}")
    languages = language_catalogue(data)
    entries = data.get("entries")
    if not isinstance(entries, list):
        raise ValidationError("Kana mnemonic entries must be a list.")

    seen: set[str] = set()
    script_counts = {"hiragana": 0, "katakana": 0}
    allowed = {"character", "romaji", "reviews", *languages}
    canonical = {char: row[0] for row in KANA if row[4] == "gojuon" for char in row[1:3]}
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValidationError("Every kana entry must be an object.")
        character = entry.get("character", "")
        if not isinstance(character, str) or len(character) != 1 or character in seen:
            raise ValidationError(f"Invalid or duplicate kana character: {character!r}")
        if extras := set(entry) - allowed:
            raise ValidationError(f"{character} has unknown fields: {sorted(extras)}")
        if canonical.get(character) != entry.get("romaji"):
            raise ValidationError(f"{character}: expected canonical basic kana and romaji.")
        seen.add(character)
        if "\u3040" <= character <= "\u309f":
            script_counts["hiragana"] += 1
        elif "\u30a0" <= character <= "\u30ff":
            script_counts["katakana"] += 1
        else:
            raise ValidationError(f"Not a hiragana or katakana character: {character}")
        for language in languages:
            if not isinstance(entry.get(language), str) or not entry[language].strip():
                raise ValidationError(f"{character} has no {language} story.")
            if character not in entry[language]:
                raise ValidationError(f"{character} is not grounded in its {language} story.")
        if len({entry[language].strip() for language in languages}) != len(languages):
            raise ValidationError(f"{character} reuses the same story across languages.")
    if len(entries) != 92:
        raise ValidationError(f"Expected 92 basic kana, found {len(entries)}.")
    if script_counts != {"hiragana": 46, "katakana": 46}:
        raise ValidationError(f"Expected 46 kana per script, found {script_counts}.")
    if seen != set(canonical):
        raise ValidationError("Catalogue must cover the exact canonical basic kana set.")
    for entry in entries:
        entry["_provenance"] = {
            language: story_provenance(path, data, entry, language) for language in languages
        }
    return entries


@transaction.atomic
def install_kana_entries(entries: list[dict[str, str]]) -> tuple[int, int, int]:
    languages = sorted({key for entry in entries for key in entry if len(key) == 2})
    by_language: dict[str, list[Mnemonic]] = {language: [] for language in languages}
    created = updated = 0

    for entry in entries:
        for language in languages:
            provenance = entry.get("_provenance", {}).get(
                language,
                {
                    "source_type": "bundled",
                    "review_status": "unverified",
                    "generation_method": "unknown",
                },
            )
            mnemonic, was_created = Mnemonic.objects.get_or_create(
                character=entry["character"],
                language=language,
                kind=Mnemonic.Kind.KANA,
                author=None,
                is_seed=True,
                defaults={
                    "story": entry[language],
                    "provenance": provenance,
                    "status": (
                        MnemonicStatus.VISIBLE
                        if provenance["review_status"] == "verified"
                        else MnemonicStatus.PENDING
                    ),
                },
            )
            if not was_created:
                # A seed rerun cannot undo moderation or republish a removal.
                if (
                    mnemonic.story != entry[language]
                    and mnemonic.status == MnemonicStatus.VISIBLE
                    and provenance["review_status"] != "verified"
                ):
                    mnemonic.status = MnemonicStatus.PENDING
                mnemonic.story = entry[language]
                mnemonic.provenance = provenance
                mnemonic.save(update_fields=["story", "provenance", "status", "updated_at"])
            created += int(was_created)
            updated += int(not was_created)
            by_language[language].append(mnemonic)

    titles = {"en": "jibiki kana mnemonics", "fr": "Mnémoniques kana jibiki"}
    descriptions = {
        "en": "Language-native visual and sound associations for the 92 basic kana.",
        "fr": "Associations visuelles et sonores françaises pour les 92 kana de base.",
    }
    for language, mnemonics in by_language.items():
        deck, _ = MnemonicDeck.objects.get_or_create(
            is_seed=True,
            kind=Mnemonic.Kind.KANA,
            language=language,
            author=None,
            defaults={
                "title": titles.get(language, f"jibiki kana ({language})"),
                "description": descriptions.get(
                    language, "Language-scoped kana mnemonic catalogue."
                ),
                "status": (
                    DeckStatus.VISIBLE
                    if any(m.status == MnemonicStatus.VISIBLE for m in mnemonics)
                    else DeckStatus.PENDING
                ),
            },
        )
        for position, mnemonic in enumerate(mnemonics):
            MnemonicDeckItem.objects.update_or_create(
                deck=deck,
                mnemonic=mnemonic,
                defaults={"position": position},
            )
        # Keep existing deck items and saved associations on repeat imports.
    return created, updated, len(by_language)
