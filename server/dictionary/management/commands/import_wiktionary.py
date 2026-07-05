"""Import kanji *glyph origin* (etymology) from the English Wiktionary API.

Wiktionary's rendered "Glyph origin" section is the cleanest free source of the
"why does this character look like this" story: whether it is a **pictogram**
(象形), an **ideogrammic compound** (会意), or — most usefully for learners — a
**phono-semantic compound** (形声/keisei), where one component carries the meaning
and another is present only for its *sound* (the 音符 / phonetic). We fetch the
parsed HTML, isolate that section, strip it to readable prose, and store it on
``Kanji.origin`` together with a coarse ``formation`` tag and the ``phonetic``
component when the text names one.

Scope defaults to the JLPT ∪ Jōyō set (~2.2k kanji) to stay polite; ``--all``
covers every kanji. Idempotent: skips kanji that already have an origin unless
``--force``. A ~1s delay + 429 backoff keeps us within Wiktionary's etiquette.
Content is CC BY-SA 4.0 — the app attributes Wiktionary in the origin section.

    python manage.py import_wiktionary                 # JLPT ∪ grade<=8
    python manage.py import_wiktionary --limit 20      # smoke test
    python manage.py import_wiktionary --all --force
"""

from __future__ import annotations

import html
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request

from django.core.management.base import BaseCommand
from django.db.models import Q

from dictionary.models import Kanji

API = "https://en.wiktionary.org/w/api.php"
# Wiktionary asks for a descriptive User-Agent identifying the tool + a contact.
UA = "jibiki-dev/0.1 (kanji etymology importer; contact e.scheer@deuse.be)"

# The Glyph-origin section header carries id="Glyph_origin"; capture everything up
# to the next heading (h2/h3/h4 or the modern mw-heading wrapper div).
_SECTION_RE = re.compile(
    r'id="Glyph_origin".*?</h[34]>(.*?)(<h[234]|<div class="mw-heading)', re.S
)
_TAG_RE = re.compile(r"<[^>]+>")
_WS_RE = re.compile(r"\s+")
# CJK ranges — used to pull the single phonetic component character out of the
# "... + phonetic 寺 ..." clause (and to avoid matching "phonetic series").
_CJK = r"一-鿿㐀-䶿豈-﫿"
_PHONETIC_RE = re.compile(rf"phonetic\s+([{_CJK}])")

# Readable prose starts at one of these formation keywords — everything before it
# is the "historical forms" / "phonetic series" reconstruction tables, which we
# drop. (keyword substring, formation tag). Order doesn't matter; we take the
# earliest match in the text.
_MARKERS: list[tuple[str, str]] = [
    ("phono-semantic compound", "phono-semantic"),
    ("ideogrammic compound", "ideogrammic"),
    ("ideogram", "ideogrammic"),
    ("pictogram", "pictogram"),
    ("phonetic loan", "phonetic-loan"),
    ("simplified from", "simplified"),
    # Modern glyphs that are a reshaped/abbreviated form of an older character —
    # e.g. 会 ← 會, 来 ← 來. Common in the Jōyō set and genuinely useful context.
    ("unorthodox variant", "variant"),
    ("vulgar variant", "variant"),
    ("variant of", "variant"),
    ("corruption of", "variant"),
    ("alternative form of", "variant"),
    ("abbreviation of", "abbreviation"),
    ("abbreviated from", "abbreviation"),
    ("originally", ""),
    ("compound of", "compound"),
    ("contraction of", "contraction"),
]

# Sister-project / reference boilerplate that can trail inside the section.
_TRAILING_NOISE = ("Wikipedia has articles on", "Wikipedia has an article on")

_MAX_LEN = 480  # keep the origin card to a few sentences


