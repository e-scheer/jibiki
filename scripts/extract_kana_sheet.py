from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "design-explorations" / "generated" / "kana_batch_manifest.json"


def load_manifest(group_id: str) -> dict:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for group in data["groups"]:
        if group["group_id"] == group_id:
            return group
    raise KeyError(group_id)


def sample_key_color(img: Image.Image) -> tuple[int, int, int]:
    rgb = img.convert("RGB")
    pixels = rgb.load()
    width, height = rgb.size
    samples: list[tuple[int, int, int]] = []
    for x in range(width):
        samples.append(pixels[x, 0])
        samples.append(pixels[x, height - 1])
    for y in range(height):
        samples.append(pixels[0, y])
        samples.append(pixels[width - 1, y])
    red = round(sum(color[0] for color in samples) / len(samples))
    green = round(sum(color[1] for color in samples) / len(samples))
    blue = round(sum(color[2] for color in samples) / len(samples))
    return red, green, blue


def make_alpha_image(img: Image.Image, tolerance: int) -> Image.Image:
    rgba = img.convert("RGBA")
    key = sample_key_color(rgba)
    pixels = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            dist = max(abs(red - key[0]), abs(green - key[1]), abs(blue - key[2]))
            if dist <= tolerance:
                pixels[x, y] = (red, green, blue, 0)
            else:
                pixels[x, y] = (red, green, blue, alpha)
    return rgba


def component_boxes(mask_img: Image.Image) -> list[tuple[int, int, int, int]]:
    mask = mask_img.convert("L")
    width, height = mask.size
    pixels = mask.load()
    visited = [[False] * width for _ in range(height)]
    boxes: list[tuple[int, int, int, int]] = []

    for y in range(height):
        for x in range(width):
            if visited[y][x] or pixels[x, y] == 0:
                continue
            queue = deque([(x, y)])
            visited[y][x] = True
            min_x = max_x = x
            min_y = max_y = y

            while queue:
                cx, cy = queue.popleft()
                min_x = min(min_x, cx)
                max_x = max(max_x, cx)
                min_y = min(min_y, cy)
                max_y = max(max_y, cy)

                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    if visited[ny][nx] or pixels[nx, ny] == 0:
                        continue
                    visited[ny][nx] = True
                    queue.append((nx, ny))

            boxes.append((min_x, min_y, max_x + 1, max_y + 1))

    return boxes


def merge_nearby_boxes(
    boxes: list[tuple[int, int, int, int]], max_gap: int
) -> list[tuple[int, int, int, int]]:
    merged = boxes[:]
    changed = True
    while changed:
        changed = False
        next_boxes: list[tuple[int, int, int, int]] = []
        while merged:
            box = merged.pop(0)
            bx0, by0, bx1, by1 = box
            keep_merging = True
            while keep_merging:
                keep_merging = False
                for index, other in enumerate(merged):
                    ox0, oy0, ox1, oy1 = other
                    horizontal_gap = max(0, max(ox0 - bx1, bx0 - ox1))
                    vertical_gap = max(0, max(oy0 - by1, by0 - oy1))
                    vertical_overlap = min(by1, oy1) - max(by0, oy0)
                    horizontal_overlap = min(bx1, ox1) - max(bx0, ox0)
                    if (
                        horizontal_gap <= max_gap and vertical_overlap > 0
                    ) or (
                        vertical_gap <= max_gap and horizontal_overlap > 0
                    ):
                        bx0 = min(bx0, ox0)
                        by0 = min(by0, oy0)
                        bx1 = max(bx1, ox1)
                        by1 = max(by1, oy1)
                        merged.pop(index)
                        changed = True
                        keep_merging = True
                        break
            next_boxes.append((bx0, by0, bx1, by1))
        merged = next_boxes
    return merged


def sorted_boxes(boxes: list[tuple[int, int, int, int]], top_count: int, bottom_count: int) -> list[tuple[int, int, int, int]]:
    if top_count == 0 or bottom_count == 0:
        return sorted(boxes, key=lambda box: (box[0], box[1]))
    centers = [((box[1] + box[3]) / 2, box) for box in boxes]
    y_values = sorted(center for center, _box in centers)
    split = (y_values[top_count - 1] + y_values[top_count]) / 2
    top = [box for center, box in centers if center <= split]
    bottom = [box for center, box in centers if center > split]
    top.sort(key=lambda box: box[0])
    bottom.sort(key=lambda box: box[0])
    return [*top, *bottom]


def crop_and_save(alpha_img: Image.Image, boxes: list[tuple[int, int, int, int]], group: dict, padding: int) -> None:
    items = group["items"]
    if len(boxes) != len(items):
        raise RuntimeError(f"expected {len(items)} items, got {len(boxes)}")

    for box, item in zip(boxes, items, strict=True):
        min_x, min_y, max_x, max_y = box
        left = max(min_x - padding, 0)
        top = max(min_y - padding, 0)
        right = min(max_x + padding, alpha_img.width)
        bottom = min(max_y + padding, alpha_img.height)
        crop = alpha_img.crop((left, top, right, bottom))
        out = ROOT / item["out"]
        out.parent.mkdir(parents=True, exist_ok=True)
        crop.save(out)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--group-id", required=True)
    parser.add_argument("--sheet", required=True)
    parser.add_argument("--tolerance", type=int, default=30)
    parser.add_argument("--dilate", type=int, default=10)
    parser.add_argument("--padding", type=int, default=18)
    args = parser.parse_args()

    group = load_manifest(args.group_id)
    sheet = Image.open(args.sheet)
    alpha = make_alpha_image(sheet, args.tolerance)
    mask = alpha.getchannel("A").point(lambda value: 255 if value > 0 else 0)
    dilated = mask.filter(ImageFilter.MaxFilter(args.dilate * 2 + 1))
    boxes = merge_nearby_boxes(component_boxes(dilated), max_gap=max(8, args.dilate // 2))
    ordered = sorted_boxes(boxes, group["top_count"], group["bottom_count"])
    crop_and_save(alpha, ordered, group, args.padding)
    print(group["group_id"])


if __name__ == "__main__":
    main()
