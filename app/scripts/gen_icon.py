"""Generate the NeoPop exploration 17 brand assets.

The app icon is the ink 字 on an acid field. Native splash assets use the
vertical mark and wordmark lockup from the identity sheet. Run from app/ with:

    python scripts/gen_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
FONT_JP = ROOT / "assets" / "fonts" / "ZenKakuGothicNew-Black.ttf"
FONT_WORD = ROOT / "assets" / "fonts" / "SpaceGrotesk-Bold.ttf"
OUT = ROOT / "assets" / "icon"

INK = (23, 19, 31, 255)  # #17131F
ACID = (242, 229, 28, 255)  # #F2E51C
KLEIN = (43, 54, 227, 255)  # #2B36E3
WHITE = (255, 255, 255, 255)
LAVENDER = (201, 184, 249, 255)
TRANSPARENT = (0, 0, 0, 0)
GLYPH = "字"


def _font(path: Path, px: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), px)


def _draw_centered_glyph(
    image: Image.Image,
    box: tuple[int, int, int, int],
    color: tuple[int, int, int, int],
    target_height: float,
) -> None:
    """Draw 字 centered by its visible ink bounds, not by its font metrics."""
    draw = ImageDraw.Draw(image)
    target = (box[3] - box[1]) * target_height
    box_height = box[3] - box[1]
    low, high, best = 16, max(32, box_height * 2), 64
    for _ in range(22):
        mid = (low + high) // 2
        bounds = draw.textbbox((0, 0), GLYPH, font=_font(FONT_JP, mid))
        height = bounds[3] - bounds[1]
        if height > target:
            high = mid
        else:
            best = mid
            low = mid + 1
    font = _font(FONT_JP, best)
    bounds = draw.textbbox((0, 0), GLYPH, font=font)
    width = bounds[2] - bounds[0]
    height = bounds[3] - bounds[1]
    x = box[0] + ((box[2] - box[0]) - width) / 2 - bounds[0]
    y = box[1] + ((box[3] - box[1]) - height) / 2 - bounds[1]
    draw.text((x, y), GLYPH, font=font, fill=color)


def _draw_blockmark(image: Image.Image, size: int, center: tuple[int, int]) -> None:
    """Draw the 17 blockmark: acid face, 5 px outline and 9 px hard shadow."""
    scale = size / 148
    shadow = round(9 * scale)
    border = max(2, round(5 * scale))
    radius = round(36 * scale)
    left = round(center[0] - size / 2)
    top = round(center[1] - size / 2)
    right = left + size
    bottom = top + size
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        (left + shadow, top + shadow, right + shadow, bottom + shadow),
        radius=radius,
        fill=INK,
    )
    draw.rounded_rectangle(
        (left, top, right, bottom),
        radius=radius,
        fill=ACID,
        outline=INK,
        width=border,
    )
    inset = border
    _draw_centered_glyph(
        image,
        (left + inset, top + inset, right - inset, bottom - inset),
        INK,
        0.72,
    )


def _wordmark_layer(
    font_size: int,
    text_color: tuple[int, int, int, int],
    dot_outline: tuple[int, int, int, int],
) -> Image.Image:
    font = _font(FONT_WORD, font_size)
    probe = ImageDraw.Draw(Image.new("RGBA", (1, 1), TRANSPARENT))
    bounds = probe.textbbox((0, 0), "jibiki", font=font)
    text_width = bounds[2] - bounds[0]
    text_height = bounds[3] - bounds[1]
    dot_size = round(font_size * 0.375)
    dot_margin = round(font_size * 0.10)
    outline = max(2, round(font_size * 0.07))
    pad = round(font_size * 0.16)
    layer = Image.new(
        "RGBA",
        (text_width + dot_margin + dot_size + pad * 4, max(text_height, dot_size) + pad * 4),
        TRANSPARENT,
    )
    draw = ImageDraw.Draw(layer)
    text_x = pad - bounds[0]
    text_y = (layer.height - text_height) / 2 - bounds[1]
    draw.text((text_x, text_y), "jibiki", font=font, fill=text_color)

    dot_canvas = Image.new("RGBA", (dot_size + outline * 4, dot_size + outline * 4), TRANSPARENT)
    dot_draw = ImageDraw.Draw(dot_canvas)
    dot_draw.rounded_rectangle(
        (outline * 2, outline * 2, outline * 2 + dot_size, outline * 2 + dot_size),
        radius=max(2, round(font_size * 0.09)),
        fill=ACID,
        outline=dot_outline,
        width=outline,
    )
    dot_canvas = dot_canvas.rotate(-12, resample=Image.Resampling.BICUBIC, expand=True)
    dot_x = pad + text_width + dot_margin
    dot_y = round((layer.height - dot_canvas.height) / 2 + text_height * 0.23)
    layer.alpha_composite(dot_canvas, (dot_x, dot_y))
    return layer


def _splash_lockup(dot_outline: tuple[int, int, int, int]) -> Image.Image:
    """1024 source becomes a 256 dp centered lockup on legacy launch screens."""
    image = Image.new("RGBA", (1024, 1024), TRANSPARENT)
    mark_size = 592
    _draw_blockmark(image, mark_size, (512, 322))
    wordmark = _wordmark_layer(176, WHITE, dot_outline)
    x = (image.width - wordmark.width) // 2
    y = 322 + mark_size // 2 + 110
    image.alpha_composite(wordmark, (x, y))
    return image


def _branding(color: tuple[int, int, int, int]) -> Image.Image:
    image = Image.new("RGBA", (1024, 112), TRANSPARENT)
    font = _font(FONT_WORD, 54)
    draw = ImageDraw.Draw(image)
    text = "dictionnaire libre, mémoire durable"
    bounds = draw.textbbox((0, 0), text, font=font)
    x = (image.width - (bounds[2] - bounds[0])) / 2 - bounds[0]
    y = (image.height - (bounds[3] - bounds[1])) / 2 - bounds[1]
    draw.text((x, y), text, font=font, fill=color)
    return image


def _master_icon() -> Image.Image:
    size = 1024
    image = Image.new("RGBA", (size, size), ACID)
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        (26, 26, size - 26, size - 26),
        radius=220,
        fill=ACID,
        outline=INK,
        width=26,
    )
    _draw_centered_glyph(image, (72, 72, size - 72, size - 72), INK, 0.61)
    return image


def generate() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    _master_icon().save(OUT / "icon.png")

    foreground = Image.new("RGBA", (1024, 1024), TRANSPARENT)
    _draw_centered_glyph(foreground, (0, 0, 1024, 1024), INK, 0.42)
    foreground.save(OUT / "icon_foreground.png")
    foreground.save(OUT / "icon_monochrome.png")

    _splash_lockup(INK).save(OUT / "splash_klein.png")
    _splash_lockup(WHITE).save(OUT / "splash_dark.png")

    android12 = Image.new("RGBA", (1152, 1152), TRANSPARENT)
    _draw_blockmark(android12, 520, (576, 576))
    android12.save(OUT / "splash_android12.png")

    _branding(WHITE).save(OUT / "branding_klein.png")
    _branding(LAVENDER).save(OUT / "branding_dark.png")

    # Kept as a compatibility alias for any release tooling that still expects
    # assets/icon/splash.png.
    _splash_lockup(INK).save(OUT / "splash.png")

    print(f"wrote exploration 17 brand assets to {OUT}")


if __name__ == "__main__":
    generate()
