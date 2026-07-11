"""The dictionary - read-mostly reference data ingested from the free EDRDG family
(JMdict, KANJIDIC2, KRADFILE) plus a bundled kana table.

Design (DEEP_SEARCH feature 4): the JMdict entry shape is normalized into
Word → WordForm (searchable kanji/kana surface forms) and Word → Sense → Gloss
(multi-language glosses). Kanji and Kana are their own tables so a study Card can
point at any of the three item kinds. Everything here is imported (management
commands) - the API only reads it.

Glosses and meanings are normalized into their own rows (not JSON) so search can
filter by language with a plain ``text__icontains``, trigram-accelerated on
Postgres (see the ``*_trgm`` migrations).
"""

from __future__ import annotations

from django.db import models

# ── Words (JMdict) ────────────────────────────────────────────────────────────


class Word(models.Model):
    """A JMdict entry. Its writeable surface forms live in WordForm; its meanings
    in Sense/Gloss. ``seq`` is JMdict's ent_seq (stable across releases)."""

    id = models.BigAutoField(primary_key=True)
    seq = models.BigIntegerField(unique=True, null=True, blank=True)  # JMdict ent_seq
    is_common = models.BooleanField(default=False)
    jlpt = models.PositiveSmallIntegerField(null=True, blank=True)  # 5..1 (community mapping)
    freq_rank = models.PositiveIntegerField(null=True, blank=True)  # lower = more frequent

    class Meta:
        db_table = "dict_words"
        indexes = [
            models.Index(fields=["is_common", "freq_rank"]),
            models.Index(fields=["jlpt"]),
        ]

    def __str__(self) -> str:
        head = self.forms.order_by("kind", "order").first()
        return head.text if head else f"word#{self.pk}"

    @property
    def headword(self) -> str:
        # Iterate the (prefetched) forms cache instead of `.filter()`, which would
        # fire a fresh query per call and defeat prefetch_related("forms").
        forms = self.forms.all()
        kanji = [f for f in forms if f.kind == WordForm.Kind.KANJI]
        kana = [f for f in forms if f.kind == WordForm.Kind.KANA]
        group = kanji or kana
        return min(group, key=lambda f: f.order).text if group else ""

    @property
    def primary_reading(self) -> str:
        kana = [f for f in self.forms.all() if f.kind == WordForm.Kind.KANA]
        return min(kana, key=lambda f: f.order).text if kana else ""


class WordForm(models.Model):
    """One written form of a word - a kanji surface form (k_ele) or a kana reading
    (r_ele). This is the Japanese-input search index: exact / prefix / contains
    lookups hit ``text`` here, ranked by ``is_common``."""

    class Kind(models.TextChoices):
        KANJI = "kanji", "Kanji"
        KANA = "kana", "Kana"

    id = models.BigAutoField(primary_key=True)
    word = models.ForeignKey(Word, on_delete=models.CASCADE, related_name="forms")
    text = models.CharField(max_length=64)
    kind = models.CharField(max_length=8, choices=Kind.choices)
    is_common = models.BooleanField(default=False)
    order = models.PositiveSmallIntegerField(default=0)
    # Pitch-accent pattern for this reading (Kanjium): e.g. "0" (heiban) or "0,2"
    # (multiple accepted patterns). Blank when unknown.
    pitch = models.CharField(max_length=32, blank=True)

    class Meta:
        db_table = "dict_word_forms"
        indexes = [
            models.Index(fields=["text"]),
            models.Index(fields=["kind", "text"]),
        ]
        ordering = ["word", "kind", "order"]

    def __str__(self) -> str:
        return self.text


class Sense(models.Model):
    """One meaning of a word: a set of parts-of-speech + cross-lingual glosses.
    ``pos`` and ``misc`` keep JMdict's tag codes as JSON lists (they are display
    metadata, never queried by value)."""

    id = models.BigAutoField(primary_key=True)
    word = models.ForeignKey(Word, on_delete=models.CASCADE, related_name="senses")
    order = models.PositiveSmallIntegerField(default=0)
    pos = models.JSONField(default=list, blank=True)  # ["n", "vs", ...]
    misc = models.JSONField(default=list, blank=True)  # ["uk", "col", ...]
    field = models.JSONField(default=list, blank=True)  # ["comp", "med", ...]

    class Meta:
        db_table = "dict_senses"
        ordering = ["word", "order"]

    def __str__(self) -> str:
        return f"sense#{self.pk} of word#{self.word_id}"


