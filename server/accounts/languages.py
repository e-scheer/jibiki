"""ISO 639-1 handling for mnemonic languages - the single source of truth.

Mnemonic languages are OPEN (the community can start any language before we
curate it - the schema is (character, language)), but only REAL languages:
codes are checked against the ISO 639 registry (pycountry) so a typo or a
made-up tag can never mint a phantom language bucket. English is the display
backup everywhere a language has no content yet.

- `DEFAULT_LANGUAGE`: the one backup/default, referenced instead of a bare "en".
- `validate_language_code`: strict - write paths (raises on bad input).
- `normalize_language_code`: lenient - read/filter paths (lowercases so
  `?language=EN` still matches the stored "en"; never raises).
"""

from __future__ import annotations

import pycountry
from django.utils.translation import gettext as _
from rest_framework import serializers

DEFAULT_LANGUAGE = "en"


def _is_iso_639_1(code: str) -> bool:
    return len(code) == 2 and pycountry.languages.get(alpha_2=code) is not None


def validate_language_code(value: str) -> str:
    """Strict: normalize + validate a two-letter ISO 639-1 code, or raise a DRF
    ValidationError. Use on write paths (profile, mnemonic/deck creation)."""
    code = (value or "").strip().lower()
    if not _is_iso_639_1(code):
        raise serializers.ValidationError(
            _("'%(value)s' is not an ISO 639-1 language code.") % {"value": value}
        )
    return code


def normalize_language_code(value: str | None, *, fallback: str = DEFAULT_LANGUAGE) -> str:
    """Lenient: lowercase/strip a language for filtering so case never silently
    zeroes a result set. Returns [fallback] for empty/invalid input - read
    paths must not 400 on a stray query param, just resolve sanely."""
    code = (value or "").strip().lower()
    return code if _is_iso_639_1(code) else fallback
