"""Import JMdict without losing source detail, stable IDs or other languages."""

from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from dictionary.importing import (
    LANGUAGES,
    XML_LANG,
    entries,
    language,
    source_provenance,
    xml_metadata,
)
from dictionary.models import Gloss, Sense, SenseNote, Word, WordForm

_COMMON_TAGS = {"news1", "ichi1", "spec1", "spec2", "gai1"}


class Command(BaseCommand):
    help = "Import JMdict XML or XML.gz with stable IDs and source metadata."

    def add_arguments(self, parser):
        parser.add_argument("path")
        parser.add_argument("--langs", default="en,fr", help="Comma-separated codes, or all")
        parser.add_argument("--limit", type=int, default=0)
        parser.add_argument("--batch-size", type=int, default=500)

    def handle(self, *args, **opts):
        path = Path(opts["path"])
        if not path.is_file():
            raise CommandError(f"File not found: {path}")
        if opts["limit"] < 0 or not 1 <= opts["batch_size"] <= 5000:
            raise CommandError("Limit must be nonnegative and batch size between 1 and 5000.")
        langs = {language(c.strip()) for c in opts["langs"].split(",") if c.strip()}
        if not langs:
            raise CommandError("Choose at least one language.")
        provenance = source_provenance(path, "jmdict")
        batch, count = [], 0
        with transaction.atomic():
            for entry in entries(path, "JMdict", "entry"):
                if entry.find("sense/example") is not None:
                    raise CommandError(
                        "Use import_jmdict_examples for JMdict_e_examp; "
                        "its English sense numbering must not replace multilingual senses."
                    )
                batch.append(self._parse(entry, langs))
                count += 1
                if len(batch) >= opts["batch_size"]:
                    self._store(batch, langs, provenance)
                    batch = []
                    if count % 5000 == 0:
                        self.stdout.write(f"Imported {count} entries")
                if opts["limit"] and count >= opts["limit"]:
                    break
            if batch:
                self._store(batch, langs, provenance)
        self.stdout.write(self.style.SUCCESS(f"Done: {count} JMdict entries imported."))

    def _ingest_entry(self, entry, langs):
        with transaction.atomic():
            self._store([self._parse(entry, langs)], langs, {"source": "jmdict"})

    @staticmethod
    def _parse(entry, langs):
        seq = int(entry.findtext("ent_seq") or "0")
        if seq <= 0:
            raise CommandError("JMdict requires a positive ent_seq.")
        forms, senses = [], []
        for tag, text_tag, kind, prefix in [
            ("k_ele", "keb", "kanji", "ke"),
            ("r_ele", "reb", "kana", "re"),
        ]:
            for order, elem in enumerate(entry.findall(tag)):
                text = elem.findtext(text_tag) or ""
                if not text or len(text) > 64:
                    raise CommandError(f"Invalid form in JMdict entry {seq}.")
                priorities = [p.text for p in elem.findall(prefix + "_pri") if p.text]
                forms.append(
                    dict(
                        text=text,
                        kind=kind,
                        order=order,
                        is_common=bool(set(priorities) & _COMMON_TAGS),
                        metadata={
                            "source": "jmdict",
                            "priorities": priorities,
                            "info": [p.text for p in elem.findall(prefix + "_inf") if p.text],
                            "restricted_kanji": [
                                p.text for p in elem.findall("re_restr") if p.text
                            ],
                            "no_kanji": elem.find("re_nokanji") is not None,
                            "raw": xml_metadata(elem),
                        },
                    )
                )
        previous_pos = []
        for order, elem in enumerate(entry.findall("sense")):
            pos = [p.text for p in elem.findall("pos") if p.text] or previous_pos
            previous_pos = pos
            glosses = []
            for gloss in elem.findall("gloss"):
                lang = language(gloss.get(XML_LANG, "eng"))
                if (gloss.text or "").strip() and ("all" in langs or lang in langs):
                    glosses.append(
                        dict(language=lang, text=gloss.text or "", metadata=dict(gloss.attrib))
                    )
            metadata = {"source": "jmdict", "raw": xml_metadata(elem)}
            for key, tag in [
                ("restricted_kanji", "stagk"),
                ("restricted_readings", "stagr"),
                ("references", "xref"),
                ("antonyms", "ant"),
                ("dialects", "dial"),
            ]:
                metadata[key] = [p.text for p in elem.findall(tag) if p.text]
            metadata["loan_sources"] = [xml_metadata(p) for p in elem.findall("lsource")]
            senses.append(
                dict(
                    order=order,
                    has_source_glosses=any((g.text or "").strip() for g in elem.findall("gloss")),
                    empty_gloss_count=sum(
                        not (g.text or "").strip() for g in elem.findall("gloss")
                    ),
                    pos=pos,
                    metadata=metadata,
                    glosses=glosses,
                    misc=[p.text for p in elem.findall("misc") if p.text],
                    field=[p.text for p in elem.findall("field") if p.text],
                    note="\n".join(p.text for p in elem.findall("s_inf") if p.text),
                )
            )
        if not forms:
            raise CommandError(f"JMdict entry {seq} has no forms.")
        return dict(
            seq=seq, forms=forms, senses=senses, is_common=any(f["is_common"] for f in forms)
        )

    @staticmethod
    def _store(batch, langs, provenance):
        words = {w.seq: w for w in Word.objects.filter(seq__in=[r["seq"] for r in batch])}
        new, changed = [], []
        for row in batch:
            word = words.get(row["seq"])
            if word is None:
                word = Word(seq=row["seq"])
                words[row["seq"]] = word
                new.append(word)
            else:
                changed.append(word)
            word.is_common = row["is_common"]
            word.provenance = {**word.provenance, "jmdict": provenance}
            anomalies = [
                dict(
                    order=s["order"],
                    raw=s["metadata"]["raw"],
                    reason="empty_source_sense"
                    if not s["has_source_glosses"]
                    else "empty_source_gloss",
                )
                for s in row["senses"]
                if not s["has_source_glosses"] or s["empty_gloss_count"]
            ]
            if anomalies:
                word.provenance["jmdict_source_anomalies"] = anomalies
            else:
                word.provenance.pop("jmdict_source_anomalies", None)
            word.provenance.pop("source_status", None)
        Word.objects.bulk_create(new)
        Word.objects.bulk_update(changed, ["is_common", "provenance"])
        ids = [w.pk for w in words.values()]
        forms = {(f.word_id, f.kind, f.text): f for f in WordForm.objects.filter(word_id__in=ids)}
        senses = {(s.word_id, s.order): s for s in Sense.objects.filter(word_id__in=ids)}
        new_forms, changed_forms, new_senses, changed_senses, source_senses = [], [], [], [], []
        for row in batch:
            word = words[row["seq"]]
            for data in row["forms"]:
                key = (word.pk, data["kind"], data["text"])
                form = forms.get(key)
                if form is None:
                    form = WordForm(word=word, **data)
                    forms[key] = form
                    new_forms.append(form)
                else:
                    for field, value in data.items():
                        setattr(
                            form,
                            field,
                            {**form.metadata, **value} if field == "metadata" else value,
                        )
                    changed_forms.append(form)
            for data in row["senses"]:
                if not data["has_source_glosses"]:
                    continue
                key = (word.pk, data["order"])
                sense = senses.get(key)
                if sense is None:
                    sense = Sense(word=word, order=data["order"])
                    senses[key] = sense
                    new_senses.append(sense)
                else:
                    changed_senses.append(sense)
                for field in ("pos", "misc", "field", "metadata"):
                    setattr(sense, field, data[field])
                source_senses.append((sense, data))
        WordForm.objects.bulk_create(new_forms)
        WordForm.objects.bulk_update(changed_forms, ["is_common", "order", "metadata"])
        # Surface forms belong to this source. Their parent word ID, pitch on
        # surviving forms, study cards and all personal references stay stable.
        refreshed_forms = {form.pk for form in new_forms + changed_forms}
        WordForm.objects.filter(word_id__in=ids).exclude(pk__in=refreshed_forms).delete()
        Sense.objects.bulk_create(new_senses)
        Sense.objects.bulk_update(changed_senses, ["pos", "misc", "field", "metadata"])
        sense_ids = [s.pk for s, _ in source_senses]
        selected = Gloss.objects.filter(sense_id__in=sense_ids)
        if "all" not in langs:
            selected = selected.filter(language__in=langs)
        selected.delete()
        notes, glosses = [], []
        for sense, data in source_senses:
            if data["note"]:
                notes.append(SenseNote(sense=sense, language="en", text=data["note"]))
            counts = {}
            for gloss in data["glosses"]:
                lang = gloss["language"]
                order = counts.get(lang, 0)
                counts[lang] = order + 1
                glosses.append(Gloss(sense=sense, order=order, **gloss))
        Gloss.objects.bulk_create(glosses)
        SenseNote.objects.filter(sense_id__in=sense_ids, language="en").delete()
        SenseNote.objects.bulk_create(notes)
        # Remove stale meanings only in the explicitly refreshed languages.
        stale = Sense.objects.filter(word_id__in=ids).exclude(pk__in=sense_ids)
        old_glosses = Gloss.objects.filter(sense__in=stale)
        if "all" not in langs:
            old_glosses = old_glosses.filter(language__in=langs)
        old_glosses.delete()
        stale.filter(glosses__isnull=True).delete()


def _iso2(code):
    return language(code)


def _iso3(langs):
    return {code for code, short in LANGUAGES.items() if short in langs} | set(langs)
