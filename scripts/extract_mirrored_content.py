"""Analyze mirrored HTML pages and extract structured site content.

The script reads successful HTML fetches from ``var/site_mirror/<site>/fetch_log.jsonl``,
infers page types, filters to Jibiki-relevant content, and writes:

- ``var/site_extract/<site>/pages.jsonl``: structured page records
- ``var/site_extract/<site>/analysis.json``: route/page-type coverage summary
- ``var/site_extract/manifest.json``: top-level run summary

Examples:

    python scripts/extract_mirrored_content.py
    python scripts/extract_mirrored_content.py --site wanikani --site kanjidraw
"""

from __future__ import annotations

import argparse
import json
import re
import urllib.parse
from collections import Counter, defaultdict
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from lxml import html

import parse_site_snapshots as snapshot_parsers

ROOT = Path(__file__).resolve().parents[1]
MIRROR_ROOT = ROOT / "var" / "site_mirror"
EXTRACT_ROOT = ROOT / "var" / "site_extract"
SUPPORTED_SITES = ("kanjidraw", "kanshudo", "tanoshii_japanese", "the_kanji_map", "wanikani")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--site", action="append", dest="sites", choices=SUPPORTED_SITES)
    args = parser.parse_args()

    sites = args.sites or [site for site in SUPPORTED_SITES if (MIRROR_ROOT / site).exists()]
    manifest = {
        "schema": "jibiki-mirror-extract/1",
        "generated_at": iso_now(),
        "mirror_root": str(MIRROR_ROOT),
        "sites": {},
    }

    EXTRACT_ROOT.mkdir(parents=True, exist_ok=True)
    for site_id in sites:
        result = extract_site(site_id)
        manifest["sites"][site_id] = result

    write_json(EXTRACT_ROOT / "manifest.json", manifest)
    print(f"Wrote {EXTRACT_ROOT / 'manifest.json'}")
    return 0


def extract_site(site_id: str) -> dict[str, Any]:
    site_root = MIRROR_ROOT / site_id
    log_path = site_root / "fetch_log.jsonl"
    output_root = EXTRACT_ROOT / site_id
    output_root.mkdir(parents=True, exist_ok=True)
    pages_path = output_root / "pages.jsonl"

    records: list[dict[str, Any]] = []
    route_counts: Counter[str] = Counter()
    page_type_counts: Counter[str] = Counter()
    included_type_counts: Counter[str] = Counter()
    skipped_page_type_counts: Counter[str] = Counter()

    pages_path.write_text("", encoding="utf-8")
    for entry in iter_successful_html_entries(log_path):
        page_type = infer_page_type(site_id, entry["url"])
        route_counts[route_key(site_id, entry["url"])] += 1
        page_type_counts[page_type] += 1
        if not is_extractable_page_type(site_id, page_type):
            skipped_page_type_counts[page_type] += 1
            continue

        record = extract_page_record(site_id, entry, page_type)
        if record is None:
            skipped_page_type_counts[page_type] += 1
            continue
        included_type_counts[page_type] += 1
        records.append(record)
        append_jsonl(pages_path, record)

    analysis = {
        "schema": "jibiki-mirror-site-analysis/1",
        "site": site_id,
        "generated_at": iso_now(),
        "source_log": str(log_path),
        "page_count": len(records),
        "route_counts": dict(route_counts.most_common()),
        "page_type_counts": dict(page_type_counts.most_common()),
        "included_page_type_counts": dict(included_type_counts.most_common()),
        "skipped_page_type_counts": dict(skipped_page_type_counts.most_common()),
        "output_pages": str(pages_path),
    }
    write_json(output_root / "analysis.json", analysis)
    print(f"Wrote {pages_path}")
    print(f"Wrote {output_root / 'analysis.json'}")
    return {
        "page_count": len(records),
        "analysis": str(output_root / "analysis.json"),
        "pages": str(pages_path),
    }


def iter_successful_html_entries(log_path: Path) -> list[dict[str, Any]]:
    if not log_path.exists():
        return []
    entries = []
    for line in log_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        status = payload.get("status")
        content_type = str(payload.get("content_type", ""))
        saved_path = payload.get("saved_path")
        if not (isinstance(status, int) and 200 <= status < 400):
            continue
        if not content_type.startswith("text/html"):
            continue
        if not isinstance(saved_path, str) or not Path(saved_path).exists():
            continue
        entries.append(payload)
    return entries


