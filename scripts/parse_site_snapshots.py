"""Parse harvested HTML snapshots and robots.txt into structured JSON.

By default this script parses already-downloaded local snapshots in
``var/source_harvest/site_snapshots``.

With ``--fetch-live`` it can refresh those snapshots directly from the source
sites before parsing them, so it can run standalone without a separate
``source_harvest.py snapshot-sites`` step.

Examples:

    python scripts/parse_site_snapshots.py
    python scripts/parse_site_snapshots.py --site jisho --site wanikani
    python scripts/parse_site_snapshots.py --fetch-live --site jisho
"""

from __future__ import annotations

import argparse
import html
import json
import re
import urllib.parse
from pathlib import Path
from typing import Any

from source_harvest import SITE_TARGETS, snapshot_site

ROOT = Path(__file__).resolve().parents[1]
SNAPSHOTS_ROOT = ROOT / "var" / "source_harvest" / "site_snapshots"

SUPPORTED_SITES = (
    "jisho",
    "kanshudo",
    "tanoshii_japanese",
    "the_kanji_map",
    "kanjidraw",
    "wanikani",
)
SITE_TARGETS_BY_ID = {site.id: site for site in SITE_TARGETS}

TAG_RE = re.compile(r"<[^>]+>")
WHITESPACE_RE = re.compile(r"\s+")
META_RE = re.compile(
    r'<meta[^>]+(?:name|property)=["\'](?P<key>[^"\']+)["\'][^>]+content=["\'](?P<value>[^"\']*)["\']',
    re.IGNORECASE,
)
TITLE_RE = re.compile(r"<title[^>]*>(.*?)</title>", re.IGNORECASE | re.DOTALL)
CANONICAL_RE = re.compile(
    r'<link[^>]+rel=["\']canonical["\'][^>]+href=["\']([^"\']+)["\']',
    re.IGNORECASE,
)
JSON_SCRIPT_RE = re.compile(
    r'<script[^>]+type=["\']application/ld\+json["\'][^>]*>(.*?)</script>',
    re.IGNORECASE | re.DOTALL,
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--site",
        action="append",
        dest="sites",
        choices=SUPPORTED_SITES,
        help="Specific site id(s) to parse. Defaults to all supported snapshots.",
    )
    parser.add_argument(
        "--fetch-live",
        action="store_true",
        help="Refresh each selected snapshot directly from its source site before parsing.",
    )
    args = parser.parse_args()

    sites = args.sites or list_supported_sites()
    if args.fetch_live and not sites:
        sites = list(SUPPORTED_SITES)
    manifest = {
        "schema": "jibiki-site-snapshot-parse/1",
        "root": str(SNAPSHOTS_ROOT),
        "sites": {},
    }

    for site_id in sites:
        if args.fetch_live:
            refresh_live_snapshot(site_id)
        parsed = parse_site_snapshot(site_id)
        write_json(SNAPSHOTS_ROOT / site_id / "parsed.json", parsed)
        manifest["sites"][site_id] = {
            "path": str(SNAPSHOTS_ROOT / site_id / "parsed.json"),
            "character": parsed["page"].get("character"),
            "title": parsed["page"].get("title"),
            "notes": parsed["page"].get("parse_notes", []),
        }
        print(f"Wrote {SNAPSHOTS_ROOT / site_id / 'parsed.json'}")

    write_json(SNAPSHOTS_ROOT / "parsed_manifest.json", manifest)
    print(f"Wrote {SNAPSHOTS_ROOT / 'parsed_manifest.json'}")
    return 0


def list_supported_sites() -> list[str]:
    return [site_id for site_id in SUPPORTED_SITES if (SNAPSHOTS_ROOT / site_id).is_dir()]


def refresh_live_snapshot(site_id: str) -> None:
    site = SITE_TARGETS_BY_ID[site_id]
    snapshot_site(site)