class Gloss(models.Model):
    """A single translated gloss inside a sense. Language-tagged (ISO 639-1-ish:
    'en', 'fr', 'de', 'nl', ...) so search can restrict to the user's language."""

    id = models.BigAutoField(primary_key=True)
    sense = models.ForeignKey(Sense, on_delete=models.CASCADE, related_name="glosses")
    language = models.CharField(max_length=8, default="en")
    text = models.CharField(max_length=255)
    order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        db_table = "dict_glosses"
        constraints = [
            models.UniqueConstraint(
                fields=["sense", "language", "order"], name="uq_gloss_language_order"
            )
        ]
        indexes = [
            models.Index(
                fields=["language", "text"], name="dict_glosse_lang_d7fe9f_idx"
            ),
        ]
        ordering = ["sense", "order"]

    def __str__(self) -> str:
        return f"[{self.language}] {self.text}"


class SenseNote(models.Model):
    """Localized usage or scope note attached to a dictionary sense."""

    id = models.BigAutoField(primary_key=True)
    sense = models.ForeignKey(Sense, on_delete=models.CASCADE, related_name="notes")
    language = models.CharField(max_length=8, default="en")
    text = models.CharField(max_length=255)

    class Meta:
        db_table = "dict_sense_notes"
        constraints = [
            models.UniqueConstraint(fields=["sense", "language"], name="uq_sense_note_language")
        ]

    def __str__(self) -> str:
        return f"[{self.language}] {self.text}"


# ── Kanji (KANJIDIC2 + KRADFILE) ───────────────────────────────────────────────


class Radical(models.Model):
    """A radical / component from RADKFILE - used for the radical-grid lookup
    (find kanji by the parts they contain, DEEP_SEARCH feature 7) and as the label
    set for kanji decomposition."""

    id = models.BigAutoField(primary_key=True)
    literal = models.CharField(max_length=4, unique=True)
    strokes = models.PositiveSmallIntegerField(default=0)
    reading = models.CharField(max_length=32, blank=True)  # kana name of the radical

    class Meta:
        db_table = "dict_radicals"
        ordering = ["strokes", "literal"]

    def __str__(self) -> str:
        return self.literal


class RadicalMeaning(models.Model):
    """A language-tagged display name for a radical or component."""

    id = models.BigAutoField(primary_key=True)
    radical = models.ForeignKey(Radical, on_delete=models.CASCADE, related_name="meanings")
    language = models.CharField(max_length=8, default="en")
    text = models.CharField(max_length=64)

    class Meta:
        db_table = "dict_radical_meanings"
        constraints = [
            models.UniqueConstraint(
                fields=["radical", "language"], name="uq_radical_meaning_language"
            )
        ]
        indexes = [
            models.Index(fields=["language", "text"], name="dict_radica_languag_8f2c77_idx")
        ]

    def __str__(self) -> str:
        return f"[{self.language}] {self.text}"


class Kanji(models.Model):
    """A KANJIDIC2 character. ``components`` is the KRADFILE decomposition (a JSON
    list of component literals) that drives the decomposition tree; ``meanings``
    are stored as rows (KanjiMeaning) for language-filtered search."""

    id = models.BigAutoField(primary_key=True)
    literal = models.CharField(max_length=4, unique=True)
    grade = models.PositiveSmallIntegerField(null=True, blank=True)  # 1..6 kyōiku, 8 jōyō, ...
    stroke_count = models.PositiveSmallIntegerField(default=0)
    jlpt = models.PositiveSmallIntegerField(null=True, blank=True)
    freq_rank = models.PositiveIntegerField(null=True, blank=True)
    radical_number = models.PositiveSmallIntegerField(null=True, blank=True)  # classical (Kangxi)

    on_readings = models.JSONField(default=list, blank=True)  # ["ショク", "ジキ"]
    kun_readings = models.JSONField(default=list, blank=True)  # ["く.う", "た.べる"]
    nanori = models.JSONField(default=list, blank=True)  # name readings

    components = models.JSONField(default=list, blank=True)  # ["𠆢", "良"] (KRADFILE)

    # Glyph origin / etymology (Wiktionary "Glyph origin", CC BY-SA). Empty until
    # import_wiktionary runs. ``formation`` is the classification the text opens
    # with ("phono-semantic", "ideogrammic", "pictogram", …); ``phonetic`` is the
    # 音符 (sound-carrying) component when the text names one - the keisei clue that
    # explains why a part is present even when it carries no meaning.
    formation = models.CharField(max_length=32, blank=True)
    phonetic = models.CharField(max_length=8, blank=True)

    # KanjiVG stroke-order data (CC BY-SA 3.0): ordered SVG path `d` strings, one
    # per stroke, drawn on a 109×109 canvas. Empty until import_kanjivg runs (the
    # demo seed bakes it for the bundled kanji). Powers the stroke animation.
    stroke_paths = models.JSONField(default=list, blank=True)
    stroke_viewbox = models.CharField(max_length=32, blank=True, default="0 0 109 109")

    class Meta:
        db_table = "dict_kanji"
        indexes = [
            models.Index(fields=["jlpt"]),
            models.Index(fields=["grade"]),
            models.Index(fields=["freq_rank"]),
        ]
        ordering = ["freq_rank", "stroke_count", "literal"]

    def __str__(self) -> str:
        return self.literal


