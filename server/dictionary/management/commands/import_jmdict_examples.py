"""Import explicitly sense-linked examples without replacing multilingual senses."""

from __future__ import annotations

import hashlib
import json
from collections import defaultdict
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.db.models import Prefetch

from dictionary.importing import XML_LANG, entries, language, source_provenance, xml_metadata
from dictionary.management.commands.import_jmdict import Command as JMdictCommand
from dictionary.models import ExampleSenseLink, ExampleSentence, ExampleTranslation, Gloss, Word


def _signature(data):
    """Exact English sense content and scope, never Japanese substring matching."""
    metadata = data["metadata"]
    scope = {
        key: metadata.get(key, [])
        for key in (
            "restricted_kanji",
            "restricted_readings",
            "references",
            "antonyms",
            "dialects",
            "loan_sources",
        )
    }
    glosses = [
        (g["text"], {k: v for k, v in g["metadata"].items() if k != XML_LANG})
        for g in data["glosses"]
        if g["language"] == "en"
    ]
    return json.dumps(
        [data["pos"], data["misc"], data["field"], scope, data["note"], glosses],
        sort_keys=True,
        ensure_ascii=False,
    )


def _sense_signature(sense):
    raw = sense.metadata.get("raw", {})
    return _signature(
        dict(
            pos=sense.pos,
            misc=sense.misc,
            field=sense.field,
            metadata=sense.metadata,
            note="\n".join(
                c["text"] for c in raw.get("children", []) if c["tag"] == "s_inf" and c["text"]
            ),
            glosses=[
                dict(language=g.language, text=g.text, metadata=g.metadata)
                for g in sorted(sense.glosses.all(), key=lambda g: g.order)
            ],
        )
    )


class Command(BaseCommand):
    help = "Import JMdict_e_examp examples using exact source sense matches."

    def add_arguments(self, parser):
        parser.add_argument("path")
        parser.add_argument("--limit", type=int, default=0)
        parser.add_argument("--report", help="JSON report of unmatched source senses")

    def handle(self, *args, **opts):
        path = Path(opts["path"])
        if not path.is_file() or opts["limit"] < 0:
            raise CommandError("A readable source and nonnegative limit are required.")
        provenance = source_provenance(path, "jmdict_examples")
        count, linked, batch, unmatched = 0, 0, [], []
        with transaction.atomic():
            for entry in entries(path, "JMdict", "entry"):
                if not entry.findall("sense/example"):
                    continue
                parsed = JMdictCommand._parse(entry, {"en"})
                examples = {
                    order: [xml_metadata(e) for e in sense.findall("example")]
                    for order, sense in enumerate(entry.findall("sense"))
                    if sense.findall("example")
                }
                batch.append((parsed, examples))
                count += 1
                if len(batch) >= 500:
                    linked += self._store(batch, provenance, unmatched)
                    batch = []
                    if count % 5000 == 0:
                        self.stdout.write(f"Processed {count} example-bearing entries")
                if opts["limit"] and count >= opts["limit"]:
                    break
            if batch:
                linked += self._store(batch, provenance, unmatched)
        report = dict(entries=count, links=linked, unmatched=unmatched, source=provenance)
        if opts["report"]:
            report_path = Path(opts["report"])
            report_path.parent.mkdir(parents=True, exist_ok=True)
            report_path.write_text(
                json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
            )
        self.stdout.write(
            self.style.SUCCESS(
                f"Done: {linked} explicit links; {len(unmatched)} unmatched senses (not guessed)."
            )
        )

    @staticmethod
    def _store(batch, provenance, unmatched):
        words = {
            w.seq: w
            for w in Word.objects.filter(seq__in=[p["seq"] for p, _ in batch]).prefetch_related(
                "senses", Prefetch("senses__glosses", queryset=Gloss.objects.filter(language="en"))
            )
        }
        rows, refreshed_senses = [], set()
        for parsed, examples in batch:
            word = words.get(parsed["seq"])
            candidates = defaultdict(list)
            if word:
                for sense in word.senses.all():
                    candidates[_sense_signature(sense)].append(sense)
            for order, source_examples in examples.items():
                matches = candidates[_signature(parsed["senses"][order])]
                if len(matches) != 1:
                    unmatched.append(
                        dict(
                            seq=parsed["seq"],
                            source_sense_order=order,
                            reason="missing_word"
                            if not word
                            else "ambiguous_sense"
                            if matches
                            else "different_sense",
                        )
                    )
                    continue
                sense = matches[0]
                refreshed_senses.add(sense.pk)
                for raw in source_examples:
                    sentences = [
                        (language(c["attributes"].get(XML_LANG, "eng")), c["text"])
                        for c in raw["children"]
                        if c["tag"] == "ex_sent"
                    ]
                    japanese = [text for lang, text in sentences if lang == "ja"]
                    if len(japanese) != 1 or not japanese[0]:
                        raise CommandError(f"Invalid Japanese example in entry {parsed['seq']}.")
                    translations = [(lang, text) for lang, text in sentences if lang != "ja"]
                    if len({lang for lang, _ in translations}) != len(translations):
                        raise CommandError(
                            "Multiple translations for one language require distinct examples."
                        )
                    digest = hashlib.sha256(
                        json.dumps(sentences, ensure_ascii=False, sort_keys=True).encode()
                    ).hexdigest()
                    key = "jmdict-example:" + digest
                    rows.append(
                        dict(
                            key=key,
                            japanese=japanese[0],
                            translations=translations,
                            sense=sense,
                            order=order,
                            raw=raw,
                            text="\n".join(
                                c["text"] for c in raw["children"] if c["tag"] == "ex_text"
                            ),
                        )
                    )
        existing = {
            e.source_key: e
            for e in ExampleSentence.objects.filter(source_key__in=[row["key"] for row in rows])
        }
        new, translations, links, seen = [], [], [], set()
        for row in rows:
            example = existing.get(row["key"])
            if example is None:
                example = ExampleSentence(
                    source_key=row["key"], japanese=row["japanese"], provenance=provenance
                )
                existing[row["key"]] = example
                new.append(example)
            pair = (row["key"], row["sense"].pk)
            if pair in seen:
                continue
            seen.add(pair)
            links.append((example, row))
        ExampleSentence.objects.bulk_create(new)
        new_keys = {e.source_key for e in new}
        seen_translations = set()
        for row in rows:
            if row["key"] not in new_keys or row["key"] in seen_translations:
                continue
            seen_translations.add(row["key"])
            translations.extend(
                ExampleTranslation(example=existing[row["key"]], language=lang, text=text)
                for lang, text in row["translations"]
            )
        ExampleTranslation.objects.bulk_create(translations)
        # Replace only links whose exact canonical sense was successfully matched.
        # Unmatched evidence and other sources are retained for explicit review.
        ExampleSenseLink.objects.filter(source="jmdict", sense_id__in=refreshed_senses).delete()
        ExampleSenseLink.objects.bulk_create(
            [
                ExampleSenseLink(
                    example=example,
                    sense=row["sense"],
                    source_sense_order=row["order"],
                    text=row["text"],
                    provenance={**provenance, "raw": row["raw"]},
                )
                for example, row in links
            ]
        )
        return len(links)