def infer_page_type(site_id: str, url: str) -> str:
    split = urllib.parse.urlsplit(url)
    path = urllib.parse.unquote(split.path or "/")
    basename = Path(path).name.lower()
    query = urllib.parse.parse_qs(split.query, keep_blank_values=True)
    first_segment = path.strip("/").split("/", 1)[0] if path.strip("/") else ""

    if site_id == "wanikani":
        if path in {"/kanji", "/vocabulary", "/radicals"}:
            return "subject_index"
        if first_segment in {"kanji", "vocabulary", "radicals"}:
            return first_segment
        return "other"

    if site_id == "the_kanji_map":
        if path == "/about":
            return "about"
        if path and path != "/" and path.count("/") == 1:
            return "kanji"
        return "other"

    if site_id == "kanjidraw":
        if path.startswith("/dictionary/"):
            return "kanji" if path != "/dictionary/" else "dictionary_index"
        if path.startswith("/kana/"):
            return "kana"
        if path.startswith("/radicals/"):
            return "radical"
        if path.startswith("/collections/"):
            return "collection"
        return "other"

    if site_id == "kanshudo":
        if path.startswith("/kanji/draw/"):
            return "kanji_draw"
        if re.fullmatch(r"/kanji/[^/]+/?", path):
            slug = Path(path.rstrip("/")).name
            return "kana" if slug and len(slug) == 1 and ord(slug) < 0x3100 else "kanji"
        if re.fullmatch(r"/word/[^/]+/?", path):
            return "word"
        if path == "/component_details" or path.startswith("/component_details/"):
            return "radical_index"
        return "other"

    if site_id == "tanoshii_japanese":
        if not path.startswith("/dictionary/"):
            return "other"
        match basename:
            case "kanji_details.cfm":
                return "kanji"
            case "kanji_stroke_order_details.cfm":
                return "kanji_strokes"
            case "entry_details.cfm":
                return "word"
            case "stroke_order_details.cfm":
                return "word_strokes"
            case "conjugation_details.cfm":
                return "word_conjugation"
            case "sentence_details.cfm":
                return "sentence"
            case "kanji.cfm" | "kanji_browse.cfm":
                return "kanji_index"
            case "browse.cfm" | "index.cfm" | "multi_search.cfm" | "sentences.cfm":
                return "dictionary_index"
            case "entry_comments.cfm" | "kanji_comments.cfm":
                return "comments"
            case _:
                return "dictionary_other"

    return "other"


def is_extractable_page_type(site_id: str, page_type: str) -> bool:
    allowed = {
        "wanikani": {"kanji", "vocabulary", "radicals"},
        "the_kanji_map": {"kanji"},
        "kanjidraw": {"kanji", "kana", "radical", "collection"},
        "kanshudo": {"kanji", "kana", "kanji_draw", "word", "radical_index"},
        "tanoshii_japanese": {
            "kanji",
            "kanji_strokes",
            "word",
            "word_strokes",
            "word_conjugation",
            "sentence",
            "kanji_index",
            "dictionary_index",
        },
    }
    return page_type in allowed.get(site_id, set())


def extract_page_record(site_id: str, entry: dict[str, Any], page_type: str) -> dict[str, Any] | None:
    url = str(entry["url"])
    saved_path = Path(str(entry["saved_path"]))
    html_text = saved_path.read_text(encoding="utf-8", errors="replace")
    tree = html.fromstring(html_text)
    split = urllib.parse.urlsplit(url)
    path = urllib.parse.unquote(split.path or "/")

    record = {
        "site": site_id,
        "url": url,
        "saved_path": str(saved_path),
        "fetched_at": entry.get("fetched_at"),
        "page_type": page_type,
        "entity_hint": entity_hint(site_id, page_type, url),
        "title": clean_scalar(tree.xpath("string(//title)")),
        "h1": clean_scalar(tree.xpath("string((//h1)[1])")),
        "canonical": first_xpath(tree, "//link[@rel='canonical']/@href"),
        "meta_description": first_xpath(tree, "//meta[@name='description']/@content"),
        "headings": collect_texts(tree, "//h1|//h2|//h3"),
        "paragraphs": collect_texts(tree, "//p"),
        "list_items": collect_texts(tree, "//li"),
        "definition_pairs": collect_definition_pairs(tree),
        "site_fields": {},
    }

    parser_payload = parse_site_specific(site_id, page_type, html_text, url)
    if parser_payload:
        record["site_fields"] = parser_payload
    return record