class Command(BaseCommand):
    help = "Import kanji glyph-origin etymology from the English Wiktionary API."

    def add_arguments(self, parser):
        parser.add_argument(
            "--all", action="store_true", help="Every kanji (default: JLPT ∪ grade<=8)."
        )
        parser.add_argument(
            "--force", action="store_true", help="Re-fetch even kanji that already have an origin."
        )
        parser.add_argument("--limit", type=int, default=0, help="Cap the number processed (0=all).")
        parser.add_argument("--delay", type=float, default=1.0, help="Seconds between requests.")

    def handle(self, *args, **opts):
        qs = Kanji.objects.all()
        if not opts["all"]:
            qs = qs.filter(Q(jlpt__isnull=False) | Q(grade__lte=8))
        if not opts["force"]:
            qs = qs.filter(origin="")
        qs = qs.order_by("freq_rank", "stroke_count", "literal")
        if opts["limit"]:
            qs = qs[: opts["limit"]]

        literals = list(qs.values_list("literal", flat=True))
        total = len(literals)
        self.stdout.write(f"Fetching glyph origins for {total} kanji …")

        done = filled = 0
        for literal in literals:
            done += 1
            try:
                page_html = self._fetch(literal, opts["delay"])
            except Exception as exc:  # network hiccup — log and keep going
                self.stderr.write(f"  {literal}: fetch failed ({exc})")
                continue
            parsed = _extract(page_html)
            if parsed is None:
                continue
            origin, formation, phonetic = parsed
            Kanji.objects.filter(literal=literal).update(
                origin=origin, formation=formation, phonetic=phonetic
            )
            filled += 1
            if done % 100 == 0 or done == total:
                self.stdout.write(f"  … {done}/{total} processed, {filled} with an origin")

        self.stdout.write(self.style.SUCCESS(f"Done — {filled}/{total} kanji got a glyph origin."))

    def _fetch(self, char: str, delay: float) -> str:
        params = urllib.parse.urlencode(
            {
                "action": "parse",
                "page": char,
                "prop": "text",
                "format": "json",
                "formatversion": "2",
                "disablelimitreport": "1",
                "redirects": "1",
            }
        )
        req = urllib.request.Request(f"{API}?{params}", headers={"User-Agent": UA})
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, timeout=25) as resp:
                    data = json.load(resp)
                time.sleep(delay)  # polite pacing between successful calls
                return data.get("parse", {}).get("text", "") or ""
            except urllib.error.HTTPError as exc:
                if exc.code == 404:
                    return ""  # no Wiktionary page for this character
                if exc.code == 429:
                    wait = _retry_after(exc, attempt)
                    self.stderr.write(f"  429 rate-limited — backing off {wait:.0f}s")
                    time.sleep(wait)
                    continue
                raise
        return ""


def _retry_after(exc: urllib.error.HTTPError, attempt: int) -> float:
    header = exc.headers.get("Retry-After") if exc.headers else None
    if header and header.isdigit():
        return float(header)
    return 5.0 * (attempt + 1)  # 5, 10, 15, 20s


def _tidy(text: str) -> str:
    """Tighten the spacing that tag-stripping leaves around punctuation."""
    for a, b in (
        (" ( ", " ("),
        ("( ", "("),
        (" )", ")"),
        (" ,", ","),
        (" :", ":"),
        (" ;", ";"),
        (" .", "."),
        ("“ ", "“"),
        (" ”", "”"),
    ):
        text = text.replace(a, b)
    return _WS_RE.sub(" ", text).strip()


def _extract(page_html: str) -> tuple[str, str, str] | None:
    """(origin_prose, formation, phonetic) or None if no usable glyph origin."""
    m = _SECTION_RE.search(page_html)
    if not m:
        return None
    text = _WS_RE.sub(" ", html.unescape(_TAG_RE.sub(" ", m.group(1)))).strip()
    low = text.lower()

    start = None
    formation = ""
    for marker, form in _MARKERS:
        i = low.find(marker)
        if i != -1 and (start is None or i < start):
            start, formation = i, form
    if start is None:
        return None

    prose = _tidy(text[start:])
    # Drop trailing sister-project boilerplate that lives inside the section.
    for noise in _TRAILING_NOISE:
        idx = prose.find(noise)
        if idx != -1:
            prose = prose[:idx].strip()
    # Trim the leading "[ edit ]" artifact if it slipped in.
    prose = prose.removeprefix("[ edit ] ").strip()
    if not prose:
        return None
    # Keep it to a few sentences: cut at the last sentence end before the cap.
    if len(prose) > _MAX_LEN:
        cut = prose.rfind(". ", 0, _MAX_LEN)
        prose = (prose[: cut + 1] if cut > 150 else prose[:_MAX_LEN].rstrip() + "…")

    phonetic = ""
    if formation == "phono-semantic":
        ph = _PHONETIC_RE.search(prose)
        phonetic = ph.group(1) if ph else ""
    return prose, formation, phonetic