class KanjiMeaning(models.Model):
    id = models.BigAutoField(primary_key=True)
    kanji = models.ForeignKey(Kanji, on_delete=models.CASCADE, related_name="meanings")
    language = models.CharField(max_length=8, default="en")
    text = models.CharField(max_length=128)
    order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        db_table = "dict_kanji_meanings"
        constraints = [
            models.UniqueConstraint(
                fields=["kanji", "language", "order"],
                name="uq_kanji_meaning_language_order",
            )
        ]
        indexes = [
            models.Index(
                fields=["language", "text"], name="dict_kanji__lang_53ea8b_idx"
            )
        ]
        ordering = ["kanji", "order"]

    def __str__(self) -> str:
        return f"[{self.language}] {self.text}"


class KanjiExplanation(models.Model):
    """Localized prose about a kanji's glyph origin.

    ``Kanji.formation`` and ``Kanji.phonetic`` remain language-neutral codes.
    Only human-readable prose belongs here.
    """

    id = models.BigAutoField(primary_key=True)
    kanji = models.ForeignKey(Kanji, on_delete=models.CASCADE, related_name="explanations")
    language = models.CharField(max_length=8, default="en")
    origin = models.TextField(blank=True)

    class Meta:
        db_table = "dict_kanji_explanations"
        constraints = [
            models.UniqueConstraint(
                fields=["kanji", "language"], name="uq_kanji_explanation_language"
            )
        ]

    def __str__(self) -> str:
        return f"{self.kanji.literal} [{self.language}]"


# ── Kana (bundled) ──────────────────────────────────────────────────────────


class Kana(models.Model):
    """A language-neutral kana character.

    Explanations and grammatical content live in localized child rows. Mnemonics
    remain separate, language-native community content in the ``mnemonics`` app.
    """

    class Script(models.TextChoices):
        HIRAGANA = "hiragana", "Hiragana"
        KATAKANA = "katakana", "Katakana"

    class Kind(models.TextChoices):
        GOJUON = "gojuon", "Gojūon"  # base syllables
        DAKUTEN = "dakuten", "Dakuten"  # voiced (゛)
        HANDAKUTEN = "handakuten", "Handakuten"  # half-voiced (゜)
        YOON = "yoon", "Yōon"  # contracted (きゃ …)

    id = models.BigAutoField(primary_key=True)
    char = models.CharField(max_length=4, unique=True)
    romaji = models.CharField(max_length=8)
    script = models.CharField(max_length=10, choices=Script.choices)
    kind = models.CharField(max_length=12, choices=Kind.choices, default=Kind.GOJUON)
    row = models.CharField(max_length=4, blank=True)  # gojūon row key: a,k,s,t,n,h,m,y,r,w
    order = models.PositiveSmallIntegerField(default=0)  # chart order

    # Writing origin: the character this glyph was derived from - a man'yōgana kanji
    # for the base gojūon set (hiragana = its cursive whole, katakana = a fragment
    # of it), or the base kana for dakuten/handakuten rows.
    origin = models.CharField(max_length=8, blank=True)

    class Meta:
        db_table = "dict_kana"
        ordering = ["script", "order"]
        indexes = [models.Index(fields=["script", "kind"])]

    def __str__(self) -> str:
        return f"{self.char} ({self.romaji})"


class KanaExplanation(models.Model):
    """Localized explanation of how a kana acquired its shape."""

    id = models.BigAutoField(primary_key=True)
    kana = models.ForeignKey(Kana, on_delete=models.CASCADE, related_name="explanations")
    language = models.CharField(max_length=8, default="en")
    origin_note = models.CharField(max_length=255)

    class Meta:
        db_table = "dict_kana_explanations"
        constraints = [
            models.UniqueConstraint(
                fields=["kana", "language"], name="uq_kana_explanation_language"
            )
        ]


