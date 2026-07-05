from __future__ import annotations

from rest_framework import serializers

from dictionary.serializers import KanaSerializer, KanjiSerializer, WordSerializer

from .models import Card, ItemType, ReviewLog


class CardSerializer(serializers.ModelSerializer):
    """A study card plus its embedded dictionary item, so the review UI can render
    the front/back without a second round-trip."""

    item_ref = serializers.CharField(read_only=True)
    item = serializers.SerializerMethodField()

    class Meta:
        model = Card
        fields = [
            "id",
            "item_type",
            "item_ref",
            "state",
            "stability",
            "difficulty",
            "due",
            "last_review",
            "reps",
            "lapses",
            "created_at",
            "item",
        ]

    def get_item(self, card: Card) -> dict | None:
        if card.item_type == ItemType.WORD and card.word:
            return WordSerializer(card.word).data
        if card.item_type == ItemType.KANJI and card.kanji:
            return KanjiSerializer(card.kanji).data
        if card.item_type == ItemType.KANA and card.kana:
            return KanaSerializer(card.kana).data
        return None


class ReviewLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReviewLog
        fields = [
            "id",
            "card",
            "rating",
            "state_before",
            "stability",
            "difficulty",
            "elapsed_days",
            "scheduled_days",
            "duration_ms",
            "reviewed_at",
        ]


class AddCardSerializer(serializers.Serializer):
    item_type = serializers.ChoiceField(choices=ItemType.choices)
    ref = serializers.CharField()


class BulkAddSerializer(serializers.Serializer):
    """Add many items at once, optionally as already-known (mature) cards."""

    items = AddCardSerializer(many=True, allow_empty=False, max_length=2000)
    known = serializers.BooleanField(default=False, required=False)


class ReviewSerializer(serializers.Serializer):
    rating = serializers.IntegerField(min_value=1, max_value=4)
    duration_ms = serializers.IntegerField(min_value=0, default=0, required=False)
