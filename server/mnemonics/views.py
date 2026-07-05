from __future__ import annotations

from django.db.models import Prefetch
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import (
    DeckStatus,
    Mnemonic,
    MnemonicDeck,
    MnemonicDeckItem,
    MnemonicDeckVote,
    MnemonicSave,
    MnemonicStatus,
    MnemonicVote,
)
from .serializers import (
    CreateDeckSerializer,
    CreateMnemonicSerializer,
    MnemonicDeckDetailSerializer,
    MnemonicDeckSerializer,
    MnemonicSerializer,
    ReportSerializer,
    VoteSerializer,
)
from .services import (
    ImageRejected,
    active_for_many,
    apply_pack,
    cast_deck_vote,
    cast_vote,
    create_deck,
    create_mnemonic,
    enroll_deck,
    file_report,
    publish_deck,
    reset_choices,
    saved_for,
    set_choice,
    toggle_save,
    visible_decks,
    visible_or_own_for,
)


def _my_votes(user, mnemonics) -> dict[int, int]:
    """Fetch the requesting user's votes for a set of mnemonics in one query."""
    if not user or not user.is_authenticated:
        return {}
    ids = [m.id for m in mnemonics]
    return dict(
        MnemonicVote.objects.filter(user=user, mnemonic_id__in=ids).values_list(
            "mnemonic_id", "value"
        )
    )


def _my_saves(user, mnemonics) -> set[int]:
    """The subset of the given mnemonics the user has saved (one query)."""
    if not user or not user.is_authenticated:
        return set()
    ids = [m.id for m in mnemonics]
    return set(
        MnemonicSave.objects.filter(user=user, mnemonic_id__in=ids).values_list(
            "mnemonic_id", flat=True
        )
    )


def _my_deck_votes(user, decks) -> dict[int, int]:
    if not user or not user.is_authenticated:
        return {}
    ids = [d.id for d in decks]
    return dict(
        MnemonicDeckVote.objects.filter(user=user, deck_id__in=ids).values_list("deck_id", "value")
    )


# Detail view: full items (each mnemonic serialized with its author) so the
# whole deck stays O(1) queries instead of O(decks × items).
_DECK_ITEMS = Prefetch(
    "items",
    queryset=MnemonicDeckItem.objects.select_related("mnemonic__author__profile").order_by(
        "position", "id"
    ),
)

# List view only needs each deck's cover image + item count, never the item
# authors — so skip the author/profile joins the detail prefetch pulls in.
_DECK_COVER = Prefetch(
    "items",
    queryset=MnemonicDeckItem.objects.select_related("mnemonic").order_by("position", "id"),
)


def _mnemonic_ctx(request, mnemonics):
    return {
        "my_votes": _my_votes(request.user, mnemonics),
        "my_saves": _my_saves(request.user, mnemonics),
        "request": request,
    }


class MnemonicListView(APIView):
    """Public, ranked mnemonics for a character in a language. Reading is open (the
    dictionary-first principle); voting/creating requires an account."""

    permission_classes = [AllowAny]

    def get(self, request):
        character = request.query_params.get("character", "")
        kind = request.query_params.get("kind", Mnemonic.Kind.KANA)
        language = request.query_params.get("language")
        if not language:
            profile = (
                getattr(request.user, "profile", None) if request.user.is_authenticated else None
            )
            language = profile.mnemonic_language if profile else "en"
        if not character:
            return Response(
                {"detail": "character is required."}, status=status.HTTP_400_BAD_REQUEST
            )

        mnemonics = visible_or_own_for(request.user, character, language, kind)
        ctx = _mnemonic_ctx(request, mnemonics)
        return Response(
            {
                "character": character,
                "language": language,
                "kind": kind,
                "results": MnemonicSerializer(mnemonics, many=True, context=ctx).data,
            }
        )


