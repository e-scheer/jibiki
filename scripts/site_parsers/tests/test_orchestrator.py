"""Tests for the extraction orchestrator, run against the real mirror.

No invented HTML: every case builds a small fetch log whose entries point at
files that really exist under ``var/site_mirror``, then runs
``extract_mirrored_content.extract_site`` into a temporary output root. Each
test names the orchestrator defect it pins down, so a regression says what
broke rather than only that something changed.

Run with ``python -m pytest scripts/site_parsers/tests/test_orchestrator.py`` from
the repo root, or directly with ``python
scripts/site_parsers/tests/test_orchestrator.py`` when pytest is not installed
in the active interpreter (the sibling parser tests do the same). Always set
``PYTHONIOENCODING=utf-8``: the console is cp1252 and dies on Japanese.
"""

from __future__ import annotations

import inspect
import json
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any

try:  # pytest is only present in the server uv environment
    import pytest
except ModuleNotFoundError:  # pragma: no cover - standalone runner path
    pytest = None  # type: ignore[assignment]


class Skipped(Exception):
    """Raised by :func:`skip` when running without pytest."""


def skip(reason: str) -> None:
    """Skip a test whether or not pytest is available."""
    if pytest is not None:
        pytest.skip(reason)
    raise Skipped(reason)


REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = REPO_ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import extract_mirrored_content as orchestrator  # noqa: E402

MIRROR_ROOT = REPO_ROOT / "var" / "site_mirror"

# Fixtures, all of them real urls of the current mirror.
KANSHUDO_ICHI = (
    "https://www.kanshudo.com/kanji/%E4%B8%80",
    "https://www.kanshudo.com/kanji/%E4%B8%80?section=readings",
    "https://www.kanshudo.com/kanji/%E4%B8%80?oq=&st=",
    "https://www.kanshudo.com/kanji/%E4%B8%80?oq=",
)
KANJIDRAW_REAL_KANJI = "https://kanjidraw.com/dictionary/%E6%AE%B5/"
KANJIDRAW_SHELL_KANJI = "https://kanjidraw.com/dictionary/%E4%B8%95/"
WANIKANI_KANJI = "https://www.wanikani.com/kanji/%E6%A1%9C"
WANIKANI_VOCABULARY = "https://www.wanikani.com/vocabulary/%E6%A1%9C"
TANOSHII_KANJI_CARDS = "https://www.tanoshiijapanese.com/dictionary/kanji.cfm?k=%E2%BA%8D"
TANOSHII_EMPTY_LIST = "https://www.tanoshiijapanese.com/dictionary/sentences.cfm"

_LOG_CACHE: dict[str, dict[str, dict[str, Any]]] = {}


