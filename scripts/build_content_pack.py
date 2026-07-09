#!/usr/bin/env python3
"""One-shot builder: EDRDG / KanjiVG (or the curated seed) → the jibiki content pack.

This is the ONLY place upstream formats are parsed. It emits jibiki's own versioned
JSON model (see docs/CONTENT_PACK.md). After running it once, the backend loads the
pack (manage.py load_pack) and the app downloads it - neither ever touches JMdict
XML again. Enrichment = add a language key to the JSON, no re-scrape.

Standalone: stdlib only, no Django import required.

    # from the committed curated seed (small, instant, always works):
    python scripts/build_content_pack.py --from-seed --server server --out content

    # from the full EDRDG + KanjiVG sources (downloaded once):
    python scripts/build_content_pack.py --out content --langs en,fr \
        --jmdict JMdict_e.xml --kanjidic kanjidic2.xml \
        --kradfile kradfile --kanjivg /path/to/kanjivg/kanji
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET
from datetime import date
from pathlib import Path

SCHEMA = "jibiki-content/1"
XML_LANG = "{http://www.w3.org/XML/1998/namespace}lang"
ISO3_FROM_2 = {"en": "eng", "fr": "fre", "de": "ger", "nl": "dut", "ru": "rus", "es": "spa"}
ISO2_FROM_3 = {v: k for k, v in ISO3_FROM_2.items()}
COMMON_TAGS = {"news1", "ichi1", "spec1", "spec2", "gai1"}

ATTRIBUTION = {
    "words": "JMdict © EDRDG, used under the EDRDG Licence.",
    "kanji": "KANJIDIC2 © EDRDG, used under the EDRDG Licence.",
    "components": "KRADFILE © EDRDG (CC BY-SA 3.0).",
    "strokes": "KanjiVG © Ulrich Apel (CC BY-SA 3.0).",
}


# ── jibiki model builders (shared by seed + sources) ────────────────────────────


def kana_entry(char, romaji, script, kind, row, order):
    return {"char": char, "romaji": romaji, "script": script, "kind": kind, "row": row, "order": order}


def kanji_entry(literal, *, grade=None, strokes_count=0, jlpt=None, freq=None, radical=None,
                on=None, kun=None, nanori=None, meanings=None, components=None, stroke_paths=None,
                viewbox="0 0 109 109"):
    return {
        "literal": literal,
        "grade": grade,
        "stroke_count": strokes_count,
        "jlpt": jlpt,
        "freq_rank": freq,
        "radical_number": radical,
        "on": on or [],
        "kun": kun or [],
        "nanori": nanori or [],
        "meanings": meanings or {},          # {"en": [...], "fr": [...]} - enrichment-friendly
        "components": components or [],
        "strokes": {"viewbox": viewbox, "paths": stroke_paths or []},
    }


def word_entry(wid, *, seq=None, common=False, jlpt=None, freq=None, kanji=None, kana=None, senses=None):
    return {
        "id": wid,
        "seq": seq,
        "common": common,
        "jlpt": jlpt,
        "freq_rank": freq,
        "kanji": kanji or [],                # [{"text","common"}]
        "kana": kana or [],
        "senses": senses or [],              # [{"pos":[],"misc":[],"glosses":{"en":[...]}}]
    }


# ── source 1: the committed curated seed (no XML) ───────────────────────────────


def build_from_seed(server_dir: Path, langs: list[str]) -> dict:
    sys.path.insert(0, str(server_dir))
    from dictionary.seed_data import KANA, KANJI, RADICALS, WORDS  # pure-python data
    from dictionary.seed_strokes import STROKES

    kana = []
    order = 0
    for romaji, hira, kata, row, kind in KANA:
        kana.append(kana_entry(hira, romaji, "hiragana", kind, row, order))
        kana.append(kana_entry(kata, romaji, "katakana", kind, row, order))
        order += 1

    radicals = [
        {"literal": lit, "strokes": s, "reading": r, "meaning": m}
        for lit, (s, r, m) in RADICALS.items()
    ]

    kanji = []
    for lit, d in KANJI.items():
        st = STROKES.get(lit, {})
        meanings = {}
        for lang in langs:
            vals = d.get(lang)
            if vals:
                meanings[lang] = list(vals)
        kanji.append(kanji_entry(
            lit, grade=d.get("grade"), strokes_count=d["strokes"], jlpt=d.get("jlpt"),
            freq=d.get("freq"), on=d["on"], kun=d["kun"], meanings=meanings,
            components=d.get("comp", []), stroke_paths=st.get("paths", []),
            viewbox=st.get("viewbox", "0 0 109 109"),
        ))

    words = []
    for i, w in enumerate(WORDS):
        senses = []
        for s in w["senses"]:
            glosses = {lang: list(s[lang]) for lang in langs if s.get(lang)}
            senses.append({"pos": s.get("pos", []), "misc": [], "glosses": glosses})
        words.append(word_entry(
            i + 1, seq=None, common=w.get("common", False), jlpt=w.get("jlpt"),
            kanji=[{"text": t, "common": c} for t, c in w.get("kanji", [])],
            kana=[{"text": t, "common": c} for t, c in w.get("kana", [])],
            senses=senses,
        ))

    return {"kana": kana, "radicals": radicals, "kanji": kanji, "words": words, "source": "seed"}


# ── source 2: the full EDRDG + KanjiVG files (parsed once) ───────────────────────


def _jmdict_entities(path: Path) -> dict[str, str]:
    entities: dict[str, str] = {}
    with path.open("r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if "<!ENTITY" in line:
                for name in re.findall(r'<!ENTITY\s+([\w-]+)\s+"[^"]*">', line):
                    entities[name] = name
            elif line.lstrip().startswith("<JMdict"):
                break
    return entities


def parse_jmdict(path: Path, langs: list[str], limit: int) -> list[dict]:
    iso3 = {ISO3_FROM_2.get(x, x) for x in langs}
    parser = ET.XMLParser()
    parser.entity.update(_jmdict_entities(path))
    words, wid, count = [], 0, 0
    for _e, entry in ET.iterparse(str(path), events=("end",), parser=parser):
        if entry.tag != "entry":
            continue
        wid += 1
        seq_text = entry.findtext("ent_seq")
        common = False
        kanji, kana = [], []
        for k in entry.findall("k_ele"):
            c = any((p.text or "") in COMMON_TAGS for p in k.findall("ke_pri"))
            common = common or c
            kanji.append({"text": k.findtext("keb") or "", "common": c})
        for r in entry.findall("r_ele"):
            c = any((p.text or "") in COMMON_TAGS for p in r.findall("re_pri"))
            common = common or c
            kana.append({"text": r.findtext("reb") or "", "common": c})
        senses = []
        for s in entry.findall("sense"):
            glosses: dict[str, list[str]] = {}
            for g in s.findall("gloss"):
                lang3 = g.get(XML_LANG, "eng")
                if lang3 in iso3 and g.text:
                    glosses.setdefault(ISO2_FROM_3.get(lang3, lang3), []).append(g.text)
            if not glosses:
                continue
            senses.append({
                "pos": [p.text for p in s.findall("pos") if p.text],
                "misc": [m.text for m in s.findall("misc") if m.text],
                "glosses": glosses,
            })
        if senses:
            words.append(word_entry(
                wid, seq=int(seq_text) if seq_text and seq_text.isdigit() else None,
                common=common, kanji=kanji, kana=kana, senses=senses,
            ))
        entry.clear()
        count += 1
        if limit and count >= limit:
            break
    return words


def parse_kanjidic(path: Path, langs: list[str]) -> list[dict]:
    out = []
    for _e, ch in ET.iterparse(str(path), events=("end",)):
        if ch.tag != "character":
            continue
        lit = ch.findtext("literal")
        misc = ch.find("misc")

        def _int(tag, node=misc):
            v = node.findtext(tag) if node is not None else None
            return int(v) if v and v.isdigit() else None

        on, kun, nanori, meanings = [], [], [], {}
        rm = ch.find("reading_meaning")
        if rm is not None:
            for grp in rm.findall("rmgroup"):
                for r in grp.findall("reading"):
                    if r.get("r_type") == "ja_on":
                        on.append(r.text or "")
                    elif r.get("r_type") == "ja_kun":
                        kun.append(r.text or "")
                for m in grp.findall("meaning"):
                    lang = m.get("m_lang", "en")
                    if lang in langs and m.text:
                        meanings.setdefault(lang, []).append(m.text)
            nanori = [n.text or "" for n in rm.findall("nanori")]
        rad = ch.find("radical")
        out.append(kanji_entry(
            lit, grade=_int("grade"), strokes_count=_int("stroke_count") or 0,
            jlpt=_int("jlpt_level"), freq=_int("freq"),
            radical=_int("rad_value", rad) if rad is not None else None,
            on=[x for x in on if x], kun=[x for x in kun if x], nanori=[x for x in nanori if x],
            meanings=meanings,
        ))
        ch.clear()
    return out


def apply_kradfile(kanji: list[dict], path: Path) -> None:
    by_lit = {k["literal"]: k for k in kanji}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        lines = path.read_text(encoding="euc-jp").splitlines()
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#") or " : " not in line:
            continue
        head, comps = line.split(" : ", 1)
        k = by_lit.get(head.strip())
        if k:
            k["components"] = [c for c in comps.split() if c]


def apply_kanjivg(kanji: list[dict], svg_dir: Path) -> None:
    path_re = re.compile(r'<path[^>]*\sd="([^"]+)"')
    vb_re = re.compile(r'viewBox="([^"]+)"')
    for k in kanji:
        svg = svg_dir / f"{ord(k['literal']):05x}.svg"
        if not svg.exists():
            continue
        text = svg.read_text(encoding="utf-8")
        paths = path_re.findall(text)
        if paths:
            vb = vb_re.search(text)
            k["strokes"] = {"viewbox": vb.group(1) if vb else "0 0 109 109", "paths": paths}


def build_from_sources(opts, langs) -> dict:
    kanji = parse_kanjidic(Path(opts.kanjidic), langs) if opts.kanjidic else []
    if opts.kradfile and kanji:
        apply_kradfile(kanji, Path(opts.kradfile))
    if opts.kanjivg and kanji:
        apply_kanjivg(kanji, Path(opts.kanjivg))
    words = parse_jmdict(Path(opts.jmdict), langs, opts.limit) if opts.jmdict else []
    return {"kana": [], "radicals": [], "kanji": kanji, "words": words, "source": "edrdg"}


# ── writing the pack ─────────────────────────────────────────────────────────


def write_pack(out: Path, data: dict, langs: list[str], version: str) -> None:
    out.mkdir(parents=True, exist_ok=True)
    files = []
    for name in ("kana", "radicals", "kanji", "words"):
        payload = json.dumps(data[name], ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        (out / f"{name}.json").write_bytes(payload)
        files.append({
            "name": f"{name}.json",
            "sha256": hashlib.sha256(payload).hexdigest(),
            "bytes": len(payload),
            "count": len(data[name]),
        })
    manifest = {
        "schema": SCHEMA,
        "version": version,
        "source": data["source"],
        "languages": langs,
        "counts": {name: len(data[name]) for name in ("kana", "radicals", "kanji", "words")},
        "files": files,
        "attribution": ATTRIBUTION,
    }
    (out / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Wrote pack v{version} ({data['source']}) → {out}")
    for f in files:
        print(f"  {f['name']}: {f['count']} entries, {f['bytes'] / 1024:.1f} KiB")


def main() -> None:
    ap = argparse.ArgumentParser(description="Build the jibiki content pack.")
    ap.add_argument("--out", default="content", help="output directory")
    ap.add_argument("--langs", default="en,fr", help="comma list of languages to keep")
    ap.add_argument("--version", default=date.today().isoformat(), help="pack version stamp")
    ap.add_argument("--from-seed", action="store_true", help="build from the committed curated seed")
    ap.add_argument("--server", default="server", help="path to the Django server dir (for --from-seed)")
    ap.add_argument("--jmdict", help="JMdict XML path")
    ap.add_argument("--kanjidic", help="KANJIDIC2 XML path")
    ap.add_argument("--kradfile", help="KRADFILE path")
    ap.add_argument("--kanjivg", help="KanjiVG kanji/ directory")
    ap.add_argument("--limit", type=int, default=0, help="cap JMdict entries (0 = all)")
    opts = ap.parse_args()

    langs = [x.strip() for x in opts.langs.split(",") if x.strip()]
    if opts.from_seed:
        data = build_from_seed(Path(opts.server), langs)
    elif opts.jmdict or opts.kanjidic:
        data = build_from_sources(opts, langs)
    else:
        ap.error("pass --from-seed or at least --jmdict / --kanjidic")

    write_pack(Path(opts.out), data, langs, opts.version)


if __name__ == "__main__":
    main()