def parse_site_specific(site_id: str, page_type: str, html_text: str, url: str) -> dict[str, Any]:
    snapshot_meta = {"sample": {"url": url}}
    try:
        if site_id == "the_kanji_map" and page_type == "kanji":
            return snapshot_parsers.parse_the_kanji_map(html_text, snapshot_meta)
        if site_id == "kanshudo":
            if page_type in {"kanji", "kana"}:
                return snapshot_parsers.parse_kanshudo(html_text, snapshot_meta)
            if page_type == "word":
                return parse_kanshudo_word_page(html_text, url)
            if page_type == "radical_index":
                return parse_kanshudo_component_page(html_text, url)
            if page_type == "kanji_draw":
                return parse_kanshudo_draw_page(html_text, url)
        if site_id == "kanjidraw":
            if page_type == "kanji":
                return snapshot_parsers.parse_kanjidraw(html_text, snapshot_meta)
            if page_type == "radical":
                return parse_kanjidraw_radical_page(html_text, url)
            if page_type == "collection":
                return parse_kanjidraw_collection_page(html_text, url)
            if page_type == "kana":
                return parse_kanjidraw_kana_page(html_text, url)
        if site_id == "tanoshii_japanese":
            if page_type == "kanji":
                return snapshot_parsers.parse_tanoshii_japanese(html_text, snapshot_meta)
            if page_type == "kanji_strokes":
                return parse_tanoshii_kanji_strokes_page(html_text, url)
            if page_type == "word":
                return parse_tanoshii_word_page(html_text, url)
            if page_type == "word_strokes":
                return parse_tanoshii_word_strokes_page(html_text, url)
            if page_type == "word_conjugation":
                return parse_tanoshii_conjugation_page(html_text, url)
            if page_type == "sentence":
                return parse_tanoshii_sentence_page(html_text, url)
        if site_id == "wanikani":
            if page_type == "kanji":
                return snapshot_parsers.parse_wanikani(html_text, snapshot_meta)
            if page_type == "vocabulary":
                return parse_wanikani_vocabulary_page(html_text, url)
            if page_type == "radicals":
                return parse_wanikani_radical_page(html_text, url)
    except Exception:
        return {}

    return generic_site_specific(site_id, page_type, html_text, url)


def generic_site_specific(site_id: str, page_type: str, html_text: str, url: str) -> dict[str, Any]:
    tree = html.fromstring(html_text)
    split = urllib.parse.urlsplit(url)
    path = urllib.parse.unquote(split.path or "/")
    query = urllib.parse.parse_qs(split.query, keep_blank_values=True)

    if site_id == "wanikani":
        return {
            "subject_type": page_type,
            "slug": urllib.parse.unquote(path.strip("/").split("/", 1)[1]) if "/" in path.strip("/") else None,
            "primary_meaning": first_labeled_value(tree, "Primary"),
            "alternative_meanings": split_csv(first_labeled_value(tree, "Alternatives")),
            "word_type": first_labeled_value(tree, "Word Type"),
            "readings": collect_texts(tree, "//*[contains(@class,'subject-readings__reading-items')]"),
            "mnemonic_texts": collect_texts(tree, "//*[contains(@class,'subject-section__text')]"),
        }

    if site_id == "kanjidraw":
        return {
            "section": first_segment(path),
            "slug": urllib.parse.unquote(path.rstrip("/").split("/")[-1]) if path != "/dictionary/" else None,
            "collection_chips": collect_texts(tree, "//*[contains(@class,'dict-collection-chip')]"),
            "intro_methods": collect_texts(tree, "//*[contains(@class,'dict-intro-method-name')]"),
        }

    if site_id == "kanshudo":
        return {
            "section": first_segment(path),
            "slug": urllib.parse.unquote(path.rstrip("/").split("/")[-1]),
            "quick_links": collect_texts(tree, "//*[contains(@class,'qslink')]"),
            "panel_titles": collect_texts(tree, "//*[contains(@class,'w_title')]"),
        }

    if site_id == "tanoshii_japanese":
        return {
            "dictionary_page": Path(path).name,
            "character_id": first_query_value(query, "character_id"),
            "entry_id": first_query_value(query, "entry_id"),
            "sentence_id": first_query_value(query, "sentence_id"),
            "romaji": collect_texts(tree, "//*[contains(@class,'romaji')]"),
            "part_of_speech": collect_texts(tree, "//*[contains(@class,'partofspeech')]"),
            "entry_links": collect_texts(tree, "//*[contains(@class,'entrylinks')]"),
        }

    return {}


def parse_wanikani_vocabulary_page(html_text: str, url: str) -> dict[str, Any]:
    tree = html.fromstring(html_text)
    split = urllib.parse.urlsplit(url)
    slug = urllib.parse.unquote(split.path.rstrip("/").split("/")[-1])
    meaning_block = snapshot_parsers.extract_section_by_id(html_text, "section-meaning")
    reading_block = snapshot_parsers.extract_section_by_id(html_text, "section-reading")
    context_block = snapshot_parsers.extract_section_by_id(html_text, "section-context")
    components_block = snapshot_parsers.extract_section_by_id(html_text, "section-components")
    return {
        "subject_type": "vocabulary",
        "slug": slug,
        "primary_meaning": first_labeled_value(tree, "Primary"),
        "alternative_meanings": split_csv(first_labeled_value(tree, "Alternatives")),
        "word_type": first_labeled_value(tree, "Word Type"),
        "readings": collect_texts(tree, "//*[contains(@class,'reading-with-audio__reading')]"),
        "reading_voices": extract_wanikani_audio_voices(tree),
        "meaning_explanation": snapshot_parsers.extract_paragraph_after(meaning_block, ""),
        "reading_explanation": snapshot_parsers.extract_paragraph_after(reading_block, ""),
        "context_sentences": extract_wanikani_context_sentences(context_block),
        "component_subjects": extract_wanikani_subject_grid(components_block),
        "mnemonic_texts": collect_texts(tree, "//*[contains(@class,'subject-section__text')]"),
    }


