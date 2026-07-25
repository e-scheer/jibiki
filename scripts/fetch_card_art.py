"""Fetch license-safe photographic art for the collection cards.

Two-step, curation-first workflow:

  1. `search`: for every card of set-001, query Wikimedia Commons for
     photo candidates (minimum resolution, allow-listed licenses only),
     download review thumbnails and build one labeled contact sheet per
     card so a human (or Claude) can pick the best shot and keep a
     consistent photographic art direction across the whole set.

  2. `pick`: given a picks file mapping card id -> candidate index (with
     an optional focal point for the crop), download the chosen images at
     high resolution, center-crop them to the card aspect (63:88 portrait),
     resize and compress them into `app/assets/art/cards/`, and write an
     `ATTRIBUTIONS.json` manifest with author, license and source URL for
     every shipped image.

Only Wikimedia Commons is queried: its API is open, and every result
carries machine-readable license and author metadata, which the manifest
preserves. Images whose license is not in ALLOWED_LICENSES are dropped.

Usage:
  python scripts/fetch_card_art.py search --workdir <dir>
  python scripts/fetch_card_art.py pick --workdir <dir> --picks <picks.json>
"""

from __future__ import annotations

import argparse
import html
import io
import json
import re
import sys
import time
from pathlib import Path

import requests
from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
ASSET_DIR = REPO_ROOT / "app" / "assets" / "art" / "cards"

API = "https://commons.wikimedia.org/w/api.php"
HEADERS = {
    "User-Agent": "jibiki-card-art/1.0 (personal study app; art curation script)"
}

# Card aspect ratio (see kCollectionCardAspect) and shipped size.
CARD_W, CARD_H = 720, 1006
THUMB_W = 480
CANDIDATES_PER_CARD = 6
MIN_WIDTH = 1200
MIN_HEIGHT = 900
# Seconds between any two HTTP requests. Wikimedia throttles aggressively;
# stay well under the anonymous limit and the whole run just takes longer.
REQUEST_INTERVAL = 2.5

# License short names accepted for shipping (with attribution recorded).
ALLOWED_LICENSES = re.compile(
    r"^(public domain|pd|cc0|cc[ -]by([ -]sa)?[ -]\d\.\d.*)$", re.IGNORECASE
)

# Curated queries per card: photographic, subject-centered, vivid. The
# first query is the preferred angle; later ones widen the net.
CARD_QUERIES: dict[str, list[str]] = {
    "set001-001": ["Mount Fuji Kawaguchiko", "Mount Fuji cherry", "Mount Fuji"],
    "set001-002": ["Fushimi Inari torii path", "torii tunnel", "torii shrine gate"],
    "set001-003": ["ramen bowl chashu", "ramen bowl", "ramen Japan"],
    "set001-004": ["matcha chasen bowl", "matcha green tea bowl", "matcha"],
    "set001-005": ["maneki neko", "maneki-neko lucky cat", "beckoning cat"],
    "set001-006": ["Shinkansen Mount Fuji", "N700 Shinkansen Tokyo station", "E5 Shinkansen platform"],
    "set001-007": ["autumn maple Kyoto temple", "momiji autumn Japan", "Japanese maple autumn leaves"],
    "set001-008": ["Ginzan Onsen", "Kusatsu Onsen Yubatake", "Jigokudani Monkey Park", "Dogo Onsen"],
    "set001-009": ["origami cranes colorful", "origami crane paper", "senbazuru"],
    "set001-010": ["Japanese vending machines night", "vending machine Japan street", "jidohanbaiki"],
    "set001-011": ["Kinkaku-ji golden pavilion", "Kinkakuji Kyoto", "Kinkaku-ji"],
    "set001-012": ["Great Wave off Kanagawa Hokusai", "Hokusai wave print"],
    "set001-013": ["sumo wrestlers dohyo tournament", "sumo bout", "sumo Japan"],
    "set001-014": ["Fushimi Inari kitsune fox statue", "kitsune statue shrine", "Inari fox statue"],
    "set001-015": ["cherry blossom sakura Japan", "sakura tree full bloom", "hanami cherry blossoms"],
    "set001-016": ["Shibuya crossing night", "Shibuya scramble crossing", "Shibuya Tokyo night"],
    "set001-017": ["Japanese temple dragon statue", "chozuya dragon fountain", "ryu dragon temple Japan"],
    "set001-018": ["fireworks festival Japan hanabi", "Japanese fireworks summer festival", "hanabi taikai"],
    "set001-019": ["Kaminarimon lantern Asakusa", "Kaminarimon Senso-ji", "Asakusa thunder gate"],
    "set001-020": ["red-crowned crane Hokkaido snow", "Grus japonensis dance", "tancho crane Japan"],
}


