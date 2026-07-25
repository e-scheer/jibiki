from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Iterable

from lxml import html


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "var" / "llm_prototype"
OUT_PATH = OUT_DIR / "raw_html_sample.json"


def clean_text(value: str | None) -> str | None:
    if value is None:
        return None
    value = re.sub(r"\s+", " ", value).strip()
    return value or None


def read_doc(path: Path):
    raw = path.read_text(encoding="utf-8", errors="ignore")
    return html.fromstring(raw)


def strip_noise(doc) -> None:
    for bad in doc.xpath("//script|//style|//noscript|//svg"):
        parent = bad.getparent()
        if parent is not None:
            parent.remove(bad)


def visible_body_text(doc, limit: int = 1600) -> str | None:
    strip_noise(doc)
    text = clean_text(" ".join(doc.xpath("//body//text()")))
    return text[:limit] if text else None


def meta_description(doc) -> str | None:
    values = doc.xpath("//meta[@name='description']/@content")
    return clean_text(values[0]) if values else None


def heading_texts(doc, limit: int = 20) -> list[str]:
    values = []
    for node in doc.xpath("//h1|//h2|//h3"):
        text = clean_text("".join(node.itertext()))
        if text:
            values.append(text)
        if len(values) >= limit:
            break
    return values


def sibling_blocks_after_heading(doc, heading_pattern: str, max_blocks: int = 4) -> list[str]:
    pattern = re.compile(heading_pattern, re.I)
    for node in doc.xpath("//h1|//h2|//h3"):
        title = clean_text("".join(node.itertext())) or ""
        if not pattern.search(title):
            continue
        blocks: list[str] = []
        sib = node.getnext()
        while sib is not None and sib.tag.lower() not in {"h1", "h2", "h3"}:
            text = clean_text("".join(sib.itertext()))
            if text:
                blocks.append(text)
                if len(blocks) >= max_blocks:
                    break
            sib = sib.getnext()
        return blocks
    return []


def load_jsonl(path: Path) -> list[dict]:
    rows = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            rows.append(json.loads(line))
    return rows


def select_kana_samples(limit: int = 10) -> list[dict]:
    base = ROOT / "var" / "site_mirror" / "kanjidraw" / "mirror" / "kanjidraw.com" / "kana"
    results = []
    for path in sorted(base.glob("*/index.html")):
        rel = path.relative_to(base.parent).as_posix()
        url_path = rel.removesuffix("/index.html")
        slug = path.parent.name
        results.append(
            {
                "category": "kana",
                "source_site": "kanjidraw",
                "url": f"https://kanjidraw.com/{url_path}/",
                "saved_path": str(path),
            }
        )
        if len(results) >= limit:
            break
    return results


def select_tanoshii_unique_words(limit: int) -> list[dict]:
    rows = load_jsonl(ROOT / "var" / "site_extract" / "tanoshii_japanese" / "pages.jsonl")
    picked = []
    seen_entry_ids: set[str] = set()
    for row in rows:
        if row.get("page_type") != "word":
            continue
        url = row.get("url") or ""
        match = re.search(r"[?&]entry_id=(\d+)", url)
        if not match:
            continue
        entry_id = match.group(1)
        if entry_id in seen_entry_ids:
            continue
        seen_entry_ids.add(entry_id)
        picked.append(
            {
                "category": "word",
                "source_site": "tanoshii_japanese",
                "url": row["url"],
                "saved_path": row["saved_path"],
            }
        )
        if len(picked) >= limit:
            break
    return picked


def select_site_extract_rows(site: str, page_type: str, limit: int) -> list[dict]:
    rows = load_jsonl(ROOT / "var" / "site_extract" / site / "pages.jsonl")
    picked = []
    for row in rows:
        if row.get("page_type") != page_type:
            continue
        picked.append(
            {
                "category": "kanji" if page_type == "kanji" else "word",
                "source_site": site,
                "url": row["url"],
                "saved_path": row["saved_path"],
            }
        )
        if len(picked) >= limit:
            break
    return picked


def base_packet(sample: dict, doc) -> dict:
    return {
        **sample,
        "html_title": clean_text(doc.xpath("string(//title)")),
        "meta_description": meta_description(doc),
        "h1": clean_text(doc.xpath("string(//h1)")),
        "headings": heading_texts(doc),
        "body_preview": visible_body_text(doc),
    }


def extract_kana_packet(sample: dict) -> dict:
    doc = read_doc(Path(sample["saved_path"]))
    packet = base_packet(sample, doc)
    packet["focus_blocks"] = {
        "identity": sibling_blocks_after_heading(doc, r"hiragana|katakana", max_blocks=3),
        "examples": sibling_blocks_after_heading(doc, r"examples", max_blocks=3),
        "practice": sibling_blocks_after_heading(doc, r"practice", max_blocks=3),
    }
    return packet