def parse_site_snapshot(site_id: str) -> dict[str, Any]:
    site_dir = SNAPSHOTS_ROOT / site_id
    snapshot_meta = json.loads((site_dir / "snapshot.json").read_text(encoding="utf-8"))
    html_path = site_dir / "sample.html"
    robots_path = site_dir / "robots.txt"
    html_text = html_path.read_text(encoding="utf-8") if html_path.exists() else ""
    robots_text = robots_path.read_text(encoding="utf-8") if robots_path.exists() else ""

    page = {
        "site": site_id,
        "title": first_group(TITLE_RE, html_text),
        "canonical": first_group(CANONICAL_RE, html_text),
        "meta": parse_meta_tags(html_text),
        "source_url": snapshot_meta.get("sample", {}).get("url"),
        "parse_notes": [],
    }
    if html_text:
        parsed_page = site_specific_parser(site_id)(html_text, snapshot_meta)
        merged_notes = page["parse_notes"] + parsed_page.get("parse_notes", [])
        page.update(parsed_page)
        page["parse_notes"] = merged_notes
    else:
        sample_meta = snapshot_meta.get("sample", {})
        error = sample_meta.get("error")
        if snapshot_meta.get("allowed_by_robots") is False:
            page["parse_notes"].append("Sample page was not fetched because robots.txt disallowed it.")
        elif error:
            page["parse_notes"].append(f"Sample page fetch failed: {error}")
        else:
            page["parse_notes"].append("Sample page HTML is missing; only snapshot metadata and robots.txt were parsed.")

    return {
        "schema": "jibiki-site-snapshot-parsed/1",
        "site": site_id,
        "snapshot": snapshot_meta,
        "robots": parse_robots_txt(robots_text),
        "page": page,
    }


def site_specific_parser(site_id: str):
    parsers = {
        "jisho": parse_jisho,
        "kanshudo": parse_kanshudo,
        "tanoshii_japanese": parse_tanoshii_japanese,
        "the_kanji_map": parse_the_kanji_map,
        "kanjidraw": parse_kanjidraw,
        "wanikani": parse_wanikani,
    }
    return parsers[site_id]


def parse_robots_txt(text: str) -> dict[str, Any]:
    lines = text.splitlines()
    comments = []
    directives: list[dict[str, Any]] = []
    blocks: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None

    for raw_line in lines:
        stripped = raw_line.strip()
        if not stripped:
            current = None
            continue
        if stripped.startswith("#"):
            comments.append(stripped[1:].strip())
            continue
        if ":" not in stripped:
            continue
        key, value = stripped.split(":", 1)
        key = key.strip()
        value = value.strip()
        lower_key = key.lower()
        directives.append({"key": key, "value": value})
        if lower_key == "user-agent":
            if current is None:
                current = {
                    "user_agents": [],
                    "allow": [],
                    "disallow": [],
                    "content_signals": [],
                    "other": {},
                }
                blocks.append(current)
            current["user_agents"].append(value)
            continue
        if current is None:
            current = {
                "user_agents": [],
                "allow": [],
                "disallow": [],
                "content_signals": [],
                "other": {},
            }
            blocks.append(current)
        if lower_key == "allow":
            current["allow"].append(value)
        elif lower_key == "disallow":
            current["disallow"].append(value)
        elif lower_key == "crawl-delay":
            current["crawl_delay"] = parse_int(value)
        elif lower_key == "content-signal":
            signal_map = {}
            for part in value.split(","):
                if "=" not in part:
                    continue
                signal_key, signal_value = part.split("=", 1)
                signal_map[signal_key.strip()] = signal_value.strip()
            current["content_signals"].append(signal_map)
        else:
            current["other"].setdefault(key, []).append(value)

    return {
        "line_count": len(lines),
        "comments": comments,
        "directives": directives,
        "blocks": blocks,
    }


