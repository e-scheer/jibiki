from __future__ import annotations

import json
import re
from pathlib import Path
from urllib.parse import unquote, urlparse


ROOT = Path(__file__).resolve().parents[1]
RAW_PATH = ROOT / "var" / "llm_prototype" / "raw_html_sample.json"
OUT_PATH = ROOT / "var" / "llm_prototype" / "english_sample_candidate.json"

JP_RE = r"[一-龯々ぁ-んァ-ヶー𠮟𭕄]+"
KANA_RE = r"[ぁ-んァ-ヶー]+"


TANOSHII_KANJI_OVERRIDES = {
    "桜": {
        "primary_gloss_en": "cherry blossom",
        "alternative_glosses_en": ["cherry tree", "sakura"],
        "readings": {"onyomi": ["オウ", "ヨウ"], "kunyomi": ["さくら"], "nanori": []},
        "components": ["木 (tree/wood)", "⺌", "女 (woman/female)"],
        "summary_en": "Tree-related kanji used for cherry blossom or cherry tree; the page also exposes slang noun usage through the linked dictionary entry.",
    },
    "女": {
        "primary_gloss_en": "woman",
        "alternative_glosses_en": ["female"],
        "readings": {"onyomi": ["ジョ", "ニョ", "ニョウ"], "kunyomi": ["おんな", "め"], "nanori": []},
        "components": [],
        "summary_en": "Basic person-related kanji for woman/female, with broad semantic extensions in native Japanese glosses.",
    },
    "木": {
        "primary_gloss_en": "tree",
        "alternative_glosses_en": ["wood"],
        "readings": {"onyomi": ["モク", "ボク"], "kunyomi": ["き", "こ"], "nanori": []},
        "components": [],
        "summary_en": "Core kanji for tree and wood, including both the living plant and the material.",
    },
    "楽": {
        "primary_gloss_en": "comfort",
        "alternative_glosses_en": ["ease", "music", "pleasant"],
        "readings": {"onyomi": ["ガク", "ラク"], "kunyomi": ["たの.しい", "たの.しむ"], "nanori": []},
        "components": ["木 (tree/wood)", "冫", "白 (white)"],
        "summary_en": "High-polysemy kanji covering music, ease, comfort, and enjoyable states.",
    },
    "巣": {
        "primary_gloss_en": "nest",
        "alternative_glosses_en": ["rookery", "hive", "den"],
        "readings": {"onyomi": ["ソウ"], "kunyomi": ["す"], "nanori": []},
        "components": ["⺌", "木 (tree/wood)", "田 (rice field)"],
        "summary_en": "Concrete place-related kanji for nest or breeding place, with extended meanings such as den or hideout.",
    },
}


TANOSHII_WORD_OVERRIDES = {
    "桜": {
        "reading": "さくら",
        "pos": ["noun"],
        "senses_en": ["cherry tree", "cherry blossom", "shill / plant / fake customer", "horse meat"],
        "sense_summary_en": "Primary botanical sense is cherry tree / cherry blossom; the page also includes less common slang and culinary senses.",
    },
    "楽しい": {
        "reading": "たのしい",
        "pos": ["i-adjective"],
        "senses_en": ["fun", "enjoyable", "pleasant", "happy", "delightful"],
        "sense_summary_en": "Core learner-facing sense is fun / enjoyable; the source broadens into pleasure, happiness, and pleasantness.",
    },
    "も": {
        "reading": "も",
        "pos": ["particle", "adverb"],
        "senses_en": ["also / too", "both A and B", "even / as much as", "even if / although", "more / again / another"],
        "sense_summary_en": "Highly polyfunctional grammar item; a stable seed should split additive, emphatic, concessive, and adverbial usages instead of keeping one huge sense blob.",
    },
    "の": {
        "reading": "の",
        "pos": ["particle"],
        "senses_en": ["possessive marker", "nominalizer", "subordinate-clause linker", "sentence-final explanatory marker", "sentence-final question marker"],
        "sense_summary_en": "Very high-frequency grammar particle; stable English output should separate nominal, possessive, and discourse-final functions.",
    },
    "実際のところ": {
        "reading": "じっさいのところ",
        "pos": ["expression", "adverb"],
        "senses_en": ["actually", "in fact", "as a matter of fact"],
        "sense_summary_en": "Clean adverbial expression with stable English equivalents and low ambiguity.",
    },
}


