"""Dev tool: render every base kana faint with a coordinate grid, so recipe
coordinates can be authored by eye. Reachable via `python -m kana_svg ref`."""
from __future__ import annotations

from .glyphs import GlyphBank, CANVAS
from .recipes import _kana_table
from .dsl import INK


def _ref_cell(g, romaji: str) -> str:
    parts = ['<rect x="0" y="0" width="100" height="100" fill="#fbf7f0"/>']
    for v in (20, 40, 60, 80):
        parts.append(f'<line x1="{v}" y1="0" x2="{v}" y2="100" stroke="#000" stroke-opacity="0.1" stroke-width="0.5"/>')
        parts.append(f'<line x1="0" y1="{v}" x2="100" y2="{v}" stroke="#000" stroke-opacity="0.1" stroke-width="0.5"/>')
    parts.append('<line x1="50" y1="0" x2="50" y2="100" stroke="#e4572e" stroke-opacity="0.4" stroke-width="0.6"/>')
    parts.append('<line x1="0" y1="50" x2="100" y2="50" stroke="#e4572e" stroke-opacity="0.4" stroke-width="0.6"/>')
    parts.append(f'<g transform="{g.transform}"><path d="{g.d}" fill="{INK}" fill-opacity="0.5"/></g>')
    parts.append(f'<text x="4" y="12" font-size="9" font-weight="800" fill="#2d9cdb">{romaji}</text>')
    return "".join(parts)


def sheet(script: str) -> str:
    items = [k for k in _kana_table() if k["script"] == script and k["kind"] == "gojuon"]
    bank = GlyphBank()
    cols, gap = 8, 6
    cw = CANVAS + gap
    rows = (len(items) + cols - 1) // cols
    W, H = cols * cw + gap, rows * cw + gap
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.0f} {H:.0f}" width="{W:.0f}" height="{H:.0f}"><rect width="{W}" height="{H}" fill="#ddd"/>']
    for i, k in enumerate(items):
        r, c = divmod(i, cols)
        x, y = gap + c * cw, gap + r * cw
        parts.append(f'<g transform="translate({x} {y})">{_ref_cell(bank.get(k["char"]), k["romaji"])}</g>')
    parts.append("</svg>")
    return "".join(parts)