def parse_jisho(html_text: str, snapshot_meta: dict[str, Any]) -> dict[str, Any]:
    character = first_group(
        re.compile(r'<h1 class="character"[^>]*>(.*?)</h1>', re.DOTALL),
        html_text,
    )
    meanings_block = first_group(
        re.compile(r'<div class="kanji-details__main-meanings">\s*(.*?)\s*</div>', re.DOTALL),
        html_text,
    )
    on_text = first_group(re.compile(r'On:\s*</dt>\s*<dd[^>]*>(.*?)</dd>', re.DOTALL), html_text)
    kun_text = first_group(re.compile(r'Kun:\s*</dt>\s*<dd[^>]*>(.*?)</dd>', re.DOTALL), html_text)
    radical_text = first_group(re.compile(r"<dt>Radical:</dt>\s*<dd>(.*?)</dd>", re.DOTALL), html_text) or ""
    radical_parts = (clean_text(radical_text) or "").split()
    page = {
        "character": clean_text(character),
        "stroke_count": parse_int(
            first_group(
                re.compile(r'kanji-details__stroke_count">\s*<strong>(\d+)</strong>', re.DOTALL),
                html_text,
            )
        ),
        "main_meanings": split_meaning_block(meanings_block),
        "radical": {
            "symbol": radical_parts[-1] if radical_parts else None,
            "meaning": " ".join(radical_parts[:-1]) or None,
        },
        "parts": unique_list(
            re.findall(r'<dt>Parts:</dt>.*?<dd>(.*?)</dd>', html_text, re.DOTALL)[0:1]
            and re.findall(r'Parts:</dt>.*?<dd>(.*?)</dd>', html_text, re.DOTALL)
        ),
        "kun_readings": split_japanese_list(clean_text(kun_text)),
        "on_readings": split_japanese_list(clean_text(on_text)),
        "jlpt_level": first_group(re.compile(r"JLPT level <strong>(N\d)</strong>"), html_text),
        "grade": parse_int(
            first_group(re.compile(r"taught in <strong>grade (\d+)</strong>", re.IGNORECASE), html_text)
        ),
        "frequency_rank": parse_int(
            first_group(re.compile(r'<div class="frequency">\s*<strong>(\d+)</strong>', re.DOTALL), html_text)
        ),
        "variants": split_japanese_list(
            clean_text(first_group(re.compile(r"<dt>Variants:</dt>\s*<dd>(.*?)</dd>", re.DOTALL), html_text))
        ),
        "source_url": snapshot_meta["sample"]["url"],
        "parse_notes": ["Parsed from kanji detail sections in the static snapshot HTML."],
    }
    parts_html = first_group(re.compile(r"<dt>Parts:</dt>\s*<dd>(.*?)</dd>", re.DOTALL), html_text)
    page["parts"] = unique_list(re.findall(r">([^<]+)</a>", parts_html or ""))
    return page


def parse_tanoshii_japanese(html_text: str, snapshot_meta: dict[str, Any]) -> dict[str, Any]:
    character = clean_text(
        first_group(re.compile(r'<div class="kanjiimg[^"]*"[^>]*>(.*?)</div>', re.DOTALL), html_text)
    )
    english_meanings = extract_list_after_pattern(html_text, re.compile(r'<div class="heading">English Meaning</div>', re.DOTALL))
    japanese_meanings = extract_list_after_pattern(html_text, re.compile(r"<h3>Japanese Meaning for .*?</h3>", re.DOTALL))
    compounds = []
    entry_match = re.search(
        r"<h3>Dictionary Entry for .*?</h3>(.*?)<div id=\"idCharacterConstruction\"",
        html_text,
        re.DOTALL,
    )
    if entry_match:
        block = entry_match.group(1)
        surface = clean_text(first_group(re.compile(r"<rb>(.*?)</rb>", re.DOTALL), block))
        reading = clean_text(first_group(re.compile(r"<rt>(.*?)</rt>", re.DOTALL), block))
        romaji = clean_text(first_group(re.compile(r'<div class="romaji hide">(.*?)</div>', re.DOTALL), block))
        part_of_speech = clean_text(first_group(re.compile(r'<span class="partofspeech">(.*?)</span>', re.DOTALL), block))
        dict_meanings = [
            clean_text(item)
            for item in re.findall(r"<ol start=\"1\">(.*?)</ol>", block, re.DOTALL)
            for item in re.findall(r"<li>(.*?)</li>", item, re.DOTALL)
        ]
        compounds.append(
            {
                "word": surface,
                "reading": reading,
                "romaji": romaji,
                "part_of_speech": part_of_speech,
                "meanings": dict_meanings,
            }
        )

    construction_rows = []
    table_match = re.search(
        r"<div id=\"idCharacterConstruction\".*?<table[^>]*>(.*?)</table>",
        html_text,
        re.DOTALL,
    )
    if table_match:
        for cells in re.findall(r"<tr>(.*?)</tr>", table_match.group(1), re.DOTALL):
            columns = re.findall(r"<td[^>]*>(.*?)</td>", cells, re.DOTALL)
            if len(columns) < 4:
                continue
            construction_rows.append(
                {
                    "symbol": clean_text(columns[1]),
                    "role": clean_text(columns[2]),
                    "meaning": clean_text(columns[3]),
                }
            )

    variants = []
    variants_block = re.search(r"Kanji variants for .*?</div>\s*<table class=\"kanjiparts\">(.*?)</table>", html_text, re.DOTALL)
    if variants_block:
        for cells in re.findall(r"<tr>(.*?)</tr>", variants_block.group(1), re.DOTALL):
            columns = re.findall(r"<td[^>]*>(.*?)</td>", cells, re.DOTALL)
            if len(columns) < 3:
                continue
            variants.append({"symbol": clean_text(columns[1]), "description": clean_text(columns[2])})

    return {
        "character": character,
        "stroke_count": parse_int(first_group(re.compile(r"(\d+)\s+Strokes"), html_text)),
        "jlpt_level": first_group(re.compile(r"JLPT Level (N\d)"), html_text),
        "grade": parse_int(first_group(re.compile(r"Taught in Grade (\d+)"), html_text)),
        "radical_summary": clean_text(first_group(re.compile(r"<b>Radical:</b>(.*?)<br/>", re.DOTALL), html_text)),
        "english_meanings": english_meanings,
        "japanese_meanings": japanese_meanings,
        "kun_readings": split_japanese_list(first_group(re.compile(r"Kun'yomi:</span></span>\s*<span class=\"info\">(.*?)<br/>", re.DOTALL), html_text)),
        "on_readings": split_japanese_list(first_group(re.compile(r"On'yomi:</span></span>\s*<span class=\"info\">(.*?)<br/>", re.DOTALL), html_text)),
        "dictionary_entries": compounds,
        "construction": construction_rows,
        "stroke_order_count": count_matches(re.compile(r"<li[^>]*>", re.DOTALL), first_group(re.compile(r"<ul class=\"stroke-order\">(.*?)</ul>", re.DOTALL), html_text)),
        "variants": variants,
        "origin": clean_text(first_group(re.compile(r"Origin and construction of .*?</div>\s*<ol class=\"jp\">\s*<li>(.*?)</li>", re.DOTALL), html_text)),
        "source_url": snapshot_meta["sample"]["url"],
        "parse_notes": ["Dictionary entry meanings were parsed from the sample character page."],
    }


