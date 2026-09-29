"""Refresh JMnedict names by stable ent_seq without deleting the catalogue."""

from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from dictionary.importing import XML_LANG, entries, language, source_provenance, xml_metadata
from dictionary.models import Name, NameTranslation


class Command(BaseCommand):
    help = "Import JMnedict XML or XML.gz without changing existing name IDs."

    def add_arguments(self, parser):
        parser.add_argument("path")
        parser.add_argument("--limit", type=int, default=0)
        parser.add_argument("--langs", default="all", help="Comma-separated language codes, or all")

    def handle(self, *args, **opts):
        path = Path(opts["path"])
        if not path.is_file() or opts["limit"] < 0:
            raise CommandError("A readable source and nonnegative limit are required.")
        provenance = source_provenance(path, "jmnedict")
        langs = {language(code.strip()) for code in opts["langs"].split(",") if code.strip()}
        if not langs:
            raise CommandError("Choose at least one language.")
        count, batch = 0, []
        with transaction.atomic():
            for elem in entries(path, "JMnedict", "entry"):
                seq = int(elem.findtext("ent_seq") or "0")
                if seq <= 0:
                    raise CommandError("JMnedict requires a positive ent_seq.")
                kanji = [e.text for e in elem.findall("k_ele/keb") if e.text]
                readings = [e.text for e in elem.findall("r_ele/reb") if e.text]
                if not kanji and not readings:
                    raise CommandError(f"Name {seq} has no form or reading.")
                if any(len(text) > 64 for text in kanji + readings):
                    raise CommandError(f"Name {seq} exceeds the supported form length.")
                types, translations = set(), []
                for group in elem.findall("trans"):
                    types.update(t.text for t in group.findall("name_type") if t.text)
                    translations.extend(
                        (language(t.get(XML_LANG, "eng")), t.text)
                        for t in group.findall("trans_det")
                        if t.text and ("all" in langs or language(t.get(XML_LANG, "eng")) in langs)
                    )
                batch.append(
                    (
                        dict(
                            seq=seq,
                            kanji=next(iter(kanji), ""),
                            reading=next(iter(readings), ""),
                            name_types=sorted(types),
                            metadata={
                                "kanji": kanji,
                                "readings": readings,
                                "raw": xml_metadata(elem),
                            },
                            provenance={"jmnedict": provenance},
                        ),
                        translations,
                    )
                )
                count += 1
                if len(batch) >= 3000:
                    self._flush(batch, langs)
                    batch = []
                if opts["limit"] and count >= opts["limit"]:
                    break
            if batch:
                self._flush(batch, langs)
        self.stdout.write(self.style.SUCCESS(f"Done: {count} names imported."))

    @staticmethod
    def _flush(batch, langs=frozenset({"all"})):
        existing = {
            n.seq: n for n in Name.objects.filter(seq__in=[data["seq"] for data, _ in batch])
        }
        new, changed = [], []
        for data, _ in batch:
            name = existing.get(data["seq"])
            if name is None:
                name = Name(**data)
                existing[name.seq] = name
                new.append(name)
            else:
                for key, value in data.items():
                    setattr(
                        name,
                        key,
                        {**getattr(name, key), **value}
                        if key in ("provenance", "metadata")
                        else value,
                    )
                changed.append(name)
        Name.objects.bulk_create(new)
        Name.objects.bulk_update(
            changed, ["kanji", "reading", "name_types", "metadata", "provenance"]
        )
        selected = NameTranslation.objects.filter(name_id__in=[n.pk for n in existing.values()])
        if "all" not in langs:
            selected = selected.filter(language__in=langs)
        selected.delete()
        translations = []
        for data, values in batch:
            counts = {}
            for lang, text in values:
                order = counts.get(lang, 0)
                counts[lang] = order + 1
                translations.append(
                    NameTranslation(
                        name=existing[data["seq"]], language=lang, text=text, order=order
                    )
                )
        NameTranslation.objects.bulk_create(translations)