def parse_wanikani_radical_page(html_text: str, url: str) -> dict[str, Any]:
    tree = html.fromstring(html_text)
    split = urllib.parse.urlsplit(url)
    slug = urllib.parse.unquote(split.path.rstrip("/").split("/")[-1])
    meaning_block = snapshot_parsers.extract_section_by_id(html_text, "section-meaning")
    amalgamations_block = snapshot_parsers.extract_section_by_id(html_text, "section-amalgamations")
    return {
        "subject_type": "radical",
        "slug": slug,
        "primary_meaning": first_labeled_value(tree, "Primary"),
        "alternative_meanings": split_csv(first_labeled_value(tree, "Alternatives")),
        "mnemonic_texts": collect_texts(tree, "//*[contains(@class,'subject-section__text')]"),
        "meaning_explanation": snapshot_parsers.extract_paragraph_after(meaning_block, ""),
        "found_in_kanji": extract_wanikani_subject_grid(amalgamations_block),
    }


def extract_wanikani_audio_voices(tree: html.HtmlElement) -> list[dict[str, str | None]]:
    items = []
    for node in tree.xpath("//*[contains(@class,'reading-with-audio__audio-item')]"):
        name = first_xpath(node, ".//*[contains(@class,'reading-with-audio__voice-actor-name')]")
        description = first_xpath(node, ".//*[contains(@class,'reading-with-audio__voice-actor-description')]")
        if name or description:
            items.append({"name": name, "description": description})
    return items


def extract_wanikani_context_sentences(section_html: str) -> list[dict[str, str | None]]:
    if not section_html:
        return []
    tree = html.fromstring(f"<div>{section_html}</div>")
    sentences = []
    for group in tree.xpath("//*[contains(@class,'subject-section__text--grouped')]"):
        paragraphs = [clean_scalar(p.text_content()) for p in group.xpath(".//p")]
        paragraphs = [value for value in paragraphs if value]
        if not paragraphs:
            continue
        sentences.append(
            {
                "jp": paragraphs[0] if paragraphs else None,
                "en": paragraphs[1] if len(paragraphs) > 1 else None,
            }
        )
    return sentences


def extract_wanikani_subject_grid(section_html: str) -> list[dict[str, str | None]]:
    if not section_html:
        return []
    tree = html.fromstring(f"<div>{section_html}</div>")
    items = []
    for card in tree.xpath("//*[contains(@class,'subject-character-grid__item')]//*[self::a or self::div][contains(@class,'subject-character')]"):
        character = first_xpath(card, ".//*[contains(@class,'subject-character__characters-text')]")
        reading = first_xpath(card, ".//*[contains(@class,'subject-character__reading')]")
        meaning = first_xpath(card, ".//*[contains(@class,'subject-character__meaning')]")
        href = first_xpath(card, "./@href")
        if character or meaning:
            items.append({"character": character, "reading": reading, "meaning": meaning, "href": href})
    return snapshot_parsers.unique_list(items)


def parse_kanjidraw_radical_page(html_text: str, url: str) -> dict[str, Any]:
    tree = html.fromstring(html_text)
    preloads = snapshot_parsers.extract_window_json_assignments(html_text)
    preload = preloads.get("__PRELOAD_RADICAL__", {})
    card = preload.get("card", {})
    root_cards = []
    for node in tree.xpath("//a[contains(@href,'/radicals/') and contains(@class,'radical')] | //a[contains(@href,'/radicals/') and contains(@class,'dict')]"):
        href = first_xpath(node, "./@href")
        label = clean_scalar(node.text_content())
        if href or label:
            root_cards.append({"label": label, "href": href})
    return {
        "section": "radicals",
        "slug": urllib.parse.unquote(urllib.parse.urlsplit(url).path.rstrip("/").split("/")[-1]),
        "radical_number": card.get("num") or preload.get("num"),
        "character": card.get("char") or first_xpath(tree, "//*[contains(@class,'radical-detail-glyph')]"),
        "meaning": card.get("meaning") or first_xpath(tree, "//*[contains(@class,'radical-detail-name')]"),
        "stroke_count": card.get("strokes") or snapshot_parsers.parse_int(first_xpath(tree, "//*[contains(@class,'radical-detail-sub')]")),
        "joyo_count": card.get("joyoCount"),
        "other_count": card.get("otherCount"),
        "component_filters": [
            {"character": item.get("c"), "meaning": item.get("m"), "count": item.get("n")}
            for item in preload.get("components", [])
        ],
        "joyo_members": [
            {
                "character": item.get("c"),
                "stroke_count": item.get("sc"),
                "grade": item.get("g"),
                "reading": item.get("on"),
                "meaning": item.get("mn"),
                "position": item.get("p"),
            }
            for item in preload.get("members", [])
        ],
        "other_members": [
            {
                "character": item.get("c"),
                "stroke_count": item.get("sc"),
                "grade": item.get("g"),
                "reading": item.get("on"),
                "meaning": item.get("mn"),
                "position": item.get("p"),
            }
            for item in preload.get("other", [])
        ],
        "neighbor_links": [
            {"label": clean_scalar(node.text_content()), "href": first_xpath(node, "./@href")}
            for node in tree.xpath("//*[contains(@class,'radical-neighbor')]")
        ],
        "index_links": snapshot_parsers.unique_list(root_cards),
    }