def parse_kanshudo(html_text: str, snapshot_meta: dict[str, Any]) -> dict[str, Any]:
    character = urllib.parse.unquote(snapshot_meta["sample"]["url"].rstrip("/").split("/")[-1])
    meaning = first_group(re.compile(r"means\s*&#39;(.*?)&#39;", re.DOTALL), html_text)
    if not meaning:
        meaning = first_group(re.compile(r"<h1>\s*.*?means '(.*?)'\s*</h1>", re.DOTALL), html_text)

    common_block = block_between(html_text, "Common readings", "Additional readings")
    additional_block = block_between(html_text, "Additional readings", "Variants")
    common_readings = []
    common_on = first_group(re.compile(r'color:darkgray">On</span>.*?([ァ-ヶー]+)\s*</div>', re.DOTALL), common_block)
    if common_on:
        common_readings.append({"type": "on", "reading": common_on, "gloss": None})
    common_kun_match = re.search(r"searchw\?q=.*?'>(.*?)<span.*?</a>\s*(.*?)</div>", common_block, re.DOTALL)
    if common_kun_match:
        common_readings.append(
            {
                "type": "kun",
                "reading": clean_text(common_kun_match.group(1)),
                "gloss": clean_text(common_kun_match.group(2)),
            }
        )

    additional_readings = []
    additional_on = first_group(re.compile(r"On\s*&nbsp;&nbsp;</span>\s*([ァ-ヶー]+)", re.DOTALL), additional_block)
    if additional_on:
        additional_readings.append({"type": "on", "reading": additional_on, "gloss": None})
    additional_name_match = re.search(r"Name\s*&nbsp;&nbsp;</span>\s*(.*?)</div>", additional_block, re.DOTALL)
    if additional_name_match:
        for reading in re.findall(r"[ぁ-ゖァ-ヶー]+", clean_text(additional_name_match.group(1)) or ""):
            additional_readings.append({"type": "name", "reading": reading, "gloss": None})

    variants = []
    variants_block = re.search(
        r"Variants</div>\s*<div class=\"col-3-4\">(.*?)</div>\s*</div>\s*<div class=\"g-row\">\s*<div class=\"col-1-4 col-colors search\">Notes",
        html_text,
        re.DOTALL | re.IGNORECASE,
    )
    if variants_block:
        for variant in re.findall(r">([^<]{1,12})</a>", variants_block.group(1)):
            variants.append(clean_text(variant))

    components_match = re.search(
        r"Components</div>\s*<div class=\"col-3-4\">(.*?)<div style=\"font-size:15px",
        html_text,
        re.DOTALL,
    )
    components_html = components_match.group(1) if components_match else ""
    components_text = (clean_text(components_html) or "").replace("⿰", " ").replace("⿱", " ")
    component_pairs = []
    component_symbols = []
    for match in re.finditer(r"<a href='/kanji/[^']+'>(.*?)</a>", components_html):
        symbol = clean_text(match.group(1))
        if not symbol:
            continue
        prefix = components_html[max(0, match.start() - 3) : match.start()]
        if prefix.endswith("("):
            continue
        if symbol not in component_symbols:
            component_symbols.append(symbol)
    positions = []
    cursor = 0
    for symbol in component_symbols:
        index = components_text.find(symbol, cursor)
        if index == -1:
            continue
        positions.append((symbol, index))
        cursor = index + len(symbol)
    for idx, (symbol, start) in enumerate(positions):
        gloss_start = start + len(symbol)
        gloss_end = positions[idx + 1][1] if idx + 1 < len(positions) else len(components_text)
        gloss = components_text[gloss_start:gloss_end].strip()
        gloss = re.sub(r"^\(\s*[^)]*\)\s*", "", gloss).strip(" ;")
        component_pairs.append({"symbol": symbol, "meaning": gloss or None})

    return {
        "character": character,
        "meanings": [meaning] if meaning else [],
        "stroke_count": parse_int(first_group(re.compile(r"Strokes\s*:</span>\s*(\d+)", re.IGNORECASE), html_text)),
        "frequency_rank": parse_int(first_group(re.compile(r"Frequency:</span>\s*(\d+)", re.IGNORECASE), html_text)),
        "jlpt_level": first_group(re.compile(r"JLPT:\s*</span>\s*<a [^>]*>(N\d)</a>", re.IGNORECASE), html_text),
        "grade": parse_int(first_group(re.compile(r"Grade:\s*</span>\s*<a [^>]*>(\d+)</a>", re.IGNORECASE), html_text)),
        "common_readings": common_readings,
        "additional_readings": additional_readings,
        "variants": variants,
        "components": component_pairs,
        "mnemonic_available": not bool(re.search(r"LOG IN</a> to view this kanji's\s*<a href=\"/kanshudo_system\">mnemonic</a>", html_text)),
        "source_url": snapshot_meta["sample"]["url"],
        "parse_notes": [
            "Kanshudo exposes some learning content behind login; only public snapshot fields were parsed.",
        ],
    }


