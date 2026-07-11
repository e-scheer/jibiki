from __future__ import annotations

from rest_framework import serializers

from accounts.languages import DEFAULT_LANGUAGE, normalize_language_code

from .models import (
    ExampleSentence,
    Gloss,
    Kana,
    Kanji,
    KanjiMeaning,
    Name,
    Radical,
    Sense,
    SenseNote,
    Word,
    WordForm,
)


def _requested_language(context: dict) -> str:
    request = context.get("request")
    value = request.query_params.get("lang") if request is not None else None
    return normalize_language_code(value)


def _localized(rows, language: str):
    """Select one language without pretending that a fallback is a translation."""

    values = list(rows)
    exact = [row for row in values if row.language == language]
    if exact:
        return exact
    english = [row for row in values if row.language == DEFAULT_LANGUAGE]
    return english or values[:1]


class GlossSerializer(serializers.ModelSerializer):
    class Meta:
        model = Gloss
        fields = ["language", "text"]


class TranslationSerializer(serializers.Serializer):
    language = serializers.CharField()
    text = serializers.CharField()


class ExampleSerializer(serializers.ModelSerializer):
    translations = TranslationSerializer(many=True, read_only=True)
    translation = serializers.SerializerMethodField()

    class Meta:
        model = ExampleSentence
        fields = ["japanese", "translation", "translations"]

    def get_translation(self, example: ExampleSentence) -> str:
        rows = _localized(example.translations.all(), _requested_language(self.context))
        return rows[0].text if rows else ""


class NameSerializer(serializers.ModelSerializer):
    translations = TranslationSerializer(source="localized_names", many=True, read_only=True)
    translation = serializers.SerializerMethodField()

    class Meta:
        model = Name
        fields = ["kanji", "reading", "translation", "translations", "name_types"]

    def get_translation(self, name: Name) -> str:
        rows = _localized(name.localized_names.all(), _requested_language(self.context))
        return rows[0].text if rows else ""


class SenseNoteSerializer(serializers.ModelSerializer):
    class Meta:
        model = SenseNote
        fields = ["language", "text"]


class SenseSerializer(serializers.ModelSerializer):
    glosses = GlossSerializer(many=True, read_only=True)
    notes = SenseNoteSerializer(many=True, read_only=True)

    class Meta:
        model = Sense
        fields = ["order", "pos", "misc", "field", "notes", "glosses"]


class WordFormSerializer(serializers.ModelSerializer):
    class Meta:
        model = WordForm
        fields = ["text", "is_common", "pitch"]


class WordSerializer(serializers.ModelSerializer):
    headword = serializers.CharField(read_only=True)
    primary_reading = serializers.CharField(read_only=True)
    kanji = serializers.SerializerMethodField()
    readings = serializers.SerializerMethodField()
    senses = SenseSerializer(many=True, read_only=True)

    class Meta:
        model = Word
        fields = [
            "id",
            "seq",
            "is_common",
            "jlpt",
            "freq_rank",
            "headword",
            "primary_reading",
            "kanji",
            "readings",
            "senses",
        ]

    def _forms(self, word: Word, kind: str) -> list[dict]:
        forms = [form for form in word.forms.all() if form.kind == kind]
        forms.sort(key=lambda form: form.order)
        return WordFormSerializer(forms, many=True).data

    def get_kanji(self, word: Word) -> list[dict]:
        return self._forms(word, WordForm.Kind.KANJI)

    def get_readings(self, word: Word) -> list[dict]:
        return self._forms(word, WordForm.Kind.KANA)


class KanjiMeaningSerializer(serializers.ModelSerializer):
    class Meta:
        model = KanjiMeaning
        fields = ["language", "text"]


class KanjiSerializer(serializers.ModelSerializer):
    meanings = KanjiMeaningSerializer(many=True, read_only=True)

    class Meta:
        model = Kanji
        fields = [
            "literal",
            "grade",
            "stroke_count",
            "jlpt",
            "freq_rank",
            "radical_number",
            "on_readings",
            "kun_readings",
            "nanori",
            "components",
            "meanings",
        ]