def parse_kanjidraw_collection_page(html_text: str, url: str) -> dict[str, Any]:
    tree = html.fromstring(html_text)
    ld_graph = snapshot_parsers.first_json_ld_graph(html_text) or []
    collection_meta = snapshot_parsers.first_of_type(ld_graph, "CollectionPage")
    cards = []
    for node in tree.xpath("//*[contains(@class,'collection-kanji-card')]"):
        cards.append(
            {
                "character": first_xpath(node, ".//*[contains(@class,'collection-kanji-char')]"),
                "reading": first_xpath(node, ".//*[contains(@class,'collection-kanji-reading')]"),
                "meaning": first_xpath(node, ".//*[contains(@class,'collection-kanji-meaning')]"),
                "href": first_xpath(node, "./@href"),
            }
        )
    return {
        "section": "collections",
        "slug": urllib.parse.unquote(urllib.parse.urlsplit(url).path.rstrip("/").split("/")[-1]),
        "collection_name": collection_meta.get("name") or first_xpath(tree, "//*[contains(@class,'collection-page-title')]"),
        "description": collection_meta.get("description") or first_xpath(tree, "//*[contains(@class,'collection-page-desc')]"),
        "item_count": snapshot_parsers.parse_int(first_xpath(tree, "//*[contains(@class,'collection-page-count')]")),
        "items": snapshot_parsers.unique_list(cards),
        "practice_modes": collect_texts(tree, "//*[contains(@class,'collection-modes-list')]//li"),
        "see_also": [
            {"label": clean_scalar(node.text_content()), "href": first_xpath(node, "./@href")}
            for node in tree.xpath("//*[contains(@class,'collection-seealso-link')]")
        ],
    }


def parse_kanjidraw_kana_page(html_text: str, url: str) -> dict[str, Any]:
    tree = html.fromstring(html_text)
    cells = []
    for node in tree.xpath("//*[contains(@class,'kana-cell') and @href]"):
        cells.append(
            {
                "character": first_xpath(node, ".//*[contains(@class,'kana-cell-char')]"),
                "romaji": first_xpath(node, ".//*[contains(@class,'kana-cell-romaji')]"),
                "href": first_xpath(node, "./@href"),
            }
        )
    examples = []
    for node in tree.xpath("//*[contains(@class,'kana-detail-example-row')]"):
        examples.append(
            {
                "word": first_xpath(node, ".//*[contains(@class,'kana-detail-example-word')]"),
                "meaning": first_xpath(node, ".//*[contains(@class,'kana-detail-example-meaning')]"),
            }
        )
    return {
        "section": "kana",
        "slug": urllib.parse.unquote(urllib.parse.urlsplit(url).path.rstrip("/").split("/")[-1]) if urllib.parse.urlsplit(url).path.rstrip("/") != "/kana" else "kana",
        "title_emoji": first_xpath(tree, "//*[contains(@class,'kana-title-emoji')]"),
        "detail_character": first_xpath(tree, "//*[contains(@class,'kana-detail-char')]"),
        "detail_romaji": first_xpath(tree, "//*[contains(@class,'kana-detail-romaji')]"),
        "detail_strokes": snapshot_parsers.parse_int(first_xpath(tree, "//*[contains(@class,'kana-detail-strokes')]")),
        "practice_hint": first_xpath(tree, "//*[contains(@class,'kana-practice-block-desc')]"),
        "kana_cells": snapshot_parsers.unique_list(cells),
        "examples": snapshot_parsers.unique_list(examples),
    }


