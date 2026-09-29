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

import hashlib
import xml.etree.ElementTree as ET
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from dictionary.models import Kanji


def strokes_for(svg_dir: Path, literal: str) -> tuple[list[str], str] | None:
    """Return (ordered stroke paths, viewBox) for a character, or None if absent."""
    svg = svg_dir / f"{ord(literal):05x}.svg"
    if not svg.exists():
        return None
    root = ET.fromstring(svg.read_text(encoding="utf-8"))
    paths = [
        node.attrib["d"]
        for node in root.iter()
        if node.tag.rsplit("}", 1)[-1] == "path" and node.attrib.get("d")
    ]
    if not paths:
        return None
    viewbox = root.attrib.get("viewBox", "0 0 109 109")
    values = [float(v) for v in viewbox.split()]
    if len(values) != 4 or values[2] <= 0 or values[3] <= 0:
        raise ValueError(f"Invalid SVG viewBox for {literal}")
    return paths, viewbox


class Command(BaseCommand):
    help = "Import KanjiVG stroke-order paths for kanji already in the dictionary."

    def add_arguments(self, parser):
        parser.add_argument("dir", help="Path to the KanjiVG kanji/ directory")
        parser.add_argument(
            "--source-url", default="", help="Release URL recorded as source evidence"
        )

    @transaction.atomic
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
            svg = svg_dir / f"{ord(kanji.literal):05x}.svg"
            kanji.provenance = {
                **kanji.provenance,
                "kanjivg": {
                    "source": "kanjivg",
                    "file": svg.name,
                    "sha256": hashlib.sha256(svg.read_bytes()).hexdigest(),
                    "source_url": opts["source_url"],
                    "transformation": "deterministic_svg_path_extraction",
                    "authoring_method": "upstream_unspecified",
                    "stroke_path_count": len(kanji.stroke_paths),
                },
            }
            kanji.save(update_fields=["stroke_paths", "stroke_viewbox", "provenance"])
            updated += 1
        self.stdout.write(
            self.style.SUCCESS(f"Done - strokes set on {updated} kanji ({missing} not in KanjiVG).")
        )
