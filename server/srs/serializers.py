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
            "source_sentence",
            "source_url",
            "source_title",
            "source_media",
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
    source_sentence = serializers.CharField(max_length=4000, required=False, allow_blank=True)
    source_url = serializers.URLField(max_length=2000, required=False, allow_blank=True)
    source_title = serializers.CharField(max_length=200, required=False, allow_blank=True)
    source_media = serializers.CharField(max_length=200, required=False, allow_blank=True)


class SetStatusSerializer(AddCardSerializer):
    """Set one item's study status to exactly `status` - the detail-screen
    Study / I-know-it toggles."""

    status = serializers.ChoiceField(choices=["none", "learning", "known"])


class BulkAddSerializer(serializers.Serializer):
    """Add many items at once, optionally as already-known (mature) cards."""

    items = AddCardSerializer(many=True, allow_empty=False, max_length=2000)
    known = serializers.BooleanField(default=False, required=False)


class ReviewSerializer(serializers.Serializer):
    rating = serializers.IntegerField(min_value=1, max_value=4)
    duration_ms = serializers.IntegerField(min_value=0, default=0, required=False)


class SyncCardSerializer(serializers.ModelSerializer):
    """Card state for /study/sync - no embedded dictionary item (offline
    clients read content from their local packs), but everything the local
    scheduler needs, including `step`."""

    item_ref = serializers.CharField(read_only=True)

    class Meta:
        model = Card
        fields = [
            "id",
            "item_type",
            "item_ref",
            "state",
            "step",
            "stability",
            "difficulty",
            "due",
            "last_review",
            "reps",
            "lapses",
            "favorite",
            "created_at",
            "updated_at",
            "source_sentence",
            "source_url",
            "source_title",
            "source_media",
        ]


class SyncReviewSerializer(serializers.Serializer):
    client_review_id = serializers.UUIDField()
    item_type = serializers.ChoiceField(choices=ItemType.choices)
    ref = serializers.CharField(max_length=64)
    rating = serializers.IntegerField(min_value=1, max_value=4)
    duration_ms = serializers.IntegerField(min_value=0, default=0, required=False)
    # Informational - the server recomputes state; kept as the log placeholder
    # for out-of-order inserts until the fold rewrites it.
    state_before = serializers.IntegerField(min_value=0, max_value=3, required=False)
    reviewed_at = serializers.DateTimeField()


class SyncOpSerializer(serializers.Serializer):
    client_op_id = serializers.UUIDField()
    kind = serializers.CharField(max_length=32)
    payload = serializers.JSONField(required=False, default=dict)
    performed_at = serializers.DateTimeField()


class SyncSerializer(serializers.Serializer):
    """One /study/sync request: the client outbox (capped - the client pages
    until drained) plus its delta watermark."""

    last_synced_at = serializers.DateTimeField(required=False, allow_null=True, default=None)
    mode = serializers.ChoiceField(
        choices=("sync", "preview", "replace_cloud"), default="sync", required=False
    )
    reviews = SyncReviewSerializer(many=True, required=False, default=list, max_length=500)
    ops = SyncOpSerializer(many=True, required=False, default=list, max_length=200)
