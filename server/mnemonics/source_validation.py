"""Structural validation and traceable review evidence for bundled stories.

A non-empty story is not a linguistic review. Publication requires explicit,
language-specific evidence tied to the exact story checksum.
"""

import hashlib
import json
import re
from datetime import date
from pathlib import Path

import pycountry
from django.core.exceptions import ValidationError


def language_catalogue(doc):
    languages = doc.get("languages")
    if not isinstance(languages, list) or not languages:
        raise ValidationError("Missing languages list.")
    if any(
        not isinstance(code, str)
        or len(code) != 2
        or code != code.lower()
        or pycountry.languages.get(alpha_2=code) is None
        for code in languages
    ):
        raise ValidationError("Expected lowercase ISO 639-1 language codes.")
    if len(set(languages)) != len(languages):
        raise ValidationError("Duplicate language code.")
    return tuple(languages)


def story_provenance(path: Path, doc, entry, language):
    story = entry[language].strip()
    story_hash = hashlib.sha256(story.encode("utf-8")).hexdigest()
    reviews = entry.get("reviews", {})
    if not isinstance(reviews, dict):
        raise ValidationError("Reviews must be an object keyed by language.")
    review = reviews.get(language, {})
    if not isinstance(review, dict):
        raise ValidationError("Review evidence must be an object per language.")
    status = review.get("status", "unverified")
    if status not in ("unverified", "verified"):
        raise ValidationError("Unknown editorial review status.")
    if status == "verified":
        if not all(
            isinstance(review.get(key), str) and review[key].strip()
            for key in ("reviewer", "reviewed_at", "story_sha256")
        ):
            raise ValidationError("Verified stories require reviewer, date and story checksum.")
        try:
            if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", review["reviewed_at"]):
                raise ValueError("Expected extended ISO date")
            date.fromisoformat(review["reviewed_at"])
        except ValueError as error:
            raise ValidationError("Review date must be YYYY-MM-DD.") from error
        if review["story_sha256"] != story_hash:
            raise ValidationError("Review checksum does not match this story.")
    if "_source_sha256" not in doc:
        doc["_source_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    result = {
        "source_type": "bundled",
        "source_path": f"mnemonics/{path.name}",
        "source_sha256": doc["_source_sha256"],
        "story_sha256": story_hash,
        "language": language,
        "strategy": doc["strategy"],
        "review_status": status,
        "generation_method": doc.get("generation_method", "unknown"),
    }
    if status == "verified":
        result["review"] = review
    return result


def load_kanji_brief(path: Path, *, reading: bool):
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise ValidationError(f"Cannot read {path.name}: {error}") from error
    kind = "reading" if reading else "meaning"
    expected = f"jibiki-kanji-{kind}-briefs/1"
    strategy = "phonetic_reading" if reading else "visual_meaning"
    if (
        not isinstance(doc, dict)
        or doc.get("schema") != expected
        or doc.get("strategy") != strategy
    ):
        raise ValidationError(f"{path.name}: invalid schema or strategy.")
    languages = language_catalogue(doc)
    entries = doc.get("kanji")
    if not isinstance(entries, list) or doc.get("count") != len(entries):
        raise ValidationError(f"{path.name}: count does not match kanji entries.")
    seen = set()
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValidationError("Every kanji entry must be an object.")
        literal = entry.get("literal", "")
        if (
            not isinstance(literal, str)
            or len(literal) != 1
            or not ("\u3400" <= literal <= "\u9fff" or "\U00020000" <= literal <= "\U000323af")
        ):
            raise ValidationError(f"Invalid kanji literal: {literal!r}")
        sound = entry.get("reading", "")
        if reading and (not isinstance(sound, str) or not re.fullmatch(r"[ァ-ヺー]+", sound)):
            raise ValidationError(f"{literal}: expected a katakana on-yomi reading.")
        key = (literal, sound)
        if key in seen:
            raise ValidationError(f"Duplicate kanji target: {key}")
        seen.add(key)
        for language in languages:
            story = entry.get(language)
            if not isinstance(story, str) or not story.strip():
                raise ValidationError(f"{literal}: missing {language} story.")
            if any(mark in story for mark in (chr(0x2013), chr(0x2014))):
                raise ValidationError(f"{literal}: dash in {language} story.")
        if reading and len({entry[language].strip() for language in languages}) != len(languages):
            raise ValidationError(f"{literal}: duplicated language story.")
        entry["_provenance"] = {
            language: story_provenance(path, doc, entry, language) for language in languages
        }
    return entries, languages
