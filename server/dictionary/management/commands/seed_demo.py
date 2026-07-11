"""Load the curated demo dataset (dictionary/seed_data.py) so the app is usable
offline the moment the server boots. Idempotent; `--if-empty` makes it a no-op
when the dictionary already has data (used by the Docker CMD)."""

from __future__ import annotations

from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand
from django.db import transaction

from dictionary.models import (
    Gloss,
    Kana,
    KanaExplanation,
    KanaUsage,
    KanaUsageExample,
    KanaUsageExampleTranslation,
    KanaUsageTranslation,
    Kanji,
    KanjiMeaning,
    Radical,
    RadicalMeaning,
    Sense,
    Word,
    WordForm,
)
from dictionary.seed_data import (
    KANA,
    KANJI,
    RADICALS,
    WORDS,
    kana_origin,
    kana_usage,
    kana_usage_examples,
)
from dictionary.seed_strokes import STROKES
from mnemonics.seeds import install_kana_entries, load_kana_entries


class Command(BaseCommand):
    help = "Seed the curated demo dictionary + kana mnemonics."

    def add_arguments(self, parser):
        parser.add_argument(
            "--if-empty",
            action="store_true",
            help="Skip entirely if the dictionary already has words/kana.",
        )

    @transaction.atomic
    def handle(self, *args, **opts):
        if opts["if_empty"] and (Word.objects.exists() or Kana.objects.exists()):
            self.stdout.write("Dictionary already populated - skipping seed.")
            return

        self._seed_kana()
        self._seed_radicals()
        self._seed_kanji()
        self._seed_words()
        self._seed_mnemonics()
        self.stdout.write(self.style.SUCCESS("Demo dataset seeded."))

    def _seed_kana(self) -> None:
        for order, (romaji, hira, kata, row, kind) in enumerate(KANA):
            o_h, n_h = kana_origin(romaji, Kana.Script.HIRAGANA, kind)
            o_k, n_k = kana_origin(romaji, Kana.Script.KATAKANA, kind)
            u_label, u_text = kana_usage(romaji, Kana.Script.HIRAGANA)  # particles are hiragana
            u_examples = kana_usage_examples(romaji, Kana.Script.HIRAGANA)
            Kana.objects.update_or_create(
                char=hira,
                defaults=dict(
                    romaji=romaji, script=Kana.Script.HIRAGANA, kind=kind, row=row, order=order,
                    origin=o_h,
                ),
            )
            Kana.objects.update_or_create(
                char=kata,
                defaults=dict(
                    romaji=romaji, script=Kana.Script.KATAKANA, kind=kind, row=row, order=order,
                    origin=o_k,
                ),
            )
            self._set_kana_content(hira, n_h, u_label, u_text, u_examples)
            self._set_kana_content(kata, n_k, "", "", [])
        self.stdout.write(f"  kana: {Kana.objects.count()}")

    def _set_kana_content(self, char, origin_note, label, explanation, examples) -> None:
        kana = Kana.objects.get(char=char)
        kana.explanations.all().delete()
        if origin_note:
            KanaExplanation.objects.create(
                kana=kana, language="en", origin_note=origin_note
            )
        KanaUsage.objects.filter(kana=kana).delete()
        if not (label or explanation or examples):
            return
        usage = KanaUsage.objects.create(kana=kana)
        if label or explanation:
            KanaUsageTranslation.objects.create(
                usage=usage, language="en", label=label, explanation=explanation
            )
        for order, item in enumerate(examples):
            example = KanaUsageExample.objects.create(
                usage=usage,
                order=order,
                before=item.get("before", ""),
                particle=item.get("particle", ""),
                after=item.get("after", ""),
                pronunciation=item.get("romaji", ""),
            )
            if item.get("en"):
                KanaUsageExampleTranslation.objects.create(
                    example=example, language="en", text=item["en"]
                )

    def _seed_radicals(self) -> None:
        for literal, (strokes, reading, meaning) in RADICALS.items():
            radical, _ = Radical.objects.update_or_create(
                literal=literal,
                defaults=dict(strokes=strokes, reading=reading),
            )
            RadicalMeaning.objects.update_or_create(
                radical=radical, language="en", defaults={"text": meaning}
            )
        self.stdout.write(f"  radicals: {Radical.objects.count()}")

    def _seed_kanji(self) -> None:
        for literal, d in KANJI.items():
            strokes = STROKES.get(literal, {})
            kanji, _ = Kanji.objects.update_or_create(
                literal=literal,
                defaults=dict(
                    on_readings=d["on"],
                    kun_readings=d["kun"],
                    nanori=[],
                    stroke_count=d["strokes"],
                    grade=d.get("grade"),
                    jlpt=d.get("jlpt"),
                    freq_rank=d.get("freq"),
                    components=d.get("comp", []),
                    stroke_paths=strokes.get("paths", []),
                    stroke_viewbox=strokes.get("viewbox", "0 0 109 109"),
                ),
            )
            kanji.meanings.all().delete()
            order = 0
            for lang, key in (("en", "en"), ("fr", "fr")):
                for text in d.get(key, []):
                    KanjiMeaning.objects.create(
                        kanji=kanji, language=lang, text=text, order=order
                    )
                    order += 1
        self.stdout.write(f"  kanji: {Kanji.objects.count()}")

    def _seed_words(self) -> None:
        for i, w in enumerate(WORDS):
            # Deterministic negative seq so re-seeding is idempotent and never
            # collides with real JMdict ent_seq values (which are positive).
            seq = -(i + 1)
            word, _ = Word.objects.update_or_create(
                seq=seq,
                defaults=dict(is_common=w.get("common", False), jlpt=w.get("jlpt")),
            )
            word.forms.all().delete()
            word.senses.all().delete()
            for order, (text, common) in enumerate(w.get("kanji", [])):
                WordForm.objects.create(
                    word=word, text=text, kind=WordForm.Kind.KANJI, is_common=common, order=order
                )
            for order, (text, common) in enumerate(w.get("kana", [])):
                WordForm.objects.create(
                    word=word, text=text, kind=WordForm.Kind.KANA, is_common=common, order=order
                )
            for si, sense in enumerate(w["senses"]):
                s = Sense.objects.create(word=word, order=si, pos=sense.get("pos", []))
                go = 0
                for lang, key in (("en", "en"), ("fr", "fr")):
                    for text in sense.get(key, []):
                        Gloss.objects.create(
                            sense=s, language=lang, text=text, order=go
                        )
                        go += 1
        self.stdout.write(f"  words: {Word.objects.count()}")

    def _seed_mnemonics(self) -> None:
        path = Path(settings.CONTENT_SOURCE_DIR) / "mnemonics" / "kana_stories.json"
        created, updated, decks = install_kana_entries(load_kana_entries(path))
        self.stdout.write(
            f"  kana mnemonics: {created} created, {updated} updated, {decks} default packs"
        )
