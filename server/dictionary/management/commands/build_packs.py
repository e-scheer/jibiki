"""Export the Postgres dictionary into prebuilt SQLite pack files (offline-first).

The app reads all dictionary content from these packs, downloaded via
/api/v1/content/packs/* (or bundled as base.db); Postgres stays the source of
truth. Pack ids in packs_manifest.json are stable; the version string is the
release stamp. words.id inside a pack IS the server Word.id - study Cards
reference it (SRS item_ref), so ids are copied verbatim, never remapped.

    python manage.py build_packs --out data/content/packs
    python manage.py build_packs --out data/content/packs --packs core,gloss-en
    python manage.py build_packs --out /tmp/packs --base       # bundled base.db.gz
"""

from __future__ import annotations

import gzip
import hashlib
import json
import sqlite3
from datetime import UTC, date, datetime
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db.models import Q

from dictionary import pack_schema
from dictionary.models import (
    ExampleSentence,
    Gloss,
    Kana,
    Kanji,
    KanjiMeaning,
    Name,
    Radical,
    Sense,
    Word,
    WordForm,
)

DEFAULT_PACKS = ["core", "gloss-en", "gloss-fr", "names", "examples", "mnemonics-en"]
MIN_APP_VERSION = "0.2.0"

# The bundled base pack ships the useful core: common words + anything JLPT.
BASE_WORDS = Q(is_common=True) | Q(jlpt__isnull=False)
BASE_WORDS_REL = Q(word__is_common=True) | Q(word__jlpt__isnull=False)
BASE_WORDS_GLOSS = Q(sense__word__is_common=True) | Q(sense__word__jlpt__isnull=False)
BASE_LANGS = ["en", "fr"]

RANK_MAX = 99_999_999  # COALESCE(freq_rank, RANK_MAX): unranked words sort last
KANJI_WORDS_CAP = 12

ATTRIBUTION = {
    "words": "JMdict © EDRDG, used under the EDRDG Licence.",
    "kanji": "KANJIDIC2 © EDRDG, used under the EDRDG Licence.",
    "components": "KRADFILE © EDRDG (CC BY-SA 3.0).",
    "strokes": "KanjiVG © Ulrich Apel (CC BY-SA 3.0).",
    "pitch": "Kanjium pitch-accent data (CC BY-SA 4.0).",
    "names": "JMnedict © EDRDG, used under the EDRDG Licence.",
    "examples": "Tanaka Corpus / Tatoeba (CC-BY 2.0 FR).",
    "mnemonics": "jibiki built-in mnemonics © jibiki contributors.",
}

LANG_TITLES = {"en": ("English", "anglais"), "fr": ("French", "français")}

INSERT_WORD = (
    "INSERT INTO words(id, seq, is_common, jlpt, freq_rank, headword, primary_reading)"
    " VALUES (?, ?, ?, ?, ?, ?, ?)"
)
INSERT_FORM = (
    "INSERT INTO word_forms(id, word_id, text, kind, is_common, ord, pitch)"
    " VALUES (?, ?, ?, ?, ?, ?, ?)"
)
INSERT_SENSE = (
    "INSERT INTO senses(id, word_id, ord, pos, misc, field, info) VALUES (?, ?, ?, ?, ?, ?, ?)"
)
INSERT_KANJI = (
    "INSERT INTO kanji(literal, grade, stroke_count, jlpt, freq_rank, radical_number,"
    " on_readings, kun_readings, nanori, components, origin, formation, phonetic,"
    " stroke_paths, stroke_viewbox) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
)
INSERT_KANJI_COMPONENT = "INSERT INTO kanji_components(kanji, component) VALUES (?, ?)"
INSERT_KANJI_WORD = "INSERT INTO kanji_words(kanji, word_id, rank) VALUES (?, ?, ?)"
INSERT_KANA = (
    'INSERT INTO kana(char, romaji, script, kind, "row", ord, origin, origin_note,'
    " usage_label, usage, usage_examples) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
)
INSERT_RADICAL = "INSERT INTO radicals(literal, strokes, reading, meaning) VALUES (?, ?, ?, ?)"
INSERT_GLOSS = (
    "INSERT INTO glosses(id, sense_id, word_id, lang, ord, text, word_rank, word_common)"
    " VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
)
INSERT_KANJI_MEANING = "INSERT INTO kanji_meanings(kanji, lang, ord, text) VALUES (?, ?, ?, ?)"
INSERT_NAME = (
    "INSERT INTO names(id, kanji, reading, translations, name_types) VALUES (?, ?, ?, ?, ?)"
)
INSERT_EXAMPLE = "INSERT INTO examples(id, japanese, english) VALUES (?, ?, ?)"
INSERT_MNEMONIC = (
    "INSERT INTO mnemonics(id, kind, character, language, story, score, image, image_w, image_h)"
    " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
)