def parse_kanshudo_word_page(html_text: str, url: str) -> dict[str, Any]:
    tree = html.fromstring(html_text)
    surface = urllib.parse.unquote(urllib.parse.urlsplit(url).path.rstrip("/").split("/")[-1])
    title = clean_scalar(tree.xpath("string(//title)")) or ""
    reading_matches = re.findall(r"Reading\s*:\s*</span>\s*<a[^>]*>(.*?)</a>", html_text, re.DOTALL)
    gloss_match = re.search(r"<div><div class='vm'><div><span>(.*?)</span></div>(.*?)</div></div>", html_text, re.DOTALL)
    example_sentences = []
    for jp, en in re.findall(r"<div class=\"tat-tf\"[^>]*>.*?</div>\s*(.*?)<br/>\s*<div class=\"tat-tf noflip\".*?</div>\s*<span class=\"tat_eng\"[^>]*>\s*<span class=\"text\"\s*>(.*?)</span>", html_text, re.DOTALL):
        example_sentences.append({"jp": snapshot_parsers.clean_text(jp), "en": snapshot_parsers.clean_text(en)})
    component_kanji = []
    for symbol, reading in re.findall(r"<div class='kanji'[^>]*>.*?<a [^>]*>(.*?)</a>.*?<div class='reading'>\s*(.*?)\s*</div>", html_text, re.DOTALL):
        component_kanji.append({"character": snapshot_parsers.clean_text(symbol), "reading": snapshot_parsers.clean_text(reading)})
    alternative_forms = []
    for form, reading in re.findall(r"<div class=\"ent_w\">(.*?)</div>.*?Reading\s*:\s*</span>\s*<a[^>]*>(.*?)</a>", html_text, re.DOTALL):
        alternative_forms.append({"form": snapshot_parsers.clean_text(form), "reading": snapshot_parsers.clean_text(reading)})
    return {
        "surface": surface,
        "title": title.replace(" Word Detail - Kanshudo", "") or None,
        "readings": snapshot_parsers.unique_list([snapshot_parsers.clean_text(item) for item in reading_matches if snapshot_parsers.clean_text(item)]),
        "part_of_speech": snapshot_parsers.clean_text(gloss_match.group(1)) if gloss_match else None,
        "primary_gloss": snapshot_parsers.clean_text(gloss_match.group(2)) if gloss_match else None,
        "usefulness": collect_texts(tree, "//*[contains(@class,'ent_item')]"),
        "example_sentences": snapshot_parsers.unique_list(example_sentences),
        "alternative_forms": snapshot_parsers.unique_list(alternative_forms),
        "component_kanji": snapshot_parsers.unique_list(component_kanji),
        "collection_links": [
            {"label": clean_scalar(node.text_content()), "href": first_xpath(node, "./@href")}
            for node in tree.xpath("//a[contains(@href,'/collections/')]")
        ],
    }


def parse_kanshudo_component_page(html_text: str, url: str) -> dict[str, Any]:
    tree = html.fromstring(html_text)
    return {
        "section": first_segment(urllib.parse.urlsplit(url).path or "/"),
        "quick_links": collect_texts(tree, "//*[contains(@class,'qslink')]"),
        "panel_titles": collect_texts(tree, "//*[contains(@class,'w_title')]"),
        "linked_components": [
            {"label": clean_scalar(node.text_content()), "href": first_xpath(node, "./@href")}
            for node in tree.xpath("//a[contains(@href,'/kanji/')]")
        ],
    }


def parse_kanshudo_draw_page(html_text: str, url: str) -> dict[str, Any]:
    tree = html.fromstring(html_text)
    return {
        "section": "kanji_draw",
        "quick_links": collect_texts(tree, "//*[contains(@class,'qslink')]"),
        "panel_titles": collect_texts(tree, "//*[contains(@class,'w_title')]"),
        "help_text": collect_texts(tree, "//*[contains(@class,'spaced')]"),
    }


def parse_tanoshii_kanji_strokes_page(html_text: str, url: str) -> dict[str, Any]:
    tree = html.fromstring(html_text)
    return {
        **parse_tanoshii_wordish_common(tree, url),
        "stroke_order_count": len(tree.xpath("//*[@id='idStrokeOrderDiagrams']//li")),
        "entry_links": extract_href_records(tree, "//*[@id='idStrokeOrderDiagrams']//a"),
    }


def parse_tanoshii_word_page(html_text: str, url: str) -> dict[str, Any]:
    tree = html.fromstring(html_text)
    payload = parse_tanoshii_wordish_common(tree, url)
    payload["sample_sentences"] = extract_tanoshii_sample_sentences(tree)
    payload["kanji_meanings"] = extract_tanoshii_table_rows(tree, "idKanjiMeanings")
    payload["synonym_senses"] = extract_tanoshii_synonym_senses(tree)
    payload["hyponyms"] = extract_tanoshii_table_rows(tree, "idHyponyms")
    return payload


def parse_tanoshii_word_strokes_page(html_text: str, url: str) -> dict[str, Any]:
    tree = html.fromstring(html_text)
    payload = parse_tanoshii_wordish_common(tree, url)
    payload["stroke_order_count"] = len(tree.xpath("//*[@id='idStrokeOrderDiagrams']//li"))
    payload["sample_sentences"] = extract_tanoshii_sample_sentences(tree)
    return payload