def strip_html(value: str) -> str:
    return html.unescape(re.sub(r"<[^>]+>", "", value or "")).strip()


_last_request = 0.0


def _throttled_get(url: str, params: dict | None = None) -> requests.Response:
    """One polite GET: global 1 req/s pacing, honoring 429 Retry-After."""
    global _last_request
    for attempt in range(6):
        wait = _last_request + REQUEST_INTERVAL - time.monotonic()
        if wait > 0:
            time.sleep(wait)
        _last_request = time.monotonic()
        resp = requests.get(url, params=params, headers=HEADERS, timeout=60)
        if resp.status_code == 429:
            delay = max(float(resp.headers.get("Retry-After", 0) or 0), 20.0)
            print(f"  429, backing off {delay:.0f}s", file=sys.stderr, flush=True)
            time.sleep(delay * (attempt + 1))
            continue
        resp.raise_for_status()
        return resp
    resp.raise_for_status()
    return resp


def api_get(params: dict) -> dict:
    params = {"format": "json", **params}
    for attempt in range(3):
        try:
            return _throttled_get(API, params).json()
        except Exception as error:  # noqa: BLE001 - retry then surface
            if attempt == 2:
                raise
            print(f"  retry after error: {error}", file=sys.stderr)
            time.sleep(4 * (attempt + 1))
    return {}


def search_commons(query: str, limit: int) -> list[dict]:
    """Search Commons files; returns candidate dicts with license metadata."""
    data = api_get(
        {
            "action": "query",
            "generator": "search",
            "gsrsearch": f"{query} filetype:bitmap filew:>{MIN_WIDTH}",
            "gsrnamespace": 6,
            "gsrlimit": limit,
            "prop": "imageinfo",
            "iiprop": "url|size|extmetadata",
            "iiurlwidth": THUMB_W,
        }
    )
    pages = (data.get("query") or {}).get("pages") or {}
    results = []
    for page in pages.values():
        infos = page.get("imageinfo") or []
        if not infos:
            continue
        info = infos[0]
        meta = info.get("extmetadata") or {}
        license_name = strip_html((meta.get("LicenseShortName") or {}).get("value", ""))
        if not ALLOWED_LICENSES.match(license_name):
            continue
        width, height = info.get("width", 0), info.get("height", 0)
        if width < MIN_WIDTH or height < MIN_HEIGHT:
            continue
        results.append(
            {
                "title": page.get("title", ""),
                "page_url": info.get("descriptionshorturl")
                or info.get("descriptionurl", ""),
                "thumb_url": info.get("thumburl", ""),
                "full_url": info.get("url", ""),
                "width": width,
                "height": height,
                "license": license_name,
                "artist": strip_html((meta.get("Artist") or {}).get("value", ""))
                or "Unknown",
                "rank": page.get("index", 999),
            }
        )
    results.sort(key=lambda r: r["rank"])
    return results


def thumb_at(full_url: str, title: str, width: int) -> str:
    """Commons thumbnail URL for an arbitrary width."""
    # thumburl from the API is fixed at THUMB_W; rebuild for larger sizes.
    name = title.removeprefix("File:").replace(" ", "_")
    m = re.match(r"https://upload\.wikimedia\.org/wikipedia/commons/(.)/(..)/", full_url)
    if not m:
        return full_url
    return (
        f"https://upload.wikimedia.org/wikipedia/commons/thumb/"
        f"{m.group(1)}/{m.group(2)}/{name}/{width}px-{name}"
        + (".png" if name.lower().endswith(".svg") else "")
    )


def download(url: str) -> bytes:
    return _throttled_get(url).content


