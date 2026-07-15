"""Fetch and normalize the published RTK search index from hochanh.github.io.

This source is a static site index rather than a canonical open dataset. The
script keeps the scope narrow: one robots file, one search index JS, and one
normalized JSON export.
"""

from __future__ import annotations

import argparse
import json
import re
import urllib.request
from pathlib import Path

BASE = "https://hochanh.github.io/rtk"
USER_AGENT = "jibiki-source-harvester/0.1 (+personal educational project)"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--out-dir",
        default="var/source_harvest/upstreams/hochanh_rtk",
        help="Directory to write raw and normalized files into.",
    )
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    raw_dir = out_dir / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)

    robots = raw_dir / "robots.txt"
    search_js = raw_dir / "search.js"
    fetch(f"{BASE}/robots.txt", robots)
    fetch(f"{BASE}/assets/js/search.js", search_js)

    docs = parse_docs(search_js.read_text(encoding="utf-8"))
    payload = {
        "schema": "jibiki-hochanh-rtk-index/1",
        "source": BASE,
        "entry_count": len(docs),
        "docs": docs,
    }
    out_path = out_dir / "rtk_search_index.json"
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {out_path}")
    return 0


def fetch(url: str, path: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request) as response:
        path.write_bytes(response.read())


def parse_docs(js: str) -> list[dict[str, str]]:
    body = js
    start = body.find("[")
    end = body.find("];")
    if start == -1 or end == -1 or end <= start:
        raise ValueError("could not isolate docs array in search.js")
    body = body[start : end + 1]
    body = re.sub(r",\s*([}\]])", r"\1", body)
    docs = json.loads(body)
    normalized = []
    for doc in docs:
        normalized.append(
            {
                "id": str(doc.get("id", "")).strip(),
                "kanji": str(doc.get("kanji", "")).strip(),
                "keyword": str(doc.get("keyword", "")).strip(),
                "elements": str(doc.get("elements", "")).strip(),
            }
        )
    return normalized


if __name__ == "__main__":
    raise SystemExit(main())
