"""Mirror authorized reference sites into a local archive.

This crawler is designed for site-owner-authorized mirroring. It supports a
mix of sitemap seeding and same-host HTML discovery, stores fetched responses
under ``var/site_mirror/<site>/mirror/``, and records progress in JSONL logs so
long runs can be resumed or inspected.

Examples:

    python scripts/mirror_sites.py --site kanjidraw --max-pages 25
    python scripts/mirror_sites.py --site kanshudo --scope jibiki --delay-seconds 15
"""

from __future__ import annotations

import argparse
import hashlib
import html.parser
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
import urllib.robotparser
import xml.etree.ElementTree as ET
from collections import deque
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MIRROR_ROOT = ROOT / "var" / "site_mirror"
DEFAULT_USER_AGENT = "jibiki-authorized-mirror/0.1 (+site owner authorized crawl)"
TRACKING_QUERY_RE = re.compile(r"^(utm_|fbclid$|gclid$|mc_cid$|mc_eid$)", re.IGNORECASE)
INLINE_URL_RE = re.compile(r"""(?P<quote>["'])(?P<url>(?:https?://|/|\.\./)[^"'<>\s]+)(?P=quote)""")


@dataclass(frozen=True)
class SiteConfig:
    id: str
    start_urls: tuple[str, ...]
    allowed_hosts: tuple[str, ...]
    sitemap_urls: tuple[str, ...] = ()
    default_delay_seconds: float = 15.0
    canonical_host: str | None = None


SITE_CONFIGS = {
    "kanshudo": SiteConfig(
        id="kanshudo",
        start_urls=(
            "https://www.kanshudo.com/kanji/%E6%9C%AC",
            "https://www.kanshudo.com/word/%E7%89%87%E4%BB%AE%E5%90%8D",
            "https://www.kanshudo.com/component_details",
            "https://www.kanshudo.com/collections",
        ),
        allowed_hosts=("www.kanshudo.com", "kanshudo.com"),
        sitemap_urls=("https://www.kanshudo.com/sitemap.xml",),
    ),
    "the_kanji_map": SiteConfig(
        id="the_kanji_map",
        start_urls=("https://thekanjimap.com/%E4%B8%8B",),
        allowed_hosts=("thekanjimap.com", "the-kanji-map.com"),
        sitemap_urls=("https://thekanjimap.com/sitemap.xml",),
        canonical_host="thekanjimap.com",
    ),
    "kanjidraw": SiteConfig(
        id="kanjidraw",
        start_urls=(
            "https://kanjidraw.com/dictionary/%E6%AE%B5/",
            "https://kanjidraw.com/kana/",
            "https://kanjidraw.com/radicals/",
            "https://kanjidraw.com/collections/jlpt-n5/",
        ),
        allowed_hosts=("kanjidraw.com", "www.kanjidraw.com"),
        sitemap_urls=("https://kanjidraw.com/sitemap-index.xml",),
    ),
    "wanikani": SiteConfig(
        id="wanikani",
        start_urls=(
            "https://www.wanikani.com/kanji/%E6%A1%9C",
            "https://www.wanikani.com/vocabulary/%E6%A1%9C",
            "https://www.wanikani.com/radicals/tree",
        ),
        allowed_hosts=("www.wanikani.com", "wanikani.com"),
    ),
    "tanoshii_japanese": SiteConfig(
        id="tanoshii_japanese",
        start_urls=(
            "https://www.tanoshiijapanese.com/dictionary/",
            "https://www.tanoshiijapanese.com/dictionary/kanji_details.cfm?character_id=26716&k=%E6%A1%9C",
            "https://www.tanoshiijapanese.com/dictionary/entry_details.cfm?entry_id=57284",
            "https://www.tanoshiijapanese.com/dictionary/sentence_details.cfm?sentence_id=180404",
            "https://www.tanoshiijapanese.com/dictionary/conjugation_details.cfm?entry_id=19621",
        ),
        allowed_hosts=("www.tanoshiijapanese.com", "tanoshiijapanese.com"),
    ),
}