def _json(value) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def _batched(conn: sqlite3.Connection, sql: str, rows, size: int = 2000) -> int:
    batch, n = [], 0
    for row in rows:
        batch.append(row)
        if len(batch) >= size:
            conn.executemany(sql, batch)
            n += len(batch)
            batch.clear()
    if batch:
        conn.executemany(sql, batch)
        n += len(batch)
    return n


# ── fillers (shared between the per-kind packs and base) ─────────────────────


def _fill_core(conn: sqlite3.Connection, *, base: bool) -> dict[str, int]:
    counts: dict[str, int] = {}

    word_q = Word.objects.order_by("pk")
    if base:
        word_q = word_q.filter(BASE_WORDS)

    # One pass over words (forms prefetched for headword/primary_reading), while
    # accumulating the ranking metadata kanji_words needs per included word.
    word_meta: dict[int, tuple[int, int]] = {}

    def word_rows():
        for w in word_q.prefetch_related("forms").iterator(chunk_size=2000):
            rank = w.freq_rank if w.freq_rank is not None else RANK_MAX
            word_meta[w.pk] = (int(w.is_common), rank)
            yield (
                w.pk,
                w.seq,
                int(w.is_common),
                w.jlpt,
                w.freq_rank,
                w.headword,
                w.primary_reading,
            )

    counts["words"] = _batched(conn, INSERT_WORD, word_rows())

    form_q = WordForm.objects.order_by("pk")
    if base:
        form_q = form_q.filter(BASE_WORDS_REL)
    counts["word_forms"] = _batched(
        conn,
        INSERT_FORM,
        (
            (pk, wid, text, pack_schema.FORM_KIND[kind], int(common), ord_, pitch)
            for pk, wid, text, kind, common, ord_, pitch in form_q.values_list(
                "id", "word_id", "text", "kind", "is_common", "order", "pitch"
            ).iterator(chunk_size=2000)
        ),
    )

    sense_q = Sense.objects.order_by("pk")
    if base:
        sense_q = sense_q.filter(BASE_WORDS_REL)
    counts["senses"] = _batched(
        conn,
        INSERT_SENSE,
        (
            (pk, wid, ord_, _json(pos or []), _json(misc or []), _json(field or []), info or "")
            for pk, wid, ord_, pos, misc, field, info in sense_q.values_list(
                "id", "word_id", "order", "pos", "misc", "field", "info"
            ).iterator(chunk_size=2000)
        ),
    )

    kanji_q = Kanji.objects.order_by("pk")
    if base:
        kanji_q = kanji_q.filter(jlpt__isnull=False)
    kanji_set: set[str] = set()
    comp_rows: list[tuple[str, str]] = []

    def kanji_rows():
        for k in kanji_q.iterator(chunk_size=2000):
            kanji_set.add(k.literal)
            comp_rows.extend((k.literal, c) for c in (k.components or []))
            yield (
                k.literal, k.grade, k.stroke_count, k.jlpt, k.freq_rank, k.radical_number,
                _json(k.on_readings or []), _json(k.kun_readings or []), _json(k.nanori or []),
                _json(k.components or []), k.origin, k.formation, k.phonetic,
                _json(k.stroke_paths or []), k.stroke_viewbox or "0 0 109 109",
            )  # fmt: skip

    counts["kanji"] = _batched(conn, INSERT_KANJI, kanji_rows())
    counts["kanji_components"] = _batched(conn, INSERT_KANJI_COMPONENT, comp_rows)

    # kanji_words: one pass over kanji-kind forms - every character of every form
    # text is a candidate link; rank by is_common DESC, freq_rank ASC, cap at 12.
    kform_q = WordForm.objects.filter(kind=WordForm.Kind.KANJI)
    if base:
        kform_q = kform_q.filter(BASE_WORDS_REL)
    candidates: dict[str, set[int]] = {}
    for wid, text in kform_q.values_list("word_id", "text").iterator(chunk_size=2000):
        for ch in set(text):
            if ch in kanji_set:
                candidates.setdefault(ch, set()).add(wid)

    def kanji_word_rows():
        for literal, wids in candidates.items():
            ranked = sorted(wids, key=lambda i: (-word_meta[i][0], word_meta[i][1], i))
            for rank, wid in enumerate(ranked[:KANJI_WORDS_CAP]):
                yield (literal, wid, rank)

    counts["kanji_words"] = _batched(conn, INSERT_KANJI_WORD, kanji_word_rows())

    def kana_rows():
        for k in Kana.objects.order_by("pk").iterator(chunk_size=2000):
            yield (
                k.char, k.romaji, k.script, k.kind, k.row, k.order, k.origin, k.origin_note,
                k.usage_label, k.usage, _json(k.usage_examples or []),
            )  # fmt: skip

    counts["kana"] = _batched(conn, INSERT_KANA, kana_rows())
    counts["radicals"] = _batched(
        conn,
        INSERT_RADICAL,
        Radical.objects.order_by("pk")
        .values_list("literal", "strokes", "reading", "meaning")
        .iterator(chunk_size=2000),
    )
    return counts