def _log_index(site_id: str) -> dict[str, dict[str, Any]]:
    """Map url to its fetch-log entry, read once per site."""
    if site_id in _LOG_CACHE:
        return _LOG_CACHE[site_id]
    log_path = MIRROR_ROOT / site_id / "fetch_log.jsonl"
    index: dict[str, dict[str, Any]] = {}
    if log_path.exists():
        with log_path.open("r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                if not line.strip():
                    continue
                try:
                    payload = json.loads(line)
                except json.JSONDecodeError:
                    continue
                url = payload.get("url")
                if isinstance(url, str) and url not in index:
                    index[url] = payload
    _LOG_CACHE[site_id] = index
    return index


def entry_for(site_id: str, url: str, **overrides: Any) -> dict[str, Any]:
    """A real fetch-log entry, or skip the test when the mirror lacks it."""
    payload = _log_index(site_id).get(url)
    if payload is None:
        skip(f"{site_id} mirror does not contain {url}")
    saved_path = payload.get("saved_path")
    if not isinstance(saved_path, str) or not Path(saved_path).exists():
        skip(f"{site_id} mirror file for {url} is not on disk")
    entry = {
        "url": url,
        "status": 200,
        "content_type": "text/html",
        "bytes": payload.get("bytes") or Path(saved_path).stat().st_size,
        "sha256": payload.get("sha256"),
        "fetched_at": payload.get("fetched_at"),
        "saved_path": saved_path,
    }
    entry.update(overrides)
    return entry


def synthetic_entry(url: str, saved_path: str, byte_size: int) -> dict[str, Any]:
    return {
        "url": url,
        "status": 200,
        "content_type": "text/html",
        "bytes": byte_size,
        "sha256": None,
        "fetched_at": "2026-07-14T22:46:47+00:00",
        "saved_path": saved_path,
    }


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


class Run:
    """One orchestrator run and its four output files."""

    def __init__(self, site_id: str, root: Path, analysis: dict[str, Any]) -> None:
        self.site_id = site_id
        self.root = root
        self.analysis = analysis
        self.records = read_jsonl(root / site_id / "pages.jsonl")
        self.failures = read_jsonl(root / site_id / "failures.jsonl")
        self.needs_refetch = read_jsonl(root / site_id / "needs_refetch.jsonl")

    @property
    def counts(self) -> dict[str, Any]:
        return self.analysis["counts"]


def run_site(
    tmp_path: Path,
    site_id: str,
    entries: list[dict[str, Any]],
    **kwargs: Any,
) -> Run:
    tmp_path.mkdir(parents=True, exist_ok=True)
    log_path = tmp_path / f"{site_id}_fetch_log.jsonl"
    with log_path.open("w", encoding="utf-8", newline="\n") as handle:
        for entry in entries:
            handle.write(json.dumps(entry, ensure_ascii=False) + "\n")
    extract_root = tmp_path / "extract"
    analysis = orchestrator.extract_site(
        site_id,
        extract_root=extract_root,
        log_path=log_path,
        progress_every=0,
        quiet=True,
        **kwargs,
    )
    return Run(site_id, extract_root, analysis)


# --- deduplication ------------------------------------------------------------


def test_query_string_variants_collapse_into_one_record(tmp_path: Path) -> None:
    """Defect: 4665 paths were fetched several times and emitted several times.

    ``/kanji/一`` was mirrored four times because the crawl varied the query
    string (``?oq=&st=``, ``?oq=``, ``?section=readings``). Kanshudo emits no
    ``rel=canonical``, so identity has to come from ``dedupe_key``.
    """
    entries = [entry_for("kanshudo", url) for url in KANSHUDO_ICHI]
    run = run_site(tmp_path, "kanshudo", entries)

    assert len(run.records) == 1
    assert run.counts["pages_seen"] == 4
    assert run.counts["deduped_away"] == 3
    assert run.counts["pages_parsed"] == 1

    record = run.records[0]
    assert record["dedupe_key"] == "kanshudo:kanji:/kanji/一"
    assert len(record["duplicate_urls"]) == 3
    assert set(record["duplicate_urls"]) | {record["url"]} == set(KANSHUDO_ICHI)


def test_largest_fetch_of_a_duplicate_group_wins(tmp_path: Path) -> None:
    """A truncated sibling must never beat the complete fetch of the same entity."""
    entries = [entry_for("kanshudo", url) for url in KANSHUDO_ICHI]
    largest = max(entries, key=lambda entry: entry["bytes"])
    run = run_site(tmp_path, "kanshudo", entries)
    assert run.records[0]["url"] == largest["url"]

    # Order in the log must not decide it: reverse the log and expect the same winner.
    reversed_run = run_site(tmp_path / "reversed", "kanshudo", list(reversed(entries)))
    assert reversed_run.records[0]["url"] == largest["url"]


# --- crawl artifacts ----------------------------------------------------------


def test_homepage_shell_goes_to_needs_refetch_not_to_pages(tmp_path: Path) -> None:
    """Defect: 74.1% of kanjidraw dictionary pages are homepage copies.

    The old pipeline emitted them as empty kanji records carrying a false
    ``parse_notes`` claim that the data came from the preload JSON. They are
    refetchable artifacts, and that has to survive into the output.
    """
    run = run_site(
        tmp_path,
        "kanjidraw",
        [
            entry_for("kanjidraw", KANJIDRAW_REAL_KANJI),
            entry_for("kanjidraw", KANJIDRAW_SHELL_KANJI),
        ],
    )

    assert len(run.records) == 1
    assert run.records[0]["url"] == KANJIDRAW_REAL_KANJI
    assert run.counts["shells"] == 1
    assert run.counts["failures"] == 0

    refetch = run.needs_refetch
    assert len(refetch) == 1
    assert refetch[0]["url"] == KANJIDRAW_SHELL_KANJI
    assert refetch[0]["reason"] == "is_shell"
    assert refetch[0]["page_type"] == "kanji"
    # A shell is not a missing entry, so it never reaches the records file.
    assert all(record["url"] != KANJIDRAW_SHELL_KANJI for record in run.records)
    assert run.analysis["by_page_type"]["kanji"]["shells"] == 1


# --- failures -----------------------------------------------------------------


def test_parse_failure_is_recorded_and_does_not_stop_the_run(tmp_path: Path) -> None:
    """Defect: ``except Exception: return {}`` hid real breakage.

    A vocabulary url served the kanji document raises inside the module. The run
    must keep going and the failure must be written down with its exception type.
    """
    kanji = entry_for("wanikani", WANIKANI_KANJI)
    mismatched = synthetic_entry(WANIKANI_VOCABULARY, kanji["saved_path"], kanji["bytes"])
    run = run_site(tmp_path, "wanikani", [mismatched, kanji])

    assert len(run.records) == 1
    assert run.records[0]["page_type"] == "kanji"
    assert run.counts["failures"] == 1
    assert len(run.failures) == 1

    failure = run.failures[0]
    assert failure["url"] == WANIKANI_VOCABULARY
    assert failure["page_type"] == "vocabulary"
    assert failure["stage"] == "parse"
    assert failure["error_type"] == "WanikaniParseError"
    assert "reading-with-audio" in failure["error"]
    assert run.analysis["failures_by_error_type"] == {"WanikaniParseError": 1}
    assert run.analysis["by_page_type"]["vocabulary"]["failures"] == 1


def test_missing_mirror_file_is_a_failure_not_a_crash(tmp_path: Path) -> None:
    entries = [
        synthetic_entry(WANIKANI_KANJI, str(tmp_path / "gone" / "index.html"), 1000),
        entry_for("wanikani", "https://www.wanikani.com/radicals/tree"),
    ]
    run = run_site(tmp_path, "wanikani", entries)
    assert run.counts["failures"] == 1
    assert run.failures[0]["stage"] == "read_document"
    assert run.failures[0]["error_type"] == "FileNotFoundError"
    assert len(run.records) == 1


def test_an_alias_file_rescues_a_winner_whose_file_vanished(tmp_path: Path) -> None:
    """A dedupe group must not lose its entity because the largest file is gone."""
    real = entry_for("kanshudo", KANSHUDO_ICHI[0])
    ghost = synthetic_entry(
        KANSHUDO_ICHI[1], str(tmp_path / "vanished" / "index.html"), real["bytes"] + 10_000
    )
    run = run_site(tmp_path, "kanshudo", [real, ghost])
    assert run.counts["failures"] == 0
    assert len(run.records) == 1
    assert run.records[0]["saved_path"] == real["saved_path"]


def test_empty_result_page_is_not_reported_as_a_failure(tmp_path: Path) -> None:
    """``sentences.cfm`` with no query is a search form, not breakage."""
    run = run_site(tmp_path, "tanoshii_japanese", [entry_for("tanoshii_japanese", TANOSHII_EMPTY_LIST)])
    assert run.counts["failures"] == 0
    assert run.failures == []
    assert run.counts["pages_without_records"] == 1
    assert run.analysis["empty_pages"]["sample_urls"] == [TANOSHII_EMPTY_LIST]


# --- one page, many records ---------------------------------------------------


def test_a_card_list_page_emits_one_record_per_card(tmp_path: Path) -> None:
    """Defect: 767 ``kanji.cfm`` pages carry up to 20 full kanji cards each.

    Roughly 2271 kanji exist only as such a card, so collapsing the page to one
    record would drop them.
    """
    run = run_site(tmp_path, "tanoshii_japanese", [entry_for("tanoshii_japanese", TANOSHII_KANJI_CARDS)])

    assert run.counts["pages_parsed"] == 1
    assert len(run.records) > 1
    assert run.counts["records_emitted"] == len(run.records)
    assert {record["record_count"] for record in run.records} == {len(run.records)}
    assert sorted(record["record_index"] for record in run.records) == list(range(len(run.records)))
    assert len({record["dedupe_key"] for record in run.records}) == 1
    assert len({record["site_fields"]["character"] for record in run.records}) == len(run.records)


# --- envelope and provenance --------------------------------------------------


def test_record_envelope_carries_no_generic_page_chrome(tmp_path: Path) -> None:
    """Defect: headings, paragraphs, list items and dl pairs leaked nav chrome."""
    run = run_site(tmp_path, "wanikani", [entry_for("wanikani", WANIKANI_KANJI)])
    record = run.records[0]
    for name in ("headings", "paragraphs", "list_items", "definition_pairs", "debug_envelope"):
        assert name not in record
    assert "headings" not in record["site_fields"]
    assert set(record) >= {"site", "url", "page_type", "dedupe_key", "site_fields", "provenance"}


def test_debug_envelope_flag_restores_the_chrome_dump(tmp_path: Path) -> None:
    run = run_site(tmp_path, "wanikani", [entry_for("wanikani", WANIKANI_KANJI)], debug_envelope=True)
    envelope = run.records[0]["debug_envelope"]
    assert envelope["title"]
    assert envelope["headings"]
    assert isinstance(envelope["paragraphs"], list)
    assert isinstance(envelope["definition_pairs"], list)
    assert run.analysis["run"]["debug_envelope"] is True


def test_provenance_is_surfaced_and_reference_only_fields_are_counted(tmp_path: Path) -> None:
    """Defect: nothing said which fields may not ship.

    WaniKani mnemonics are Tofugu editorial content, so the module stamps them
    ``ship: reference-only`` and the orchestrator has to make that visible on the
    record and countable in the analysis.
    """
    run = run_site(tmp_path, "wanikani", [entry_for("wanikani", WANIKANI_KANJI)])
    record = run.records[0]

    provenance = record["provenance"]
    assert provenance["mnemonics"]["ship"] == "reference-only"
    assert provenance["character"]["ship"] == "allowed"
    assert "_provenance" not in record["site_fields"]
    assert "mnemonics" in record["reference_only_fields"]

    reference_only = run.analysis["reference_only"]
    assert reference_only["field_count"] == len(record["reference_only_fields"])
    assert reference_only["records_with_reference_only_fields"] == 1
    assert reference_only["by_field"]["mnemonics"] == 1


# --- planning and reporting ---------------------------------------------------


def test_non_extractable_pages_are_counted_and_never_opened(tmp_path: Path) -> None:
    """A utility route is skipped by page type, so its file is never read.

    The saved path here does not exist. If the orchestrator opened it anyway the
    run would record a failure, which is how a skipped route used to look like
    broken markup.
    """
    entries = [
        synthetic_entry("https://www.kanshudo.com/kanji/mastery", str(tmp_path / "nope.html"), 500),
        entry_for("kanshudo", KANSHUDO_ICHI[0]),
    ]
    run = run_site(tmp_path, "kanshudo", entries)
    assert run.counts["pages_skipped_page_type"] == 1
    assert run.counts["failures"] == 0
    assert len(run.records) == 1


def test_non_html_and_failed_fetches_are_excluded(tmp_path: Path) -> None:
    good = entry_for("wanikani", WANIKANI_KANJI)
    entries = [
        {**good, "status": 404},
        {**good, "content_type": "image/png"},
        good,
    ]
    run = run_site(tmp_path, "wanikani", entries)
    assert run.counts["pages_seen"] == 1
    assert run.counts["pages_not_usable"] == 2
    assert len(run.records) == 1


def test_limit_bounds_the_number_of_pages_parsed(tmp_path: Path) -> None:
    entries = [
        entry_for("wanikani", WANIKANI_KANJI),
        entry_for("wanikani", WANIKANI_VOCABULARY),
        entry_for("wanikani", "https://www.wanikani.com/radicals/tree"),
    ]
    run = run_site(tmp_path, "wanikani", entries, limit=2)
    assert run.counts["pages_parsed"] == 2
    assert run.analysis["run"]["pages_planned"] == 3
    assert run.analysis["run"]["complete"] is False

    full = run_site(tmp_path / "full", "wanikani", entries)
    assert full.analysis["run"]["complete"] is True
    assert full.counts["pages_parsed"] == 3


def test_analysis_reports_every_required_count(tmp_path: Path) -> None:
    run = run_site(
        tmp_path,
        "kanjidraw",
        [
            entry_for("kanjidraw", KANJIDRAW_REAL_KANJI),
            entry_for("kanjidraw", KANJIDRAW_SHELL_KANJI),
        ],
    )
    for name in (
        "pages_seen",
        "deduped_away",
        "shells",
        "failures",
        "records_emitted",
        "pages_skipped_page_type",
    ):
        assert name in run.counts, name
    assert "field_count" in run.analysis["reference_only"]
    assert run.analysis["by_page_type"]["kanji"] == {
        "seen": 2,
        "extractable": 2,
        "deduped_away": 0,
        "records": 1,
        "shells": 1,
        "failures": 0,
        "empty": 0,
    }
    outputs = run.analysis["outputs"]
    assert Path(outputs["pages"]).exists()
    assert Path(outputs["failures"]).exists()
    assert Path(outputs["needs_refetch"]).exists()


def test_rerunning_a_site_truncates_instead_of_appending(tmp_path: Path) -> None:
    entries = [entry_for("wanikani", WANIKANI_KANJI)]
    first = run_site(tmp_path, "wanikani", entries)
    second = run_site(tmp_path, "wanikani", entries)
    assert len(first.records) == len(second.records) == 1


# --- manifest -----------------------------------------------------------------


def test_manifest_registers_sites_that_were_not_in_this_run(tmp_path: Path) -> None:
    """Defect: the manifest listed only ``tanoshii_japanese`` after a --site run.

    It is rebuilt from the per-site analyses on disk, so a partial run can no
    longer make the other four sites look unextracted, and no manual edit is
    needed.
    """
    run = run_site(tmp_path, "wanikani", [entry_for("wanikani", WANIKANI_KANJI)])

    other = run.root / "kanshudo"
    other.mkdir(parents=True, exist_ok=True)
    (other / "analysis.json").write_text(
        json.dumps(
            {
                "generated_at": "2026-07-20T00:00:00+00:00",
                "run": {"complete": True, "limit": None},
                "counts": {
                    "pages_seen": 12634,
                    "pages_parsed": 5290,
                    "deduped_away": 7273,
                    "records_emitted": 5290,
                    "shells": 2,
                    "failures": 0,
                },
                "reference_only": {"field_count": 12},
                "outputs": {"pages": str(other / "pages.jsonl")},
            }
        ),
        encoding="utf-8",
    )

    manifest = orchestrator.build_manifest(run.root, ["wanikani"])
    assert set(manifest["sites"]) == {"wanikani", "kanshudo"}
    assert manifest["sites"]["wanikani"]["in_last_run"] is True
    assert manifest["sites"]["kanshudo"]["in_last_run"] is False
    assert manifest["sites"]["kanshudo"]["records_emitted"] == 5290
    assert manifest["sites_in_last_run"] == ["wanikani"]
    assert manifest["totals"]["deduped_away"] == 7273


def test_manifest_survives_an_unreadable_analysis(tmp_path: Path) -> None:
    broken = tmp_path / "extract" / "kanjidraw"
    broken.mkdir(parents=True, exist_ok=True)
    (broken / "analysis.json").write_text("{not json", encoding="utf-8")
    manifest = orchestrator.build_manifest(tmp_path / "extract", [])
    assert manifest["sites"]["kanjidraw"]["status"] == "unreadable_analysis"


def _main() -> int:  # pragma: no cover - standalone runner
    """Run every test without pytest, mirroring the sibling parser tests."""
    failures = 0
    for name, function in sorted(globals().items()):
        if not name.startswith("test_") or not callable(function):
            continue
        needs_tmp = "tmp_path" in inspect.signature(function).parameters
        tmp_dir = Path(tempfile.mkdtemp(prefix="jibiki_orch_")) if needs_tmp else None
        try:
            function(tmp_dir) if needs_tmp else function()
        except Skipped as reason:
            print(f"skip {name}: {reason}")
        except Exception as error:
            failures += 1
            print(f"FAIL {name}: {type(error).__name__}: {error}")
        else:
            print(f"ok   {name}")
        finally:
            if tmp_dir is not None:
                shutil.rmtree(tmp_dir, ignore_errors=True)
    print(f"{failures} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(_main())