def parse_wanikani(html_text: str, snapshot_meta: dict[str, Any]) -> dict[str, Any]:
    character = urllib.parse.unquote(snapshot_meta["sample"]["url"].rstrip("/").split("/")[-1])
    meaning_block = extract_section_by_id(html_text, "section-meaning")
    reading_block = extract_section_by_id(html_text, "section-reading")
    vocab_block = extract_section_by_id(html_text, "section-amalgamations")

    radicals = []
    radical_block = extract_section_by_id(html_text, "section-components")
    for symbol, label in re.findall(
        r'subject-character__characters-text" lang="ja">\s*(.*?)\s*</span>.*?<span class="subject-character__meaning">(.*?)</span>',
        radical_block,
        re.DOTALL,
    ):
        radicals.append({"symbol": clean_text(symbol), "meaning": clean_text(label)})

    vocabulary = []
    for word, reading, meaning in re.findall(
        r'subject-character__characters-text" lang="ja">\s*(.*?)\s*</span>.*?<span class="subject-character__reading">(.*?)</span>.*?<span class="subject-character__meaning">(.*?)</span>',
        vocab_block,
        re.DOTALL,
    ):
        vocabulary.append(
            {
                "word": clean_text(word),
                "reading": clean_text(reading),
                "meaning": clean_text(meaning),
            }
        )

    return {
        "character": character,
        "radical_combination": radicals,
        "primary_meaning": first_group(re.compile(r"Primary</h2>\s*<p class='subject-section__meanings-items'>(.*?)</p>", re.DOTALL), meaning_block),
        "alternative_meanings": split_meaning_block(first_group(re.compile(r"Alternatives</h2>\s*<p class='subject-section__meanings-items'>(.*?)</p>", re.DOTALL), meaning_block)),
        "meaning_mnemonic": first_group(re.compile(r"<h3 class='subject-section__subtitle'>Mnemonic</h3>\s*<p class=\"subject-section__text\">(.*?)</p>", re.DOTALL), meaning_block),
        "meaning_hint": first_group(re.compile(r"<p class=\"wk-hint__text\">(.*?)</p>", re.DOTALL), meaning_block),
        "on_readings": split_japanese_list(first_group(re.compile(r"On.yomi</h3>\s*<p class=\"subject-readings__reading-items\" lang=\"ja\">\s*(.*?)\s*</p>", re.DOTALL), reading_block)),
        "kun_readings": split_japanese_list(first_group(re.compile(r"Kun.yomi</h3>\s*<p class=\"subject-readings__reading-items\" lang=\"ja\">\s*(.*?)\s*</p>", re.DOTALL), reading_block)),
        "nanori": split_japanese_list(first_group(re.compile(r"Nanori</h3>\s*<p class=\"subject-readings__reading-items\" lang=\"ja\">\s*(.*?)\s*</p>", re.DOTALL), reading_block)),
        "reading_mnemonic": first_group(re.compile(r"<h3 class='subject-section__subtitle'>Mnemonic</h3>\s*<p class=\"subject-section__text\">(.*?)</p>", re.DOTALL), reading_block),
        "reading_hint": first_group(re.compile(r"<p class=\"wk-hint__text\">(.*?)</p>", re.DOTALL), reading_block),
        "vocabulary_examples": vocabulary,
        "source_url": snapshot_meta["sample"]["url"],
        "parse_notes": ["Mnemonics and vocabulary were parsed from the public lesson snapshot."],
    }


