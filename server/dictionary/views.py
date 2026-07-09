from __future__ import annotations

from django.db.models import F, Q
from rest_framework import generics
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import ExampleSentence, Kana, Kanji, Name, Radical, Word
from .search import kanji_in, search_words
from .serializers import (
    ExampleSerializer,
    KanaSerializer,
    KanjiDetailSerializer,
    KanjiSerializer,
    NameSerializer,
    RadicalSerializer,
    WordSerializer,
)

# The dictionary is public reference data - immediately useful with no account
# (DEEP_SEARCH stage-1 rule). Auth only gates the study/mnemonic write surfaces.


class SearchView(APIView):
    permission_classes = [AllowAny]
    throttle_scope = "search"

    def get(self, request):
        from accounts.languages import normalize_language_code

        q = request.query_params.get("q", "")
        # Lenient: gloss search filters by language, so case must match and a
        # stray value should fall back to English rather than return nothing.
        lang = normalize_language_code(request.query_params.get("lang"))
        try:
            limit = min(int(request.query_params.get("limit", 25)), 50)
        except ValueError:
            limit = 25
        words = search_words(q, lang=lang, limit=limit)
        # Proper names live in their own table so they never dilute word search;
        # surface a small ranked set alongside (trigram-indexed on Postgres).
        names = (
            list(Name.objects.filter(Q(kanji__icontains=q) | Q(reading__icontains=q))[:12])
            if q
            else []
        )
        return Response(
            {
                "query": q,
                "count": len(words),
                "results": WordSerializer(words, many=True).data,
                "names": NameSerializer(names, many=True).data,
            }
        )


class WordDetailView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, pk: int):
        word = Word.objects.filter(pk=pk).prefetch_related("forms", "senses__glosses").first()
        if word is None:
            return Response({"detail": "Not found."}, status=404)
        data = WordSerializer(word).data
        # Break the headword into its constituent kanji so the app can render the
        # per-kanji breakdown inline (jpdb-style, DEEP_SEARCH feature 7).
        chars = kanji_in(word.headword)
        kanji = Kanji.objects.filter(literal__in=chars).prefetch_related("meanings")
        by_lit = {k.literal: k for k in kanji}
        data["kanji_breakdown"] = [KanjiSerializer(by_lit[c]).data for c in chars if c in by_lit]
        # A few example sentences containing the headword (Tanaka corpus).
        examples = ExampleSentence.objects.filter(japanese__contains=word.headword)[:6]
        data["examples"] = ExampleSerializer(examples, many=True).data
        return Response(data)


class KanjiDetailView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, literal: str):
        kanji = Kanji.objects.filter(literal=literal).prefetch_related("meanings").first()
        if kanji is None:
            return Response({"detail": "Not found."}, status=404)
        return Response(KanjiDetailSerializer(kanji).data)


class WordListView(generics.ListAPIView):
    """Browse (not search) the dictionary by category - common words, JLPT level -
    so a user can read entries without typing a query first. Paginated."""

    permission_classes = [AllowAny]
    serializer_class = WordSerializer

    def get_queryset(self):
        qs = Word.objects.prefetch_related("forms", "senses__glosses")
        p = self.request.query_params
        if p.get("common") in ("1", "true", "yes"):
            qs = qs.filter(is_common=True)
        jlpt = p.get("jlpt")
        if jlpt:
            qs = qs.filter(jlpt=jlpt)
        # Most-frequent first; unranked entries last.
        return qs.order_by(F("freq_rank").asc(nulls_last=True), "id")


class KanjiListView(generics.ListAPIView):
    permission_classes = [AllowAny]
    serializer_class = KanjiSerializer

    def get_queryset(self):
        qs = Kanji.objects.prefetch_related("meanings")
        jlpt = self.request.query_params.get("jlpt")
        grade = self.request.query_params.get("grade")
        contains = self.request.query_params.get("contains")  # radical-grid lookup
        if jlpt:
            qs = qs.filter(jlpt=jlpt)
        if grade:
            qs = qs.filter(grade=grade)
        if contains:
            # kanji whose component list includes ALL requested radical literals
            for radical in contains:
                qs = qs.filter(components__contains=radical)
        return qs


class KanaListView(generics.ListAPIView):
    permission_classes = [AllowAny]
    serializer_class = KanaSerializer
    pagination_class = None  # the full chart is small; ship it in one response

    def get_queryset(self):
        qs = Kana.objects.all()
        script = self.request.query_params.get("script")
        if script:
            qs = qs.filter(script=script)
        return qs


class KanaDetailView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, char: str):
        kana = Kana.objects.filter(char=char).first()
        if kana is None:
            return Response({"detail": "Not found."}, status=404)
        return Response(KanaSerializer(kana).data)


class RadicalListView(generics.ListAPIView):
    permission_classes = [AllowAny]
    serializer_class = RadicalSerializer
    pagination_class = None

    def get_queryset(self):
        return Radical.objects.all()