class KanaUsage(models.Model):
    """A language-neutral grammatical role carried by a kana."""

    id = models.BigAutoField(primary_key=True)
    kana = models.OneToOneField(
        Kana, on_delete=models.CASCADE, related_name="grammatical_usage"
    )

    class Meta:
        db_table = "dict_kana_usages"


class KanaUsageTranslation(models.Model):
    id = models.BigAutoField(primary_key=True)
    usage = models.ForeignKey(KanaUsage, on_delete=models.CASCADE, related_name="translations")
    language = models.CharField(max_length=8, default="en")
    label = models.CharField(max_length=48)
    explanation = models.CharField(max_length=255)

    class Meta:
        db_table = "dict_kana_usage_translations"
        constraints = [
            models.UniqueConstraint(
                fields=["usage", "language"], name="uq_kana_usage_translation_language"
            )
        ]


class KanaUsageExample(models.Model):
    """Japanese sentence segments are neutral; translations are separate rows."""

    id = models.BigAutoField(primary_key=True)
    usage = models.ForeignKey(KanaUsage, on_delete=models.CASCADE, related_name="examples")
    order = models.PositiveSmallIntegerField(default=0)
    before = models.TextField(blank=True)
    particle = models.CharField(max_length=8)
    after = models.TextField(blank=True)
    pronunciation = models.CharField(max_length=255, blank=True)

    class Meta:
        db_table = "dict_kana_usage_examples"
        ordering = ["usage", "order"]
        constraints = [
            models.UniqueConstraint(
                fields=["usage", "order"], name="uq_kana_usage_example_order"
            )
        ]


class KanaUsageExampleTranslation(models.Model):
    id = models.BigAutoField(primary_key=True)
    example = models.ForeignKey(
        KanaUsageExample, on_delete=models.CASCADE, related_name="translations"
    )
    language = models.CharField(max_length=8, default="en")
    text = models.TextField()

    class Meta:
        db_table = "dict_kana_usage_example_translations"
        constraints = [
            models.UniqueConstraint(
                fields=["example", "language"], name="uq_kana_example_translation_language"
            )
        ]


# ── Example sentences (Tanaka/Tatoeba corpus) ──────────────────────────────────


class ExampleSentence(models.Model):
    """A Japanese sentence. Language-specific translations are child rows."""

    id = models.BigAutoField(primary_key=True)
    japanese = models.TextField()

    class Meta:
        db_table = "dict_examples"

    def __str__(self) -> str:
        return self.japanese[:40]


class ExampleTranslation(models.Model):
    id = models.BigAutoField(primary_key=True)
    example = models.ForeignKey(
        ExampleSentence, on_delete=models.CASCADE, related_name="translations"
    )
    language = models.CharField(max_length=8, default="en")
    text = models.TextField()

    class Meta:
        db_table = "dict_example_translations"
        constraints = [
            models.UniqueConstraint(
                fields=["example", "language"], name="uq_example_translation_language"
            )
        ]


# ── Proper names (JMnedict) ────────────────────────────────────────────────────


class Name(models.Model):
    """A JMnedict proper-name entry: a place, surname, given name, company, etc.
    Kept in its own table so it never dilutes ordinary word search unless asked."""

    id = models.BigAutoField(primary_key=True)
    seq = models.BigIntegerField(unique=True, null=True, blank=True)
    kanji = models.CharField(max_length=64, blank=True)  # surface form (may be empty)
    reading = models.CharField(max_length=64)  # kana reading
    name_types = models.JSONField(default=list, blank=True)  # ["place", "surname", …]

    class Meta:
        db_table = "dict_names"
        indexes = [
            models.Index(fields=["reading"]),
            models.Index(fields=["kanji"]),
        ]

    def __str__(self) -> str:
        return f"{self.kanji or self.reading} ({self.reading})"


class NameTranslation(models.Model):
    id = models.BigAutoField(primary_key=True)
    name = models.ForeignKey(
        Name, on_delete=models.CASCADE, related_name="localized_names"
    )
    language = models.CharField(max_length=8, default="en")
    text = models.CharField(max_length=255)
    order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        db_table = "dict_name_translations"
        ordering = ["name", "language", "order"]
        constraints = [
            models.UniqueConstraint(
                fields=["name", "language", "order"],
                name="uq_name_translation_language_order",
            )
        ]
        indexes = [
            models.Index(fields=["language", "text"], name="dict_name_t_languag_f34c86_idx")
        ]