class LinkCollector(html.parser.HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.links: set[str] = set()
        self.assets: set[str] = set()

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attr_map = {key.lower(): value for key, value in attrs if value}
        if "href" in attr_map:
            href = attr_map["href"]
            if tag.lower() == "a":
                self.links.add(href)
            else:
                self.assets.add(href)
        if "action" in attr_map:
            self.links.add(attr_map["action"])
        if "src" in attr_map:
            self.assets.add(attr_map["src"])
        if "srcset" in attr_map:
            for item in attr_map["srcset"].split(","):
                candidate = item.strip().split(" ", 1)[0].strip()
                if candidate:
                    self.assets.add(candidate)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--site", action="append", dest="sites", choices=sorted(SITE_CONFIGS), required=True)
    parser.add_argument("--delay-seconds", type=float, default=None, help="Delay between requests.")
    parser.add_argument("--user-agent", default=DEFAULT_USER_AGENT)
    parser.add_argument("--max-pages", type=int, default=None, help="Optional cap on HTML pages fetched.")
    parser.add_argument("--max-assets", type=int, default=None, help="Optional cap on assets fetched.")
    parser.add_argument("--max-urls", type=int, default=None, help="Optional cap on total fetched URLs.")
    parser.add_argument("--discover-links", action="store_true", help="Follow same-host links found in HTML pages.")
    parser.add_argument("--include-assets", action="store_true", help="Fetch same-host assets referenced by HTML pages.")
    parser.add_argument("--ignore-robots", action="store_true", help="Skip robots gating checks.")
    parser.add_argument(
        "--scope",
        choices=("full", "jibiki"),
        default="full",
        help="Crawl the full site or keep only Jibiki-relevant lexical content.",
    )
    args = parser.parse_args()

    for site_id in args.sites:
        config = SITE_CONFIGS[site_id]
        delay = args.delay_seconds if args.delay_seconds is not None else config.default_delay_seconds
        mirror_site(
            config=config,
            user_agent=args.user_agent,
            delay_seconds=delay,
            max_pages=args.max_pages,
            max_assets=args.max_assets,
            max_urls=args.max_urls,
            discover_links=args.discover_links,
            include_assets=args.include_assets,
            ignore_robots=args.ignore_robots,
            scope=args.scope,
        )
    return 0


def mirror_site(
    *,
    config: SiteConfig,
    user_agent: str,
    delay_seconds: float,
    max_pages: int | None,
    max_assets: int | None,
    max_urls: int | None,
    discover_links: bool,
    include_assets: bool,
    ignore_robots: bool,
    scope: str,
) -> None:
    site_root = MIRROR_ROOT / config.id
    mirror_root = site_root / "mirror"
    mirror_root.mkdir(parents=True, exist_ok=True)
    log_path = site_root / "fetch_log.jsonl"
    summary_path = site_root / "summary.json"

    robots = build_robot_parsers(config, user_agent) if not ignore_robots else {}
    queue: deque[str] = deque()
    enqueued: set[str] = set()
    visited: set[str] = load_visited(log_path)
    asset_queue: deque[str] = deque()

    for url in seed_urls(config, user_agent):
        enqueue(url, queue, enqueued, visited, config, scope=scope)

    counts = {"pages": 0, "assets": 0, "total": 0}
    last_request_at = 0.0

    while queue or asset_queue:
        use_asset_queue = not queue and asset_queue
        current_queue = asset_queue if use_asset_queue else queue
        url = current_queue.popleft()
        if url in visited:
            continue
        if max_urls is not None and counts["total"] >= max_urls:
            break
        if use_asset_queue and max_assets is not None and counts["assets"] >= max_assets:
            continue
        if not use_asset_queue and max_pages is not None and counts["pages"] >= max_pages:
            continue
        if not ignore_robots and not can_fetch(url, robots, user_agent):
            append_jsonl(
                log_path,
                {
                    "timestamp": iso_now(),
                    "url": url,
                    "status": "skipped",
                    "reason": "robots",
                },
            )
            visited.add(url)
            continue

        sleep_for = delay_seconds - max(0.0, time.monotonic() - last_request_at)
        if sleep_for > 0:
            time.sleep(sleep_for)
        last_request_at = time.monotonic()

        fetch_meta = fetch_url(url, user_agent)
        fetch_meta["fetched_at"] = iso_now()
        if fetch_meta.get("body") is not None:
            body = fetch_meta.pop("body")
            saved_path = save_response(mirror_root, url, body, fetch_meta.get("content_type"))
            fetch_meta["saved_path"] = str(saved_path)
            visited.add(url)
            counts["total"] += 1
            content_type = str(fetch_meta.get("content_type", ""))
            if content_type.startswith("text/html"):
                counts["pages"] += 1
                collector = collect_links(body)
                if discover_links:
                    for candidate in collector.links:
                        enqueue(candidate, queue, enqueued, visited, config, scope=scope, base_url=url)
                    for candidate in extract_embedded_links(body):
                        enqueue(candidate, queue, enqueued, visited, config, scope=scope, base_url=url)
                if include_assets:
                    for candidate in collector.assets:
                        enqueue(candidate, asset_queue, enqueued, visited, config, scope=scope, base_url=url)
            else:
                counts["assets"] += 1
        else:
            visited.add(url)

        append_jsonl(log_path, fetch_meta)

    summary = {
        "site": config.id,
        "config": asdict(config),
        "delay_seconds": delay_seconds,
        "ignore_robots": ignore_robots,
        "discover_links": discover_links,
        "include_assets": include_assets,
        "counts": counts,
        "visited_count": len(visited),
        "scope": scope,
        "completed_at": iso_now(),
    }
    summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {summary_path}")


def seed_urls(config: SiteConfig, user_agent: str) -> list[str]:
    urls = list(config.start_urls)
    for sitemap_url in config.sitemap_urls:
        try:
            urls.extend(iter_sitemap_urls(sitemap_url, user_agent))
        except Exception:
            continue
    return urls


def iter_sitemap_urls(sitemap_url: str, user_agent: str) -> list[str]:
    req = urllib.request.Request(sitemap_url, headers={"User-Agent": user_agent})
    with urllib.request.urlopen(req, timeout=60) as response:
        body = response.read()
    root = ET.fromstring(body)
    root_tag = root.tag.split("}")[-1]
    if root_tag == "sitemapindex":
        urls: list[str] = []
        for node in root.findall("{*}sitemap"):
            loc = node.find("{*}loc")
            if loc is None or not loc.text:
                continue
            urls.extend(iter_sitemap_urls(loc.text.strip(), user_agent))
        return urls
    if root_tag == "urlset":
        urls = []
        for node in root.findall("{*}url"):
            loc = node.find("{*}loc")
            if loc is not None and loc.text:
                urls.append(loc.text.strip())
        return urls
    return []


def build_robot_parsers(config: SiteConfig, user_agent: str) -> dict[str, urllib.robotparser.RobotFileParser]:
    parsers: dict[str, urllib.robotparser.RobotFileParser] = {}
    for host in config.allowed_hosts:
        robots_url = f"https://{host}/robots.txt"
        parser = urllib.robotparser.RobotFileParser()
        parser.set_url(robots_url)
        try:
            req = urllib.request.Request(robots_url, headers={"User-Agent": user_agent})
            with urllib.request.urlopen(req, timeout=30) as response:
                parser.parse(response.read().decode("utf-8", errors="replace").splitlines())
            parsers[host] = parser
        except Exception:
            continue
    return parsers


def can_fetch(url: str, parsers: dict[str, urllib.robotparser.RobotFileParser], user_agent: str) -> bool:
    host = urllib.parse.urlsplit(url).netloc.lower()
    parser = parsers.get(host)
    if parser is None:
        return True
    return parser.can_fetch(user_agent, url)


def enqueue(
    raw_url: str,
    queue: deque[str],
    enqueued: set[str],
    visited: set[str],
    config: SiteConfig,
    scope: str,
    *,
    base_url: str | None = None,
) -> None:
    normalized = normalize_url(raw_url, config, base_url=base_url)
    if normalized is None:
        return
    if scope == "jibiki" and not is_jibiki_relevant(normalized, config):
        return
    if normalized is None or normalized in enqueued or normalized in visited:
        return
    enqueued.add(normalized)
    queue.append(normalized)


def normalize_url(raw_url: str, config: SiteConfig, *, base_url: str | None = None) -> str | None:
    raw_url = raw_url.strip()
    if not raw_url or raw_url.startswith(("#", "mailto:", "javascript:", "tel:", "data:")):
        return None
    joined = urllib.parse.urljoin(base_url or config.start_urls[0], raw_url)
    split = urllib.parse.urlsplit(joined)
    if split.scheme not in {"http", "https"}:
        return None
    if split.netloc.lower() not in {host.lower() for host in config.allowed_hosts}:
        return None
    normalized_path = split.path or "/"
    if normalized_path != "/" and normalized_path.endswith("/"):
        normalized_path = normalized_path.rstrip("/") + "/"
    normalized_path = urllib.parse.quote(urllib.parse.unquote(normalized_path), safe="/-._~!$&'()*+,;=:@")
    query = urllib.parse.parse_qsl(split.query, keep_blank_values=True)
    filtered_query = [(k, v) for k, v in query if not TRACKING_QUERY_RE.search(k)]
    normalized_query = urllib.parse.urlencode(filtered_query, doseq=True)
    cleaned = split._replace(
        scheme=split.scheme.lower(),
        netloc=(config.canonical_host or split.netloc).lower(),
        path=normalized_path,
        fragment="",
        query=normalized_query,
    )
    return urllib.parse.urlunsplit(cleaned)


def is_jibiki_relevant(url: str, config: SiteConfig) -> bool:
    split = urllib.parse.urlsplit(url)
    path = urllib.parse.unquote(split.path or "/")
    query = urllib.parse.parse_qs(split.query, keep_blank_values=True)

    if config.id == "wanikani":
        return path.startswith(("/kanji/", "/vocabulary/", "/radicals/"))

    if config.id == "tanoshii_japanese":
        if not path.startswith("/dictionary/"):
            return False
        basename = Path(path).name.lower()
        if basename in {"entry_comments.cfm", "kanji_comments.cfm"}:
            return False
        return True

    if config.id == "kanshudo":
        if path == "/collections" or path.startswith("/collections/"):
            return True
        if path == "/component_details" or path.startswith("/component_details/"):
            return True
        if re.fullmatch(r"/kanji/[^/]+/?", path):
            return True
        if re.fullmatch(r"/word/[^/]+/?", path):
            return True
        return False

    if config.id == "kanjidraw":
        if path.startswith("/ru/"):
            return False
        return path.startswith(("/dictionary/", "/kana/", "/radicals/", "/collections/"))

    if config.id == "the_kanji_map":
        if path == "/about":
            return False
        return path.count("/") == 1 and len(path) > 1

    return True


def fetch_url(url: str, user_agent: str) -> dict[str, Any]:
    request = urllib.request.Request(url, headers={"User-Agent": user_agent})
    meta: dict[str, Any] = {"url": url}
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            body = response.read()
            meta.update(
                {
                    "status": response.getcode(),
                    "content_type": response.headers.get_content_type(),
                    "bytes": len(body),
                    "sha256": hashlib.sha256(body).hexdigest(),
                    "body": body,
                }
            )
    except urllib.error.HTTPError as exc:
        meta.update({"status": exc.code, "error": str(exc)})
    except urllib.error.URLError as exc:
        meta.update({"error": str(exc)})
    return meta


def collect_links(body: bytes) -> LinkCollector:
    parser = LinkCollector()
    parser.feed(body.decode("utf-8", errors="replace"))
    return parser


def extract_embedded_links(body: bytes) -> set[str]:
    text = body.decode("utf-8", errors="replace")
    return {match.group("url") for match in INLINE_URL_RE.finditer(text)}


def save_response(root: Path, url: str, body: bytes, content_type: Any) -> Path:
    path = local_path_for_url(root, url, content_type)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(body)
    return path


def local_path_for_url(root: Path, url: str, content_type: Any) -> Path:
    split = urllib.parse.urlsplit(url)
    host = split.netloc.lower()
    path = split.path or "/"
    suffix = Path(path).suffix.lower()
    if path.endswith("/") or not suffix:
        suffix = guess_suffix(content_type, default=".html")
        path = path.rstrip("/") + "/index" + suffix if path != "/" else "/index" + suffix
    query_suffix = ""
    if split.query:
        query_hash = hashlib.sha1(split.query.encode("utf-8")).hexdigest()[:10]
        stem = Path(path).stem
        ext = Path(path).suffix
        parent = str(Path(path).parent).replace("\\", "/")
        path = f"{parent}/{stem}__q_{query_hash}{ext}".replace("//", "/")
    return root / host / path.lstrip("/")


def guess_suffix(content_type: Any, *, default: str) -> str:
    value = str(content_type or "").lower()
    if "html" in value:
        return ".html"
    if "xml" in value:
        return ".xml"
    if "json" in value:
        return ".json"
    if "css" in value:
        return ".css"
    if "javascript" in value:
        return ".js"
    if "svg" in value:
        return ".svg"
    if "png" in value:
        return ".png"
    if "jpeg" in value:
        return ".jpg"
    if "webp" in value:
        return ".webp"
    if "gif" in value:
        return ".gif"
    if "plain" in value:
        return ".txt"
    return default


def append_jsonl(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=False) + "\n")


def load_visited(log_path: Path) -> set[str]:
    if not log_path.exists():
        return set()
    visited = set()
    for line in log_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        url = payload.get("url")
        status = payload.get("status")
        succeeded = isinstance(status, int) and 200 <= status < 400
        skipped = status == "skipped"
        if isinstance(url, str) and (succeeded or skipped):
            visited.add(url)
    return visited


def iso_now() -> str:
    return datetime.now(UTC).isoformat(timespec="seconds")


if __name__ == "__main__":
    raise SystemExit(main())
