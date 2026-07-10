from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "design-explorations" / "generated" / "kana_batch_manifest.json"
OUT_ROOT = ROOT / "design-explorations" / "generated" / "kana"
FONT_PATH = ROOT / "app" / "assets" / "fonts" / "NotoSansJP.ttf"

CANVAS = 1024
SHADOW = 22
GLYPH_STROKE = 14
FACE_STROKE = 10
PROP_STROKE = 10

INK = "#111018"
WHITE = "#f8f6f2"
YELLOW = "#ffe60a"
PINK = "#ff4aa2"
BLUE = "#2741ff"
LAVENDER = "#c6adff"
LIME = "#98ef28"
ORANGE = "#ffb21c"
BROWN = "#8f5a2a"
GRAY = "#9ca4b0"

PALETTE = [PINK, YELLOW, BLUE, LAVENDER, ORANGE, LIME]


def load_entries() -> list[dict]:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entries: list[dict] = []
    for group in data["groups"]:
        for item in group["items"]:
            entries.append(item)
    return entries


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_PATH), size=size)


def glyph_bbox(character: str, size: int) -> tuple[int, int, int, int]:
    probe = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(probe)
    return draw.textbbox((0, 0), character, font=font(size), stroke_width=GLYPH_STROKE)


def fit_font_size(character: str) -> tuple[int, tuple[int, int, int, int]]:
    size = 820
    while size > 200:
        box = glyph_bbox(character, size)
        width = box[2] - box[0]
        height = box[3] - box[1]
        if width <= 700 and height <= 760:
            return size, box
        size -= 20
    return size, glyph_bbox(character, size)


def anchor(box: tuple[int, int, int, int]) -> tuple[int, int]:
    x0, y0, x1, y1 = box
    width = x1 - x0
    height = y1 - y0
    left = (CANVAS - width) // 2 - x0
    top = (CANVAS - height) // 2 - y0
    return left, top


def draw_shadowed_text(draw: ImageDraw.ImageDraw, pos: tuple[int, int], character: str, glyph_font, fill: str) -> tuple[int, int, int, int]:
    x, y = pos
    shadow_pos = (x + SHADOW, y + SHADOW)
    draw.text(shadow_pos, character, font=glyph_font, fill=INK)
    draw.text(pos, character, font=glyph_font, fill=fill, stroke_width=GLYPH_STROKE, stroke_fill=INK)
    return draw.textbbox(pos, character, font=glyph_font, stroke_width=GLYPH_STROKE)