def _fill_glosses(conn: sqlite3.Connection, langs: list[str], *, base: bool) -> dict[str, int]:
    counts: dict[str, int] = {}

    gloss_q = Gloss.objects.filter(lang__in=langs).order_by("pk")
    if base:
        gloss_q = gloss_q.filter(BASE_WORDS_GLOSS)

    def gloss_rows():
        fields = (
            "id", "sense_id", "sense__word_id", "lang", "order", "text",
            "sense__word__freq_rank", "sense__word__is_common",
        )  # fmt: skip
        for pk, sid, wid, lang, ord_, text, rank, common in gloss_q.values_list(*fields).iterator(
            chunk_size=2000
        ):
            word_rank = rank if rank is not None else RANK_MAX
            yield (pk, sid, wid, lang, ord_, text, word_rank, int(common))

    counts["glosses"] = _batched(conn, INSERT_GLOSS, gloss_rows())

    meaning_q = KanjiMeaning.objects.filter(lang__in=langs).order_by("pk")
    if base:
        meaning_q = meaning_q.filter(kanji__jlpt__isnull=False)
    counts["kanji_meanings"] = _batched(
        conn,
        INSERT_KANJI_MEANING,
        meaning_q.values_list("kanji__literal", "lang", "order", "text").iterator(chunk_size=2000),
    )

    # External-content FTS: create after the rows exist, then bulk-index once.
    conn.execute(pack_schema.GLOSS_FTS)
    conn.execute("INSERT INTO gloss_fts(gloss_fts) VALUES('rebuild')")
    return counts


def _fill_names(conn: sqlite3.Connection) -> dict[str, int]:
    rows = (
        (pk, kanji or "", reading, _json(translations or []), _json(name_types or []))
        for pk, kanji, reading, translations, name_types in Name.objects.order_by("pk")
        .values_list("id", "kanji", "reading", "translations", "name_types")
        .iterator(chunk_size=2000)
    )
    return {"names": _batched(conn, INSERT_NAME, rows)}


def _fill_examples(conn: sqlite3.Connection) -> dict[str, int]:
    rows = (
        (pk, japanese, english or "")
        for pk, japanese, english in ExampleSentence.objects.order_by("pk")
        .values_list("id", "japanese", "english")
        .iterator(chunk_size=2000)
    )
    return {"examples": _batched(conn, INSERT_EXAMPLE, rows)}


def _fill_mnemonics(conn: sqlite3.Connection, lang: str) -> dict[str, int]:
    # Local import: mnemonics is a peer app, read-only here (seed_demo pattern).
    from mnemonics.models import Mnemonic, MnemonicStatus

    def rows():
        q = Mnemonic.objects.filter(
            is_seed=True, status=MnemonicStatus.VISIBLE, language=lang
        ).order_by("pk")
        for m in q.iterator(chunk_size=500):
            blob = None
            if m.image:
                try:
                    with m.image.open("rb") as fh:
                        blob = fh.read()
                except OSError:  # media file missing - ship the story without art
                    blob = None
            yield (
                m.pk, m.kind, m.character, m.language, m.story, m.score,
                blob, m.image_width, m.image_height,
            )  # fmt: skip

    return {"mnemonics": _batched(conn, INSERT_MNEMONIC, rows())}


# ── pack plans ────────────────────────────────────────────────────────────────


