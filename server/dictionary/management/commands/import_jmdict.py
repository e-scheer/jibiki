"""Import the full JMdict (EDRDG) XML into Word/WordForm/Sense/Gloss.

One-shot batch command (NOT a request-path parser): run it once to populate, or
again to refresh when EDRDG publishes a new release. It streams the file with
iterparse so a 400 MB JMdict fits in a small container.

    python manage.py import_jmdict /path/to/JMdict_e.xml --langs en,fr

JMdict encodes part-of-speech / misc as XML entities (``<pos>&n;</pos>``). We seed
the parser's entity table with {name: name} so those resolve to their short CODE
("n", "vs", …) rather than the long human expansion - that is what the schema
stores. EDRDG attribution is required (see the repo README / NOTICE).
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from dictionary.models import Gloss, Sense, SenseNote, Word, WordForm

_ENTITY_RE = re.compile(r'<!ENTITY\s+([\w-]+)\s+"[^"]*">')
_COMMON_TAGS = {"news1", "ichi1", "spec1", "spec2", "gai1"}  # ke_pri/re_pri "common" markers


def _entity_map(path: Path) -> dict[str, str]:
    """Read the internal DTD's <!ENTITY …> lines and map each name to ITSELF so
    entity refs resolve to their code, not their prose expansion."""
    entities: dict[str, str] = {}
    with path.open("r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if "<!ENTITY" in line:
                for name in _ENTITY_RE.findall(line):
                    entities[name] = name
            elif line.lstrip().startswith("<JMdict"):
                break  # DTD is over
    return entities


class Command(BaseCommand):
    help = "Import JMdict XML (EDRDG) into the dictionary tables."

    def add_arguments(self, parser):
        parser.add_argument("path", help="Path to JMdict / JMdict_e XML file")
        parser.add_argument("--langs", default="en", help="Comma list of gloss langs to keep")
        parser.add_argument("--limit", type=int, default=0, help="Stop after N entries (0 = all)")

    def handle(self, *args, **opts):
        path = Path(opts["path"])
        if not path.exists():
            raise CommandError(f"file not found: {path}")
        langs = {code.strip() for code in opts["langs"].split(",") if code.strip()}
        limit = opts["limit"]

        parser = ET.XMLParser()
        # ET.XMLParser exposes an `entity` dict it consults for &name; refs.
        parser.entity.update(_entity_map(path))

        count = 0
        self.stdout.write(f"Importing {path.name} (langs={sorted(langs)}) …")
        with transaction.atomic():
            for _event, elem in ET.iterparse(str(path), events=("end",), parser=parser):
                if elem.tag != "entry":
                    continue
                self._ingest_entry(elem, langs)
                elem.clear()
                count += 1
                if count % 5000 == 0:
                    self.stdout.write(f"  … {count} entries")
                if limit and count >= limit:
                    break
        self.stdout.write(self.style.SUCCESS(f"Done - {count} JMdict entries imported."))

    def _ingest_entry(self, entry, langs: set[str]) -> None:
        seq_text = entry.findtext("ent_seq")
        seq = int(seq_text) if seq_text and seq_text.isdigit() else None

        word, _ = Word.objects.update_or_create(seq=seq, defaults={})
        # Rebuild children idempotently so re-import refreshes cleanly.
        word.forms.all().delete()
        word.senses.all().delete()

        is_common = False
        forms: list[WordForm] = []
        for order, k in enumerate(entry.findall("k_ele")):
            text = k.findtext("keb") or ""
            common = any((p.text or "") in _COMMON_TAGS for p in k.findall("ke_pri"))
            is_common = is_common or common
            forms.append(
                WordForm(
                    word=word, text=text, kind=WordForm.Kind.KANJI, is_common=common, order=order
                )
            )
        for order, r in enumerate(entry.findall("r_ele")):
            text = r.findtext("reb") or ""
            common = any((p.text or "") in _COMMON_TAGS for p in r.findall("re_pri"))
            is_common = is_common or common
            forms.append(
                WordForm(
                    word=word, text=text, kind=WordForm.Kind.KANA, is_common=common, order=order
                )
            )
        WordForm.objects.bulk_create(forms)

        for order, s in enumerate(entry.findall("sense")):
            glosses = [
                g
                for g in s.findall("gloss")
                if (g.get("{http://www.w3.org/XML/1998/namespace}lang", "eng")) in _iso3(langs)
            ]
            if not glosses:
                continue
            sense = Sense.objects.create(
                word=word,
                order=order,
                pos=[p.text for p in s.findall("pos") if p.text],
                misc=[m.text for m in s.findall("misc") if m.text],
                field=[f.text for f in s.findall("field") if f.text],
            )
            note = (s.findtext("s_inf") or "")[:255]
            if note:
                SenseNote.objects.create(sense=sense, language="en", text=note)
            Gloss.objects.bulk_create(
                Gloss(
                    sense=sense,
                    language=_iso2(
                        g.get("{http://www.w3.org/XML/1998/namespace}lang", "eng")
                    ),
                    text=(g.text or "")[:255],
                    order=i,
                )
                for i, g in enumerate(glosses)
            )

        word.is_common = is_common
        word.save(update_fields=["is_common"])


# JMdict uses ISO-639-2/B (3-letter: eng, fre, ger, dut); the app speaks 2-letter.
_ISO3_FROM_2 = {"en": "eng", "fr": "fre", "de": "ger", "nl": "dut", "ru": "rus", "es": "spa"}
_ISO2_FROM_3 = {v: k for k, v in _ISO3_FROM_2.items()}


def _iso3(langs: set[str]) -> set[str]:
    return {_ISO3_FROM_2.get(code, code) for code in langs}


def _iso2(code: str) -> str:
    return _ISO2_FROM_3.get(code, code)
