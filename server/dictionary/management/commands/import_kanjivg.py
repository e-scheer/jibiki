"""Import KanjiVG stroke-order data into Kanji.stroke_paths.

One-shot batch command. KanjiVG ships one SVG per character, named by zero-padded
lowercase Unicode codepoint (字 U+5B57 → ``05b57.svg``); each ``<path d="…">`` is
one stroke, in draw order. We extract the ``d`` strings (regex - robust to the
kvg: attribute namespace) for every kanji already in the DB.

    python manage.py import_kanjivg /path/to/kanjivg/kanji

KanjiVG © Ulrich Apel, CC BY-SA 3.0 - see NOTICE.md (share-alike applies to
derivatives of these assets).
"""

from __future__ import annotations

import re
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from dictionary.models import Kanji

_PATH_RE = re.compile(r'<path[^>]*\sd="([^"]+)"')
_VIEWBOX_RE = re.compile(r'viewBox="([^"]+)"')


def strokes_for(svg_dir: Path, literal: str) -> tuple[list[str], str] | None:
    """Return (ordered stroke paths, viewBox) for a character, or None if absent."""
    svg = svg_dir / f"{ord(literal):05x}.svg"
    if not svg.exists():
        return None
    text = svg.read_text(encoding="utf-8")
    paths = _PATH_RE.findall(text)
    if not paths:
        return None
    vb = _VIEWBOX_RE.search(text)
    return paths, (vb.group(1) if vb else "0 0 109 109")


class Command(BaseCommand):
    help = "Import KanjiVG stroke-order paths for kanji already in the dictionary."

    def add_arguments(self, parser):
        parser.add_argument("dir", help="Path to the KanjiVG kanji/ directory")

    def handle(self, *args, **opts):
        svg_dir = Path(opts["dir"])
        if not svg_dir.is_dir():
            raise CommandError(f"not a directory: {svg_dir}")

        updated = missing = 0
        for kanji in Kanji.objects.all().iterator():
            result = strokes_for(svg_dir, kanji.literal)
            if result is None:
                missing += 1
                continue
            kanji.stroke_paths, kanji.stroke_viewbox = result
            kanji.save(update_fields=["stroke_paths", "stroke_viewbox"])
            updated += 1
        self.stdout.write(self.style.SUCCESS(f"Done - strokes set on {updated} kanji ({missing} not in KanjiVG)."))