def ellipse(draw: ImageDraw.ImageDraw, box, fill, outline=INK, width=PROP_STROKE, shadow=True):
    x0, y0, x1, y1 = box
    if shadow:
        shadow_box = (x0 + SHADOW // 2, y0 + SHADOW // 2, x1 + SHADOW // 2, y1 + SHADOW // 2)
        draw.ellipse(shadow_box, fill=INK)
    draw.ellipse(box, fill=fill, outline=outline, width=width)


def polygon(draw: ImageDraw.ImageDraw, points, fill, outline=INK, width=PROP_STROKE, shadow=True):
    if shadow:
        shadow_points = [(x + SHADOW // 2, y + SHADOW // 2) for x, y in points]
        draw.polygon(shadow_points, fill=INK)
    draw.polygon(points, fill=fill, outline=outline, width=width)


def line(draw: ImageDraw.ImageDraw, points, fill=INK, width=PROP_STROKE):
    shadow_points = [(x + SHADOW // 2, y + SHADOW // 2) for x, y in points]
    draw.line(shadow_points, fill=INK, width=width)
    draw.line(points, fill=fill, width=width)


def arc(draw: ImageDraw.ImageDraw, box, start, end, fill=INK, width=PROP_STROKE):
    sx0, sy0, sx1, sy1 = [value + SHADOW // 2 for value in box]
    draw.arc((sx0, sy0, sx1, sy1), start=start, end=end, fill=INK, width=width)
    draw.arc(box, start=start, end=end, fill=fill, width=width)


def draw_face(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], fill: str) -> None:
    x0, y0, x1, y1 = box
    width = x1 - x0
    height = y1 - y0
    eye_x = x0 + int(width * 0.68)
    eye_y = y0 + int(height * 0.28)
    mouth_x = x0 + int(width * 0.54)
    mouth_y = y0 + int(height * 0.44)
    ellipse(draw, (eye_x - 24, eye_y - 34, eye_x + 24, eye_y + 34), WHITE, shadow=False)
    ellipse(draw, (eye_x - 8, eye_y - 16, eye_x + 8, eye_y + 16), INK, outline=INK, width=2, shadow=False)
    ellipse(draw, (eye_x - 58, eye_y + 50, eye_x - 8, eye_y + 84), YELLOW, outline=INK, width=6, shadow=False)
    arc(draw, (mouth_x - 42, mouth_y - 10, mouth_x + 42, mouth_y + 48), 15, 165, fill=INK, width=FACE_STROKE)
    if fill == YELLOW:
        ellipse(draw, (eye_x + 26, eye_y + 50, eye_x + 76, eye_y + 84), PINK, outline=INK, width=6, shadow=False)


def cue_type(story: str) -> str:
    text = story.lower()
    checks = [
        ("cheerleader", "pompom"),
        ("chien", "paw"),
        ("dog", "paw"),
        ("yak", "horns"),
        ("vache", "horns"),
        ("cow", "horns"),
        ("yoga", "lotus"),
        ("fish", "fish"),
        ("poisson", "fish"),
        ("bird", "feather"),
        ("oiseau", "feather"),
        ("coucou", "sound"),
        ("cuckoo", "sound"),
        ("key", "ring"),
        ("clé", "ring"),
        ("karaté", "motion"),
        ("karate", "motion"),
        ("ball", "ball"),
        ("balle", "ball"),
        ("tsunami", "wave"),
        ("vague", "wave"),
        ("mount fuji", "mountain"),
        ("fuji", "mountain"),
        ("montagne", "mountain"),
        ("mountain", "mountain"),
        ("sail", "sail"),
        ("voile", "sail"),
        ("lapin", "ears"),
        ("rabbit", "ears"),
        ("licorne", "horn"),
        ("unicorn", "horn"),
        ("queue d'un chat", "tail"),
        ("cat's tail", "tail"),
        ("nœud", "loop"),
        ("knot", "loop"),
        ("noodles", "swirl"),
        ("nouilles", "swirl"),
        ("route", "road"),
        ("road", "road"),
        ("sign", "sign"),
        ("interdit", "sign"),
        ("gong", "buzz"),
        ("guitar", "music"),
        ("guitare", "music"),
        ("geyser", "splash"),
        ("zombie", "stitches"),
        ("zèbre", "stripes"),
        ("zebra", "stripes"),
        ("panda", "panda"),
        ("jean", "jeans"),
        ("jeans", "jeans"),
        ("dj", "record"),
        ("platines", "record"),
        ("dé", "dice"),
        ("die", "dice"),
        ("door", "door"),
        ("dodo", "sleep"),
        ("ballon", "balloon"),
        ("balloon", "balloon"),
        ("mouton", "sheep"),
        ("sheep", "sheep"),
        ("bateau", "boat"),
        ("boat", "boat"),
        ("pop-corn", "popcorn"),
        ("popcorn", "popcorn"),
        ("pie", "bird_note"),
        ("chick", "bird_note"),
        ("fumée", "smoke"),
        ("smoke", "smoke"),
        ("caillou", "pebble"),
        ("pebble", "pebble"),
        ("pot", "pot"),
        ("eye", "eye"),
        ("œil", "eye"),
        ("mama", "heart"),
        ("maman", "heart"),
        ("21", "note"),
        ("note", "note"),
        ("hameçon", "hook"),
        ("hook", "hook"),
        ("cerf-volant", "kite"),
        ("kite", "kite"),
        ("hammer", "nail"),
        ("marteau", "nail"),
        ("face", "spark"),
        ("profile", "spark"),
        ("reeds", "reeds"),
        ("roseaux", "reeds"),
        ("capital 'a'", "antenna"),
        ("grand « a »", "antenna"),
        ("signature", "signature"),
        ("n final", "signature"),
        ("swan", "water"),
        ("cygne", "water"),
        ("throwing", "throw"),
        ("lance", "throw"),
        ("mouth", "tongue"),
        ("langue", "tongue"),
        ("zigzag", "zigzag"),
        ("laugh", "laugh"),
        ("rire", "laugh"),
        ("smile", "smile"),
        ("sourire", "smile"),
        ("genou", "knee"),
        ("knee", "knee"),
        ("runner", "runner"),
        ("coureur", "runner"),
        ("toe", "thorn"),
        ("orteil", "thorn"),
        ("table", "table"),
    ]
    for needle, cue in checks:
        if needle in text:
            return cue
    return "spark"


def draw_prop(draw: ImageDraw.ImageDraw, cue: str, box: tuple[int, int, int, int], accent: str, lang: str) -> None:
    x0, y0, x1, y1 = box
    width = x1 - x0
    height = y1 - y0
    if cue == "antenna":
        line(draw, [(x1 - 10, y0 - 10), (x1 + 20, y0 - 70)], fill=accent)
        line(draw, [(x1 + 28, y0), (x1 + 60, y0 - 60)], fill=BLUE)
    elif cue == "reeds":
        ellipse(draw, (x1 - 10, y0 + 20, x1 + 30, y0 + 120), accent)
        ellipse(draw, (x1 + 40, y0, x1 + 80, y0 + 100), BLUE)
    elif cue in {"fish", "wave", "water"}:
        polygon(draw, [(x1 + 30, y0 + 90), (x1 + 90, y0 + 40), (x1 + 90, y0 + 140)], BLUE)
        line(draw, [(x1 + 120, y1 - 50), (x1 + 150, y1 - 80), (x1 + 180, y1 - 50)], fill=accent)
    elif cue == "feather":
        polygon(draw, [(x1 + 40, y0 + 60), (x1 + 90, y0 + 20), (x1 + 120, y0 + 130), (x1 + 70, y0 + 150)], BLUE)
        line(draw, [(x1 + 70, y0 + 130), (x1 + 96, y0 + 50)], fill=WHITE, width=6)
    elif cue == "ball":
        ellipse(draw, (x1 + 26, y0 + 58, x1 + 112, y0 + 144), WHITE)
    elif cue == "ring":
        ellipse(draw, (x1 + 10, y1 - 180, x1 + 90, y1 - 100), WHITE)
    elif cue == "kite":
        polygon(draw, [(x1 + 50, y0 + 10), (x1 + 92, y0 + 58), (x1 + 50, y0 + 106), (x1 + 8, y0 + 58)], accent)
        line(draw, [(x1 + 50, y0 + 106), (x1 + 72, y0 + 170)], fill=BLUE, width=6)
    elif cue == "hook":
        arc(draw, (x1 + 25, y0 + 40, x1 + 115, y0 + 150), 220, 30, fill=accent)
    elif cue == "swirl":
        arc(draw, (x1 + 10, y0 + 20, x1 + 130, y0 + 140), 0, 320, fill=accent)
        arc(draw, (x1 + 38, y0 + 48, x1 + 102, y0 + 112), 0, 320, fill=BLUE, width=8)
    elif cue == "tongue":
        ellipse(draw, (x1 + 24, y0 + 90, x1 + 84, y0 + 126), PINK)
    elif cue == "zigzag":
        line(draw, [(x1 + 10, y0 + 30), (x1 + 50, y0 + 70), (x1 + 90, y0 + 30), (x1 + 130, y0 + 70)], fill=accent)
    elif cue == "nail":
        line(draw, [(x1 + 36, y0 + 30), (x1 + 110, y0 + 30)], fill=GRAY)
        line(draw, [(x1 + 73, y0 + 30), (x1 + 73, y0 + 96)], fill=GRAY)
    elif cue == "paw":
        ellipse(draw, (x0 - 150, y1 - 90, x0 - 70, y1 - 10), LIME)
        for dx, dy in ((-132, -108), (-104, -126), (-76, -108), (-104, -76)):
            ellipse(draw, (x0 + dx, y1 + dy, x0 + dx + 26, y1 + dy + 26), INK, outline=INK, width=4, shadow=False)
    elif cue == "mountain":
        polygon(draw, [(x1 + 10, y1 - 30), (x1 + 70, y1 - 150), (x1 + 130, y1 - 30)], BLUE)
        polygon(draw, [(x1 + 45, y1 - 90), (x1 + 70, y1 - 150), (x1 + 95, y1 - 90)], WHITE, width=6)
    elif cue == "sail":
        line(draw, [(x1 + 52, y0 + 20), (x1 + 52, y0 + 160)], fill=BROWN)
        polygon(draw, [(x1 + 52, y0 + 36), (x1 + 120, y0 + 78), (x1 + 52, y0 + 120)], WHITE)
    elif cue == "heart":
        polygon(draw, [(x1 + 56, y0 + 44), (x1 + 96, y0 + 6), (x1 + 132, y0 + 44), (x1 + 96, y0 + 104)], PINK)
    elif cue == "note":
        line(draw, [(x1 + 68, y0 + 14), (x1 + 68, y0 + 110)], fill=INK, width=12)
        ellipse(draw, (x1 + 34, y0 + 84, x1 + 82, y0 + 130), accent)
        polygon(draw, [(x1 + 68, y0 + 14), (x1 + 122, y0 + 32), (x1 + 68, y0 + 48)], BLUE)
    elif cue == "horns":
        polygon(draw, [(x1 + 16, y0 + 10), (x1 + 46, y0 - 58), (x1 + 84, y0 + 10)], YELLOW)
        polygon(draw, [(x1 + 70, y0 + 10), (x1 + 100, y0 - 58), (x1 + 138, y0 + 10)], WHITE)
    elif cue == "lotus":
        ellipse(draw, (x1 + 10, y1 - 90, x1 + 120, y1 - 20), BLUE)
        ellipse(draw, (x1 + 70, y1 - 90, x1 + 180, y1 - 20), WHITE)
    elif cue == "ears":
        polygon(draw, [(x1 + 18, y0 + 16), (x1 + 48, y0 - 56), (x1 + 78, y0 + 16)], PINK)
        polygon(draw, [(x1 + 64, y0 + 16), (x1 + 94, y0 - 56), (x1 + 124, y0 + 16)], BLUE)
    elif cue == "horn":
        polygon(draw, [(x1 + 30, y0 + 20), (x1 + 100, y0 + 40), (x1 + 54, y0 + 120)], YELLOW)
    elif cue == "road":
        line(draw, [(x1 + 20, y1 - 80), (x1 + 130, y1 - 80)], fill=GRAY)
        for offset in (36, 74, 112):
            line(draw, [(x1 + offset, y1 - 80), (x1 + offset + 18, y1 - 80)], fill=YELLOW, width=6)
    elif cue == "runner":
        line(draw, [(x1 + 26, y0 + 34), (x1 + 90, y0 + 10), (x1 + 130, y0 + 58)], fill=BLUE)
    elif cue == "tail":
        arc(draw, (x1 + 10, y1 - 120, x1 + 120, y1 - 10), 220, 40, fill=PINK)
    elif cue == "sign":
        ellipse(draw, (x1 + 30, y0 + 40, x1 + 120, y0 + 130), WHITE)
        line(draw, [(x1 + 50, y0 + 110), (x1 + 100, y0 + 60)], fill=PINK, width=8)
    elif cue == "buzz":
        line(draw, [(x1 + 28, y0 + 24), (x1 + 72, y0 - 26)], fill=BLUE, width=8)
        line(draw, [(x1 + 80, y0 + 34), (x1 + 124, y0 - 16)], fill=YELLOW, width=8)
    elif cue == "music":
        line(draw, [(x1 + 56, y0 + 18), (x1 + 56, y0 + 112)], fill=INK, width=10)
        ellipse(draw, (x1 + 28, y0 + 84, x1 + 76, y0 + 128), BLUE)
        polygon(draw, [(x1 + 56, y0 + 18), (x1 + 122, y0 + 42), (x1 + 56, y0 + 58)], PINK)
    elif cue == "splash":
        for dx, dy, color in ((18, 92, BLUE), (68, 40, YELLOW), (118, 94, WHITE)):
            ellipse(draw, (x1 + dx, y0 + dy, x1 + dx + 40, y0 + dy + 68), color)
    elif cue == "stripes":
        for offset in (20, 54, 88):
            line(draw, [(x1 + offset, y0 + 20), (x1 + offset, y0 + 126)], fill=INK, width=8)
    elif cue == "stitches":
        for offset in (18, 60, 102):
            line(draw, [(x1 + offset, y0 + 20), (x1 + offset + 26, y0 + 46)], fill=WHITE, width=8)
            line(draw, [(x1 + offset + 26, y0 + 20), (x1 + offset, y0 + 46)], fill=WHITE, width=8)
    elif cue == "panda":
        ellipse(draw, (x1 + 28, y0 + 18, x1 + 120, y0 + 110), WHITE)
        ellipse(draw, (x1 + 20, y0 + 8, x1 + 54, y0 + 42), INK)
        ellipse(draw, (x1 + 94, y0 + 8, x1 + 128, y0 + 42), INK)
    elif cue == "jeans":
        polygon(draw, [(x1 + 32, y0 + 18), (x1 + 120, y0 + 18), (x1 + 98, y0 + 140), (x1 + 54, y0 + 140)], BLUE)
    elif cue == "record":
        ellipse(draw, (x1 + 20, y0 + 18, x1 + 128, y0 + 126), INK, outline=INK, width=8)
        ellipse(draw, (x1 + 58, y0 + 56, x1 + 90, y0 + 88), WHITE, outline=WHITE, width=2, shadow=False)
    elif cue == "dice":
        polygon(draw, [(x1 + 30, y0 + 20), (x1 + 108, y0 + 20), (x1 + 108, y0 + 98), (x1 + 30, y0 + 98)], WHITE)
        for dx, dy in ((46, 36), (82, 36), (64, 60), (46, 84), (82, 84)):
            ellipse(draw, (x1 + dx, y0 + dy, x1 + dx + 10, y0 + dy + 10), INK, outline=INK, width=2, shadow=False)
    elif cue == "sleep":
        line(draw, [(x1 + 24, y0 + 30), (x1 + 84, y0 + 30), (x1 + 24, y0 + 90), (x1 + 84, y0 + 90)], fill=BLUE)
    elif cue == "balloon":
        ellipse(draw, (x1 + 24, y0 + 18, x1 + 112, y0 + 130), PINK)
        line(draw, [(x1 + 68, y0 + 130), (x1 + 82, y0 + 168)], fill=GRAY, width=6)
    elif cue == "sheep":
        ellipse(draw, (x1 + 18, y0 + 26, x1 + 122, y0 + 126), WHITE)
        ellipse(draw, (x1 + 100, y0 + 52, x1 + 150, y0 + 98), BROWN)
    elif cue == "boat":
        polygon(draw, [(x1 + 18, y0 + 102), (x1 + 136, y0 + 102), (x1 + 104, y0 + 142), (x1 + 42, y0 + 142)], BLUE)
    elif cue == "popcorn":
        for dx, dy, color in ((20, 84, WHITE), (54, 44, YELLOW), (92, 84, WHITE), (126, 42, BLUE)):
            ellipse(draw, (x1 + dx, y0 + dy, x1 + dx + 40, y0 + dy + 40), color)
    elif cue == "bird_note":
        polygon(draw, [(x1 + 18, y0 + 60), (x1 + 94, y0 + 18), (x1 + 96, y0 + 102)], YELLOW)
        line(draw, [(x1 + 110, y0 + 20), (x1 + 150, y0 + 6)], fill=BLUE, width=8)
    elif cue == "smoke":
        arc(draw, (x1 + 14, y0 + 48, x1 + 94, y0 + 128), 0, 300, fill=GRAY)
        arc(draw, (x1 + 84, y0 + 12, x1 + 160, y0 + 88), 30, 310, fill=WHITE)
    elif cue == "pebble":
        ellipse(draw, (x1 + 30, y0 + 80, x1 + 106, y0 + 130), GRAY)
    elif cue == "pot":
        polygon(draw, [(x1 + 20, y0 + 60), (x1 + 130, y0 + 60), (x1 + 118, y0 + 136), (x1 + 32, y0 + 136)], ORANGE)
    elif cue == "eye":
        ellipse(draw, (x1 + 16, y0 + 44, x1 + 140, y0 + 124), WHITE)
        ellipse(draw, (x1 + 64, y0 + 58, x1 + 92, y0 + 108), BLUE)
    elif cue == "signature":
        line(draw, [(x1 + 18, y0 + 82), (x1 + 68, y0 + 60), (x1 + 118, y0 + 92)], fill=BLUE)
    elif cue == "throw":
        polygon(draw, [(x1 + 20, y0 + 30), (x1 + 90, y0 + 18), (x1 + 52, y0 + 86)], ORANGE)
    elif cue == "thorn":
        polygon(draw, [(x1 + 16, y0 + 88), (x1 + 70, y0 + 70), (x1 + 42, y0 + 130)], GRAY)
    elif cue == "table":
        polygon(draw, [(x1 + 20, y0 + 40), (x1 + 130, y0 + 40), (x1 + 130, y0 + 70), (x1 + 20, y0 + 70)], WHITE)
        line(draw, [(x1 + 42, y0 + 70), (x1 + 42, y0 + 130)], fill=GRAY)
        line(draw, [(x1 + 110, y0 + 70), (x1 + 110, y0 + 130)], fill=GRAY)
    elif cue == "laugh":
        for dx in (0, 30, 60):
            arc(draw, (x0 - 120 + dx, y0 + 60, x0 - 70 + dx, y0 + 110), 15, 165, fill=YELLOW, width=8)
    elif cue == "smile":
        arc(draw, (x1 + 20, y0 + 60, x1 + 120, y0 + 120), 15, 165, fill=PINK, width=10)
    elif cue == "knee":
        line(draw, [(x1 + 30, y0 + 34), (x1 + 84, y0 + 84), (x1 + 130, y0 + 44)], fill=BLUE)
    elif cue == "sound":
        for dy in (18, 54, 90):
            polygon(draw, [(x0 - 120, y0 + dy), (x0 - 70, y0 + dy + 18), (x0 - 120, y0 + dy + 36)], YELLOW)
    else:
        ellipse(draw, (x1 + 28, y0 + 26, x1 + 76, y0 + 74), accent)
        ellipse(draw, (x1 + 94, y0 + 80, x1 + 128, y0 + 114), BLUE)


def render_one(entry: dict, index: int) -> Image.Image:
    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    fill = PALETTE[index % len(PALETTE)]
    glyph_size, probe_box = fit_font_size(entry["char"])
    glyph_font = font(glyph_size)
    pos = anchor(probe_box)
    box = draw_shadowed_text(draw, pos, entry["char"], glyph_font, fill)
    draw_face(draw, box, fill)
    draw_prop(draw, cue_type(entry["story"]), box, accent=PALETTE[(index + 2) % len(PALETTE)], lang=entry["out"].split("/")[3])
    return image


def contact_sheet(entries: list[dict], language: str) -> None:
    items = [entry for entry in entries if f"/{language}/" in entry["out"]]
    cols = 8
    cell = 160
    rows = math.ceil(len(items) / cols)
    sheet = Image.new("RGBA", (cols * cell, rows * cell), (0, 0, 0, 0))
    for idx, entry in enumerate(items):
        item = Image.open(ROOT / entry["out"]).convert("RGBA")
        item.thumbnail((cell - 20, cell - 20))
        x = (idx % cols) * cell + (cell - item.width) // 2
        y = (idx // cols) * cell + (cell - item.height) // 2
        sheet.alpha_composite(item, (x, y))
    sheet.save(ROOT / "design-explorations" / "generated" / f"kana-{language}-contact.png")


def main() -> None:
    entries = load_entries()
    for index, entry in enumerate(entries):
        image = render_one(entry, index)
        out = ROOT / entry["out"]
        out.parent.mkdir(parents=True, exist_ok=True)
        image.save(out)
    for language in ("fr", "en"):
        contact_sheet(entries, language)
    print(f"rendered {len(entries)} kana mascots")


if __name__ == "__main__":
    main()
