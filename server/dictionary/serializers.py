from __future__ import annotations

from rest_framework import serializers

from .models import (
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


class GlossSerializer(serializers.ModelSerializer):
    class Meta:
        model = Gloss
        fields = ["lang", "text"]


class ExampleSerializer(serializers.ModelSerializer):
    class Meta:
        model = ExampleSentence
        fields = ["japanese", "english"]


class NameSerializer(serializers.ModelSerializer):
    class Meta:
        model = Name
        fields = ["kanji", "reading", "translations", "name_types"]


class SenseSerializer(serializers.ModelSerializer):
    glosses = GlossSerializer(many=True, read_only=True)

    class Meta:
        model = Sense
        fields = ["order", "pos", "misc", "field", "info", "glosses"]


class WordFormSerializer(serializers.ModelSerializer):
    class Meta:
        model = WordForm
        fields = ["text", "is_common", "pitch"]


class WordSerializer(serializers.ModelSerializer):
    """Full JMdict entry as the app consumes it: kanji forms + readings + senses.
    Relies on the caller prefetching `forms` and `senses__glosses` (search/detail
    both do) so these method fields never trigger per-row queries."""

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
        forms = [f for f in word.forms.all() if f.kind == kind]
        forms.sort(key=lambda f: f.order)
        return WordFormSerializer(forms, many=True).data

    def get_kanji(self, word: Word) -> list[dict]:
        return self._forms(word, WordForm.Kind.KANJI)

    def get_readings(self, word: Word) -> list[dict]:
        return self._forms(word, WordForm.Kind.KANA)


class KanjiMeaningSerializer(serializers.ModelSerializer):
    class Meta:
        model = KanjiMeaning
        fields = ["lang", "text"]


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
    """Adds the decomposition tree (component labels), a sample of words that
    contain this kanji, and the KanjiVG stroke-order paths - the cross-links +
    stroke animation of DEEP_SEARCH features 4 & 7."""

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

    def get_component_details(self, kanji: Kanji) -> list[dict]:
        out = []
        for lit in kanji.components or []:
            comp = Kanji.objects.filter(literal=lit).prefetch_related("meanings").first()
            if comp:
                gloss = comp.meanings.first()
                out.append(
                    {"literal": lit, "meaning": gloss.text if gloss else "", "is_kanji": True}
                )
                continue
            rad = Radical.objects.filter(literal=lit).first()
            out.append(
                {
                    "literal": lit,
                    "meaning": rad.meaning if rad else "",
                    "reading": rad.reading if rad else "",
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
            .prefetch_related("forms", "senses__glosses")
            .order_by("-is_common", "freq_rank")[:12]
        )
        return WordSerializer(words, many=True).data


class RadicalSerializer(serializers.ModelSerializer):
    class Meta:
        model = Radical
        fields = ["literal", "strokes", "reading", "meaning"]


class KanaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Kana
        fields = [
            "char", "romaji", "script", "kind", "row", "order",
            "origin", "origin_note", "usage_label", "usage", "usage_examples",
        ]