def parse_tanoshii_conjugation_page(html_text: str, url: str) -> dict[str, Any]:
    tree = html.fromstring(html_text)
    payload = parse_tanoshii_wordish_common(tree, url)
    conjugations = []
    current_group = None
    for node in tree.xpath("//*[@id='idConjugations']//*[contains(@class,'conjugationgroup') or contains(@class,'jmdelement')]"):
        classes = " ".join(node.get("class", "").split())
        if "conjugationgroup" in classes:
            current_group = clean_scalar(node.text_content())
            continue
        if "jmdelement" not in classes:
            continue
        conjugations.append(
            {
                "group": current_group,
                "label": first_xpath(node, ".//*[contains(@class,'conjugation')]"),
                "surface": first_xpath(node, ".//*[contains(@class,'jp')]"),
                "romaji": first_xpath(node, ".//*[contains(@class,'romaji')]"),
                "detail_href": first_xpath(node, ".//*[contains(@class,'link')]//a/@href"),
            }
        )
    payload["conjugations"] = snapshot_parsers.unique_list(conjugations)
    payload["sample_sentences"] = extract_tanoshii_sample_sentences(tree)
    payload["stroke_order_count"] = len(tree.xpath("//*[@id='idStrokeOrderDiagrams']//li"))
    return payload


def parse_tanoshii_sentence_page(html_text: str, url: str) -> dict[str, Any]:
    tree = html.fromstring(html_text)
    sentence_words = []
    for node in tree.xpath("//*[@id='idVocabularyElements']//div[contains(@class,'entry')]"):
        sentence_words.append(
            {
                "surface": first_xpath(node, ".//*[contains(@class,'jp')]"),
                "romaji": first_xpath(node, ".//*[contains(@class,'romaji')]"),
                "part_of_speech": first_xpath(node, ".//*[contains(@class,'partofspeech')]"),
                "meanings": collect_texts(node, ".//div[contains(@class,'en')]//li"),
                "entry_links": extract_href_records(node, ".//*[contains(@class,'entrylinks')]//a"),
            }
        )
    return {
        **parse_tanoshii_wordish_common(tree, url),
        "sentence_japanese": first_xpath(tree, "//*[contains(@class,'sentence')]//*[contains(@class,'jp')]"),
        "sentence_english": first_xpath(tree, "//*[starts-with(@id,'eng_')]//*[contains(@class,'text')]"),
        "sentence_word_links": extract_href_records(tree, "//*[@id='idSentenceVocabulary']//a[contains(@href,'entry_details.cfm')]"),
        "sentence_words": snapshot_parsers.unique_list(sentence_words),
    }


def parse_tanoshii_wordish_common(tree: html.HtmlElement, url: str) -> dict[str, Any]:
    split = urllib.parse.urlsplit(url)
    query = urllib.parse.parse_qs(split.query, keep_blank_values=True)
    english_meanings = collect_texts(tree, "//*[@id='idEnglishMeaning']//li")
    forms = []
    for form in tree.xpath("//*[@name='fEntryDetails']//div[contains(@class,'furigana')]"):
        text = clean_scalar(form.text_content())
        if text:
            forms.append(text)
    return {
        "dictionary_page": Path(split.path).name,
        "character_id": first_query_value(query, "character_id"),
        "entry_id": first_query_value(query, "entry_id"),
        "sentence_id": first_query_value(query, "sentence_id"),
        "forms": dedupe(forms),
        "romaji": collect_texts(tree, "//*[contains(@class,'romaji')]"),
        "part_of_speech": collect_texts(tree, "//*[contains(@class,'partofspeech')]"),
        "english_meanings": english_meanings,
        "entry_links": extract_href_records(tree, "//*[contains(@class,'entrylinks')]//a"),
        "kanji_links": extract_href_records(tree, "//a[contains(@href,'kanji_details.cfm')]"),
    }


def extract_tanoshii_sample_sentences(tree: html.HtmlElement) -> list[dict[str, str | None]]:
    sentences = []
    for block in tree.xpath("//*[@id='idSampleSentences']//div[contains(@class,'jp')]"):
        english = first_xpath(block.getparent() if hasattr(block, "getparent") else tree, ".//*[contains(@class,'en')]")
        sentences.append({"jp": clean_scalar(block.text_content()), "en": english})
    return snapshot_parsers.unique_list(sentences)


def extract_tanoshii_table_rows(tree: html.HtmlElement, section_id: str) -> list[dict[str, str | None]]:
    rows = []
    for tr in tree.xpath(f"//*[@id='{section_id}']//tr"):
        cells = [clean_scalar(cell.text_content()) for cell in tr.xpath("./td")]
        cells = [cell for cell in cells if cell]
        if cells:
            rows.append({"cells": cells})
    return rows