def parse_kanjidraw(html_text: str, snapshot_meta: dict[str, Any]) -> dict[str, Any]:
    preloads = extract_window_json_assignments(html_text)
    ld_json = first_json_ld_graph(html_text)
    defined_term = first_of_type(ld_json, "DefinedTerm") if ld_json else {}

    radical_info = preloads.get("__PRELOAD_KANJI_COMPONENT_INFO__", {}).get("info", {}).get("radical", {})
    components = preloads.get("__PRELOAD_KANJI_COMPONENT_INFO__", {}).get("info", {}).get("components", [])
    heisig = preloads.get("__PRELOAD_HEISIG__", {}).get("entry", {})
    preload_kanji = preloads.get("__PRELOAD_KANJI__", {})

    compounds = []
    for compound in preload_kanji.get("compounds", []):
        compounds.append(
            {
                "word": compound.get("word"),
                "reading": compound.get("reading"),
                "meaning": compound.get("meaning"),
            }
        )

    return {
        "character": preload_kanji.get("char") or defined_term.get("name"),
        "hero_meaning": clean_text(first_group(re.compile(r'dict-word-hero-meaning">(.*?)</div>'), html_text)),
        "stroke_count": preload_kanji.get("strokeCount") or property_value(defined_term, "Stroke count"),
        "grade": preload_kanji.get("grade") or property_value(defined_term, "School grade"),
        "jlpt_level": normalize_jlpt(preload_kanji.get("jlptLevel")),
        "on_readings": preload_kanji.get("onReadings", []) or listify(defined_term.get("alternateName")),
        "kun_readings": preload_kanji.get("kunReadings", []),
        "meanings": preload_kanji.get("meaningsEn", []),
        "badges": unique_list(re.findall(r'dict-badge[^>]*>(.*?)</a>', html_text)),
        "popular_usage": unique_list(re.findall(r'dict-related-chip" href="[^"]+">(.*?)</a>', html_text)),
        "radical": {
            "symbol": radical_info.get("char"),
            "meaning": radical_info.get("meaning"),
            "number": radical_info.get("num"),
            "strokes": radical_info.get("strokes"),
        },
        "components": components,
        "rtk_mnemonic": {
            "keyword": heisig.get("keyword"),
            "primitives": heisig.get("primitives", []),
            "frame": heisig.get("frame"),
        },
        "compound_words": compounds,
        "source_url": snapshot_meta["sample"]["url"],
        "parse_notes": ["Primary data came from embedded preload JSON and JSON-LD."],
    }