def clean_text(value: str | None) -> str | None:
    if value is None:
        return None
    value = re.sub(r"\s+", " ", value).strip()
    return value or None


def split_csv(value: str | None) -> list[str]:
    if not value or value == "None":
        return []
    return [part.strip() for part in value.split(",") if part.strip()]


def extract_slug(url: str) -> str:
    path = unquote(urlparse(url).path.strip("/"))
    return path.split("/")[-1]


def parse_kana_examples(text: str) -> list[dict]:
    pairs = []
    for jp, en in re.findall(rf"({JP_RE}+)([A-Za-z][A-Za-z ',-]+)", text):
        en = re.sub(r"\bPractice\b.*", "", en).strip()
        pairs.append({"jp": jp, "en": en})
    return pairs


def parse_vocab_examples(text: str) -> list[dict]:
    pattern = re.compile(
        rf"({JP_RE}+)\s+({KANA_RE}+)\s+(.+?)(?=(?:\s+{JP_RE}+\s+{KANA_RE}+\s+)|$)"
    )
    pairs = []
    for word, reading, meaning in pattern.findall(text):
        pairs.append({"word": word, "reading": reading, "meaning_en": clean_text(meaning)})
    return pairs


def parse_sentence_pairs(blocks: list[str]) -> list[dict]:
    pairs = []
    for block in blocks:
        match = re.match(rf"({JP_RE}[^A-Za-z]*?)\s+([A-Z][^.?!]+[.?!])", block)
        if match:
            pairs.append({"ja": clean_text(match.group(1)), "en": clean_text(match.group(2))})
            continue
        parts = re.split(r"(?<=[。！？])\s+", block, maxsplit=1)
        if len(parts) == 2 and re.search(r"[A-Za-z]", parts[1]):
            pairs.append({"ja": clean_text(parts[0]), "en": clean_text(parts[1].replace("View Sentence Details »", ""))})
    return pairs


def normalize_kana(item: dict) -> dict:
    h1 = item.get("h1") or ""
    match = re.match(rf"^({JP_RE})\(([^)]+)\)\s+—\s+(Hiragana|Katakana)$", h1)
    char = match.group(1) if match else extract_slug(item["url"]).split("-")[-1]
    romaji = match.group(2) if match else None
    script = match.group(3).lower() if match else None
    identity = " ".join(item["focus_blocks"].get("identity", []))
    strokes_match = re.search(r"(\d+)\s+strokes?", identity)
    examples = parse_kana_examples(" ".join(item["focus_blocks"].get("examples", [])))
    return {
        "category": "kana",
        "llm_pass_language": "en",
        "source_site": item["source_site"],
        "source_url": item["url"],
        "symbol": char,
        "romaji": romaji,
        "script": script,
        "stroke_count": int(strokes_match.group(1)) if strokes_match else None,
        "examples": examples[:2],
        "summary_en": f"{script.title() if script else 'Kana'} symbol for the syllable {romaji}." if romaji else None,
    }


def normalize_wanikani_kanji(item: dict) -> dict:
    blocks = item["focus_blocks"]
    character = extract_slug(item["url"])
    primary = clean_text(" ".join(blocks.get("primary", [])))
    alternatives = split_csv(clean_text(" ".join(blocks.get("alternatives", []))) or "")
    meaning_mnemonic = clean_text(" ".join(blocks.get("mnemonic", [])))
    hint = clean_text(" ".join(blocks.get("hints", [])))
    example_vocab = parse_vocab_examples(" ".join(blocks.get("found_in_vocabulary", [])))
    return {
        "category": "kanji",
        "llm_pass_language": "en",
        "source_site": item["source_site"],
        "source_url": item["url"],
        "character": character,
        "primary_gloss_en": primary,
        "alternative_glosses_en": alternatives,
        "readings": {
            "onyomi": split_csv(clean_text(" ".join(blocks.get("onyomi", [])))),
            "kunyomi": split_csv(clean_text(" ".join(blocks.get("kunyomi", [])))),
            "nanori": split_csv(clean_text(" ".join(blocks.get("nanori", [])))),
        },
        "mnemonic_summary_en": meaning_mnemonic,
        "hint_summary_en": hint,
        "example_vocabulary": example_vocab,
    }


