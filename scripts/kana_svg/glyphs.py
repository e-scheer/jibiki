"""Glyph geometry extraction.

The whole point of the *overlay* style is that the little drawing sits exactly on
top of the real kana stroke — so we need the real outline of each character, not a
`<text>` element that depends on the viewer having a Japanese font installed.

This module pulls the outline `d` path of any character out of a CJK font
(Noto Sans CJK JP by default) with fontTools, normalises it into a tidy square
coordinate box, and caches the result to JSON so generation is reproducible and
needs the font only once.

Coordinate convention of the cached path (and of everything the rest of the
toolkit draws): a **0..100 square, y pointing down** (SVG-native). The glyph is
scaled to fill a centred inner box (see `INK_BOX`) preserving aspect ratio, so a
decoration authored at, say, (50, 40) lands in a predictable place on every kana.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, asdict
from pathlib import Path

# fontTools is imported lazily (only `build_cache` needs it): generation runs
# entirely off the committed glyph_paths.json with zero third-party deps.

# --- output coordinate box -------------------------------------------------
# Everything the toolkit draws lives in this square. The glyph ink is fit into a
# centred sub-box so there is margin for decorations that spill past the stroke
# (ears, antennae, a hat…), and so captions have room underneath at y>100.
CANVAS = 100.0
INK_BOX = (18.0, 12.0, 82.0, 80.0)  # (x0, y0, x1, y1) target box for glyph ink

_CACHE = Path(__file__).with_name("glyph_paths.json")

# Fonts to try, in order. First one present on the system wins.
_FONT_CANDIDATES = [
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc",
    "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
]


@dataclass
class Glyph:
    """A character's outline plus the transform that maps it into the 0..100 box.

    We keep the path in raw font units and carry an SVG `transform` rather than
    rewriting every coordinate — robust against every curve command the pen emits,
    and the render layer just wraps the path in `<g transform=...>`.
    """

    char: str
    d: str          # SVG path data in font units (y up), fill-rule nonzero
    transform: str  # SVG transform mapping font units -> the 0..100 y-down box
    box: list        # [x0, y0, x1, y1] actual ink bounds inside the canvas
    cx: float        # ink centre x
    cy: float        # ink centre y


def _open_font(path: str) -> "TTFont":
    """Open a single JP face, whether the file is a .ttc collection or a .ttf."""
    from fontTools.ttLib import TTFont, TTCollection
    if path.lower().endswith(".ttc"):
        coll = TTCollection(path)
        for f in coll.fonts:
            name = f["name"].getDebugName(1) or ""
            if "JP" in name or "Japan" in name:
                return f
        return coll.fonts[0]
    return TTFont(path)


def _find_font() -> str:
    for c in _FONT_CANDIDATES:
        if Path(c).exists():
            return c
    raise FileNotFoundError(
        "No CJK font found. Install fonts-noto-cjk or point _FONT_CANDIDATES at a JP font."
    )


def _extract(font: "TTFont", char: str) -> Glyph:
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.pens.boundsPen import BoundsPen
    cmap = font.getBestCmap()
    cp = ord(char)
    if cp not in cmap:
        raise KeyError(f"{char!r} (U+{cp:04X}) not in font cmap")
    glyph_set = font.getGlyphSet()
    g = glyph_set[cmap[cp]]

    # Ink bounds in font units (y up).
    bp = BoundsPen(glyph_set)
    g.draw(bp)
    if bp.bounds is None:  # whitespace-only glyph — shouldn't happen for kana
        raise ValueError(f"{char!r} has no outline")
    xmin, ymin, xmax, ymax = bp.bounds

    # Raw path in font units (y up, origin at baseline).
    pen = SVGPathPen(glyph_set)
    g.draw(pen)
    raw = pen.getCommands()

    # Fit the ink box into INK_BOX preserving aspect ratio, flipping y.
    bx0, by0, bx1, by1 = INK_BOX
    gw, gh = (xmax - xmin) or 1.0, (ymax - ymin) or 1.0
    scale = min((bx1 - bx0) / gw, (by1 - by0) / gh)
    # Centre inside the target box.
    tx = bx0 + ((bx1 - bx0) - gw * scale) / 2
    ty = by0 + ((by1 - by0) - gh * scale) / 2

    # svg = translate(tx - xmin*s, ty + ymax*s) . scale(s, -s) . (x, y)
    transform = (
        f"translate({tx - xmin * scale:.3f} {ty + ymax * scale:.3f}) "
        f"scale({scale:.5f} {-scale:.5f})"
    )
    ix0, iy0 = tx, ty
    ix1, iy1 = tx + gw * scale, ty + gh * scale
    return Glyph(
        char=char,
        d=raw,
        transform=transform,
        box=[round(ix0, 2), round(iy0, 2), round(ix1, 2), round(iy1, 2)],
        cx=round((ix0 + ix1) / 2, 2),
        cy=round((iy0 + iy1) / 2, 2),
    )


class GlyphBank:
    """Lazy, cached access to glyph outlines for a set of characters."""

    def __init__(self) -> None:
        self._glyphs: dict[str, Glyph] = {}
        if _CACHE.exists():
            data = json.loads(_CACHE.read_text(encoding="utf-8"))
            self._glyphs = {k: Glyph(**v) for k, v in data.items()}
        self._font: TTFont | None = None

    def get(self, char: str) -> Glyph:
        if char not in self._glyphs:
            if self._font is None:
                self._font = _open_font(_find_font())
            self._glyphs[char] = _extract(self._font, char)
        return self._glyphs[char]

    def save(self) -> None:
        data = {k: asdict(v) for k, v in sorted(self._glyphs.items())}
        _CACHE.write_text(json.dumps(data, ensure_ascii=False, indent=0), encoding="utf-8")


def build_cache(chars: list[str]) -> None:
    bank = GlyphBank()
    for c in chars:
        bank.get(c)
    bank.save()
    print(f"cached {len(chars)} glyphs -> {_CACHE}")


if __name__ == "__main__":
    # Smoke test: dump a couple of glyphs and their boxes.
    bank = GlyphBank()
    for c in ["き", "ぬ", "ア", "ン", "は"]:
        g = bank.get(c)
        print(c, "box", g.box, "center", (g.cx, g.cy), "d[:60]", g.d[:60])
    bank.save()
