"""CLI for the kana SVG mnemonic generator.

    python -m kana_svg gen    --out out --lang fr           # one SVG per kana + manifest
    python -m kana_svg sheet  --script hiragana --out out   # a single contact-sheet SVG
    python -m kana_svg html   --out out --lang fr           # self-contained preview page
    python -m kana_svg cache                                # (re)build the glyph outline cache
    python -m kana_svg ref    --out out                     # coordinate reference sheets (dev)

Flags: --script {hiragana,katakana,both}  --lang {fr,en}  --base-only  --no-guide
Only `cache` needs the CJK font; everything else runs off the committed
glyph_paths.json, so generation has no system-font dependency.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .glyphs import GlyphBank, build_cache, CANVAS
from .recipes import all_recipes, _kana_table
from .render import standalone, contact_sheet, cell, TILE_H, _short


def _slug(rec) -> str:
    return f"{rec.script[:4]}_{rec.romaji}_{ord(rec.char):04x}"


def cmd_gen(args) -> None:
    out = Path(args.out); out.mkdir(parents=True, exist_ok=True)
    bank = GlyphBank()
    scripts = ["hiragana", "katakana"] if args.script == "both" else [args.script]
    manifest = []
    n = 0
    for script in scripts:
        d = out / script
        d.mkdir(exist_ok=True)
        for rec in all_recipes(script, include_variants=not args.base_only):
            svg = standalone(rec, bank, lang=args.lang, guide=not args.no_guide)
            fn = d / f"{_slug(rec)}.svg"
            fn.write_text(svg, encoding="utf-8")
            manifest.append({
                "char": rec.char, "romaji": rec.romaji, "script": rec.script,
                "picture": rec.label(args.lang), "hook": rec.hook.get(args.lang, ""),
                "file": str(fn.relative_to(out)),
            })
            n += 1
    (out / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote {n} SVGs + manifest.json -> {out}")


def cmd_sheet(args) -> None:
    out = Path(args.out); out.mkdir(parents=True, exist_ok=True)
    bank = GlyphBank()
    scripts = ["hiragana", "katakana"] if args.script == "both" else [args.script]
    for script in scripts:
        recs = all_recipes(script, include_variants=not args.base_only)
        svg = contact_sheet(recs, bank, cols=args.cols, lang=args.lang, guide=not args.no_guide)
        (out / f"sheet_{script}.svg").write_text(svg, encoding="utf-8")
        print(f"sheet_{script}.svg ({len(recs)} kana)")


def cmd_html(args) -> None:
    out = Path(args.out); out.mkdir(parents=True, exist_ok=True)
    bank = GlyphBank()
    page = build_html(bank, lang=args.lang, base_only=args.base_only, guide=not args.no_guide)
    (out / "index.html").write_text(page, encoding="utf-8")
    print(f"wrote index.html -> {out}")


def cmd_cache(args) -> None:
    chars = [k["char"] for k in _kana_table()]
    build_cache(chars)


def cmd_ref(args) -> None:
    from . import _refsheet
    out = Path(args.out); out.mkdir(parents=True, exist_ok=True)
    for s in ("hiragana", "katakana"):
        (out / f"ref_{s}.svg").write_text(_refsheet.sheet(s), encoding="utf-8")
    print(f"wrote ref_*.svg -> {out}")


def build_html(bank, *, lang="fr", base_only=False, guide=True) -> str:
    """A self-contained preview page: every kana card inlined, grouped by script,
    with its romaji, picture and sound hook."""
    sections = []
    for script in ("hiragana", "katakana"):
        recs = all_recipes(script, include_variants=not base_only)
        cards = []
        for rec in recs:
            inner = cell(rec, bank, lang=lang, guide=guide)
            svg = (f'<svg viewBox="0 0 {CANVAS:.0f} {TILE_H:.0f}" class="card">{inner}</svg>')
            hook = _esc(rec.hook.get(lang, ""))
            cards.append(f'<figure title="{hook}">{svg}<figcaption>{_esc(_short(rec.label(lang)))}</figcaption></figure>')
        title = "Hiragana" if script == "hiragana" else "Katakana"
        sections.append(f'<h2>{title} · {len(recs)}</h2><div class="grid">{"".join(cards)}</div>')
    style = (
        "body{margin:0;padding:24px;background:#e9e4db;font-family:Inter,system-ui,sans-serif;color:#22201d}"
        "h1{margin:0 0 4px}h2{margin:28px 0 12px}p{margin:0 0 8px;color:#6b645c}"
        ".grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(96px,1fr));gap:10px}"
        "figure{margin:0}.card{width:100%;height:auto;display:block}"
        "figcaption{display:none}"
    )
    return (f'<!doctype html><html lang="{lang}"><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<title>Kana mnémoniques</title><style>{style}</style>'
            f'<h1>Kana mnémoniques SVG</h1><p>Overlay : le dessin épouse le trait du kana.</p>'
            f'{"".join(sections)}</html>')


def _esc(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


def main() -> None:
    p = argparse.ArgumentParser(prog="kana_svg", description="Generate SVG overlay mnemonics for every kana.")
    sub = p.add_subparsers(dest="cmd", required=True)

    def common(sp):
        sp.add_argument("--script", choices=["hiragana", "katakana", "both"], default="both")
        sp.add_argument("--lang", choices=["fr", "en"], default="fr")
        sp.add_argument("--out", default="out")
        sp.add_argument("--base-only", action="store_true", help="only the 46 base gojūon (no dakuten)")
        sp.add_argument("--no-guide", action="store_true", help="hide the faint reference glyph")

    g = sub.add_parser("gen", help="one standalone SVG per kana + manifest.json"); common(g); g.set_defaults(fn=cmd_gen)
    s = sub.add_parser("sheet", help="one contact-sheet SVG per script"); common(s)
    s.add_argument("--cols", type=int, default=8); s.set_defaults(fn=cmd_sheet)
    h = sub.add_parser("html", help="self-contained preview page"); common(h); h.set_defaults(fn=cmd_html)
    c = sub.add_parser("cache", help="(re)build glyph_paths.json from the CJK font"); c.set_defaults(fn=cmd_cache)
    r = sub.add_parser("ref", help="coordinate reference sheets (dev)"); r.add_argument("--out", default="out"); r.set_defaults(fn=cmd_ref)

    args = p.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