def parse_the_kanji_map(html_text: str, snapshot_meta: dict[str, Any]) -> dict[str, Any]:
    payload_match = re.search(r'"requestedId\\":\\"(.*?)\\"', html_text)
    requested_id = unescape_js_fragment(payload_match.group(1)) if payload_match else None
    canonical_id_match = re.search(r'"canonicalId\\":\\"(.*?)\\"', html_text)
    canonical_id = unescape_js_fragment(canonical_id_match.group(1)) if canonical_id_match else None

    field_patterns = {
        "grade": r'"grade\\":(\d+)',
        "meaning": r'"meaning\\":\\"(.*?)\\"',
        "kstroke": r'"kstroke\\":(\d+)',
        "onyomi_ja": r'"onyomi_ja\\":\\"(.*?)\\"',
        "onyomi": r'"onyomi\\":\\"(.*?)\\"',
        "kunyomi_ja": r'"kunyomi_ja\\":\\"(.*?)\\"',
        "kunyomi": r'"kunyomi\\":\\"(.*?)\\"',
        "jlptLevel": r'"jlptLevel\\":\\"(N\d)\\"',
        "newspaperFrequencyRank": r'"newspaperFrequencyRank\\":\\"(\d+)\\"',
        "taughtIn": r'"taughtIn\\":\\"(.*?)\\"',
        "radicalSymbol": r'"radical\\":\{[^{}]*"symbol\\":\\"(.*?)\\"',
        "radicalMeaning": r'"radical\\":\{[^{}]*"meaning\\":\\"(.*?)\\"',
    }
    extracted = {}
    for key, pattern in field_patterns.items():
        match = re.search(pattern, html_text)
        if not match:
            continue
        value = match.group(1)
        extracted[key] = parse_int(value) if value.isdigit() else unescape_js_fragment(value)

    parts = [
        unescape_js_fragment(part)
        for part in re.findall(r'"parts\\":\[(.*?)\]', html_text)
        for part in re.findall(r'\\"(.*?)\\"', part)
    ]
    links = [
        {
            "source": unescape_js_fragment(source),
            "target": unescape_js_fragment(target),
        }
        for source, target in re.findall(r'"source\\":\\"(.*?)\\",\\"target\\":\\"(.*?)\\"', html_text)
    ]

    return {
        "character": requested_id,
        "canonical_id": canonical_id,
        "title_character": clean_text(first_group(re.compile(r"<title>(.*?) \| The Kanji Map</title>"), html_text)),
        "meaning": extracted.get("meaning"),
        "stroke_count": extracted.get("kstroke"),
        "grade": extracted.get("grade"),
        "jlpt_level": extracted.get("jlptLevel"),
        "frequency_rank": extracted.get("newspaperFrequencyRank"),
        "taught_in": extracted.get("taughtIn"),
        "on_readings": split_japanese_list(extracted.get("onyomi_ja", "")),
        "kun_readings": split_japanese_list(extracted.get("kunyomi_ja", "")),
        "radical": {
            "symbol": extracted.get("radicalSymbol"),
            "meaning": extracted.get("radicalMeaning"),
        },
        "parts": unique_list(parts),
        "graph_links": links,
        "graph_link_count": len(links),
        "source_url": snapshot_meta["sample"]["url"],
        "parse_notes": ["Extracted from escaped Next.js flight payload embedded in the snapshot HTML."],
    }


def extract_kanshudo_readings(html_text: str, heading: str) -> list[dict[str, Any]]:
    block = compact_block(html_text, heading)
    readings = []
    for label, reading, meaning in re.findall(
        r"<td[^>]*>\s*(On|Kun|Name)\s*</td>.*?<a[^>]*>(.*?)</a>.*?(?:<span[^>]*>(.*?)</span>)?",
        block,
        re.DOTALL,
    ):
        readings.append(
            {
                "type": clean_text(label).lower(),
                "reading": clean_text(reading),
                "gloss": clean_text(meaning),
            }
        )
    return readings


def extract_following_list_items(html_text: str, header_re: re.Pattern[str]) -> list[str]:
    header_match = header_re.search(html_text)
    if not header_match:
        return []
    tail = html_text[header_match.end() :]
    list_match = re.search(r"<ul[^>]*>(.*?)</ul>", tail, re.DOTALL)
    if not list_match:
        return []
    return [clean_text(item) for item in re.findall(r"<li[^>]*>(.*?)</li>", list_match.group(1), re.DOTALL)]


def extract_list_after_pattern(html_text: str, header_re: re.Pattern[str], *, list_tag: str = "ol") -> list[str]:
    header_match = header_re.search(html_text)
    if not header_match:
        return []
    tail = html_text[header_match.end() :]
    list_match = re.search(rf"<{list_tag}[^>]*>(.*?)</{list_tag}>", tail, re.DOTALL)
    if not list_match:
        return []
    return [clean_text(item) for item in re.findall(r"<li[^>]*>(.*?)</li>", list_match.group(1), re.DOTALL)]


def extract_readings_block(html_text: str, label: str) -> list[str]:
    match = re.search(rf"<b>{re.escape(label)}:</b>(.*?)<br/>", html_text, re.DOTALL)
    if not match:
        return []
    return split_japanese_list(clean_text(match.group(1)))


def extract_marked_list(text: str, class_name: str) -> list[str]:
    return [clean_text(item) for item in re.findall(rf'{class_name}[^>]*>(.*?)</', text, re.DOTALL)]


def extract_paragraph_after(block: str, anchor: str) -> str | None:
    match = re.search(rf"<p class=\"subject-section__text\">.*?{re.escape(anchor)}(.*?)</p>", block, re.DOTALL)
    if not match:
        texts = re.findall(r"<p class=\"subject-section__text\">(.*?)</p>", block, re.DOTALL)
        return clean_text(texts[-1]) if texts else None
    return clean_text(f"{anchor}{match.group(1)}")


