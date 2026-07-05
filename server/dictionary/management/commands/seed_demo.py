"""Load the curated demo dataset (dictionary/seed_data.py) so the app is usable
offline the moment the server boots. Idempotent; `--if-empty` makes it a no-op
when the dictionary already has data (used by the Docker CMD)."""

from __future__ import annotations

from django.core.management.base import BaseCommand
from django.db import transaction

from dictionary.models import (
    Gloss,
    Kana,
    Kanji,
    KanjiMeaning,
    Radical,
    Sense,
    Word,
    WordForm,
)
from dictionary.seed_data import KANA, KANA_STORIES, KANJI, RADICALS, WORDS, kana_origin, kana_usage
from dictionary.seed_strokes import STROKES


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
            self.stdout.write("Dictionary already populated — skipping seed.")
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
            Kana.objects.update_or_create(
                char=hira,
                defaults=dict(
                    romaji=romaji, script=Kana.Script.HIRAGANA, kind=kind, row=row, order=order,
                    origin=o_h, origin_note=n_h, usage_label=u_label, usage=u_text,
                ),
            )
            Kana.objects.update_or_create(
                char=kata,
                defaults=dict(
                    romaji=romaji, script=Kana.Script.KATAKANA, kind=kind, row=row, order=order,
                    origin=o_k, origin_note=n_k,
                ),
            )
        self.stdout.write(f"  kana: {Kana.objects.count()}")

    def _seed_radicals(self) -> None:
        for literal, (strokes, reading, meaning) in RADICALS.items():
            Radical.objects.update_or_create(
                literal=literal,
                defaults=dict(strokes=strokes, reading=reading, meaning=meaning),
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
                    KanjiMeaning.objects.create(kanji=kanji, lang=lang, text=text, order=order)
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
                        Gloss.objects.create(sense=s, lang=lang, text=text, order=go)
                        go += 1
        self.stdout.write(f"  words: {Word.objects.count()}")

    def _seed_mnemonics(self) -> None:
        # Local import: the mnemonics app is a peer; seeding is a batch job, so a
        # cross-app import here is fine (and keeps dictionary import-light).
        from mnemonics.models import (
            DeckStatus,
            Mnemonic,
            MnemonicDeck,
            MnemonicDeckItem,
            MnemonicStatus,
        )
        from mnemonics.seeding import attach_art

        by_lang: dict[str, list] = {}
        imaged = 0
        # One story per gojūon sound, applied to BOTH the hiragana and katakana
        # character, in every language → the complete built-in default pack.
        for romaji, hira, kata, _row, kind in KANA:
            if kind != Kana.Kind.GOJUON:
                continue
            stories = KANA_STORIES.get(romaji)
            if not stories:
                continue
            for lang, story in stories.items():
                for char in (hira, kata):
                    m, _ = Mnemonic.objects.update_or_create(
                        character=char,
                        language=lang,
                        kind=Mnemonic.Kind.KANA,
                        author=None,
                        story=story,
                        defaults=dict(status=MnemonicStatus.VISIBLE, is_seed=True),
                    )
                    # Give the seed mnemonic its generated picture, through the
                    # same ingest as a user upload (idempotent — skips if set).
                    imaged += attach_art(m)
                    by_lang.setdefault(lang, []).append(m)

        # A built-in default pack per language, so every user has a browsable /
        # applicable base set out of the box (idempotent on re-seed).
        for lang, mnemonics in by_lang.items():
            deck, _ = MnemonicDeck.objects.update_or_create(
                is_seed=True,
                kind=Mnemonic.Kind.KANA,
                language=lang,
                author=None,
                defaults=dict(
                    title="jibiki · Kana mascots",
                    description="The built-in starter mnemonics.",
                    status=DeckStatus.VISIBLE,
                ),
            )
            for pos, m in enumerate(mnemonics):
                MnemonicDeckItem.objects.update_or_create(
                    deck=deck, mnemonic=m, defaults=dict(position=pos)
                )

        self.stdout.write(
            f"  kana mnemonics: {Mnemonic.objects.filter(is_seed=True).count()}"
            f" ({imaged} with art)"
            f" · default packs: {MnemonicDeck.objects.filter(is_seed=True).count()}"
        )
