from __future__ import annotations

from django.conf import settings
from rest_framework import serializers

from .models import Mnemonic, MnemonicDeck, ReportReason


def _display_name(author, *, is_seed: bool) -> str:
    if is_seed or author is None:
        return "jibiki"
    profile = getattr(author, "profile", None)
    return profile.display_name if profile and profile.display_name else "contributor"


class MnemonicSerializer(serializers.ModelSerializer):
    image_src = serializers.CharField(read_only=True)
    author_name = serializers.SerializerMethodField()
    my_vote = serializers.SerializerMethodField()
    saved = serializers.SerializerMethodField()

    class Meta:
        model = Mnemonic
        fields = [
            "id",
            "character",
            "kind",
            "language",
            "story",
            "image_src",
            "image_width",
            "image_height",
            "author_name",
            "is_seed",
            "status",
            "score",
            "my_vote",
            "saved",
            "created_at",
        ]

    def get_author_name(self, m: Mnemonic) -> str:
        return _display_name(m.author, is_seed=m.is_seed)

    def get_my_vote(self, m: Mnemonic) -> int:
        # Populated by the view from a single prefetch to avoid N+1.
        votes = self.context.get("my_votes") or {}
        return votes.get(m.id, 0)

    def get_saved(self, m: Mnemonic) -> bool:
        saves = self.context.get("my_saves") or set()
        return m.id in saves


class MnemonicDeckSerializer(serializers.ModelSerializer):
    """List/card view of a community deck — no items, just the cover + counts."""

    author_name = serializers.SerializerMethodField()
    item_count = serializers.SerializerMethodField()
    cover_src = serializers.SerializerMethodField()
    my_vote = serializers.SerializerMethodField()

    class Meta:
        model = MnemonicDeck
        fields = [
            "id",
            "title",
            "description",
            "language",
            "kind",
            "author_name",
            "is_seed",
            "status",
            "score",
            "item_count",
            "cover_src",
            "my_vote",
            "created_at",
        ]

    def get_author_name(self, d: MnemonicDeck) -> str:
        return _display_name(d.author, is_seed=d.is_seed)

    def get_item_count(self, d: MnemonicDeck) -> int:
        # `items` is prefetched by the view, so len() avoids a per-deck query.
        return len(d.items.all())

    def get_cover_src(self, d: MnemonicDeck) -> str:
        m = d.cover_item()
        return m.image_src if m else ""

    def get_my_vote(self, d: MnemonicDeck) -> int:
        votes = self.context.get("my_deck_votes") or {}
        return votes.get(d.id, 0)


class MnemonicDeckDetailSerializer(MnemonicDeckSerializer):
    """Full deck view — includes the ordered mnemonics."""

    items = serializers.SerializerMethodField()

    class Meta(MnemonicDeckSerializer.Meta):
        fields = [*MnemonicDeckSerializer.Meta.fields, "items"]

    def get_items(self, d: MnemonicDeck) -> list:
        mnemonics = [it.mnemonic for it in d.items.all() if it.mnemonic_id]
        return MnemonicSerializer(mnemonics, many=True, context=self.context).data


class CreateDeckSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=120)
    description = serializers.CharField(
        max_length=2000, required=False, allow_blank=True, default=""
    )
    language = serializers.CharField(max_length=8, default="en")
    kind = serializers.ChoiceField(choices=Mnemonic.Kind.choices, default=Mnemonic.Kind.KANA)
    mnemonic_ids = serializers.ListField(
        child=serializers.IntegerField(), required=False, default=list
    )
    publish = serializers.BooleanField(default=False)


class CreateMnemonicSerializer(serializers.Serializer):
    character = serializers.CharField(max_length=4)
    kind = serializers.ChoiceField(choices=Mnemonic.Kind.choices)
    language = serializers.CharField(max_length=8, default="en")
    story = serializers.CharField(max_length=2000)
    image = serializers.FileField(required=False)

    def validate_image(self, f):
        if f.size > settings.MNEMONIC_IMAGE_MAX_BYTES:
            mb = settings.MNEMONIC_IMAGE_MAX_BYTES // (1024 * 1024)
            raise serializers.ValidationError(f"Image exceeds the {mb} MB limit.")
        return f


class VoteSerializer(serializers.Serializer):
    value = serializers.IntegerField(min_value=-1, max_value=1)


class ReportSerializer(serializers.Serializer):
    reason = serializers.ChoiceField(choices=ReportReason.choices)
    detail = serializers.CharField(max_length=1000, required=False, allow_blank=True, default="")
