"""Import KANJIDIC2 (EDRDG) XML into the Kanji + KanjiMeaning tables.

One-shot batch command. KANJIDIC2 has no custom content entities, so plain
iterparse suffices.

    python manage.py import_kanjidic /path/to/kanjidic2.xml --langs en,fr
"""

from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from dictionary.models import Kanji, KanjiMeaning


class Command(BaseCommand):
    help = "Import KANJIDIC2 XML (EDRDG) into the kanji tables."

    def add_arguments(self, parser):
        parser.add_argument("path", help="Path to kanjidic2.xml")
        parser.add_argument("--langs", default="en", help="Comma list of meaning langs to keep")

    def handle(self, *args, **opts):
        path = Path(opts["path"])
        if not path.exists():
            raise CommandError(f"file not found: {path}")
        langs = {code.strip() for code in opts["langs"].split(",") if code.strip()}

        count = 0
        self.stdout.write(f"Importing {path.name} …")
        with transaction.atomic():
            for _event, elem in ET.iterparse(str(path), events=("end",)):
                if elem.tag != "character":
                    continue
                self._ingest(elem, langs)
                elem.clear()
                count += 1
                if count % 2000 == 0:
                    self.stdout.write(f"  … {count} kanji")
        self.stdout.write(self.style.SUCCESS(f"Done - {count} kanji imported."))

    def _ingest(self, ch, langs: set[str]) -> None:
        literal = ch.findtext("literal")
        if not literal:
            return
        misc = ch.find("misc")
        grade = _int(misc.findtext("grade")) if misc is not None else None
        strokes = _int(misc.findtext("stroke_count")) if misc is not None else 0
        freq = _int(misc.findtext("freq")) if misc is not None else None
        jlpt = (
            _int(misc.findtext("jlpt_level")) if misc is not None else None
        )  # kanjidic2 modern tag

        radical_number = None
        rad = ch.find("radical")
        if rad is not None:
            radical_number = _int(rad.findtext("rad_value"))

        on_r, kun_r, nanori = [], [], []
        rm = ch.find("reading_meaning")
        meanings: list[tuple[str, str]] = []
        if rm is not None:
            for grp in rm.findall("rmgroup"):
                for r in grp.findall("reading"):
                    rtype = r.get("r_type")
                    if rtype == "ja_on":
                        on_r.append(r.text or "")
                    elif rtype == "ja_kun":
                        kun_r.append(r.text or "")
                for m in grp.findall("meaning"):
                    lang = m.get("m_lang", "en")  # absent attr → English
                    if lang in langs:
                        meanings.append((lang, m.text or ""))
            for nr in rm.findall("nanori"):
                nanori.append(nr.text or "")

        kanji, _ = Kanji.objects.update_or_create(
            literal=literal,
            defaults={
                "grade": grade,
                "stroke_count": strokes or 0,
                "jlpt": jlpt,
                "freq_rank": freq,
                "radical_number": radical_number,
                "on_readings": [r for r in on_r if r],
                "kun_readings": [r for r in kun_r if r],
                "nanori": [n for n in nanori if n],
            },
        )
        kanji.meanings.all().delete()
        KanjiMeaning.objects.bulk_create(
            KanjiMeaning(kanji=kanji, language=lang, text=text[:128], order=i)
            for i, (lang, text) in enumerate(meanings)
            if text
        )


def _int(value) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None
