"""Assemble Recipe objects: wire each kana's draw function (from the per-script
registries) to its metadata (from the research JSON) and the canonical ordering
(from content/kana.json).

Dakuten / handakuten kana (が, ぱ, ヴ…) reuse their *base* recipe: the voiced
glyph already carries the ゛/゜ marks in its own outline, so tinting it draws them
for free, and the mnemonic picture is the base character's picture.
"""

from __future__ import annotations

import json
import unicodedata
from functools import lru_cache
from pathlib import Path

from .render import Recipe
from .recipes_hiragana import REGISTRY as HIRA
from .recipes_katakana import REGISTRY as KATA

HERE = Path(__file__).parent
_CONTENT = HERE.parent.parent / "content" / "kana.json"


def _base_char(ch: str) -> str:
    """The unvoiced base of a kana: NFD strips the combining ゛/゜ mark."""
    return unicodedata.normalize("NFD", ch)[0]


@lru_cache(maxsize=1)
def _research() -> dict:
    out: dict[str, dict] = {}
    for name in ("research_hiragana.json", "research_katakana.json"):
        for e in json.loads((HERE / name).read_text(encoding="utf-8")):
            out[e["char"]] = e
    return out


@lru_cache(maxsize=1)
def _kana_table() -> list[dict]:
    return json.loads(_CONTENT.read_text(encoding="utf-8"))


def registry_for(script: str) -> dict:
    return HIRA if script == "hiragana" else KATA


def recipe_for(char: str, romaji: str, script: str) -> Recipe | None:
    base = _base_char(char)
    reg = registry_for(script)
    draw = reg.get(char) or reg.get(base)
    if draw is None:
        return None
    meta = _research().get(char) or _research().get(base) or {}
    return Recipe(
        char=char,
        romaji=romaji,
        script=script,
        draw=draw,
        picture={"en": meta.get("picture_en", ""), "fr": meta.get("picture_fr", "")},
        hook={"en": meta.get("hook_en", ""), "fr": meta.get("hook_fr", "")},
    )


def all_recipes(script: str | None = None, *, include_variants: bool = True) -> list[Recipe]:
    """Every kana as a Recipe, in gojūon order. `script` filters to one syllabary;
    `include_variants=False` keeps only the 46 base gojūon (drops dakuten)."""
    recs: list[Recipe] = []
    for k in _kana_table():
        if script and k["script"] != script:
            continue
        if not include_variants and k["kind"] != "gojuon":
            continue
        r = recipe_for(k["char"], k["romaji"], k["script"])
        if r:
            recs.append(r)
    return recs


def coverage() -> dict:
    """Which kana still lack a recipe — a QA aid."""
    missing = []
    for k in _kana_table():
        if recipe_for(k["char"], k["romaji"], k["script"]) is None:
            missing.append(k["char"])
    total = len(_kana_table())
    return {"total": total, "covered": total - len(missing), "missing": missing}
