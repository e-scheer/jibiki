"""DDL for the on-device SQLite content packs (schema_version 1).

One pack = one SQLite file the Flutter app opens read-only; the server's
build_packs command is the only writer. The layout mirrors the Django models but
denormalizes what the app needs hot (headword/primary_reading on words,
word_rank/word_common on glosses) so list screens are single-table scans.

Invariants the app relies on:
  * words.id IS the server Word.id - study Cards reference it (SRS item_ref),
    so ids are copied verbatim, never remapped.
  * word_forms.kind is packed to an integer (FORM_KIND below): 0=kanji, 1=kana.
  * JSON-typed model fields (pos, components, usage_examples, …) are stored as
    JSON text; '[]' when empty.
  * Indexes are NOT part of the table lists - the builder creates them after the
    bulk inserts (faster, and keeps the file layout compact for VACUUM).
"""

from __future__ import annotations

SCHEMA_VERSION = 1

# WordForm.Kind → packed integer (word_forms.kind).
FORM_KIND = {"kanji": 0, "kana": 1}

META_TABLE = "CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT)"

# ── core (dict-core, also the first half of base) ────────────────────────────

CORE_TABLES = [
    """CREATE TABLE words(
        id INTEGER PRIMARY KEY,
        seq INTEGER,
        is_common INTEGER NOT NULL DEFAULT 0,
        jlpt INTEGER,
        freq_rank INTEGER,
        headword TEXT NOT NULL,
        primary_reading TEXT NOT NULL
    )""",
    """CREATE TABLE word_forms(
        id INTEGER PRIMARY KEY,
        word_id INTEGER NOT NULL,
        text TEXT NOT NULL,
        kind INTEGER NOT NULL,
        is_common INTEGER NOT NULL DEFAULT 0,
        ord INTEGER NOT NULL DEFAULT 0,
        pitch TEXT NOT NULL DEFAULT ''
    )""",
    """CREATE TABLE senses(
        id INTEGER PRIMARY KEY,
        word_id INTEGER NOT NULL,
        ord INTEGER NOT NULL,
        pos TEXT NOT NULL DEFAULT '[]',
        misc TEXT NOT NULL DEFAULT '[]',
        field TEXT NOT NULL DEFAULT '[]',
        info TEXT NOT NULL DEFAULT ''
    )""",
    """CREATE TABLE kanji(
        literal TEXT PRIMARY KEY,
        grade INTEGER,
        stroke_count INTEGER NOT NULL,
        jlpt INTEGER,
        freq_rank INTEGER,
        radical_number INTEGER,
        on_readings TEXT,
        kun_readings TEXT,
        nanori TEXT,
        components TEXT,
        origin TEXT DEFAULT '',
        formation TEXT DEFAULT '',
        phonetic TEXT DEFAULT '',
        stroke_paths TEXT DEFAULT '[]',
        stroke_viewbox TEXT DEFAULT '0 0 109 109'
    )""",
    # Kanji.components exploded to rows - the radical-grid lookup needs
    # component → kanji, which JSON text can't index.
    """CREATE TABLE kanji_components(
        kanji TEXT NOT NULL,
        component TEXT NOT NULL
    )""",
    # Top words per kanji, precomputed at build time (rank 0 = best) - replaces
    # the server-side "words containing this kanji" query on the detail screen.
    """CREATE TABLE kanji_words(
        kanji TEXT NOT NULL,
        word_id INTEGER NOT NULL,
        rank INTEGER NOT NULL
    )""",
    """CREATE TABLE kana(
        char TEXT PRIMARY KEY,
        romaji TEXT NOT NULL,
        script TEXT NOT NULL,
        kind TEXT NOT NULL,
        "row" TEXT NOT NULL DEFAULT '',
        ord INTEGER NOT NULL DEFAULT 0,
        origin TEXT NOT NULL DEFAULT '',
        origin_note TEXT NOT NULL DEFAULT '',
        usage_label TEXT NOT NULL DEFAULT '',
        usage TEXT NOT NULL DEFAULT '',
        usage_examples TEXT NOT NULL DEFAULT '[]'
    )""",
    """CREATE TABLE radicals(
        literal TEXT PRIMARY KEY,
        strokes INTEGER NOT NULL DEFAULT 0,
        reading TEXT NOT NULL DEFAULT '',
        meaning TEXT NOT NULL DEFAULT ''
    )""",
]