class MnemonicCreateView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request):
        serializer = CreateMnemonicSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            mnemonic = create_mnemonic(
                request.user,
                character=data["character"],
                kind=data["kind"],
                language=data["language"],
                story=data["story"],
                image_file=data.get("image"),
            )
        except ImageRejected:
            return Response(
                {"detail": "Uploaded file is not a valid image."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return Response(
            MnemonicSerializer(mnemonic, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class MnemonicVoteView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request, pk: int):
        mnemonic = Mnemonic.objects.filter(pk=pk, status=MnemonicStatus.VISIBLE).first()
        if mnemonic is None:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        serializer = VoteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        score = cast_vote(request.user, mnemonic, serializer.validated_data["value"])
        return Response(
            {"id": mnemonic.id, "score": score, "my_vote": serializer.validated_data["value"]}
        )


class MnemonicReportView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request, pk: int):
        mnemonic = Mnemonic.objects.filter(pk=pk).first()
        if mnemonic is None:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        serializer = ReportSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        hidden = file_report(
            request.user,
            mnemonic,
            serializer.validated_data["reason"],
            serializer.validated_data.get("detail", ""),
        )
        return Response({"reported": True, "hidden": hidden}, status=status.HTTP_201_CREATED)


class MyMnemonicsView(APIView):
    """The signed-in user's own contributions across all statuses (so they can see
    a pending submission is being reviewed — never silently dropped)."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        mnemonics = list(
            Mnemonic.objects.filter(author=request.user).select_related("author__profile")
        )
        ctx = _mnemonic_ctx(request, mnemonics)
        return Response(MnemonicSerializer(mnemonics, many=True, context=ctx).data)


class MnemonicSaveView(APIView):
    """Toggle the Instagram 🔖 bookmark on a mnemonic."""

    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request, pk: int):
        mnemonic = Mnemonic.objects.filter(pk=pk, status=MnemonicStatus.VISIBLE).first()
        if mnemonic is None:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        saved = toggle_save(request.user, mnemonic)
        return Response({"id": mnemonic.id, "saved": saved})


class SavedMnemonicsView(APIView):
    """The signed-in user's saved (bookmarked) mnemonics."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        mnemonics = list(saved_for(request.user).select_related("author__profile"))
        ctx = _mnemonic_ctx(request, mnemonics)
        return Response(MnemonicSerializer(mnemonics, many=True, context=ctx).data)


# ── Active mnemonic resolution (the "everywhere" visual layer) ──────────────


class MnemonicActiveView(APIView):
    """Batch-resolve the active mnemonic for a set of characters: the user's own
    choice if any, else the top-ranked visible one. Reading is open."""

    permission_classes = [AllowAny]

    def post(self, request):
        kind = request.data.get("kind", Mnemonic.Kind.KANA)
        characters = request.data.get("characters")
        if not isinstance(characters, list):
            return Response(
                {"detail": "characters must be a list."}, status=status.HTTP_400_BAD_REQUEST
            )
        language = request.data.get("language")
        if not language:
            profile = (
                getattr(request.user, "profile", None) if request.user.is_authenticated else None
            )
            language = profile.mnemonic_language if profile else "en"
        chars = [str(c) for c in characters][:500]
        resolved = active_for_many(request.user, chars, kind, language)
        ctx = _mnemonic_ctx(request, list(resolved.values()))
        results = {
            c: (MnemonicSerializer(resolved[c], context=ctx).data if c in resolved else None)
            for c in chars
        }
        return Response({"language": language, "kind": kind, "results": results})


class MnemonicChooseView(APIView):
    """Override one character's active mnemonic (a per-character swap)."""

    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request):
        mid = request.data.get("mnemonic_id")
        mnemonic = (
            Mnemonic.objects.filter(pk=mid)
            .exclude(status__in=[MnemonicStatus.HIDDEN, MnemonicStatus.REMOVED])
            .first()
        )
        if mnemonic is None:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        set_choice(request.user, mnemonic)
        return Response(
            {
                "character": mnemonic.character,
                "kind": mnemonic.kind,
                "language": mnemonic.language,
                "mnemonic_id": mnemonic.id,
            }
        )


class MnemonicResetView(APIView):
    """Drop overrides (back to the default) — optionally scoped to one kind."""

    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request):
        kind = request.data.get("kind") or None
        removed = reset_choices(request.user, kind)
        return Response({"reset": removed})


# ── Community decks ─────────────────────────────────────────────────────────