def cmd_search(workdir: Path, only: set[str] | None = None) -> None:
    workdir.mkdir(parents=True, exist_ok=True)
    # Re-runs merge into the existing candidate index, so single cards can be
    # re-queried without redownloading the whole set.
    index_path = workdir / "candidates.json"
    all_candidates: dict[str, list[dict]] = (
        json.loads(index_path.read_text(encoding="utf-8"))
        if index_path.exists()
        else {}
    )
    for card_id, queries in CARD_QUERIES.items():
        if only is not None and card_id not in only:
            continue
        print(f"[{card_id}] searching...", flush=True)
        seen: set[str] = set()
        candidates: list[dict] = []
        for query in queries:
            if len(candidates) >= CANDIDATES_PER_CARD:
                break
            for result in search_commons(query, CANDIDATES_PER_CARD):
                if result["title"] in seen:
                    continue
                seen.add(result["title"])
                candidates.append(result)
                if len(candidates) >= CANDIDATES_PER_CARD:
                    break
            time.sleep(0.4)
        card_dir = workdir / card_id
        card_dir.mkdir(exist_ok=True)
        kept = []
        for index, cand in enumerate(candidates):
            try:
                raw = download(cand["thumb_url"])
                (card_dir / f"{index}.jpg").write_bytes(raw)
                cand["index"] = index
                kept.append(cand)
            except Exception as error:  # noqa: BLE001 - drop broken candidates
                print(f"  candidate {index} failed: {error}", file=sys.stderr)
        all_candidates[card_id] = kept
        build_contact_sheet(card_dir, kept, workdir / f"contact-{card_id}.jpg")
        print(f"  {len(kept)} candidates", flush=True)
    index_path.write_text(
        json.dumps(all_candidates, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(f"done -> {workdir}")


def build_contact_sheet(card_dir: Path, candidates: list[dict], out: Path) -> None:
    if not candidates:
        return
    cols = 4
    cell_w, cell_h, caption = 320, 240, 34
    rows = (len(candidates) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell_w, rows * (cell_h + caption)), "#111")
    draw = ImageDraw.Draw(sheet)
    for cand in candidates:
        i = cand["index"]
        cx, cy = (i % cols) * cell_w, (i // cols) * (cell_h + caption)
        try:
            img = Image.open(card_dir / f"{i}.jpg").convert("RGB")
        except Exception:  # noqa: BLE001
            continue
        img.thumbnail((cell_w - 8, cell_h - 8))
        sheet.paste(img, (cx + (cell_w - img.width) // 2, cy + (cell_h - img.height) // 2))
        label = f"[{i}] {cand['width']}x{cand['height']}  {cand['license']}"
        draw.text((cx + 6, cy + cell_h + 6), label[:52], fill="#eee")
    sheet.save(out, quality=80)


def cmd_pick(workdir: Path, picks_path: Path) -> None:
    candidates = json.loads((workdir / "candidates.json").read_text(encoding="utf-8"))
    picks = json.loads(picks_path.read_text(encoding="utf-8"))
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for card_id, pick in picks.items():
        index = pick["index"] if isinstance(pick, dict) else pick
        focal_x = pick.get("fx", 0.5) if isinstance(pick, dict) else 0.5
        focal_y = pick.get("fy", 0.5) if isinstance(pick, dict) else 0.5
        cand = next(c for c in candidates[card_id] if c["index"] == index)
        print(f"[{card_id}] {cand['title']}")
        # Fetch a large-enough thumbnail rather than the (huge) original.
        want = max(CARD_W * 2, 1600)
        url = cand["full_url"] if cand["width"] <= want else thumb_at(
            cand["full_url"], cand["title"], want
        )
        try:
            raw = download(url)
        except Exception:  # noqa: BLE001 - fall back to the original file
            raw = download(cand["full_url"])
        img = Image.open(io.BytesIO(raw)).convert("RGB")
        img = crop_to_card(img, focal_x, focal_y)
        out = ASSET_DIR / f"{card_id}.jpg"
        img.save(out, quality=86, optimize=True, progressive=True)
        manifest[card_id] = {
            "file": out.name,
            "title": cand["title"],
            "source": cand["page_url"],
            "author": cand["artist"],
            "license": cand["license"],
        }
        print(f"  -> {out.relative_to(REPO_ROOT)} ({out.stat().st_size // 1024} KB)")
    manifest_path = ASSET_DIR / "ATTRIBUTIONS.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"manifest -> {manifest_path.relative_to(REPO_ROOT)}")


def crop_to_card(img: Image.Image, focal_x: float, focal_y: float) -> Image.Image:
    """Crop to the 63:88 portrait card window around a focal point."""
    target = CARD_W / CARD_H
    w, h = img.size
    if w / h > target:
        crop_w, crop_h = int(h * target), h
    else:
        crop_w, crop_h = w, int(w / target)
    x = min(max(int(focal_x * w - crop_w / 2), 0), w - crop_w)
    y = min(max(int(focal_y * h - crop_h / 2), 0), h - crop_h)
    img = img.crop((x, y, x + crop_w, y + crop_h))
    return img.resize((CARD_W, CARD_H), Image.LANCZOS)


def main() -> None:
    # Commons file titles carry Japanese; never trust the console codepage.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    p_search = sub.add_parser("search")
    p_search.add_argument("--workdir", type=Path, required=True)
    p_search.add_argument(
        "--only", help="comma-separated card ids to (re)query", default=None
    )
    p_pick = sub.add_parser("pick")
    p_pick.add_argument("--workdir", type=Path, required=True)
    p_pick.add_argument("--picks", type=Path, required=True)
    args = parser.parse_args()
    if args.cmd == "search":
        cmd_search(
            args.workdir,
            only=set(args.only.split(",")) if args.only else None,
        )
    else:
        cmd_pick(args.workdir, args.picks)


if __name__ == "__main__":
    main()