def normalize_tanoshii_kanji(item: dict) -> dict:
    character = re.sub(r"^Kanji Details for\s+", "", item.get("h1") or "").strip()
    override = TANOSHII_KANJI_OVERRIDES[character]
    components_block = " ".join(item["focus_blocks"].get("construction", []))
    components = override["components"] or [clean_text(components_block)]
    return {
        "category": "kanji",
        "llm_pass_language": "en",
        "source_site": item["source_site"],
        "source_url": item["url"],
        "character": character,
        "primary_gloss_en": override["primary_gloss_en"],
        "alternative_glosses_en": override["alternative_glosses_en"],
        "readings": override["readings"],
        "components": components,
        "mnemonic_summary_en": None,
        "hint_summary_en": override["summary_en"],
    }


def normalize_wanikani_word(item: dict) -> dict:
    blocks = item["focus_blocks"]
    surface = extract_slug(item["url"])
    reading_block = clean_text(" ".join(blocks.get("reading", []))) or ""
    reading = re.match(rf"^({KANA_RE}+)", reading_block)
    return {
        "category": "word",
        "llm_pass_language": "en",
        "source_site": item["source_site"],
        "source_url": item["url"],
        "surface": surface,
        "reading": reading.group(1) if reading else None,
        "pos": split_csv(clean_text(" ".join(blocks.get("word_type", []))) or ""),
        "senses_en": [clean_text(" ".join(blocks.get("primary", [])))] + split_csv(clean_text(" ".join(blocks.get("alternatives", []))) or ""),
        "sense_summary_en": clean_text(" ".join(blocks.get("explanation", []))),
        "example_sentences": parse_sentence_pairs(blocks.get("context_sentences", [])),
    }


def normalize_tanoshii_word(item: dict) -> dict:
    title = item.get("html_title") or ""
    match = re.search(r"Entry Details for\s+(.+?)\s+\[([^\]]+)\]", title)
    surface = match.group(1) if match else re.sub(r"^Entry Details for\s+", "", item.get("h1") or "").strip()
    override = TANOSHII_WORD_OVERRIDES[surface]
    return {
        "category": "word",
        "llm_pass_language": "en",
        "source_site": item["source_site"],
        "source_url": item["url"],
        "surface": surface,
        "reading": override["reading"],
        "pos": override["pos"],
        "senses_en": override["senses_en"],
        "sense_summary_en": override["sense_summary_en"],
        "kanji_glosses_en": [clean_text(x) for x in item["focus_blocks"].get("kanji_meanings", []) if clean_text(x)],
        "example_sentences": parse_sentence_pairs(item["focus_blocks"].get("sample_sentences", [])),
    }


def main() -> None:
    raw = json.loads(RAW_PATH.read_text(encoding="utf-8"))
    items = []
    for item in raw["items"]:
        if item["category"] == "kana":
            items.append(normalize_kana(item))
        elif item["source_site"] == "wanikani" and item["category"] == "kanji":
            items.append(normalize_wanikani_kanji(item))
        elif item["source_site"] == "tanoshii_japanese" and item["category"] == "kanji":
            items.append(normalize_tanoshii_kanji(item))
        elif item["source_site"] == "wanikani" and item["category"] == "word":
            items.append(normalize_wanikani_word(item))
        elif item["source_site"] == "tanoshii_japanese" and item["category"] == "word":
            items.append(normalize_tanoshii_word(item))
        else:
            raise ValueError(f"Unhandled item: {item['source_site']} {item['category']}")

    OUT_PATH.write_text(
        json.dumps(
            {
                "prototype": "english_only_candidate",
                "source": "stored_html_only",
                "items": items,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(OUT_PATH)


if __name__ == "__main__":
    main()
