"""Import JMnedict (EDRDG) proper names into the Name table.

Same XML/entity handling as JMdict (name_type is an entity like &place;). One-shot;
clears the table first, then bulk-inserts one row per entry (first kanji + first
reading, all translations/types).

    python manage.py import_jmnedict /path/to/JMnedict.xml
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from dictionary.models import Name

_ENTITY_RE = re.compile(r'<!ENTITY\s+([\w-]+)\s+"[^"]*">')


def _entity_map(path: Path) -> dict[str, str]:
    entities: dict[str, str] = {}
    with path.open("r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if "<!ENTITY" in line:
                for name in _ENTITY_RE.findall(line):
                    entities[name] = name
            elif line.lstrip().startswith("<JMnedict"):
                break
    return entities


class Command(BaseCommand):
    help = "Import JMnedict XML (EDRDG) into the names table."

    def add_arguments(self, parser):
        parser.add_argument("path", help="Path to JMnedict.xml")
        parser.add_argument("--limit", type=int, default=0)

    def handle(self, *args, **opts):
        path = Path(opts["path"])
        if not path.exists():
            raise CommandError(f"file not found: {path}")
        limit = opts["limit"]

        parser = ET.XMLParser()
        parser.entity.update(_entity_map(path))

        Name.objects.all().delete()
        batch: list[Name] = []
        total = 0
        self.stdout.write(f"Importing {path.name} …")
        for _event, elem in ET.iterparse(str(path), events=("end",), parser=parser):
            if elem.tag != "entry":
                continue
            seq_text = elem.findtext("ent_seq")
            seq = int(seq_text) if seq_text and seq_text.isdigit() else None
            kanji = elem.findtext("k_ele/keb") or ""
            reading = elem.findtext("r_ele/reb") or ""
            types: set[str] = set()
            trans: list[str] = []
            for t in elem.findall("trans"):
                types.update(nt.text for nt in t.findall("name_type") if nt.text)
                trans.extend(td.text for td in t.findall("trans_det") if td.text)
            elem.clear()
            if not (reading or kanji):
                continue
            batch.append(
                Name(
                    seq=seq,
                    kanji=kanji,
                    reading=reading or kanji,
                    translations=trans,
                    name_types=sorted(types),
                )
            )
            if len(batch) >= 3000:
                Name.objects.bulk_create(batch)
                total += len(batch)
                batch = []
                if total % 60000 == 0:
                    self.stdout.write(f"  … {total} names")
            if limit and total >= limit:
                break
        if batch:
            Name.objects.bulk_create(batch)
            total += len(batch)
        self.stdout.write(self.style.SUCCESS(f"Done — {total} names imported."))