def extract_wanikani_kanji_packet(sample: dict) -> dict:
    doc = read_doc(Path(sample["saved_path"]))
    packet = base_packet(sample, doc)
    packet["focus_blocks"] = {
        "meaning": sibling_blocks_after_heading(doc, r"^Meaning$", max_blocks=2),
        "primary": sibling_blocks_after_heading(doc, r"^Primary$", max_blocks=1),
        "alternatives": sibling_blocks_after_heading(doc, r"^Alternatives?$", max_blocks=1),
        "mnemonic": sibling_blocks_after_heading(doc, r"^Mnemonic$", max_blocks=2),
        "hints": sibling_blocks_after_heading(doc, r"^Hints$", max_blocks=2),
        "readings": sibling_blocks_after_heading(doc, r"^Readings?$", max_blocks=2),
        "onyomi": sibling_blocks_after_heading(doc, r"On.?yomi", max_blocks=1),
        "kunyomi": sibling_blocks_after_heading(doc, r"Kun.?yomi", max_blocks=1),
        "nanori": sibling_blocks_after_heading(doc, r"Nanori", max_blocks=1),
        "found_in_vocabulary": sibling_blocks_after_heading(doc, r"Found In Vocabulary", max_blocks=3),
    }
    return packet


def extract_wanikani_word_packet(sample: dict) -> dict:
    doc = read_doc(Path(sample["saved_path"]))
    packet = base_packet(sample, doc)
    packet["focus_blocks"] = {
        "meaning": sibling_blocks_after_heading(doc, r"^Meaning$", max_blocks=2),
        "primary": sibling_blocks_after_heading(doc, r"^Primary$", max_blocks=1),
        "alternatives": sibling_blocks_after_heading(doc, r"^Alternatives?$", max_blocks=1),
        "word_type": sibling_blocks_after_heading(doc, r"Word Type", max_blocks=1),
        "explanation": sibling_blocks_after_heading(doc, r"^Explanation$", max_blocks=2),
        "reading": sibling_blocks_after_heading(doc, r"^Reading$", max_blocks=2),
        "context": sibling_blocks_after_heading(doc, r"^Context$", max_blocks=2),
        "context_sentences": sibling_blocks_after_heading(doc, r"Context Sentences", max_blocks=3),
        "kanji_composition": sibling_blocks_after_heading(doc, r"Kanji Composition", max_blocks=2),
    }
    return packet


def extract_tanoshii_word_packet(sample: dict) -> dict:
    doc = read_doc(Path(sample["saved_path"]))
    packet = base_packet(sample, doc)
    packet["focus_blocks"] = {
        "english_meanings": sibling_blocks_after_heading(doc, r"English Meaning\(s\)", max_blocks=2),
        "definition_and_synonyms": sibling_blocks_after_heading(doc, r"Definition and Synonyms", max_blocks=2),
        "kanji_meanings": sibling_blocks_after_heading(doc, r"Meanings for each kanji", max_blocks=2),
        "categories": sibling_blocks_after_heading(doc, r"Categories .* is a member of", max_blocks=2),
        "sample_sentences": sibling_blocks_after_heading(doc, r"Sample Sentences for", max_blocks=4),
    }
    return packet


def extract_tanoshii_kanji_packet(sample: dict) -> dict:
    doc = read_doc(Path(sample["saved_path"]))
    packet = base_packet(sample, doc)
    packet["focus_blocks"] = {
        "japanese_meaning": sibling_blocks_after_heading(doc, r"Japanese Meaning", max_blocks=2),
        "dictionary_entry": sibling_blocks_after_heading(doc, r"Dictionary Entry", max_blocks=2),
        "construction": sibling_blocks_after_heading(doc, r"Construction of Character", max_blocks=2),
        "related_kanji": sibling_blocks_after_heading(doc, r"Kanji related to", max_blocks=2),
        "other_languages": sibling_blocks_after_heading(doc, r"Meanings in Other Languages", max_blocks=2),
    }
    return packet


def build_packets(samples: Iterable[dict]) -> list[dict]:
    packets = []
    for sample in samples:
        site = sample["source_site"]
        category = sample["category"]
        if category == "kana":
            packets.append(extract_kana_packet(sample))
        elif site == "wanikani" and category == "kanji":
            packets.append(extract_wanikani_kanji_packet(sample))
        elif site == "wanikani" and category == "word":
            packets.append(extract_wanikani_word_packet(sample))
        elif site == "tanoshii_japanese" and category == "word":
            packets.append(extract_tanoshii_word_packet(sample))
        elif site == "tanoshii_japanese" and category == "kanji":
            packets.append(extract_tanoshii_kanji_packet(sample))
        else:
            raise ValueError(f"Unsupported sample: {sample}")
    return packets


def main() -> None:
    samples: list[dict] = []
    samples.extend(select_kana_samples(limit=10))
    samples.extend(select_site_extract_rows("wanikani", "kanji", limit=5))
    samples.extend(select_site_extract_rows("tanoshii_japanese", "kanji", limit=5))
    samples.extend(select_site_extract_rows("wanikani", "vocabulary", limit=5))
    samples.extend(select_tanoshii_unique_words(limit=5))

    packets = build_packets(samples)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(
        json.dumps(
            {
                "generated_from": "stored_html_only",
                "counts": {"kana": 10, "kanji": 10, "word": 10},
                "items": packets,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(OUT_PATH)


if __name__ == "__main__":
    main()
