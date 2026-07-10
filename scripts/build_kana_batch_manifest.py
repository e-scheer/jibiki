from __future__ import annotations

import ast
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
KANA_JSON = ROOT / "content" / "kana.json"
BRIEFS_JSON = ROOT / "content" / "mnemonic_briefs.json"
SEED_DATA = ROOT / "server" / "dictionary" / "seed_data.py"
OUT_JSON = ROOT / "design-explorations" / "generated" / "kana_batch_manifest.json"

BASE_ROW_ORDER = ["a", "k", "s", "t", "n", "h", "m", "y", "r", "w"]
VOICED_ROW_ORDER = ["g", "z", "d", "b", "p"]


def load_seed_stories() -> dict[str, dict[str, str]]:
    module = ast.parse(SEED_DATA.read_text(encoding="utf-8"))
    for node in module.body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id == "KANA_STORIES":
                    return ast.literal_eval(node.value)
        if isinstance(node, ast.AnnAssign):
            if isinstance(node.target, ast.Name) and node.target.id == "KANA_STORIES":
                return ast.literal_eval(node.value)
    raise RuntimeError("KANA_STORIES not found")


def build_story_map() -> dict[str, dict[str, str]]:
    kana = json.loads(KANA_JSON.read_text(encoding="utf-8"))
    base_stories = load_seed_stories()
    briefs = json.loads(BRIEFS_JSON.read_text(encoding="utf-8"))
    story_map = {"en": {}, "fr": {}}

    for item in kana:
        if item["kind"] != "gojuon":
            continue
        romaji = item["romaji"]
        for lang in ("en", "fr"):
            story_map[lang][item["char"]] = base_stories[romaji][lang]

    voiced_cache: dict[str, dict[str, str]] = {}
    for entry in briefs["voiced_kana"]:
        if "same_as" in entry:
            continue
        voiced_cache[entry["char"]] = {
            "en": entry["en"]["story"],
            "fr": entry["fr"]["story"],
        }

    for entry in briefs["voiced_kana"]:
        if "same_as" in entry:
            base = voiced_cache[entry["same_as"]]
            for lang in ("en", "fr"):
                story_map[lang][entry["char"]] = base[lang]
        else:
            for lang in ("en", "fr"):
                story_map[lang][entry["char"]] = entry[lang]["story"]

    return story_map


def group_entries() -> list[dict]:
    kana = json.loads(KANA_JSON.read_text(encoding="utf-8"))
    story_map = build_story_map()
    by_script_row: dict[tuple[str, str], list[dict]] = {}

    for item in sorted(kana, key=lambda value: (value["script"], value["order"], value["char"])):
        row = item["row"]
        if item["romaji"] == "n":
            row = "n_final"
        by_script_row.setdefault((item["script"], row), []).append(item)

    groups: list[dict] = []
    for lang in ("fr", "en"):
        for row in [*BASE_ROW_ORDER, "n_final", *VOICED_ROW_ORDER]:
            top = by_script_row.get(("hiragana", row), [])
            bottom = by_script_row.get(("katakana", row), [])
            if not top and not bottom:
                continue
            items = []
            for script_name, script_items in (("hiragana", top), ("katakana", bottom)):
                for item in script_items:
                    items.append(
                        {
                            "char": item["char"],
                            "codepoint": f"{ord(item['char']):04x}",
                            "script": script_name,
                            "row": row,
                            "romaji": item["romaji"],
                            "story": story_map[lang][item["char"]],
                            "out": f"design-explorations/generated/kana/{lang}/{ord(item['char']):04x}.png",
                        }
                    )
            groups.append(
                {
                    "group_id": f"{lang}_{row}",
                    "lang": lang,
                    "row": row,
                    "top_count": len(top),
                    "bottom_count": len(bottom),
                    "top": [item["char"] for item in top],
                    "bottom": [item["char"] for item in bottom],
                    "items": items,
                }
            )
    return groups


def main() -> None:
    groups = group_entries()
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(
        json.dumps(
            {
                "schema": "jibiki-kana-batch/1",
                "groups": groups,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(OUT_JSON)


if __name__ == "__main__":
    main()
