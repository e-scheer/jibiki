"""Assemble a full kana card: paper → faint guide glyph → illustration → caption.

`cell()` returns a self-contained `<g>` (a 100×118 tile) so it can be dropped into
a contact-sheet grid; `standalone()` wraps one cell in an `<svg>` document. In
*overlay* mode the guide glyph is drawn faintly and the illustration sits on top
of it - the learner sees the drawing trace the stroke. `guide=False` (fine for
kanji, per the brief) hides the glyph and just keeps the picture + caption.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable

from .dsl import Art, INK, PAPER
from .glyphs import Glyph, GlyphBank, CANVAS

CAPTION_H = 20.0
TILE_H = CANVAS + CAPTION_H  # 120
GUIDE_OPACITY = 0.13  # faintness of the reference glyph behind the drawing


@dataclass
class Recipe:
    char: str
    romaji: str
    script: str  # "hiragana" | "katakana"
    draw: Callable[[Art, Glyph], None]
    picture: dict = field(default_factory=dict)  # {"en": "...", "fr": "..."}
    hook: dict = field(default_factory=dict)      # {"en": "...", "fr": "..."}

    def label(self, lang: str) -> str:
        return self.picture.get(lang) or self.picture.get("en") or ""


def cell(rec: Recipe, bank: GlyphBank, *, lang: str = "fr", guide: bool = True,
         caption: bool = True, card: bool = True, guide_class: str = "") -> str:
    """One tile as an SVG `<g>` fragment. With a caption the tile is 100×120;
    without one it is a 100×100 square. `guide_class` tags the faint glyph layer
    so a host page can toggle the overlay on/off in CSS."""
    g = bank.get(rec.char)
    h = TILE_H if caption else CANVAS
    parts: list[str] = ['<g>']

    if card:
        parts.append(
            f'<rect x="0.6" y="0.6" width="{CANVAS-1.2:.1f}" height="{h-1.2:.1f}" '
            f'rx="9" fill="{PAPER}" stroke="#000000" stroke-opacity="0.08" stroke-width="0.8"/>'
        )

    # faint guide glyph (the thing being overlaid)
    if guide:
        cls = f' class="{guide_class}"' if guide_class else ""
        parts.append(
            f'<g transform="{g.transform}"{cls}><path d="{g.d}" fill="{INK}" '
            f'fill-opacity="{GUIDE_OPACITY}"/></g>'
        )

    # the illustration
    a = Art()
    rec.draw(a, g)
    parts.append(a.svg())

    # caption band
    if caption:
        parts.append(_caption(rec, lang))

    parts.append("</g>")
    return "".join(parts)


def _caption(rec: Recipe, lang: str) -> str:
    y0 = CANVAS
    label = _short(rec.label(lang))
    romaji = rec.romaji
    out = [
        f'<line x1="10" y1="{y0+0.5:.1f}" x2="90" y2="{y0+0.5:.1f}" stroke="#000000" stroke-opacity="0.06" stroke-width="0.8"/>',
        f'<text x="50" y="{y0+9.5:.1f}" font-size="9.5" font-weight="800" fill="{INK}" '
        f'text-anchor="middle" font-family="Inter, system-ui, sans-serif">{_esc(romaji)}</text>',
    ]
    if label:
        out.append(
            f'<text x="50" y="{y0+17:.1f}" font-size="5.4" font-weight="600" fill="#7a736c" '
            f'text-anchor="middle" font-family="Inter, system-ui, sans-serif">{_esc(label)}</text>'
        )
    return "".join(out)


def _short(s: str) -> str:
    """Trim a research picture phrase to a compact caption: drop parentheticals
    and '/'-alternatives, cap the length."""
    s = s.split("(")[0].split(" / ")[0].split("/")[0].strip().rstrip(" ,;")
    return s if len(s) <= 26 else s[:25].rstrip() + "…"


def standalone(rec: Recipe, bank: GlyphBank, **kw) -> str:
    inner = cell(rec, bank, **kw)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {CANVAS:.0f} {TILE_H:.0f}" '
        f'width="{CANVAS:.0f}" height="{TILE_H:.0f}" role="img" '
        f'aria-label="{_esc(rec.romaji)} - {_esc(rec.label(kw.get("lang", "fr")))}">'
        f'{inner}</svg>'
    )


def contact_sheet(recs: list[Recipe], bank: GlyphBank, *, cols: int = 10,
                  lang: str = "fr", guide: bool = True, gap: float = 6.0) -> str:
    """A grid of every tile in one SVG document (great for a single-PNG QA render)."""
    cw, ch = CANVAS + gap, TILE_H + gap
    rows = (len(recs) + cols - 1) // cols
    W, H = cols * cw + gap, rows * ch + gap
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.0f} {H:.0f}" '
        f'width="{W:.0f}" height="{H:.0f}">',
        f'<rect width="{W:.0f}" height="{H:.0f}" fill="#e9e4db"/>',
    ]
    for i, rec in enumerate(recs):
        r, c = divmod(i, cols)
        x, y = gap + c * cw, gap + r * ch
        parts.append(f'<g transform="translate({x:.1f} {y:.1f})">{cell(rec, bank, lang=lang, guide=guide)}</g>')
    parts.append("</svg>")
    return "".join(parts)


def _esc(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