class KanjiDetailSerializer(KanjiSerializer):
    origin = serializers.SerializerMethodField()
    component_details = serializers.SerializerMethodField()
    words = serializers.SerializerMethodField()

    class Meta(KanjiSerializer.Meta):
        fields = [
            *KanjiSerializer.Meta.fields,
            "origin",
            "formation",
            "phonetic",
            "component_details",
            "words",
            "stroke_paths",
            "stroke_viewbox",
        ]

    def get_origin(self, kanji: Kanji) -> str:
        rows = _localized(kanji.explanations.all(), _requested_language(self.context))
        return rows[0].origin if rows else ""

    def get_component_details(self, kanji: Kanji) -> list[dict]:
        language = _requested_language(self.context)
        out = []
        for literal in kanji.components or []:
            component = Kanji.objects.filter(literal=literal).prefetch_related("meanings").first()
            if component:
                meanings = _localized(component.meanings.all(), language)
                out.append(
                    {
                        "literal": literal,
                        "meaning": meanings[0].text if meanings else "",
                        "is_kanji": True,
                    }
                )
                continue
            radical = Radical.objects.filter(literal=literal).prefetch_related("meanings").first()
            meanings = _localized(radical.meanings.all(), language) if radical else []
            out.append(
                {
                    "literal": literal,
                    "meaning": meanings[0].text if meanings else "",
                    "reading": radical.reading if radical else "",
                    "is_kanji": False,
                }
            )
        return out

    def get_words(self, kanji: Kanji) -> list[dict]:
        from django.db.models import Q

        word_ids = list(
            WordForm.objects.filter(kind=WordForm.Kind.KANJI, text__contains=kanji.literal)
            .order_by("-is_common")
            .values_list("word_id", flat=True)[:12]
        )
        words = (
            Word.objects.filter(Q(pk__in=word_ids))
            .prefetch_related("forms", "senses__glosses", "senses__notes")
            .order_by("-is_common", "freq_rank")[:12]
        )
        return WordSerializer(words, many=True, context=self.context).data


class RadicalSerializer(serializers.ModelSerializer):
    meanings = TranslationSerializer(many=True, read_only=True)
    meaning = serializers.SerializerMethodField()

    class Meta:
        model = Radical
        fields = ["literal", "strokes", "reading", "meaning", "meanings"]

    def get_meaning(self, radical: Radical) -> str:
        rows = _localized(radical.meanings.all(), _requested_language(self.context))
        return rows[0].text if rows else ""


class KanaSerializer(serializers.ModelSerializer):
    origin_note = serializers.SerializerMethodField()
    usage_label = serializers.SerializerMethodField()
    usage = serializers.SerializerMethodField()
    usage_examples = serializers.SerializerMethodField()

    class Meta:
        model = Kana
        fields = [
            "char",
            "romaji",
            "script",
            "kind",
            "row",
            "order",
            "origin",
            "origin_note",
            "usage_label",
            "usage",
            "usage_examples",
        ]

    def _usage_translation(self, kana: Kana):
        role = getattr(kana, "grammatical_usage", None)
        if role is None:
            return None
        rows = _localized(role.translations.all(), _requested_language(self.context))
        return rows[0] if rows else None

    def get_origin_note(self, kana: Kana) -> str:
        rows = _localized(kana.explanations.all(), _requested_language(self.context))
        return rows[0].origin_note if rows else ""

    def get_usage_label(self, kana: Kana) -> str:
        translation = self._usage_translation(kana)
        return translation.label if translation else ""

    def get_usage(self, kana: Kana) -> str:
        translation = self._usage_translation(kana)
        return translation.explanation if translation else ""

    def get_usage_examples(self, kana: Kana) -> list[dict]:
        role = getattr(kana, "grammatical_usage", None)
        if role is None:
            return []
        language = _requested_language(self.context)
        out = []
        for example in role.examples.all():
            translations = _localized(example.translations.all(), language)
            out.append(
                {
                    "before": example.before,
                    "particle": example.particle,
                    "after": example.after,
                    "pronunciation": example.pronunciation,
                    "translation": translations[0].text if translations else "",
                    "language": translations[0].language if translations else "",
                }
            )
        return out
