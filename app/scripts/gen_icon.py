"""Generate jibiki's app icon from the brand glyph 字 (a hanko-style seal):
white 字 on vermilion 朱. Emits the master icon, the Android adaptive foreground,
and a monochrome (themed-icon) layer. Run: python scripts/gen_icon.py"""

import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(HERE, "assets", "fonts", "NotoSansJP.ttf")
OUT = os.path.join(HERE, "assets", "icon")
os.makedirs(OUT, exist_ok=True)

SIZE = 1024
VERMILION = (212, 64, 42, 255)  # #D4402A — the brand seal red
WHITE = (255, 255, 255, 255)
GLYPH = "字"


def _font(px: int) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(FONT, px)
    # NotoSansJP is a variable font — pin a heavy weight so the seal reads bold.
    try:
        f.set_variation_by_axes([800])
    except Exception:
        pass
    return f


def _draw_glyph(img: Image.Image, color, target_frac: float) -> None:
    """Draw 字 centred, scaled so its ink box spans ~target_frac of the canvas."""
    draw = ImageDraw.Draw(img)
    # Binary-search a pixel size that makes the glyph's bounding box the right size.
    lo, hi, best = 100, 1400, 700
    for _ in range(24):
        mid = (lo + hi) // 2
        box = draw.textbbox((0, 0), GLYPH, font=_font(mid))
        h = box[3] - box[1]
        if h > SIZE * target_frac:
            hi = mid
        else:
            best = mid
            lo = mid
    font = _font(best)
    box = draw.textbbox((0, 0), GLYPH, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    x = (SIZE - w) / 2 - box[0]
    y = (SIZE - h) / 2 - box[1]
    draw.text((x, y), GLYPH, font=font, fill=color)


def master() -> None:
    """Full-bleed vermilion seal + white 字 (iOS / legacy Android mask this)."""
    img = Image.new("RGBA", (SIZE, SIZE), VERMILION)
    _draw_glyph(img, WHITE, 0.60)
    img.save(os.path.join(OUT, "icon.png"))


def foreground() -> None:
    """Android adaptive foreground: transparent, 字 kept inside the safe zone."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    _draw_glyph(img, WHITE, 0.42)  # smaller — adaptive masks crop the outer ~1/3
    img.save(os.path.join(OUT, "icon_foreground.png"))


def monochrome() -> None:
    """Android 13+ themed-icon layer: solid glyph on transparent, OS tints it."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    _draw_glyph(img, (0, 0, 0, 255), 0.42)
    img.save(os.path.join(OUT, "icon_monochrome.png"))


def splash() -> None:
    """Launch screen glyph: vermilion 字 on transparent, so on a white splash it
    matches the app's crisp white surface (no jarring colour flash)."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    _draw_glyph(img, VERMILION, 0.34)
    img.save(os.path.join(OUT, "splash.png"))


if __name__ == "__main__":
    master()
    foreground()
    monochrome()
    splash()
    print("wrote icon.png, icon_foreground.png, icon_monochrome.png, splash.png to", OUT)