def _plan(name: str) -> dict:
    if name == "core":
        return {
            "id": "dict-core",
            "langs": [],
            "tables": pack_schema.CORE_TABLES,
            "indexes": pack_schema.CORE_INDEXES,
            "fill": lambda conn: _fill_core(conn, base=False),
            "requires": [],
            "title": {"en": "Japanese dictionary core", "fr": "Cœur du dictionnaire japonais"},
            "attribution": {
                k: ATTRIBUTION[k] for k in ("words", "kanji", "components", "strokes", "pitch")
            },
        }
    if name.startswith("gloss-"):
        lang = name.removeprefix("gloss-")
        en, fr = LANG_TITLES.get(lang, (lang, lang))
        return {
            "id": name,
            "langs": [lang],
            "tables": pack_schema.GLOSS_TABLES,
            "indexes": pack_schema.GLOSS_INDEXES,
            "fill": lambda conn: _fill_glosses(conn, [lang], base=False),
            "requires": ["dict-core"],  # word_id/sense_id point into dict-core
            "title": {"en": f"Definitions - {en}", "fr": f"Définitions - {fr}"},
            "attribution": {k: ATTRIBUTION[k] for k in ("words", "kanji")},
        }
    if name == "names":
        return {
            "id": "names",
            "langs": [],
            "tables": pack_schema.NAMES_TABLES,
            "indexes": pack_schema.NAMES_INDEXES,
            "fill": _fill_names,
            "requires": [],
            "title": {"en": "Proper names (JMnedict)", "fr": "Noms propres (JMnedict)"},
            "attribution": {"names": ATTRIBUTION["names"]},
        }
    if name == "examples":
        return {
            "id": "examples",
            "langs": [],
            "tables": pack_schema.EXAMPLES_TABLES,
            "indexes": pack_schema.EXAMPLES_INDEXES,
            "fill": _fill_examples,
            "requires": [],
            "title": {"en": "Example sentences", "fr": "Phrases d'exemple"},
            "attribution": {"examples": ATTRIBUTION["examples"]},
        }
    if name.startswith("mnemonics-"):
        lang = name.removeprefix("mnemonics-")
        en, fr = LANG_TITLES.get(lang, (lang, lang))
        return {
            "id": name,
            "langs": [lang],
            "tables": pack_schema.MNEMONICS_TABLES,
            "indexes": pack_schema.MNEMONICS_INDEXES,
            "fill": lambda conn: _fill_mnemonics(conn, lang),
            "requires": [],
            "title": {"en": f"Starter mnemonics - {en}", "fr": f"Mnémoniques de base - {fr}"},
            "attribution": {"mnemonics": ATTRIBUTION["mnemonics"]},
        }
    raise CommandError(f"unknown pack {name!r}")


# ── sqlite build plumbing ─────────────────────────────────────────────────────


def _create_db(
    path: Path, tables: list[str], pack_id: str, version: str, rev: int,
    langs: list[str], attribution: dict,
) -> sqlite3.Connection:  # fmt: skip
    path.unlink(missing_ok=True)
    conn = sqlite3.connect(path)
    # page_size must precede the first write; journal off - the build is one-shot
    # into a fresh file, a crashed build is simply rerun.
    conn.execute("PRAGMA page_size = 4096")
    conn.execute("PRAGMA journal_mode = OFF")
    conn.execute("PRAGMA synchronous = OFF")
    conn.execute(pack_schema.META_TABLE)
    for ddl in tables:
        conn.execute(ddl)
    conn.executemany(
        "INSERT INTO meta(key, value) VALUES (?, ?)",
        [
            ("pack_id", pack_id),
            ("pack_version", version),
            ("schema_version", str(pack_schema.SCHEMA_VERSION)),
            ("dataset_rev", str(rev)),
            ("built_at", datetime.now(UTC).isoformat(timespec="seconds")),
            ("attribution", _json(attribution)),
            ("languages", _json(langs)),
        ],
    )
    return conn


def _finish_db(conn: sqlite3.Connection, indexes: list[str]) -> None:
    for ddl in indexes:
        conn.execute(ddl)
    conn.execute("ANALYZE")
    conn.commit()
    conn.execute("VACUUM")  # needs autocommit - after the commit
    conn.close()


def _package(db_path: Path) -> dict:
    """Gzip the built db (deterministically: mtime=0), hash both, drop the raw file."""
    raw = db_path.read_bytes()
    gz = gzip.compress(raw, 9, mtime=0)
    gz_path = db_path.with_name(db_path.name + ".gz")
    gz_path.write_bytes(gz)
    db_path.unlink()
    return {
        "file": gz_path.name,
        "bytes": len(gz),
        "installed_bytes": len(raw),
        "sha256": hashlib.sha256(gz).hexdigest(),
        "sha256_db": hashlib.sha256(raw).hexdigest(),
    }


