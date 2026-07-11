"""SQLite schema for generated offline content packs.

The schema mirrors domain boundaries, not import file shapes. Core tables contain
language-neutral Japanese data. Human-readable translations live only in locale
packs. Mnemonics are intentionally stored in language-specific packs because a
mnemonic is authored for a language, not translated from a neutral original.
"""

from __future__ import annotations

SCHEMA_VERSION = 2

FORM_KIND = {"kanji": 0, "kana": 1}
META_TABLE = "CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT)"

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
        field TEXT NOT NULL DEFAULT '[]'
    )""",
    """CREATE TABLE kanji(
        literal TEXT PRIMARY KEY,
        grade INTEGER,
        stroke_count INTEGER NOT NULL,
        jlpt INTEGER,
        freq_rank INTEGER,
        radical_number INTEGER,
        on_readings TEXT NOT NULL DEFAULT '[]',
        kun_readings TEXT NOT NULL DEFAULT '[]',
        nanori TEXT NOT NULL DEFAULT '[]',
        components TEXT NOT NULL DEFAULT '[]',
        formation TEXT NOT NULL DEFAULT '',
        phonetic TEXT NOT NULL DEFAULT '',
        stroke_paths TEXT NOT NULL DEFAULT '[]',
        stroke_viewbox TEXT NOT NULL DEFAULT '0 0 109 109'
    )""",
    """CREATE TABLE kanji_components(
        kanji TEXT NOT NULL,
        component TEXT NOT NULL
    )""",
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
        origin TEXT NOT NULL DEFAULT ''
    )""",
    """CREATE TABLE kana_usages(
        id INTEGER PRIMARY KEY,
        kana TEXT NOT NULL UNIQUE
    )""",
    """CREATE TABLE kana_usage_examples(
        id INTEGER PRIMARY KEY,
        usage_id INTEGER NOT NULL,
        ord INTEGER NOT NULL DEFAULT 0,
        before_text TEXT NOT NULL DEFAULT '',
        particle TEXT NOT NULL,
        after_text TEXT NOT NULL DEFAULT '',
        pronunciation TEXT NOT NULL DEFAULT ''
    )""",
    """CREATE TABLE radicals(
        literal TEXT PRIMARY KEY,
        strokes INTEGER NOT NULL DEFAULT 0,
        reading TEXT NOT NULL DEFAULT ''
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
    "CREATE INDEX idx_kana_usage_examples_usage ON kana_usage_examples(usage_id, ord)",
]

LOCALIZED_TABLES = [
    """CREATE TABLE glosses(
        id INTEGER PRIMARY KEY,
        sense_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        language TEXT NOT NULL,
        ord INTEGER NOT NULL,
        text TEXT NOT NULL,
        word_rank INTEGER NOT NULL,
        word_common INTEGER NOT NULL
    )""",
    """CREATE TABLE kanji_meanings(
        kanji TEXT NOT NULL,
        language TEXT NOT NULL,
        ord INTEGER NOT NULL,
        text TEXT NOT NULL
    )""",
    """CREATE TABLE sense_notes(
        sense_id INTEGER NOT NULL,
        language TEXT NOT NULL,
        text TEXT NOT NULL
    )""",
    """CREATE TABLE radical_meanings(
        radical TEXT NOT NULL,
        language TEXT NOT NULL,
        text TEXT NOT NULL
    )""",
    """CREATE TABLE kanji_explanations(
        kanji TEXT NOT NULL,
        language TEXT NOT NULL,
        origin TEXT NOT NULL DEFAULT ''
    )""",
    """CREATE TABLE kana_explanations(
        kana TEXT NOT NULL,
        language TEXT NOT NULL,
        origin_note TEXT NOT NULL
    )""",
    """CREATE TABLE kana_usage_translations(
        usage_id INTEGER NOT NULL,
        language TEXT NOT NULL,
        label TEXT NOT NULL,
        explanation TEXT NOT NULL
    )""",
    """CREATE TABLE kana_usage_example_translations(
        example_id INTEGER NOT NULL,
        language TEXT NOT NULL,
        text TEXT NOT NULL
    )""",
]

LOCALIZED_INDEXES = [
    "CREATE INDEX idx_glosses_sense ON glosses(sense_id)",
    "CREATE INDEX idx_glosses_text ON glosses(text COLLATE NOCASE)",
    "CREATE INDEX idx_kanji_meanings_kanji ON kanji_meanings(kanji)",
    "CREATE INDEX idx_radical_meanings_radical ON radical_meanings(radical)",
    "CREATE INDEX idx_kana_explanations_kana ON kana_explanations(kana)",
]

GLOSS_FTS = (
    "CREATE VIRTUAL TABLE gloss_fts USING fts5("
    "text, content='glosses', content_rowid='id', "
    'tokenize="unicode61 remove_diacritics 2")'
)

NAMES_TABLES = [
    """CREATE TABLE names(
        id INTEGER PRIMARY KEY,
        kanji TEXT NOT NULL DEFAULT '',
        reading TEXT NOT NULL,
        name_types TEXT NOT NULL DEFAULT '[]'
    )""",
    """CREATE TABLE name_translations(
        name_id INTEGER NOT NULL,
        language TEXT NOT NULL,
        ord INTEGER NOT NULL DEFAULT 0,
        text TEXT NOT NULL
    )""",
]

NAMES_INDEXES = [
    "CREATE INDEX idx_names_kanji ON names(kanji)",
    "CREATE INDEX idx_names_reading ON names(reading)",
    "CREATE INDEX idx_name_translations_name ON name_translations(name_id, language, ord)",
]

EXAMPLES_TABLES = [
    """CREATE TABLE examples(
        id INTEGER PRIMARY KEY,
        japanese TEXT NOT NULL
    )""",
    """CREATE TABLE example_translations(
        example_id INTEGER NOT NULL,
        language TEXT NOT NULL,
        text TEXT NOT NULL
    )""",
]

EXAMPLES_INDEXES = [
    "CREATE INDEX idx_example_translations_example ON example_translations(example_id, language)"
]

MNEMONICS_TABLES = [
    """CREATE TABLE mnemonics(
        id INTEGER PRIMARY KEY,
        kind TEXT NOT NULL,
        character TEXT NOT NULL,
        language TEXT NOT NULL,
        reading TEXT NOT NULL DEFAULT '',
        story TEXT NOT NULL,
        score INTEGER NOT NULL DEFAULT 0,
        image BLOB,
        image_w INTEGER NOT NULL DEFAULT 0,
        image_h INTEGER NOT NULL DEFAULT 0
    )""",
]

MNEMONICS_INDEXES = [
    "CREATE INDEX idx_mnemonics_target ON mnemonics(kind, character, reading)"
]
