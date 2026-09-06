"""Per-site parsers for mirrored HTML snapshots.

Each site owns one module exposing the interface below. Keeping one module per
site is deliberate: the previous layout split every site's logic across
``parse_site_snapshots.py`` and ``extract_mirrored_content.py``, so a single
defect had to be fixed twice and usually was not.

Module interface
----------------

``SITE_ID: str``
    Mirror directory name under ``var/site_mirror``.

``infer_page_type(url: str) -> str``
    Route a url to a page type. Return ``"other"`` when nothing matches. Page
    type names are site-local and only need to agree with ``EXTRACTABLE``.

``EXTRACTABLE: frozenset[str]``
    Page types worth parsing. Everything else is counted and skipped.

``is_shell(tree, url) -> bool``
    True when the mirrored file is a crawl artifact rather than the requested
    page: a single-page-app shell, a login wall, or a soft 404. These are not
    missing entries, they need refetching, so the caller records them
    separately instead of emitting an empty record.

``dedupe_key(url: str, page_type: str) -> str``
    Identity of the underlying entity, used to collapse query-string variants
    that produced byte-identical mirror files. Must ignore incidental query
    parameters and normalise percent-encoding.

``parse(tree, url, page_type) -> dict | list[dict]``
    Extract ``site_fields``. Return a list to emit several records from one
    page, which index pages carrying a grid of full entity cards require.
    Raise on unexpected markup rather than returning a partial result: the
    caller records the failure. Never swallow exceptions locally, the previous
    ``except Exception: return {}`` hid real breakage.

Every textual field that came from marked-up prose must be emitted as the
JSON form of a ``common.RichText`` so role annotations survive. Every field
group must be declared in the returned ``_provenance`` mapping via
``common.build_provenance_map``, listing authored third-party prose separately
from factual data.
"""

from __future__ import annotations

from importlib import import_module
from types import ModuleType

SITE_MODULES = {
    "wanikani": "site_parsers.wanikani",
    "kanshudo": "site_parsers.kanshudo",
    "kanjidraw": "site_parsers.kanjidraw",
    "the_kanji_map": "site_parsers.the_kanji_map",
    "tanoshii_japanese": "site_parsers.tanoshii",
}

_CACHE: dict[str, ModuleType] = {}


def load(site_id: str) -> ModuleType:
    """Import and cache a site parser module."""
    if site_id not in SITE_MODULES:
        raise KeyError(f"no parser module registered for site {site_id!r}")
    if site_id not in _CACHE:
        _CACHE[site_id] = import_module(SITE_MODULES[site_id])
    return _CACHE[site_id]


def supported_sites() -> tuple[str, ...]:
    return tuple(SITE_MODULES)