class Command(BaseCommand):
    help = "Build the per-pack SQLite content files + v2 manifest for offline use."

    def create_parser(self, prog_name, subcommand, **kwargs):
        # BaseCommand claims --version for Django's version banner; "resolve"
        # lets add_arguments redefine it as the pack version stamp.
        return super().create_parser(prog_name, subcommand, conflict_handler="resolve", **kwargs)

    def add_arguments(self, parser):
        parser.add_argument("--out", required=True, help="Output directory")
        parser.add_argument(
            "--packs",
            default=None,
            help=f"Comma list of packs (default: {','.join(DEFAULT_PACKS)})",
        )
        parser.add_argument(
            "--base",
            action="store_true",
            help="Also build base.db.gz (filtered, self-contained core+gloss for bundling)",
        )
        parser.add_argument(
            "--version",
            default=date.today().strftime("%Y.%m.%d"),
            help="Pack version stamp (default: today)",
        )
        parser.add_argument("--dataset-rev", type=int, default=1)

    def handle(self, *args, **opts):
        out = Path(opts["out"])
        out.mkdir(parents=True, exist_ok=True)
        version, rev = opts["version"], opts["dataset_rev"]

        packs = [p.strip() for p in (opts["packs"] or "").split(",") if p.strip()]
        if not packs and not opts["base"]:
            packs = list(DEFAULT_PACKS)

        entries = [self._build_pack(out, name, version, rev) for name in packs]
        if entries:
            manifest = {"schema": "jibiki-packs/2", "version": version, "packs": entries}
            (out / "packs_manifest.json").write_text(
                json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
            )
        if opts["base"]:
            self._build_base(out, version, rev)
        self.stdout.write(self.style.SUCCESS(f"Packs written to {out}"))

    def _build_pack(self, out: Path, name: str, version: str, rev: int) -> dict:
        plan = _plan(name)
        db_path = out / f"{plan['id']}-{version}.db"
        conn = _create_db(
            db_path, plan["tables"], plan["id"], version, rev, plan["langs"], plan["attribution"]
        )
        counts = plan["fill"](conn)
        _finish_db(conn, plan["indexes"])
        pkg = _package(db_path)
        self._report(plan["id"], version, counts, pkg)
        return {
            "id": plan["id"],
            "kind": "sqlite",
            "schema_version": pack_schema.SCHEMA_VERSION,
            "version": version,
            "dataset_rev": rev,
            **pkg,
            "counts": counts,
            "languages": plan["langs"],
            "requires": [{"id": rid, "version": version} for rid in plan["requires"]],
            "min_app_version": MIN_APP_VERSION,
            "title": plan["title"],
            "attribution": plan["attribution"],
        }

    def _build_base(self, out: Path, version: str, rev: int) -> None:
        attribution = {
            k: ATTRIBUTION[k] for k in ("words", "kanji", "components", "strokes", "pitch")
        }
        db_path = out / "base.db"
        conn = _create_db(
            db_path,
            [*pack_schema.CORE_TABLES, *pack_schema.GLOSS_TABLES],
            "dict-base", version, rev, BASE_LANGS, attribution,
        )  # fmt: skip
        counts = _fill_core(conn, base=True)
        counts |= _fill_glosses(conn, BASE_LANGS, base=True)
        _finish_db(conn, [*pack_schema.CORE_INDEXES, *pack_schema.GLOSS_INDEXES])
        pkg = _package(db_path)
        entry = {
            "id": "dict-base",
            "kind": "sqlite",
            "schema_version": pack_schema.SCHEMA_VERSION,
            "version": version,
            "dataset_rev": rev,
            **pkg,
            "counts": counts,
            "languages": BASE_LANGS,
            "min_app_version": MIN_APP_VERSION,
            "attribution": attribution,
        }
        (out / "base_manifest.json").write_text(
            json.dumps(entry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        self._report("dict-base", version, counts, pkg)

    def _report(self, pack_id: str, version: str, counts: dict[str, int], pkg: dict) -> None:
        self.stdout.write(
            f"  {pack_id} v{version}: {sum(counts.values())} rows, "
            f"{pkg['installed_bytes'] / 1_000_000:.1f} MB raw, {pkg['bytes'] / 1_000_000:.1f} MB gz"
        )