def block_between(text: str, start: str, end: str) -> str:
    start_idx = text.find(start)
    if start_idx == -1:
        return ""
    end_idx = text.find(end, start_idx + len(start))
    if end_idx == -1:
        end_idx = min(len(text), start_idx + 12000)
    return text[start_idx:end_idx]


def extract_section_by_id(html_text: str, section_id: str) -> str:
    match = re.search(rf'<section id="{re.escape(section_id)}"[^>]*>(.*?)</section></section>', html_text, re.DOTALL)
    if match:
        return match.group(1)
    return compact_block(html_text, section_id)


def extract_window_json_assignments(html_text: str) -> dict[str, Any]:
    payload = {}
    for var_name, body in re.findall(r"window\.(__[A-Z0-9_]+__)=({.*?})(?:;)?</script>", html_text, re.DOTALL):
        try:
            payload[var_name] = json.loads(body)
        except json.JSONDecodeError:
            continue
    return payload


def first_json_ld_graph(html_text: str) -> list[dict[str, Any]] | None:
    for raw in JSON_SCRIPT_RE.findall(html_text):
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            continue
        graph = parsed.get("@graph")
        if isinstance(graph, list):
            return graph
    return None


def first_of_type(items: list[dict[str, Any]] | None, type_name: str) -> dict[str, Any]:
    if not items:
        return {}
    for item in items:
        if item.get("@type") == type_name:
            return item
    return {}


def property_value(item: dict[str, Any], property_name: str) -> Any:
    for prop in item.get("additionalProperty", []):
        if prop.get("name") != property_name:
            continue
        return prop.get("value")
    return None


def parse_meta_tags(html_text: str) -> dict[str, str]:
    meta = {}
    for match in META_RE.finditer(html_text):
        meta[match.group("key")] = html.unescape(match.group("value"))
    return meta


def split_meaning_block(text: str | None) -> list[str]:
    if not text:
        return []
    cleaned = clean_text(text)
    if not cleaned:
        return []
    return [part.strip() for part in re.split(r"\s*,\s*", cleaned) if part.strip()]


def split_japanese_list(text: str | None) -> list[str]:
    if not text:
        return []
    items = []
    for part in re.split(r"[\u3001,\uFF0F/]\s*", text):
        value = part.strip().strip("。")
        if not value or value == "None":
            continue
        items.append(value)
    return items


def extract_reading_from_surface(surface: str | None) -> str | None:
    if not surface or "(" not in surface or ")" not in surface:
        return None
    return surface.split("(", 1)[1].rsplit(")", 1)[0].strip() or None


def compact_block(html_text: str, label: str) -> str:
    lowered = html_text.lower()
    idx = lowered.find(label.lower())
    if idx == -1:
        return ""
    return html_text[idx : idx + 8000]


def first_group(pattern: re.Pattern[str], text: str) -> str | None:
    match = pattern.search(text)
    return clean_text(match.group(1)) if match else None


def clean_text(value: Any) -> str | None:
    if value is None:
        return None
    text = html.unescape(str(value))
    text = TAG_RE.sub(" ", text)
    text = re.sub(r"[\u200b-\u200d\ufeff]", "", text)
    text = WHITESPACE_RE.sub(" ", text).strip()
    return text or None


def parse_int(value: Any) -> int | None:
    if value is None:
        return None
    match = re.search(r"\d+", str(value))
    return int(match.group(0)) if match else None


def normalize_jlpt(value: Any) -> str | None:
    if value in (None, ""):
        return None
    if isinstance(value, int):
        return f"N{value}"
    text = str(value).strip()
    return text if text.startswith("N") else f"N{text}"


def unique_list(values: list[Any]) -> list[Any]:
    seen = set()
    items = []
    for value in values:
        if value is None:
            continue
        key = json.dumps(value, ensure_ascii=False, sort_keys=True) if isinstance(value, dict) else str(value)
        if key in seen:
            continue
        seen.add(key)
        items.append(value)
    return items


def count_matches(pattern: re.Pattern[str], text: str | None) -> int:
    if not text:
        return 0
    return len(pattern.findall(text))


def last_match(values: list[str]) -> str | None:
    if not values:
        return None
    return clean_text(values[-1])


def listify(value: Any) -> list[Any]:
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return [value]


def unescape_js_fragment(value: str) -> str:
    try:
        return json.loads(f'"{value}"')
    except json.JSONDecodeError:
        return html.unescape(value.replace("\\/", "/"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
