"""Extract structured content from the mirrored HTML snapshots.

This is the orchestrator. All markup knowledge lives in ``scripts/site_parsers``:
one module per site, exposing ``infer_page_type``, ``EXTRACTABLE``, ``is_shell``,
``dedupe_key`` and ``parse``. This file only decides which mirrored files to
open, in what order, what to do with the result, and what to report.

What it produces, per site, under ``var/site_extract/<site>/``:

``pages.jsonl``        one record per emitted entity (a page can emit several)
``failures.jsonl``     one record per page whose parse raised
``needs_refetch.jsonl``one record per crawl artifact that must be fetched again
``analysis.json``      counts for the run, per page type and in total

plus ``var/site_extract/manifest.json``, rebuilt from every site that has an
``analysis.json`` on disk so a ``--site`` run can never leave the manifest
claiming the other four sites do not exist.

The five defects this rewrite exists to fix
-------------------------------------------

**Staleness.** The previous run covered 5878 of 112487 mirrored pages (5.2%)
because it ran while the crawls were still going, and the manifest registered
only ``tanoshii_japanese`` because the last invocation passed ``--site``. The
manifest is now rebuilt from the processed sites on every run, and progress is
printed so a partial run is visible while it happens rather than months later.

**No deduplication.** 4665 mirrored paths have more than one successful HTML
fetch, because query-string variants (``?oq=&st=``, ``?oq=&amp%3Bst=``) were
saved as sibling byte-identical files. Re-extracting without dedupe emits about
7310 redundant records. ``rel=canonical`` cannot fix this: kanshudo emits none
at all. So identity comes from each module's ``dedupe_key``, the largest fetch
of a group wins (a truncated variant must never beat a complete one), and the
losing urls travel with the kept record as ``duplicate_urls``.

**Crawl artifacts treated as content.** 74.1% of kanjidraw's 26628 dictionary
pages are byte copies of the homepage. Emitting them as empty kanji records, as
the old pipeline did, also attached a ``parse_notes`` claim that the values came
from the preload JSON, which was false. Every page now goes through
``is_shell`` first, and an artifact is written to ``needs_refetch.jsonl``
instead. These are refetchable, not missing, and that distinction survives into
the output.

**Silent failures.** The old ``except Exception: return {}`` hid real breakage,
and it also meant the generic fallback never ran after an exception, so the
record was empty either way. The site modules now raise deliberately. Every
failure is recorded with its url, page type, exception type and message,
counted in ``analysis.json``, and summarised loudly at the end of the run.

**One page, many records.** A tanoshii ``kanji.cfm`` page carries up to 20 full
kanji cards, and 767 of them exist, holding roughly 2271 kanji that have no
detail page in the mirror. ``parse`` may therefore return a list, and both
shapes are handled.

Envelope chrome is gone. The old record stored ``headings``, ``paragraphs``,
``list_items`` and ``definition_pairs`` scraped from the whole document, which
for most sites was navigation, cookie banners and level menus, and it leaked
into content. The site modules now produce structured fields, so that dump has
no consumer. It is available behind ``--debug-envelope`` for markup spelunking
and nothing else.

Usage:

    python scripts/extract_mirrored_content.py
    python scripts/extract_mirrored_content.py --site kanjidraw --limit 200
    python scripts/extract_mirrored_content.py --jobs 8

Always set ``PYTHONIOENCODING=utf-8``: the Windows console is cp1252 and dies on
Japanese text. The script also reconfigures its own streams defensively.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import traceback
import urllib.parse
from collections import Counter
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Iterable, Iterator

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from site_parsers import load, supported_sites  # noqa: E402
from site_parsers.common import parse_document, plain_text  # noqa: E402

ROOT = SCRIPTS_DIR.parent
MIRROR_ROOT = ROOT / "var" / "site_mirror"
EXTRACT_ROOT = ROOT / "var" / "site_extract"
SUPPORTED_SITES = supported_sites()

MANIFEST_SCHEMA = "jibiki-mirror-extract/2"
ANALYSIS_SCHEMA = "jibiki-mirror-site-analysis/2"
RECORD_SCHEMA = "jibiki-mirror-page/2"

# A run where a large share of pages raises is a broken run, not a thin one, so
# it gets a banner rather than a line buried in the counts.
LOUD_FAILURE_RATE = 0.02

SHIP_REFERENCE_ONLY = "reference-only"


# --- io helpers ---------------------------------------------------------------


def configure_streams() -> None:
    """Force utf-8 on stdout and stderr so Japanese text cannot kill the run."""
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is None:
            continue
        try:
            reconfigure(encoding="utf-8", errors="replace")
        except (ValueError, OSError):  # pragma: no cover - depends on the console
            pass


def iso_now() -> str:
    return datetime.now(UTC).isoformat(timespec="seconds")


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


class JsonlWriter:
    """Append-only jsonl sink, opened once instead of once per record.

    The previous version reopened the file for every single record, which on
    112487 pages is 112487 opens. It also truncates on entry, so a rerun cannot
    silently double a file.
    """

    def __init__(self, path: Path) -> None:
        self.path = path
        self.count = 0
        path.parent.mkdir(parents=True, exist_ok=True)
        self._handle = path.open("w", encoding="utf-8", newline="\n")

    def write(self, payload: dict[str, Any]) -> None:
        self._handle.write(json.dumps(payload, ensure_ascii=False) + "\n")
        self.count += 1
        if self.count % 500 == 0:
            self._handle.flush()

    def close(self) -> None:
        self._handle.flush()
        self._handle.close()

    def __enter__(self) -> "JsonlWriter":
        return self

    def __exit__(self, *_exc: object) -> None:
        self.close()


def iter_log_entries(log_path: Path, stats: Counter[str]) -> Iterator[dict[str, Any]]:
    """Stream a fetch log line by line.

    Never ``read_text().splitlines()``: the tanoshii log alone is 68794 lines
    and the point of this pass is to stay cheap enough to run twice.
    """
    if not log_path.exists():
        return
    with log_path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if not line.strip():
                continue
            try:
                payload = json.loads(line)
            except json.JSONDecodeError:
                stats["log_lines_malformed"] += 1
                continue
            if isinstance(payload, dict):
                stats["log_lines"] += 1
                yield payload


def is_successful_html(entry: dict[str, Any]) -> bool:
    status = entry.get("status")
    if not (isinstance(status, int) and 200 <= status < 400):
        return False
    if not str(entry.get("content_type", "")).startswith("text/html"):
        return False
    return isinstance(entry.get("saved_path"), str) and bool(entry["saved_path"])


def route_key(site_id: str, url: str) -> str:
    """Coarse route label, for a per-route sanity column in the analysis."""
    path = urllib.parse.unquote(urllib.parse.urlsplit(url).path or "/")
    if site_id == "tanoshii_japanese" and path.startswith("/dictionary/"):
        return path.rsplit("/", 1)[-1].lower() or "/dictionary/"
    segments = [segment for segment in path.split("/") if segment]
    return segments[0] if segments else "/"


# --- planning pass ------------------------------------------------------------


@dataclass(slots=True)
class Candidate:
    """One entity to parse, plus the alias fetches that collapsed into it."""

    url: str
    saved_path: str
    fetched_at: str | None
    byte_size: int
    sha256: str | None
    page_type: str
    dedupe_key: str
    duplicate_urls: list[str] = field(default_factory=list)
    alias_paths: list[str] = field(default_factory=list)


@dataclass(slots=True)
class SitePlan:
    order: list[str]
    candidates: dict[str, Candidate]
    stats: Counter[str]
    page_type_seen: Counter[str]
    page_type_extractable: Counter[str]
    page_type_deduped: Counter[str]
    route_seen: Counter[str]


def plan_site(site_id: str, log_path: Path) -> SitePlan:
    """Read the fetch log and decide which files are worth opening.

    This pass touches no HTML at all. It exists so that dedupe happens before
    parsing rather than after: the alternative is parsing 7310 pages whose
    output is then thrown away, and it is also the only way a kept record can
    carry the alias urls that collapsed into it.

    Winner selection is largest-fetch-wins with the log order as tie-break. Byte
    size beats first-seen because the duplicate groups here come from
    query-string permutations of the same crawl, so a smaller sibling is either
    identical (tie, first wins) or a truncated fetch, which must never win.
    """
    module = load(site_id)
    stats: Counter[str] = Counter()
    page_type_seen: Counter[str] = Counter()
    page_type_extractable: Counter[str] = Counter()
    page_type_deduped: Counter[str] = Counter()
    route_seen: Counter[str] = Counter()
    order: list[str] = []
    candidates: dict[str, Candidate] = {}

    for entry in iter_log_entries(log_path, stats):
        if not is_successful_html(entry):
            stats["pages_not_usable"] += 1
            continue
        url = str(entry.get("url") or "")
        if not url:
            stats["pages_not_usable"] += 1
            continue
        stats["pages_seen"] += 1
        route_seen[route_key(site_id, url)] += 1

        try:
            page_type = module.infer_page_type(url)
        except Exception:  # noqa: BLE001 - a router must never end the run
            stats["page_type_errors"] += 1
            page_type = "other"
        page_type_seen[page_type] += 1
        if page_type not in module.EXTRACTABLE:
            stats["pages_skipped_page_type"] += 1
            continue
        stats["pages_extractable"] += 1
        page_type_extractable[page_type] += 1

        try:
            key = module.dedupe_key(url, page_type)
        except Exception:  # noqa: BLE001
            stats["dedupe_key_errors"] += 1
            key = f"{page_type}:{url}"

        byte_size = entry.get("bytes")
        byte_size = byte_size if isinstance(byte_size, int) else 0
        saved_path = str(entry["saved_path"])
        existing = candidates.get(key)
        if existing is None:
            candidates[key] = Candidate(
                url=url,
                saved_path=saved_path,
                fetched_at=entry.get("fetched_at"),
                byte_size=byte_size,
                sha256=entry.get("sha256"),
                page_type=page_type,
                dedupe_key=key,
            )
            order.append(key)
            continue

        stats["deduped_away"] += 1
        page_type_deduped[page_type] += 1
        if byte_size > existing.byte_size:
            existing.duplicate_urls.append(existing.url)
            existing.alias_paths.append(existing.saved_path)
            existing.url = url
            existing.saved_path = saved_path
            existing.fetched_at = entry.get("fetched_at")
            existing.byte_size = byte_size
            existing.sha256 = entry.get("sha256")
        else:
            existing.duplicate_urls.append(url)
            existing.alias_paths.append(saved_path)

    return SitePlan(
        order=order,
        candidates=candidates,
        stats=stats,
        page_type_seen=page_type_seen,
        page_type_extractable=page_type_extractable,
        page_type_deduped=page_type_deduped,
        route_seen=route_seen,
    )


# --- per page work ------------------------------------------------------------

# Plain tuples cross the process boundary, so nothing depends on a dataclass
# defined in __main__ being importable in a spawned worker.
Payload = tuple[
    str,  # site id
    str,  # url
    str,  # saved path
    str | None,  # fetched at
    str,  # page type
    str,  # dedupe key
    tuple[str, ...],  # duplicate urls
    tuple[str, ...],  # alias saved paths
    int,  # bytes
    str | None,  # sha256
    bool,  # debug envelope
]


def payload_of(site_id: str, candidate: Candidate, debug_envelope: bool) -> Payload:
    return (
        site_id,
        candidate.url,
        candidate.saved_path,
        candidate.fetched_at,
        candidate.page_type,
        candidate.dedupe_key,
        tuple(candidate.duplicate_urls),
        tuple(candidate.alias_paths),
        candidate.byte_size,
        candidate.sha256,
        debug_envelope,
    )


def failure_entry(
    *,
    site_id: str,
    url: str,
    saved_path: str,
    page_type: str,
    dedupe_key: str,
    stage: str,
    error: BaseException,
) -> dict[str, Any]:
    """One failure row.

    The traceback tail is kept because "kanshudo reading row without a type
    label" is only actionable together with the line that raised it, and a
    failure list nobody can act on is the same silence in a different file.
    """
    tail = "".join(traceback.format_exception(type(error), error, error.__traceback__))
    return {
        "site": site_id,
        "url": url,
        "saved_path": saved_path,
        "page_type": page_type,
        "dedupe_key": dedupe_key,
        "stage": stage,
        "error_type": type(error).__name__,
        "error": str(error)[:2000],
        "traceback": tail[-2000:],
    }


def debug_envelope_of(tree: Any) -> dict[str, Any]:
    """The old generic dump, behind a flag and never on by default.

    On most sites these lists were navigation, cookie banners and level menus.
    They are kept only as a spelunking aid when a site module needs writing
    against unfamiliar markup.
    """

    def texts(xpath: str) -> list[str]:
        values: list[str] = []
        seen: set[str] = set()
        for node in tree.xpath(xpath):
            text = plain_text(node) if hasattr(node, "tag") else str(node).strip()
            if not text or text in seen:
                continue
            seen.add(text)
            values.append(text)
        return values

    pairs: list[dict[str, str]] = []
    for term in tree.xpath("//dt"):
        sibling = term.getnext()
        if sibling is None or not isinstance(sibling.tag, str) or sibling.tag.lower() != "dd":
            continue
        key = plain_text(term)
        value = plain_text(sibling)
        if key and value:
            pairs.append({"term": key, "value": value})

    canonical = tree.xpath("//link[@rel='canonical']/@href")
    description = tree.xpath("//meta[@name='description']/@content")
    return {
        "title": plain_text(next(iter(tree.iter("title")), None)) or None,
        "h1": (texts("//h1") or [None])[0],
        "canonical": str(canonical[0]).strip() if canonical else None,
        "meta_description": str(description[0]).strip() if description else None,
        "headings": texts("//h1|//h2|//h3"),
        "paragraphs": texts("//p"),
        "list_items": texts("//li"),
        "definition_pairs": pairs,
    }


def reference_only_fields(provenance: Any) -> list[str]:
    """Field names a provenance map marks as not shippable."""
    if not isinstance(provenance, dict):
        return []
    return sorted(
        name
        for name, stamp in provenance.items()
        if isinstance(stamp, dict) and stamp.get("ship") == SHIP_REFERENCE_ONLY
    )


def build_record(
    *,
    site_id: str,
    url: str,
    saved_path: str,
    fetched_at: str | None,
    page_type: str,
    dedupe_key: str,
    duplicate_urls: tuple[str, ...],
    fields: dict[str, Any],
    index: int,
    total: int,
    envelope: dict[str, Any] | None,
) -> dict[str, Any]:
    """Wrap parser output in the transport envelope.

    Deliberately thin. The site fields are the payload, the provenance map is
    lifted to the top level so a consumer can refuse to ship a record without
    walking into ``site_fields``, and nothing generic is scraped off the page.
    """
    payload = dict(fields)
    provenance = payload.pop("_provenance", None)
    record: dict[str, Any] = {
        "schema": RECORD_SCHEMA,
        "site": site_id,
        "url": url,
        "saved_path": saved_path,
        "fetched_at": fetched_at,
        "page_type": page_type,
        "dedupe_key": dedupe_key,
        "duplicate_urls": list(duplicate_urls),
        "record_index": index,
        "record_count": total,
        "site_fields": payload,
        "provenance": provenance,
        "reference_only_fields": reference_only_fields(provenance),
    }
    if envelope is not None:
        record["debug_envelope"] = envelope
    return record


def read_document(saved_path: str, alias_paths: Iterable[str]) -> tuple[Any, str]:
    """Parse the mirrored file, falling back to an alias fetch of the same entity.

    A dedupe group can have a winner whose file is gone while a sibling is still
    on disk, and losing the entity over that would be a self-inflicted gap.
    """
    tried: list[str] = []
    last_error: Exception | None = None
    for path in [saved_path, *alias_paths]:
        if path in tried:
            continue
        tried.append(path)
        candidate = Path(path)
        if not candidate.exists():
            continue
        try:
            text = candidate.read_text(encoding="utf-8", errors="replace")
            return parse_document(text), path
        except Exception as error:  # noqa: BLE001 - reported as a failure row
            last_error = error
    if last_error is not None:
        raise last_error
    raise FileNotFoundError(f"no mirrored file on disk for {saved_path}")


def process_payload(payload: Payload) -> dict[str, Any]:
    """Parse one entity. Returns an outcome, never raises.

    Runs in the parent process by default and in a worker process when
    ``--jobs`` is above one, so it takes and returns plain data only.
    """
    (
        site_id,
        url,
        saved_path,
        fetched_at,
        page_type,
        dedupe_key,
        duplicate_urls,
        alias_paths,
        byte_size,
        sha256,
        debug_envelope,
    ) = payload

    def failure(stage: str, error: BaseException) -> dict[str, Any]:
        return {
            "kind": "failure",
            "page_type": page_type,
            "failure": failure_entry(
                site_id=site_id,
                url=url,
                saved_path=saved_path,
                page_type=page_type,
                dedupe_key=dedupe_key,
                stage=stage,
                error=error,
            ),
        }

    try:
        module = load(site_id)
    except Exception as error:  # noqa: BLE001
        return failure("load_module", error)

    try:
        tree, used_path = read_document(saved_path, alias_paths)
    except Exception as error:  # noqa: BLE001
        return failure("read_document", error)

    try:
        if module.is_shell(tree, url):
            return {
                "kind": "shell",
                "page_type": page_type,
                "needs_refetch": {
                    "site": site_id,
                    "url": url,
                    "saved_path": used_path,
                    "page_type": page_type,
                    "dedupe_key": dedupe_key,
                    "duplicate_urls": list(duplicate_urls),
                    "bytes": byte_size,
                    "sha256": sha256,
                    "reason": "is_shell",
                    "detail": (
                        "the mirrored file is a crawl artifact (app shell, login wall or "
                        "soft 404), so this url is refetchable and not a missing entity"
                    ),
                },
            }
    except Exception as error:  # noqa: BLE001
        return failure("is_shell", error)

    try:
        parsed = module.parse(tree, url, page_type)
    except Exception as error:  # noqa: BLE001
        return failure("parse", error)

    if isinstance(parsed, dict):
        items = [parsed]
    elif isinstance(parsed, list):
        items = [item for item in parsed if isinstance(item, dict)]
    else:
        return failure("parse", TypeError(f"parse returned {type(parsed).__name__}, not a dict or list"))

    if not items:
        # A list route can legitimately have no cards: tanoshii serves
        # ``sentences.cfm`` with no query as a bare search form, and
        # ``kanji.cfm?grade=7`` asks for a grade bucket that does not exist. That
        # is neither an exception nor a crawl artifact, so it gets its own
        # outcome instead of being filed as a parse failure (which would make the
        # failure list unactionable) or dropped in silence.
        return {"kind": "empty", "page_type": page_type, "url": url}

    envelope = debug_envelope_of(tree) if debug_envelope else None
    records = [
        build_record(
            site_id=site_id,
            url=url,
            saved_path=used_path,
            fetched_at=fetched_at,
            page_type=page_type,
            dedupe_key=dedupe_key,
            duplicate_urls=duplicate_urls,
            fields=item,
            index=index,
            total=len(items),
            envelope=envelope,
        )
        for index, item in enumerate(items)
    ]
    return {"kind": "records", "page_type": page_type, "records": records}


# --- per site driver ----------------------------------------------------------


def iter_outcomes(payloads: list[Payload], jobs: int) -> Iterator[dict[str, Any]]:
    """Outcomes in candidate order, sequentially or across worker processes."""
    if jobs <= 1 or len(payloads) <= 1:
        for payload in payloads:
            yield process_payload(payload)
        return
    from concurrent.futures import ProcessPoolExecutor

    chunk = max(1, min(64, len(payloads) // (jobs * 4) or 1))
    with ProcessPoolExecutor(max_workers=jobs) as pool:
        yield from pool.map(process_payload, payloads, chunksize=chunk)


def extract_site(
    site_id: str,
    *,
    limit: int | None = None,
    jobs: int = 1,
    debug_envelope: bool = False,
    progress_every: int = 250,
    extract_root: Path | None = None,
    log_path: Path | None = None,
    quiet: bool = False,
) -> dict[str, Any]:
    """Extract one site and write its four output files."""
    started = time.monotonic()
    extract_root = extract_root or EXTRACT_ROOT
    log_path = log_path or (MIRROR_ROOT / site_id / "fetch_log.jsonl")
    output_root = extract_root / site_id
    output_root.mkdir(parents=True, exist_ok=True)

    def say(message: str) -> None:
        if not quiet:
            print(message, flush=True)

    say(f"[{site_id}] planning from {log_path}")
    plan = plan_site(site_id, log_path)
    keys = plan.order if limit is None else plan.order[:limit]
    total = len(keys)
    say(
        f"[{site_id}] {plan.stats['pages_seen']} pages seen, "
        f"{plan.stats['pages_extractable']} extractable, "
        f"{plan.stats['deduped_away']} deduped away, {total} to parse"
        + (f" (limited from {len(plan.order)})" if limit is not None else "")
    )

    records_by_type: Counter[str] = Counter()
    shells_by_type: Counter[str] = Counter()
    failures_by_type: Counter[str] = Counter()
    failures_by_error: Counter[str] = Counter()
    empty_by_type: Counter[str] = Counter()
    empty_samples: list[str] = []
    reference_only_by_field: Counter[str] = Counter()
    counts: Counter[str] = Counter()

    pages_path = output_root / "pages.jsonl"
    failures_path = output_root / "failures.jsonl"
    refetch_path = output_root / "needs_refetch.jsonl"

    payloads = [payload_of(site_id, plan.candidates[key], debug_envelope) for key in keys]

    with (
        JsonlWriter(pages_path) as pages,
        JsonlWriter(failures_path) as failures,
        JsonlWriter(refetch_path) as refetch,
    ):
        for processed, outcome in enumerate(iter_outcomes(payloads, jobs), start=1):
            page_type = str(outcome.get("page_type") or "other")
            kind = outcome.get("kind")
            if kind == "records":
                for record in outcome["records"]:
                    pages.write(record)
                    names = record.get("reference_only_fields") or []
                    if names:
                        counts["records_with_reference_only"] += 1
                        for name in names:
                            reference_only_by_field[name] += 1
                records_by_type[page_type] += len(outcome["records"])
                counts["records_emitted"] += len(outcome["records"])
                counts["pages_with_records"] += 1
            elif kind == "shell":
                refetch.write(outcome["needs_refetch"])
                shells_by_type[page_type] += 1
                counts["shells"] += 1
            elif kind == "empty":
                empty_by_type[page_type] += 1
                counts["pages_without_records"] += 1
                if len(empty_samples) < 20:
                    empty_samples.append(str(outcome.get("url") or ""))
            else:
                entry = outcome.get("failure") or {}
                failures.write(entry)
                failures_by_type[page_type] += 1
                failures_by_error[str(entry.get("error_type") or "Exception")] += 1
                counts["failures"] += 1

            if progress_every and processed % progress_every == 0:
                elapsed = max(time.monotonic() - started, 1e-6)
                say(
                    f"[{site_id}] {processed}/{total} parsed, "
                    f"records {counts['records_emitted']}, "
                    f"shells {counts['shells']}, failures {counts['failures']}, "
                    f"{processed / elapsed:.0f} pages/s"
                )

    duration = time.monotonic() - started
    page_types = sorted(
        set(plan.page_type_seen)
        | set(records_by_type)
        | set(shells_by_type)
        | set(failures_by_type)
        | set(empty_by_type)
    )
    by_page_type = {
        page_type: {
            "seen": plan.page_type_seen.get(page_type, 0),
            "extractable": plan.page_type_extractable.get(page_type, 0),
            "deduped_away": plan.page_type_deduped.get(page_type, 0),
            "records": records_by_type.get(page_type, 0),
            "shells": shells_by_type.get(page_type, 0),
            "failures": failures_by_type.get(page_type, 0),
            "empty": empty_by_type.get(page_type, 0),
        }
        for page_type in page_types
    }

    reference_only_total = sum(reference_only_by_field.values())
    analysis = {
        "schema": ANALYSIS_SCHEMA,
        "site": site_id,
        "generated_at": iso_now(),
        "source_log": str(log_path),
        "duration_seconds": round(duration, 2),
        "run": {
            "limit": limit,
            "jobs": jobs,
            "debug_envelope": debug_envelope,
            "pages_planned": len(plan.order),
            "pages_parsed": total,
            "complete": limit is None or limit >= len(plan.order),
        },
        "counts": {
            "log_lines": plan.stats["log_lines"],
            "log_lines_malformed": plan.stats["log_lines_malformed"],
            "pages_seen": plan.stats["pages_seen"],
            "pages_not_usable": plan.stats["pages_not_usable"],
            "pages_skipped_page_type": plan.stats["pages_skipped_page_type"],
            "pages_extractable": plan.stats["pages_extractable"],
            "deduped_away": plan.stats["deduped_away"],
            "pages_parsed": total,
            "pages_with_records": counts["pages_with_records"],
            "records_emitted": counts["records_emitted"],
            "shells": counts["shells"],
            "failures": counts["failures"],
            "pages_without_records": counts["pages_without_records"],
            "page_type_errors": plan.stats["page_type_errors"],
            "dedupe_key_errors": plan.stats["dedupe_key_errors"],
        },
        "rates": {
            "failure_rate_of_parsed": round(counts["failures"] / total, 4) if total else 0.0,
            "shell_rate_of_parsed": round(counts["shells"] / total, 4) if total else 0.0,
        },
        "by_page_type": by_page_type,
        "page_type_counts": dict(plan.page_type_seen.most_common()),
        "route_counts": dict(plan.route_seen.most_common()),
        "failures_by_error_type": dict(failures_by_error.most_common()),
        # Pages that parsed cleanly and had nothing on them: an empty search
        # result, not an exception and not an artifact. Counted so they stay
        # visible without polluting the failure list.
        "empty_pages": {
            "count": counts["pages_without_records"],
            "by_page_type": dict(empty_by_type.most_common()),
            "sample_urls": empty_samples,
        },
        "reference_only": {
            "field_count": reference_only_total,
            "records_with_reference_only_fields": counts["records_with_reference_only"],
            "by_field": dict(reference_only_by_field.most_common()),
        },
        "outputs": {
            "pages": str(pages_path),
            "failures": str(failures_path),
            "needs_refetch": str(refetch_path),
        },
    }
    write_json(output_root / "analysis.json", analysis)

    say(
        f"[{site_id}] done in {duration:.1f}s: {counts['records_emitted']} records, "
        f"{counts['shells']} need refetch, {counts['failures']} failures"
    )
    if counts["failures"]:
        rate = counts["failures"] / total if total else 0.0
        marker = "!! " if rate >= LOUD_FAILURE_RATE else ""
        say(
            f"{marker}[{site_id}] {counts['failures']} pages failed to parse "
            f"({rate:.1%} of parsed): {failures_path}"
        )
        for error_type, number in failures_by_error.most_common(5):
            say(f"{marker}[{site_id}]   {number} x {error_type}")
    if counts["pages_without_records"]:
        say(
            f"[{site_id}] {counts['pages_without_records']} pages parsed to no record "
            "(empty list or search page), see analysis.empty_pages"
        )
    if reference_only_total:
        say(
            f"[{site_id}] {reference_only_total} reference-only field values across "
            f"{counts['records_with_reference_only']} records: these may not ship"
        )
    return analysis


# --- manifest -----------------------------------------------------------------


def build_manifest(extract_root: Path, processed: Iterable[str]) -> dict[str, Any]:
    """Rebuild the manifest from every site that has an analysis on disk.

    Rebuilt, not merged into: the previous manifest registered only
    ``tanoshii_japanese`` because the last run passed ``--site``, which made the
    top-level file claim four sites had never been extracted. Reading the
    per-site analyses back means a partial run can no longer lie about the
    others, and no manual edit is ever needed.
    """
    processed = set(processed)
    sites: dict[str, Any] = {}
    for site_id in SUPPORTED_SITES:
        analysis_path = extract_root / site_id / "analysis.json"
        if not analysis_path.exists():
            continue
        try:
            analysis = json.loads(analysis_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            sites[site_id] = {"status": "unreadable_analysis", "analysis": str(analysis_path)}
            continue
        counts = analysis.get("counts") or {}
        run = analysis.get("run") or {}
        sites[site_id] = {
            "generated_at": analysis.get("generated_at"),
            "in_last_run": site_id in processed,
            "complete": run.get("complete"),
            "limit": run.get("limit"),
            "pages_seen": counts.get("pages_seen"),
            "pages_parsed": counts.get("pages_parsed"),
            "deduped_away": counts.get("deduped_away"),
            "records_emitted": counts.get("records_emitted"),
            "shells": counts.get("shells"),
            "failures": counts.get("failures"),
            "pages_without_records": counts.get("pages_without_records"),
            "reference_only_field_count": (analysis.get("reference_only") or {}).get("field_count"),
            "analysis": str(analysis_path),
            "pages": (analysis.get("outputs") or {}).get("pages"),
            "needs_refetch": (analysis.get("outputs") or {}).get("needs_refetch"),
            "failures_log": (analysis.get("outputs") or {}).get("failures"),
        }

    totals = Counter()
    for payload in sites.values():
        for name in ("pages_seen", "pages_parsed", "deduped_away", "records_emitted", "shells", "failures"):
            value = payload.get(name)
            if isinstance(value, int):
                totals[name] += value
    return {
        "schema": MANIFEST_SCHEMA,
        "generated_at": iso_now(),
        "mirror_root": str(MIRROR_ROOT),
        "sites_in_last_run": sorted(processed),
        "totals": dict(totals),
        "sites": sites,
    }


# --- cli ----------------------------------------------------------------------


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract structured content from the mirrored site snapshots.",
    )
    parser.add_argument(
        "--site",
        action="append",
        dest="sites",
        choices=SUPPORTED_SITES,
        help="site to extract, repeatable. Default: all five.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="parse at most N entities per site, for smoke runs.",
    )
    parser.add_argument(
        "--jobs",
        type=int,
        default=1,
        help="parse in N worker processes. 1 keeps everything in this process.",
    )
    parser.add_argument(
        "--debug-envelope",
        action="store_true",
        help="also store the generic headings/paragraphs/list dump. Off by default: it is nav chrome.",
    )
    parser.add_argument(
        "--progress-every",
        type=int,
        default=250,
        help="print a progress line every N parsed pages. 0 disables it.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    configure_streams()
    args = parse_args(argv)
    if args.limit is not None and args.limit <= 0:
        print("--limit must be positive", file=sys.stderr)
        return 2
    if args.jobs < 1:
        print("--jobs must be at least 1", file=sys.stderr)
        return 2

    sites = args.sites or list(SUPPORTED_SITES)
    EXTRACT_ROOT.mkdir(parents=True, exist_ok=True)

    processed: list[str] = []
    failed_sites: dict[str, str] = {}
    started = time.monotonic()
    for site_id in sites:
        log_path = MIRROR_ROOT / site_id / "fetch_log.jsonl"
        if not log_path.exists():
            print(f"[{site_id}] no fetch log at {log_path}, skipping", flush=True)
            failed_sites[site_id] = "missing fetch log"
            continue
        try:
            extract_site(
                site_id,
                limit=args.limit,
                jobs=args.jobs,
                debug_envelope=args.debug_envelope,
                progress_every=max(0, args.progress_every),
            )
        except Exception as error:  # noqa: BLE001 - one site must not end the run
            failed_sites[site_id] = f"{type(error).__name__}: {error}"
            print(f"!! [{site_id}] site extraction aborted: {type(error).__name__}: {error}", flush=True)
            traceback.print_exc()
            continue
        processed.append(site_id)

    manifest = build_manifest(EXTRACT_ROOT, processed)
    if failed_sites:
        manifest["sites_not_extracted"] = failed_sites
    write_json(EXTRACT_ROOT / "manifest.json", manifest)
    totals = manifest["totals"]
    print(
        f"Wrote {EXTRACT_ROOT / 'manifest.json'} in {time.monotonic() - started:.1f}s: "
        f"{totals.get('records_emitted', 0)} records, "
        f"{totals.get('deduped_away', 0)} deduped away, "
        f"{totals.get('shells', 0)} need refetch, "
        f"{totals.get('failures', 0)} failures across {len(manifest['sites'])} sites",
        flush=True,
    )
    return 1 if failed_sites else 0


if __name__ == "__main__":
    raise SystemExit(main())