def extract_tanoshii_synonym_senses(tree: html.HtmlElement) -> list[dict[str, Any]]:
    senses = []
    current: dict[str, Any] | None = None
    for row in tree.xpath("//*[@id='idSynonyms']//tr"):
        row_class = row.get("class", "")
        cells = [clean_scalar(cell.text_content()) for cell in row.xpath("./td")]
        cells = [cell for cell in cells if cell]
        if not cells:
            continue
        if "jp" in row_class:
            current = {"jp": cells[-2] if len(cells) >= 2 else cells[0], "jp_gloss": cells[-1] if len(cells) >= 1 else None}
            senses.append(current)
        elif "en" in row_class and current is not None:
            current["en"] = cells[-2] if len(cells) >= 2 else cells[0]
            current["en_gloss"] = cells[-1] if len(cells) >= 1 else None
        elif "syn" in row_class and current is not None:
            current["synonyms"] = cells[-1]
    return senses


def extract_href_records(tree: html.HtmlElement, xpath: str) -> list[dict[str, str | None]]:
    records = []
    for node in tree.xpath(xpath):
        href = node if isinstance(node, str) else first_xpath(node, "./@href")
        label = clean_scalar(node if isinstance(node, str) else node.text_content())
        if href or label:
            records.append({"label": label, "href": href})
    return snapshot_parsers.unique_list(records)


def route_key(site_id: str, url: str) -> str:
    split = urllib.parse.urlsplit(url)
    path = urllib.parse.unquote(split.path or "/")
    if site_id == "tanoshii_japanese" and path.startswith("/dictionary/"):
        return Path(path).name.lower() or "/dictionary/"
    parts = [part for part in path.split("/") if part]
    return parts[0] if parts else "/"


def entity_hint(site_id: str, page_type: str, url: str) -> str | None:
    split = urllib.parse.urlsplit(url)
    path = urllib.parse.unquote(split.path or "/")
    query = urllib.parse.parse_qs(split.query, keep_blank_values=True)
    parts = [part for part in path.split("/") if part]

    if site_id in {"wanikani", "kanjidraw", "kanshudo"} and parts:
        return urllib.parse.unquote(parts[-1])
    if site_id == "the_kanji_map" and parts:
        return urllib.parse.unquote(parts[0])
    if site_id == "tanoshii_japanese":
        return first_query_value(query, "k") or first_query_value(query, "entry_id") or first_query_value(query, "sentence_id")
    return None


def collect_texts(tree: html.HtmlElement, xpath: str) -> list[str]:
    values = []
    for node in tree.xpath(xpath):
        text = clean_scalar(node.text_content() if hasattr(node, "text_content") else str(node))
        if text:
            values.append(text)
    return dedupe(values)


def collect_definition_pairs(tree: html.HtmlElement) -> list[dict[str, str]]:
    terms = tree.xpath("//dt")
    pairs = []
    for term in terms:
        key = clean_scalar(term.text_content())
        sibling = term.getnext()
        if sibling is None or sibling.tag.lower() != "dd":
            continue
        value = clean_scalar(sibling.text_content())
        if key and value:
            pairs.append({"term": key, "value": value})
    return pairs


def first_xpath(tree: html.HtmlElement, xpath: str) -> str | None:
    values = tree.xpath(xpath)
    if not values:
        return None
    return clean_scalar(values[0] if isinstance(values[0], str) else values[0].text_content())


def first_labeled_value(tree: html.HtmlElement, label: str) -> str | None:
    heading = tree.xpath(f"//*[self::h1 or self::h2 or self::h3][normalize-space()='{label}']")
    if not heading:
        return None
    node = heading[0].getnext()
    while node is not None:
        text = clean_scalar(node.text_content())
        if text:
            return text
        node = node.getnext()
    return None


def split_csv(value: str | None) -> list[str]:
    if not value:
        return []
    return [part.strip() for part in re.split(r"\s*,\s*", value) if part.strip()]


def first_query_value(query: dict[str, list[str]], key: str) -> str | None:
    values = query.get(key)
    return values[0] if values else None


def first_segment(path: str) -> str | None:
    parts = [part for part in path.split("/") if part]
    return parts[0] if parts else None


def clean_scalar(value: Any) -> str | None:
    text = re.sub(r"\s+", " ", str(value or "")).strip()
    return text or None


def dedupe(items: list[str]) -> list[str]:
    seen = set()
    result = []
    for item in items:
        if item in seen:
            continue
        seen.add(item)
        result.append(item)
    return result


def append_jsonl(path: Path, payload: dict[str, Any]) -> None:
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=False) + "\n")


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def iso_now() -> str:
    return datetime.now(UTC).isoformat(timespec="seconds")


if __name__ == "__main__":
    raise SystemExit(main())