class MnemonicDeckListView(APIView):
    """Browse the community decks (public + ranked). `?mine=1` returns the
    signed-in user's own decks across all statuses instead."""

    permission_classes = [AllowAny]

    def get(self, request):
        mine = request.query_params.get("mine") in ("1", "true", "yes")
        language = request.query_params.get("language")
        kind = request.query_params.get("kind")
        if mine:
            if not request.user.is_authenticated:
                return Response({"detail": "Authentication required."}, status=401)
            qs = (
                MnemonicDeck.objects.filter(author=request.user)
                .exclude(status=DeckStatus.REMOVED)
                .order_by("-created_at")
            )
        else:
            qs = visible_decks(language, kind)
        decks = list(qs.select_related("author__profile").prefetch_related(_DECK_COVER))
        ctx = {"my_deck_votes": _my_deck_votes(request.user, decks), "request": request}
        return Response({"results": MnemonicDeckSerializer(decks, many=True, context=ctx).data})


class MnemonicDeckCreateView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request):
        serializer = CreateDeckSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        deck = create_deck(
            request.user,
            title=data["title"],
            description=data.get("description", ""),
            language=data["language"],
            kind=data["kind"],
            mnemonic_ids=data.get("mnemonic_ids") or [],
            publish=data.get("publish", False),
        )
        deck = (
            MnemonicDeck.objects.select_related("author__profile")
            .prefetch_related(_DECK_ITEMS)
            .get(pk=deck.pk)
        )
        ctx = {"my_deck_votes": {}, "request": request}
        return Response(
            MnemonicDeckDetailSerializer(deck, context=ctx).data,
            status=status.HTTP_201_CREATED,
        )


class MnemonicDeckDetailView(APIView):
    permission_classes = [AllowAny]

    def _get(self, request, pk):
        deck = (
            MnemonicDeck.objects.select_related("author__profile")
            .prefetch_related(_DECK_ITEMS)
            .filter(pk=pk)
            .first()
        )
        if deck is None:
            return None
        # A draft/hidden deck is visible only to its author.
        if deck.status != DeckStatus.VISIBLE and deck.author_id != getattr(
            request.user, "id", None
        ):
            return None
        return deck

    def get(self, request, pk: int):
        deck = self._get(request, pk)
        if deck is None:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        items = [it.mnemonic for it in deck.items.all() if it.mnemonic_id]
        ctx = {
            "my_deck_votes": _my_deck_votes(request.user, [deck]),
            "my_votes": _my_votes(request.user, items),
            "my_saves": _my_saves(request.user, items),
            "request": request,
        }
        return Response(MnemonicDeckDetailSerializer(deck, context=ctx).data)


class MnemonicDeckPublishView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request, pk: int):
        deck = MnemonicDeck.objects.filter(pk=pk, author=request.user).first()
        if deck is None:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        new_status = publish_deck(deck, request.user)
        return Response({"id": deck.id, "status": new_status})


class MnemonicDeckVoteView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request, pk: int):
        deck = MnemonicDeck.objects.filter(pk=pk, status=DeckStatus.VISIBLE).first()
        if deck is None:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        serializer = VoteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        score = cast_deck_vote(request.user, deck, serializer.validated_data["value"])
        my_vote = 1 if serializer.validated_data["value"] > 0 else 0
        return Response({"id": deck.id, "score": score, "my_vote": my_vote})


class MnemonicDeckEnrollView(APIView):
    """Study a community deck: create SRS cards for the characters it covers."""

    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request, pk: int):
        deck = MnemonicDeck.objects.filter(pk=pk).first()
        if deck is None or (
            deck.status != DeckStatus.VISIBLE and deck.author_id != request.user.id
        ):
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        created = enroll_deck(request.user, deck)
        return Response({"id": deck.id, "enrolled": created})


class MnemonicDeckApplyView(APIView):
    """Adopt a pack as your visual base: set a per-character choice for every item
    and mark it as your active pack (distinct from enroll, which spawns cards)."""

    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request, pk: int):
        deck = MnemonicDeck.objects.filter(pk=pk).first()
        if deck is None or (
            deck.status != DeckStatus.VISIBLE and deck.author_id != request.user.id
        ):
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        applied = apply_pack(request.user, deck)
        return Response({"id": deck.id, "applied": applied})
