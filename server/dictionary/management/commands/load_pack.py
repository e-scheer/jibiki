"""Load a jibiki content pack (docs/CONTENT_PACK.md) into the DB.

This is the PRIMARY hydration path — the DB is populated from jibiki's own JSON
model, never from upstream XML (that is the build step, done once). Idempotent:
keyed by natural keys (kana char, kanji literal, word seq) so reloading an
enriched pack updates in place and never deletes a Word a study Card points at.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
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

SCHEMA_PREFIX = "jibiki-content/"


class Command(BaseCommand):
    help = "Load a jibiki content pack directory into the dictionary tables."

    def add_arguments(self, parser):
        parser.add_argument("dir", nargs="?", help="Pack directory (defaults to settings.CONTENT_PACK_DIR)")
        parser.add_argument("--no-verify", action="store_true", help="Skip sha256 verification")

    def handle(self, *args, **opts):
        from django.conf import settings

        pack = Path(opts["dir"] or settings.CONTENT_PACK_DIR)
        manifest_path = pack / "manifest.json"
        if not manifest_path.exists():
            raise CommandError(f"no manifest.json in {pack}")
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if not str(manifest.get("schema", "")).startswith(SCHEMA_PREFIX):
            raise CommandError(f"unsupported schema {manifest.get('schema')!r}")

        data = {}
        for f in manifest["files"]:
            raw = (pack / f["name"]).read_bytes()
            if not opts["no_verify"]:
                digest = hashlib.sha256(raw).hexdigest()
                if digest != f["sha256"]:
                    raise CommandError(f"checksum mismatch for {f['name']}")
            data[f["name"].removesuffix(".json")] = json.loads(raw.decode("utf-8"))

        self.stdout.write(f"Loading pack v{manifest['version']} (source={manifest['source']}, "
                          f"langs={manifest['languages']}) …")
        with transaction.atomic():
            self._kana(data.get("kana", []))
            self._radicals(data.get("radicals", []))
            self._kanji(data.get("kanji", []))
            self._words(data.get("words", []))
        self.stdout.write(self.style.SUCCESS("Pack loaded."))

    def _kana(self, rows) -> None:
        for r in rows:
            Kana.objects.update_or_create(
                char=r["char"],
                defaults=dict(
                    romaji=r["romaji"], script=r["script"], kind=r["kind"],
                    row=r.get("row", ""), order=r.get("order", 0),
                ),
            )
        self.stdout.write(f"  kana: {Kana.objects.count()}")

    def _radicals(self, rows) -> None:
        for r in rows:
            Radical.objects.update_or_create(
                literal=r["literal"],
                defaults=dict(strokes=r.get("strokes", 0), reading=r.get("reading", ""), meaning=r.get("meaning", "")),
            )
        self.stdout.write(f"  radicals: {Radical.objects.count()}")

    def _kanji(self, rows) -> None:
        for r in rows:
            strokes = r.get("strokes") or {}
            kanji, _ = Kanji.objects.update_or_create(
                literal=r["literal"],
                defaults=dict(
                    grade=r.get("grade"), stroke_count=r.get("stroke_count", 0),
                    jlpt=r.get("jlpt"), freq_rank=r.get("freq_rank"), radical_number=r.get("radical_number"),
                    on_readings=r.get("on", []), kun_readings=r.get("kun", []), nanori=r.get("nanori", []),
                    components=r.get("components", []),
                    stroke_paths=strokes.get("paths", []), stroke_viewbox=strokes.get("viewbox", "0 0 109 109"),
                ),
            )
            kanji.meanings.all().delete()
            order = 0
            for lang, texts in (r.get("meanings") or {}).items():
                for text in texts:
                    KanjiMeaning.objects.create(kanji=kanji, lang=lang, text=text[:128], order=order)
                    order += 1
        self.stdout.write(f"  kanji: {Kanji.objects.count()}")

    def _words(self, rows) -> None:
        for r in rows:
            # Natural key: real JMdict seq when present; else a stable negative seq
            # from the pack id (never collides with positive upstream seqs).
            seq = r.get("seq")
            if seq is None:
                seq = -(int(r["id"]))
            word, _ = Word.objects.update_or_create(
                seq=seq,
                defaults=dict(is_common=r.get("common", False), jlpt=r.get("jlpt"), freq_rank=r.get("freq_rank")),
            )
            word.forms.all().delete()
            word.senses.all().delete()
            for order, k in enumerate(r.get("kanji", [])):
                WordForm.objects.create(word=word, text=k["text"], kind=WordForm.Kind.KANJI,
                                        is_common=k.get("common", False), order=order)
            for order, k in enumerate(r.get("kana", [])):
                WordForm.objects.create(word=word, text=k["text"], kind=WordForm.Kind.KANA,
                                        is_common=k.get("common", False), order=order)
            for si, s in enumerate(r.get("senses", [])):
                sense = Sense.objects.create(word=word, order=si, pos=s.get("pos", []), misc=s.get("misc", []))
                go = 0
                for lang, texts in (s.get("glosses") or {}).items():
                    for text in texts:
                        Gloss.objects.create(sense=sense, lang=lang, text=text[:255], order=go)
                        go += 1
        self.stdout.write(f"  words: {Word.objects.count()}")