CORE_INDEXES = [
    "CREATE INDEX idx_words_common_rank ON words(is_common, freq_rank)",
    "CREATE INDEX idx_words_jlpt ON words(jlpt) WHERE jlpt IS NOT NULL",
    "CREATE INDEX idx_word_forms_text ON word_forms(text)",
    "CREATE INDEX idx_word_forms_word ON word_forms(word_id)",
    "CREATE INDEX idx_senses_word ON senses(word_id)",
    "CREATE INDEX idx_kanji_jlpt ON kanji(jlpt)",
    "CREATE INDEX idx_kanji_grade ON kanji(grade)",
    "CREATE INDEX idx_kanji_components_component ON kanji_components(component)",
    "CREATE INDEX idx_kanji_words_kanji ON kanji_words(kanji, rank)",
]

# ── gloss packs (gloss-<lang>, also the second half of base) ─────────────────

GLOSS_TABLES = [
    # word_rank/word_common denormalize the owning Word's ranking so reverse
    # search (gloss text → word) can ORDER BY without the words table attached.
    """CREATE TABLE glosses(
        id INTEGER PRIMARY KEY,
        sense_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        lang TEXT NOT NULL,
        ord INTEGER NOT NULL,
        text TEXT NOT NULL,
        word_rank INTEGER NOT NULL,
        word_common INTEGER NOT NULL
    )""",
    """CREATE TABLE kanji_meanings(
        kanji TEXT NOT NULL,
        lang TEXT NOT NULL,
        ord INTEGER NOT NULL,
        text TEXT NOT NULL
    )""",
]

GLOSS_INDEXES = [
    "CREATE INDEX idx_glosses_sense ON glosses(sense_id)",
    "CREATE INDEX idx_glosses_text ON glosses(text COLLATE NOCASE)",
    "CREATE INDEX idx_kanji_meanings_kanji ON kanji_meanings(kanji)",
]

# External-content FTS over glosses.text - created (then 'rebuild'-populated)
# after the glosses inserts. remove_diacritics 2 folds é/è/ê for French search.
GLOSS_FTS = (
    "CREATE VIRTUAL TABLE gloss_fts USING fts5("
    "text, content='glosses', content_rowid='id', "
    'tokenize="unicode61 remove_diacritics 2")'
)

# ── names pack (JMnedict) ─────────────────────────────────────────────────────

NAMES_TABLES = [
    """CREATE TABLE names(
        id INTEGER PRIMARY KEY,
        kanji TEXT DEFAULT '',
        reading TEXT NOT NULL,
        translations TEXT DEFAULT '[]',
        name_types TEXT DEFAULT '[]'
    )""",
]

NAMES_INDEXES = [
    "CREATE INDEX idx_names_kanji ON names(kanji)",
    "CREATE INDEX idx_names_reading ON names(reading)",
]

# ── examples pack (Tanaka/Tatoeba) ───────────────────────────────────────────

EXAMPLES_TABLES = [
    """CREATE TABLE examples(
        id INTEGER PRIMARY KEY,
        japanese TEXT NOT NULL,
        english TEXT DEFAULT ''
    )""",
]

EXAMPLES_INDEXES: list[str] = []

# ── mnemonics packs (mnemonics-<lang>, seed content only) ───────────────────

MNEMONICS_TABLES = [
    """CREATE TABLE mnemonics(
        id INTEGER PRIMARY KEY,
        kind TEXT,
        character TEXT,
        language TEXT,
        story TEXT,
        score INTEGER,
        image BLOB,
        image_w INTEGER,
        image_h INTEGER
    )""",
]

MNEMONICS_INDEXES = [
    "CREATE INDEX idx_mnemonics_kind_character ON mnemonics(kind, character)",
]
