"""A tiny vector-drawing DSL for building simple, cute line illustrations.

Everything is authored in the same 0..100 y-down square the glyph lives in
(`glyphs.CANVAS`), so a decoration placed at (50, 40) always lands in the same
spot on top of the faint kana. The `Art` builder collects SVG fragments; a
transform stack (`with a.at(...)`) lets motifs be drawn once and stamped anywhere.

Design language, kept deliberately narrow so 92 drawings look like one set:
  * rounded caps/joins, one ink weight for outlines, a small flat palette;
  * `eye()` / `smile()` / `blush()` turn any glyph into a friendly creature;
  * fills are solid and literal (a red apple stays red) and every sheet rides on
    its own soft paper card, so the SVG renders identically in any theme/renderer.
"""

from __future__ import annotations

import math
from contextlib import contextmanager

# --- flat palette ----------------------------------------------------------
INK = "#22201d"       # near-black outline
RED = "#e4572e"
ORANGE = "#f3a712"
YELLOW = "#f4d35e"
GREEN = "#3fa34d"
TEAL = "#22a6a6"
BLUE = "#2d9cdb"
INDIGO = "#5b5fc7"
PINK = "#e86a92"
PURPLE = "#9b5de5"
BROWN = "#8d6346"
WHITE = "#ffffff"
SKIN = "#ffd9b3"
PAPER = "#fbf7f0"      # card background
GUIDE = "#2220201f"    # faint glyph fill (~12% ink)

OUTLINE_W = 2.4        # default illustration line weight


def _n(v: float) -> str:
    """Compact number formatting for SVG attributes."""
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return s if s not in ("-0", "") else "0"


def _pts(points) -> str:
    return " ".join(f"{_n(x)},{_n(y)}" for x, y in points)


