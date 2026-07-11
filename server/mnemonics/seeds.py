"""Load and install reviewed, language-native mnemonic source files."""

from __future__ import annotations

import json
from pathlib import Path

from django.core.exceptions import ValidationError
from django.db import transaction

from .models import (
    DeckStatus,
    Mnemonic,
    MnemonicDeck,
    MnemonicDeckItem,
    MnemonicStatus,
)

KANA_SCHEMA = "jibiki-kana-mnemonics/1"


def load_kana_entries(path: Path) -> list[dict[str, str]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema") != KANA_SCHEMA:
        raise ValidationError(f"Expected {KANA_SCHEMA} in {path}")
    if data.get("strategy") != "shape_plus_native_sound_anchor":
        raise ValidationError(f"Unexpected kana mnemonic strategy in {path}")
    languages = data.get("languages")
    entries = data.get("entries")
    if not isinstance(languages, list) or not languages:
        raise ValidationError("Kana mnemonic languages must be a non-empty list.")
    if not isinstance(entries, list):
        raise ValidationError("Kana mnemonic entries must be a list.")

    seen: set[str] = set()
    script_counts = {"hiragana": 0, "katakana": 0}
    allowed = {"character", "romaji", *languages}
    for entry in entries:
        character = entry.get("character", "")
        if len(character) != 1 or character in seen:
            raise ValidationError(f"Invalid or duplicate kana character: {character!r}")
        if extras := set(entry) - allowed:
            raise ValidationError(f"{character} has unknown fields: {sorted(extras)}")
        if not entry.get("romaji"):
            raise ValidationError(f"{character} has no romaji reading.")
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
    return entries


@transaction.atomic
def install_kana_entries(entries: list[dict[str, str]]) -> tuple[int, int, int]:
    languages = sorted({key for entry in entries for key in entry if len(key) == 2})
    by_language: dict[str, list[Mnemonic]] = {language: [] for language in languages}
    created = updated = 0

    for entry in entries:
        for language in languages:
            mnemonic, was_created = Mnemonic.objects.update_or_create(
                character=entry["character"],
                language=language,
                kind=Mnemonic.Kind.KANA,
                author=None,
                defaults={
                    "story": entry[language],
                    "status": MnemonicStatus.VISIBLE,
                    "is_seed": True,
                },
            )
            created += int(was_created)
            updated += int(not was_created)
            by_language[language].append(mnemonic)

    titles = {"en": "jibiki kana mnemonics", "fr": "Mnémoniques kana jibiki"}
    descriptions = {
        "en": "Language-native visual and sound associations for the 92 basic kana.",
        "fr": "Associations visuelles et sonores françaises pour les 92 kana de base.",
    }
    for language, mnemonics in by_language.items():
        deck, _ = MnemonicDeck.objects.update_or_create(
            is_seed=True,
            kind=Mnemonic.Kind.KANA,
            language=language,
            author=None,
            defaults={
                "title": titles.get(language, f"jibiki kana ({language})"),
                "description": descriptions.get(language, "Reviewed kana mnemonics."),
                "status": DeckStatus.VISIBLE,
            },
        )
        wanted: list[int] = []
        for position, mnemonic in enumerate(mnemonics):
            item, _ = MnemonicDeckItem.objects.update_or_create(
                deck=deck,
                mnemonic=mnemonic,
                defaults={"position": position},
            )
            wanted.append(item.pk)
        deck.items.exclude(pk__in=wanted).delete()
    return created, updated, len(by_language)
