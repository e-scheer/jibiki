"""Attach the bundled, generated art tile to a seed mnemonic.

The tiles under `seed_art/` are pre-rendered PNGs (one per gojūon kana) produced by
`scripts/kana_svg`. They are ingested through the *same* pipeline as a user upload
- `imaging.process_upload` (Pillow → WebP, EXIF-stripped, dim-capped) - so a seeded
mnemonic image is byte-for-byte the kind of file the app already serves. No new
dependency: only Pillow, which the ingest already uses.
"""

from __future__ import annotations

from pathlib import Path

from .imaging import process_upload

_ART_DIR = Path(__file__).with_name("seed_art")


def art_path(character: str) -> Path | None:
    """The bundled tile for a character (keyed by codepoint), or None."""
    if len(character) != 1:
        return None
    p = _ART_DIR / f"{ord(character):04x}.png"
    return p if p.exists() else None


def attach_art(mnemonic, *, overwrite: bool = False) -> bool:
    """Set `mnemonic.image` from the bundled tile if one exists. Idempotent: a
    mnemonic that already has an image is left alone unless `overwrite`. Never
    raises - a missing tile or an unwritable media store just means "no image",
    so seeding can't be broken by art. Returns True iff an image was written."""
    if mnemonic.image and not overwrite:
        return False
    p = art_path(mnemonic.character)
    if p is None:
        return False
    try:
        with p.open("rb") as fh:
            content, name, w, h = process_upload(fh)
        mnemonic.image.save(name, content, save=False)
        mnemonic.image_width, mnemonic.image_height = w, h
        mnemonic.save(update_fields=["image", "image_width", "image_height", "updated_at"])
    except Exception:  # missing WebP support, read-only media, bad file - skip quietly
        return False
    return True