class Art:
    """Accumulates SVG fragments in the 0..100 coordinate box."""

    def __init__(self, ink: str = INK, width: float = OUTLINE_W) -> None:
        self._frags: list[str] = []
        self._tx: list[str] = []  # transform stack
        self.ink = ink
        self.width = width

    # -- transform stack ----------------------------------------------------
    @contextmanager
    def at(self, x: float = 0, y: float = 0, rotate: float = 0, scale: float = 1,
           sx: float | None = None, sy: float | None = None):
        """Push a translate/rotate/scale frame. Rotation is in degrees about
        the local origin *after* translation."""
        sx = scale if sx is None else sx
        sy = scale if sy is None else sy
        parts = []
        if x or y:
            parts.append(f"translate({_n(x)} {_n(y)})")
        if rotate:
            parts.append(f"rotate({_n(rotate)})")
        if sx != 1 or sy != 1:
            parts.append(f"scale({_n(sx)} {_n(sy)})")
        self._frags.append(f'<g transform="{" ".join(parts)}">')
        try:
            yield self
        finally:
            self._frags.append("</g>")

    # -- raw ----------------------------------------------------------------
    def raw(self, svg: str) -> None:
        self._frags.append(svg)

    def glyph(self, g, fill=None, stroke=None, w=None, opacity=1.0):
        """Paint the real kana outline itself - so a recipe can turn *the
        character* into the object's body (a green ぬ-snail, a brown き-key…).
        Uses the glyph's own transform, guaranteeing the letter stays accurate."""
        style = ""
        if fill is not None:
            style += f' fill="{fill}"'
        else:
            style += ' fill="none"'
        if stroke is not None:
            style += f' stroke="{stroke}" stroke-width="{_n((w or self.width))}" stroke-linejoin="round"'
        op = f' opacity="{_n(opacity)}"' if opacity != 1.0 else ""
        self._frags.append(
            f'<g transform="{g.transform}"{op}><path d="{g.d}"{style}/></g>'
        )

    def _stroke(self, color: str | None, w: float | None, dash: str | None,
                cap: str, join: str) -> str:
        color = self.ink if color is None else color
        w = self.width if w is None else w
        s = f'stroke="{color}" stroke-width="{_n(w)}" stroke-linecap="{cap}" stroke-linejoin="{join}"'
        if dash:
            s += f' stroke-dasharray="{dash}"'
        return s

    # -- primitives ---------------------------------------------------------
    def line(self, x1, y1, x2, y2, color=None, w=None, dash=None, cap="round"):
        self._frags.append(
            f'<path d="M{_n(x1)} {_n(y1)}L{_n(x2)} {_n(y2)}" fill="none" '
            f'{self._stroke(color, w, dash, cap, "round")}/>'
        )

    def poly(self, points, color=None, w=None, close=False, fill="none",
             dash=None, cap="round", join="round"):
        d = "M" + "L".join(f"{_n(x)} {_n(y)}" for x, y in points)
        if close:
            d += "Z"
        self._frags.append(
            f'<path d="{d}" fill="{fill}" {self._stroke(color, w, dash, cap, join)}/>'
        )

    def path(self, d, color=None, w=None, fill="none", dash=None, cap="round", join="round"):
        self._frags.append(
            f'<path d="{d}" fill="{fill}" {self._stroke(color, w, dash, cap, join)}/>'
        )

    def curve(self, points, color=None, w=None, close=False, fill="none", tension=0.5):
        """A smooth Catmull-Rom curve through the points → soft, hand-drawn feel."""
        self._frags.append(
            f'<path d="{smooth_path(points, close, tension)}" fill="{fill}" '
            f'{self._stroke(color, w, None, "round", "round")}/>'
        )

    def blob(self, points, color=None, w=None, fill=None, tension=0.6):
        """A closed smooth blob (fillable)."""
        fill = "none" if fill is None else fill
        self._frags.append(
            f'<path d="{smooth_path(points, True, tension)}" fill="{fill}" '
            f'{self._stroke(color, w, None, "round", "round")}/>'
        )

    def circle(self, cx, cy, r, fill="none", color=None, w=None):
        self._frags.append(
            f'<circle cx="{_n(cx)}" cy="{_n(cy)}" r="{_n(r)}" fill="{fill}" '
            f'{self._stroke(color, w, None, "round", "round")}/>'
        )

    def ellipse(self, cx, cy, rx, ry, fill="none", color=None, w=None, rotate=0):
        tr = f' transform="rotate({_n(rotate)} {_n(cx)} {_n(cy)})"' if rotate else ""
        self._frags.append(
            f'<ellipse cx="{_n(cx)}" cy="{_n(cy)}" rx="{_n(rx)}" ry="{_n(ry)}" fill="{fill}" '
            f'{self._stroke(color, w, None, "round", "round")}{tr}/>'
        )

    def dot(self, cx, cy, r, color=None):
        color = self.ink if color is None else color
        self._frags.append(f'<circle cx="{_n(cx)}" cy="{_n(cy)}" r="{_n(r)}" fill="{color}"/>')

    def rect(self, x, y, w, h, r=0, fill="none", color=None, sw=None):
        rr = f' rx="{_n(r)}"' if r else ""
        self._frags.append(
            f'<rect x="{_n(x)}" y="{_n(y)}" width="{_n(w)}" height="{_n(h)}"{rr} '
            f'fill="{fill}" {self._stroke(color, sw, None, "round", "round")}/>'
        )

    def arc(self, cx, cy, r, a0, a1, color=None, w=None, fill="none"):
        """Arc from angle a0 to a1 (degrees, 0=east, CCW positive in maths but
        SVG y is down so it reads clockwise)."""
        x0 = cx + r * math.cos(math.radians(a0))
        y0 = cy + r * math.sin(math.radians(a0))
        x1 = cx + r * math.cos(math.radians(a1))
        y1 = cy + r * math.sin(math.radians(a1))
        large = 1 if abs(a1 - a0) > 180 else 0
        sweep = 1 if a1 > a0 else 0
        self._frags.append(
            f'<path d="M{_n(x0)} {_n(y0)}A{_n(r)} {_n(r)} 0 {large} {sweep} {_n(x1)} {_n(y1)}" '
            f'fill="{fill}" {self._stroke(color, w, None, "round", "round")}/>'
        )

    def text(self, x, y, s, size=8, color=None, anchor="middle", weight=700, italic=False):
        color = self.ink if color is None else color
        st = ' font-style="italic"' if italic else ""
        self._frags.append(
            f'<text x="{_n(x)}" y="{_n(y)}" font-size="{_n(size)}" fill="{color}" '
            f'text-anchor="{anchor}" font-weight="{weight}" '
            f'font-family="Inter, Segoe UI, system-ui, sans-serif"{st}>{_esc(s)}</text>'
        )

    # -- composite creature parts ------------------------------------------
    def eye(self, cx, cy, r=3.2, look=(0.0, 0.0)):
        """A friendly eye: white sclera, ink pupil (optionally glancing), catchlight."""
        self.circle(cx, cy, r, fill=WHITE, color=INK, w=1.4)
        px, py = cx + look[0] * r * 0.4, cy + look[1] * r * 0.4
        self.dot(px, py, r * 0.55, color=INK)
        self.dot(px - r * 0.2, py - r * 0.2, r * 0.18, color=WHITE)

    def eyes(self, cx, cy, gap=9.0, r=3.2, look=(0.0, 0.0)):
        self.eye(cx - gap / 2, cy, r, look)
        self.eye(cx + gap / 2, cy, r, look)

    def smile(self, cx, cy, w=10.0, depth=4.0, color=None, sw=None):
        self.path(
            f"M{_n(cx - w/2)} {_n(cy)}Q{_n(cx)} {_n(cy + depth)} {_n(cx + w/2)} {_n(cy)}",
            color=color, w=sw,
        )

    def blush(self, cx, cy, rx=3.2, ry=2.0, color=PINK):
        self._frags.append(
            f'<ellipse cx="{_n(cx)}" cy="{_n(cy)}" rx="{_n(rx)}" ry="{_n(ry)}" '
            f'fill="{color}" opacity="0.5"/>'
        )

    def cheeks(self, cx, cy, gap=22.0, **kw):
        self.blush(cx - gap / 2, cy, **kw)
        self.blush(cx + gap / 2, cy, **kw)

    def sparkle(self, cx, cy, r=2.0, color=YELLOW):
        for a in (0, 45, 90, 135):
            dx = r * math.cos(math.radians(a))
            dy = r * math.sin(math.radians(a))
            self.line(cx - dx, cy - dy, cx + dx, cy + dy, color=color, w=1.2)

    # -- output -------------------------------------------------------------
    def svg(self) -> str:
        return "".join(self._frags)


def smooth_path(points, close: bool, tension: float = 0.5) -> str:
    """Catmull-Rom → cubic Bézier through `points`. Gives organic, hand-drawn
    curves from a handful of control points."""
    pts = list(points)
    if len(pts) < 3:
        d = "M" + "L".join(f"{_n(x)} {_n(y)}" for x, y in pts)
        return d + ("Z" if close else "")
    if close:
        pts = [pts[-1]] + pts + [pts[0], pts[1]]
    else:
        pts = [pts[0]] + pts + [pts[-1]]
    d = f"M{_n(pts[1][0])} {_n(pts[1][1])}"
    k = tension / 0.5 * (1 / 6)
    end = len(pts) - 2
    for i in range(1, end):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        c1x = p1[0] + (p2[0] - p0[0]) * k
        c1y = p1[1] + (p2[1] - p0[1]) * k
        c2x = p2[0] - (p3[0] - p1[0]) * k
        c2y = p2[1] - (p3[1] - p1[1]) * k
        d += f"C{_n(c1x)} {_n(c1y)} {_n(c2x)} {_n(c2y)} {_n(p2[0])} {_n(p2[1])}"
    if close:
        d += "Z"
    return d


def _esc(s: str) -> str:
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))
