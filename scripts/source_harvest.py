"""Harvest open Japanese-learning upstreams and measured site snapshots.

This script has two jobs:

1. download openly reusable upstream datasets into ``var/source_harvest``;
2. capture a tiny, rate-limited HTML snapshot of selected reference sites, with
   their ``robots.txt`` and fetch metadata, without pretending that a full-site
   mirror is a good default.

Examples:

    python scripts/source_harvest.py fetch-open
    python scripts/source_harvest.py fetch-open --include-jitendex-mdict
    python scripts/source_harvest.py snapshot-sites
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import urllib.robotparser
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
HARVEST_ROOT = ROOT / "var" / "source_harvest"
UPSTREAMS_ROOT = HARVEST_ROOT / "upstreams"
SNAPSHOTS_ROOT = HARVEST_ROOT / "site_snapshots"
USER_AGENT = "jibiki-source-harvester/0.1 (+personal educational project)"
TITLE_RE = re.compile(r"<title[^>]*>(.*?)</title>", re.IGNORECASE | re.DOTALL)
CANONICAL_RE = re.compile(
    r'<link[^>]+rel=["\']canonical["\'][^>]+href=["\']([^"\']+)["\']',
    re.IGNORECASE,
)

DEFAULT_YOMITAN_ASSETS = [
    "JMdict_english_with_examples.zip",
    "JMdict_french.zip",
    "JMnedict.zip",
    "KANJIDIC_english.zip",
    "KANJIDIC_french.zip",
]


@dataclass(frozen=True)
class SiteTarget:
    id: str
    sample_url: str


SITE_TARGETS = [
    SiteTarget("jisho", "https://jisho.org/search/%23kanji%20%E6%A1%9C"),
    SiteTarget("kanshudo", "https://www.kanshudo.com/kanji/%E6%A1%9C"),
    SiteTarget(
        "tanoshii_japanese",
        "https://www.tanoshiijapanese.com/dictionary/kanji_details.cfm?character_id=26716&k=%E6%A1%9C",
    ),
    SiteTarget("the_kanji_map", "https://thekanjimap.com/%E4%B8%8B"),
    SiteTarget("kanjidraw", "https://kanjidraw.com/dictionary/%E6%AE%B5/"),
    SiteTarget("wanikani", "https://www.wanikani.com/kanji/%E6%A1%9C"),
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    fetch_open = sub.add_parser("fetch-open", help="Download open upstream datasets.")
    fetch_open.add_argument(
        "--include-jitendex-mdict",
        action="store_true",
        help="Also download the larger Jitendex MDict package.",
    )
    fetch_open.add_argument(
        "--yomitan-asset",
        action="append",
        dest="yomitan_assets",
        help="Specific jmdict-yomitan asset(s) to download. Can be passed multiple times.",
    )

    sub.add_parser(
        "snapshot-sites",
        help="Fetch robots.txt plus one measured HTML snapshot per configured site.",
    )

    args = parser.parse_args()
    if args.command == "fetch-open":
        return fetch_open_sources(
            include_jitendex_mdict=args.include_jitendex_mdict,
            yomitan_assets=args.yomitan_assets or DEFAULT_YOMITAN_ASSETS,
        )
    if args.command == "snapshot-sites":
        return snapshot_sites()
    raise AssertionError(f"unexpected command: {args.command}")


def fetch_open_sources(*, include_jitendex_mdict: bool, yomitan_assets: list[str]) -> int:
    UPSTREAMS_ROOT.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schema": "jibiki-source-harvest-open/1",
        "fetched_at": iso_now(),
        "user_agent": USER_AGENT,
        "sources": {},
    }

    manifest["sources"]["kanjialive"] = harvest_kanjialive()
    manifest["sources"]["kanjium"] = harvest_kanjium()
    manifest["sources"]["jitendex"] = harvest_jitendex(include_mdict=include_jitendex_mdict)
    manifest["sources"]["jmdict_yomitan"] = harvest_jmdict_yomitan(yomitan_assets)
    manifest["sources"]["rtk_index"] = harvest_rtk_index()
    manifest["sources"]["sylhare_radicals"] = harvest_sylhare_radicals()
    manifest["sources"]["mr_kanji_search_wtk"] = harvest_mr_kanji_search_wtk()

    write_json(HARVEST_ROOT / "open_manifest.json", manifest)
    print(f"Wrote {HARVEST_ROOT / 'open_manifest.json'}")
    return 0


def snapshot_sites() -> int:
    SNAPSHOTS_ROOT.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schema": "jibiki-source-harvest-snapshots/1",
        "fetched_at": iso_now(),
        "user_agent": USER_AGENT,
        "sites": {},
    }

    for site in SITE_TARGETS:
        manifest["sites"][site.id] = snapshot_site(site)

    write_json(HARVEST_ROOT / "snapshot_manifest.json", manifest)
    print(f"Wrote {HARVEST_ROOT / 'snapshot_manifest.json'}")
    return 0


def harvest_kanjialive() -> dict[str, Any]:
    target_dir = UPSTREAMS_ROOT / "kanjialive"
    target_dir.mkdir(parents=True, exist_ok=True)

    run = subprocess.run(
        [
            sys.executable,
            str(ROOT / "scripts" / "fetch_kanjialive_open_data.py"),
            "--out-dir",
            str(target_dir / "normalized"),
        ],
        check=True,
        cwd=ROOT,
    )
    del run

    files = []
    for url, name in [
        ("https://raw.githubusercontent.com/kanjialive/kanji-data-media/master/README.md", "README.md"),
        ("https://raw.githubusercontent.com/kanjialive/kanji-data-media/master/LICENSE.md", "LICENSE.md"),
    ]:
        path = target_dir / name
        download(url, path)
        files.append(file_entry(path, url))

    normalized = target_dir / "normalized" / "kanji_alive.json"
    return {
        "kind": "open",
        "license": "CC BY 4.0",
        "homepage": "https://github.com/kanjialive/kanji-data-media",
        "files": files + [file_entry(normalized, str(normalized))],
    }


def harvest_kanjium() -> dict[str, Any]:
    target_dir = UPSTREAMS_ROOT / "kanjium"
    target_dir.mkdir(parents=True, exist_ok=True)
    files = []
    for url, rel in [
        ("https://raw.githubusercontent.com/mifunetoshiro/kanjium/master/README.md", "README.md"),
        ("https://raw.githubusercontent.com/mifunetoshiro/kanjium/master/LICENSE.txt", "LICENSE.txt"),
        ("https://raw.githubusercontent.com/mifunetoshiro/kanjium/master/data/kanjidb.sqlite", "data/kanjidb.sqlite"),
        ("https://raw.githubusercontent.com/mifunetoshiro/kanjium/master/data/multielements.txt", "data/multielements.txt"),
        ("https://raw.githubusercontent.com/mifunetoshiro/kanjium/master/data/idc_mappingtable.txt", "data/idc_mappingtable.txt"),
    ]:
        path = target_dir / rel
        download(url, path)
        files.append(file_entry(path, url))
    return {
        "kind": "open",
        "license": "CC BY-SA 4.0",
        "homepage": "https://github.com/mifunetoshiro/kanjium",
        "files": files,
    }


def harvest_jitendex(*, include_mdict: bool) -> dict[str, Any]:
    target_dir = UPSTREAMS_ROOT / "jitendex"
    target_dir.mkdir(parents=True, exist_ok=True)
    files = []
    for url, rel in [
        ("https://jitendex.org/pages/legal.html", "legal.html"),
        ("https://jitendex.org/pages/downloads.html", "downloads.html"),
        (
            "https://github.com/stephenmk/stephenmk.github.io/releases/latest/download/jitendex-yomitan.zip",
            "jitendex-yomitan.zip",
        ),
    ]:
        path = target_dir / rel
        download(url, path)
        files.append(file_entry(path, url))
    if include_mdict:
        mdict = target_dir / "jitendex-mdict.zip"
        download(
            "https://github.com/stephenmk/stephenmk.github.io/releases/latest/download/jitendex-mdict.zip",
            mdict,
        )
        files.append(file_entry(mdict, "https://github.com/stephenmk/stephenmk.github.io/releases/latest/download/jitendex-mdict.zip"))
    return {
        "kind": "open",
        "license": "CC BY-SA 4.0",
        "homepage": "https://jitendex.org/",
        "files": files,
    }


def harvest_jmdict_yomitan(asset_names: list[str]) -> dict[str, Any]:
    target_dir = UPSTREAMS_ROOT / "jmdict_yomitan"
    target_dir.mkdir(parents=True, exist_ok=True)
    release = github_json("https://api.github.com/repos/yomidevs/jmdict-yomitan/releases/latest")
    asset_map = {asset["name"]: asset["browser_download_url"] for asset in release.get("assets", [])}

    files = []
    release_path = target_dir / "release.json"
    write_json(release_path, release)
    files.append(file_entry(release_path, "github:releases/latest"))
    for name in asset_names:
        url = asset_map.get(name)
        if not url:
            raise SystemExit(f"jmdict-yomitan asset not found in latest release: {name}")
        path = target_dir / name
        download(url, path)
        files.append(file_entry(path, url))

    return {
        "kind": "open",
        "license": "MIT code / CC BY-SA 4.0 released dictionaries",
        "homepage": "https://github.com/yomidevs/jmdict-yomitan",
        "release_tag": release.get("tag_name"),
        "files": files,
    }


def harvest_rtk_index() -> dict[str, Any]:
    target_dir = UPSTREAMS_ROOT / "rtk_index"
    target_dir.mkdir(parents=True, exist_ok=True)
    files = []
    for url, rel in [
        ("https://raw.githubusercontent.com/cyphar/heisig-rtk-index/master/README.md", "README.md"),
        ("https://raw.githubusercontent.com/cyphar/heisig-rtk-index/master/COPYING.CC0", "COPYING.CC0"),
        ("https://raw.githubusercontent.com/cyphar/heisig-rtk-index/master/LESSONS.csv", "LESSONS.csv"),
        ("https://raw.githubusercontent.com/cyphar/heisig-rtk-index/master/MINIMAL_SET.txt", "MINIMAL_SET.txt"),
    ]:
        path = target_dir / rel
        download(url, path)
        files.append(file_entry(path, url))
    return {
        "kind": "open",
        "license": "CC0-1.0 metadata per repository",
        "homepage": "https://github.com/cyphar/heisig-rtk-index",
        "files": files,
    }


def harvest_sylhare_radicals() -> dict[str, Any]:
    target_dir = UPSTREAMS_ROOT / "sylhare_radicals"
    target_dir.mkdir(parents=True, exist_ok=True)
    files = []
    for url, rel in [
        ("https://raw.githubusercontent.com/sylhare/kanji/master/README.md", "README.md"),
        ("https://raw.githubusercontent.com/sylhare/kanji/master/LICENSE", "LICENSE"),
        ("https://raw.githubusercontent.com/sylhare/kanji/master/_data/r214.yml", "r214.yml"),
    ]:
        path = target_dir / rel
        download(url, path)
        files.append(file_entry(path, url))
    return {
        "kind": "open",
        "license": "CC BY 3.0",
        "homepage": "https://github.com/sylhare/kanji",
        "files": files,
    }


def harvest_mr_kanji_search_wtk() -> dict[str, Any]:
    target_dir = UPSTREAMS_ROOT / "mr_kanji_search_wtk"
    target_dir.mkdir(parents=True, exist_ok=True)
    files = []
    for url, rel in [
        ("https://raw.githubusercontent.com/sschmidTU/mr-kanji-search-wtk/gh-pages/README.md", "README.md"),
        ("https://raw.githubusercontent.com/sschmidTU/mr-kanji-search-wtk/gh-pages/index.html", "index.html"),
        ("https://raw.githubusercontent.com/sschmidTU/mr-kanji-search-wtk/gh-pages/robots.txt", "robots.txt"),
        ("https://raw.githubusercontent.com/sschmidTU/mr-kanji-search-wtk/gh-pages/assets/js/elementsDict.js", "assets/js/elementsDict.js"),
        ("https://raw.githubusercontent.com/sschmidTU/mr-kanji-search-wtk/gh-pages/assets/js/wk_kanji_short_min.js", "assets/js/wk_kanji_short_min.js"),
        ("https://raw.githubusercontent.com/sschmidTU/mr-kanji-search-wtk/gh-pages/assets/js/wtksearch.js", "assets/js/wtksearch.js"),
        ("https://raw.githubusercontent.com/sschmidTU/mr-kanji-search-wtk/gh-pages/_code/data-full.csv", "_code/data-full.csv"),
        ("https://raw.githubusercontent.com/sschmidTU/mr-kanji-search-wtk/gh-pages/_code/rtk1-v6-strokes.csv", "_code/rtk1-v6-strokes.csv"),
        ("https://raw.githubusercontent.com/sschmidTU/mr-kanji-search-wtk/gh-pages/_code/rtk3-remain-full.txt", "_code/rtk3-remain-full.txt"),
    ]:
        path = target_dir / rel
        download(url, path)
        files.append(file_entry(path, url))
    return {
        "kind": "open",
        "license": "Repository license unclear from metadata; inspect upstream before redistribution",
        "homepage": "https://github.com/sschmidTU/mr-kanji-search-wtk",
        "files": files,
    }


def snapshot_site(site: SiteTarget) -> dict[str, Any]:
    target_dir = SNAPSHOTS_ROOT / site.id
    target_dir.mkdir(parents=True, exist_ok=True)

    robots_url = urllib.parse.urljoin(site.sample_url, "/robots.txt")
    robots_path = target_dir / "robots.txt"
    robots_meta = fetch_capture(robots_url, robots_path)

    parser = urllib.robotparser.RobotFileParser()
    parser.set_url(robots_url)
    if robots_path.exists():
        parser.parse(robots_path.read_text(encoding="utf-8", errors="replace").splitlines())

    allowed = parser.can_fetch(USER_AGENT, site.sample_url)
    crawl_delay = parser.crawl_delay(USER_AGENT)
    sample_meta: dict[str, Any]
    if allowed:
        if crawl_delay and crawl_delay > 0:
            time.sleep(min(float(crawl_delay), 5.0))
        sample_path = target_dir / "sample.html"
        sample_meta = fetch_capture(site.sample_url, sample_path)
        if sample_path.exists() and sample_meta.get("content_type", "").startswith("text/html"):
            text = sample_path.read_text(encoding="utf-8", errors="replace")
            sample_meta["title"] = extract_title(text)
            sample_meta["canonical"] = extract_canonical(text)
    else:
        sample_meta = {"url": site.sample_url, "allowed_by_robots": False}

    result = {
        "kind": "snapshot",
        "robots": robots_meta,
        "sample": sample_meta,
        "allowed_by_robots": allowed,
        "crawl_delay": crawl_delay,
    }
    write_json(target_dir / "snapshot.json", result)
    return result


def fetch_capture(url: str, destination: Path) -> dict[str, Any]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    meta: dict[str, Any] = {"url": url}
    try:
        with urllib.request.urlopen(request) as response:
            body = response.read()
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(body)
            meta.update(
                {
                    "status": response.getcode(),
                    "content_type": response.headers.get_content_type(),
                    "bytes": len(body),
                    "path": str(destination),
                    "sha256": hashlib.sha256(body).hexdigest(),
                }
            )
    except urllib.error.HTTPError as exc:
        meta.update({"status": exc.code, "error": str(exc)})
    except urllib.error.URLError as exc:
        meta.update({"error": str(exc)})
    return meta


def download(url: str, destination: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    destination.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(request) as response:
        destination.write_bytes(response.read())
    print(f"Downloaded {url} -> {destination}")


def github_json(url: str) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/vnd.github+json",
        },
    )
    with urllib.request.urlopen(request) as response:
        return json.loads(response.read().decode("utf-8"))


def file_entry(path: Path, source: str) -> dict[str, Any]:
    return {
        "path": str(path),
        "source": source,
        "bytes": path.stat().st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def extract_title(text: str) -> str:
    match = TITLE_RE.search(text)
    if not match:
        return ""
    return " ".join(match.group(1).split())


def extract_canonical(text: str) -> str:
    match = CANONICAL_RE.search(text)
    return match.group(1).strip() if match else ""


def iso_now() -> str:
    return datetime.now(UTC).isoformat(timespec="seconds")


if __name__ == "__main__":
    raise SystemExit(main())
