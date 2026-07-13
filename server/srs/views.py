from __future__ import annotations

from django.http import HttpResponse
from django.utils.translation import gettext as _
from rest_framework import serializers, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Card, State
from .serializers import (
    AddCardSerializer,
    BulkAddSerializer,
    CardSerializer,
    ReviewLogSerializer,
    ReviewSerializer,
    SetStatusSerializer,
    SyncCardSerializer,
    SyncSerializer,
)
from .services import (
    add_card,
    build_queue,
    bulk_add,
    card_states,
    export_apkg,
    export_tsv,
    optimize_readiness,
    optimize_user,
    queue_counts,
    review_card,
    set_status,
    streak_days,
)


def _requested_new_limit(request):
    """`?new_limit=N` lets the client pull more new cards than the per-session
    default (the "Study more" action). Absent → the server's default batch."""
    raw = request.query_params.get("new_limit")
    if raw is None:
        return None
    try:
        return max(0, int(raw))
    except (TypeError, ValueError):
        return None


class QueueView(APIView):
    """The review session: everything due + a per-session batch of new cards.
    Pass `?new_limit=N` to pull more new cards on demand."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        queue = build_queue(request.user, new_limit=_requested_new_limit(request))
        return Response(
            {
                "due": CardSerializer(queue["due"], many=True).data,
                "new": CardSerializer(queue["new"], many=True).data,
                "counts": queue["counts"],
            }
        )


class AddCardView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request):
        serializer = AddCardSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        card, created = add_card(
            request.user,
            serializer.validated_data["item_type"],
            serializer.validated_data["ref"],
            context={
                key: serializer.validated_data.get(key, "")
                for key in ("source_sentence", "source_url", "source_title", "source_media")
            },
        )
        if card is None:
            return Response({"detail": _("Unknown study item.")}, status=status.HTTP_404_NOT_FOUND)
        return Response(
            CardSerializer(card).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class SetStatusView(APIView):
    """Set one item's study status (none | learning | known) - the detail-screen
    Study / I-know-it toggles. Idempotent; returns the resulting status."""

    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request):
        serializer = SetStatusSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        result = set_status(
            request.user,
            serializer.validated_data["item_type"],
            serializer.validated_data["ref"],
            serializer.validated_data["status"],
        )
        return Response({"status": result}, status=status.HTTP_200_OK)


class BulkAddView(APIView):
    """Add many items in one call, optionally as already-known (mature) cards, so
    the app can bootstrap a level in a single gesture ("I know all hiragana")."""

    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request):
        serializer = BulkAddSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        summary = bulk_add(
            request.user,
            serializer.validated_data["items"],
            known=serializer.validated_data.get("known", False),
        )
        return Response(summary, status=status.HTTP_200_OK)


class CardStatesView(APIView):
    """Compact {item_ref: state} of the user's cards, so the dictionary can mark
    which items are already seen/known. Optional ?item_type= filter."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(card_states(request.user, request.query_params.get("item_type")))


class ReviewView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request, pk: int):
        card = (
            Card.objects.filter(pk=pk, user=request.user)
            .select_related("word", "kanji", "kana")
            .first()
        )
        if card is None:
            return Response({"detail": _("Not found.")}, status=status.HTTP_404_NOT_FOUND)
        serializer = ReviewSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        log = review_card(
            card,
            serializer.validated_data["rating"],
            serializer.validated_data.get("duration_ms", 0),
        )
        return Response(
            {"card": CardSerializer(card).data, "review": ReviewLogSerializer(log).data}
        )


class CardListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        cards = (
            Card.objects.filter(user=request.user)
            .select_related("word", "kanji", "kana")
            .prefetch_related("word__forms", "word__senses__glosses", "kanji__meanings")
        )
        item_type = request.query_params.get("item_type")
        if item_type:
            cards = cards.filter(item_type=item_type)
        return Response(CardSerializer(cards, many=True).data)


class CardDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, pk: int):
        card = (
            Card.objects.filter(pk=pk, user=request.user)
            .select_related("kanji", "kana")
            .first()
        )
        if card is None:
            return Response({"detail": _("Not found.")}, status=status.HTTP_404_NOT_FOUND)
        from .services import write_tombstone

        write_tombstone(request.user, card.item_type, card.item_ref)
        card.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class StatsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        # Counts only - no need to materialize/serialize the whole queue here.
        counts = queue_counts(user)
        by_state = {
            "new": Card.objects.filter(user=user, state=State.NEW).count(),
            "learning": Card.objects.filter(
                user=user, state__in=[State.LEARNING, State.RELEARNING]
            ).count(),
            "review": Card.objects.filter(user=user, state=State.REVIEW).count(),
        }
        from datetime import timedelta

        from django.db.models import Count, Q, Sum
        from django.utils import timezone

        now = timezone.now()
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        logs = user.review_logs.all()
        reviews_today = logs.filter(reviewed_at__gte=start).count()
        total_reviews = logs.count()
        correct_reviews = logs.filter(rating__gte=2).count()
        mature_logs = logs.filter(state_before=State.REVIEW)
        rating_counts = {
            str(rating): logs.filter(rating=rating).count() for rating in range(1, 5)
        }
        since = start - timedelta(days=13)
        history_rows = (
            logs.filter(reviewed_at__gte=since)
            .values("reviewed_at__date")
            .annotate(reviews=Count("id"), correct=Count("id", filter=Q(rating__gte=2)))
            .order_by("reviewed_at__date")
        )
        history = [
            {
                "date": row["reviewed_at__date"].isoformat(),
                "reviews": row["reviews"],
                "correct": row["correct"],
            }
            for row in history_rows
        ]
        cards_by_type = {
            item_type: Card.objects.filter(user=user, item_type=item_type).count()
            for item_type in Card.objects.filter(user=user)
            .values_list("item_type", flat=True)
            .distinct()
        }
        duration = logs.aggregate(value=Sum("duration_ms"))["value"] or 0
        return Response(
            {
                "due_now": counts["due"],
                "new_remaining": counts["new_remaining"],
                "reviews_today": reviews_today,
                "streak": streak_days(user),
                "total_cards": sum(by_state.values()),
                "by_state": by_state,
                "total_reviews": total_reviews,
                "correct_reviews": correct_reviews,
                "study_time_ms": duration,
                "mature_reviews": mature_logs.count(),
                "mature_correct_reviews": mature_logs.filter(rating__gte=2).count(),
                "reviews_by_rating": rating_counts,
                "cards_by_type": cards_by_type,
                "history": history,
            }
        )


class DecksView(APIView):
    """The deck catalogue with the user's progress on each."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        from .decks import all_deck_stats

        return Response(all_deck_stats(request.user))


class DeckEnrollView(APIView):
    """Ensure cards exist for every item in a content deck (idempotent)."""

    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request, deck_id: str):
        from .decks import deck_by_id, deck_stats, enroll

        spec = deck_by_id(deck_id)
        if spec is None:
            return Response({"detail": _("Unknown deck.")}, status=status.HTTP_404_NOT_FOUND)
        enroll(request.user, spec)
        return Response(deck_stats(request.user, spec))


class DeckQueueView(APIView):
    """A review session scoped to one deck."""

    permission_classes = [IsAuthenticated]

    def get(self, request, deck_id: str):
        from .decks import deck_by_id, deck_queue

        spec = deck_by_id(deck_id)
        if spec is None:
            return Response({"detail": _("Unknown deck.")}, status=status.HTTP_404_NOT_FOUND)
        queue = deck_queue(request.user, spec, new_limit=_requested_new_limit(request))
        return Response(
            {
                "due": CardSerializer(queue["due"], many=True).data,
                "new": CardSerializer(queue["new"], many=True).data,
                "counts": queue["counts"],
            }
        )


class FavoriteView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk: int):
        card = Card.objects.filter(pk=pk, user=request.user).first()
        if card is None:
            return Response({"detail": _("Not found.")}, status=status.HTTP_404_NOT_FOUND)
        card.favorite = bool(request.data.get("value", not card.favorite))
        card.save(update_fields=["favorite", "updated_at"])
        return Response({"id": card.id, "favorite": card.favorite})


class SyncView(APIView):
    """Offline replay + delta download in one round-trip: the client uploads
    its outbox (reviews with idempotency UUIDs, last-write-wins ops), the
    server applies it and answers with every card changed since the client's
    watermark, deletions, and the fresh profile (incl. trained FSRS weights).
    See srs/sync.py for the convergence rules."""

    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request):
        from .sync import apply_sync

        serializer = SyncSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        result = apply_sync(request.user, serializer.validated_data)
        result["cards"] = SyncCardSerializer(result["cards"], many=True).data
        result["synced_at"] = serializers.DateTimeField().to_representation(result["synced_at"])
        return Response(result)


class OptimizeView(APIView):
    """GET reports readiness; POST fits + persists per-user FSRS weights when the
    review threshold is met and the fit beats the defaults."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(optimize_readiness(request.user))

    def post(self, request):
        return Response(optimize_user(request.user))


class ExportView(APIView):
    """The user's deck as Anki-importable TSV."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        lang = "en"
        profile = getattr(request.user, "profile", None)
        if profile:
            lang = profile.mnemonic_language
        tsv = export_tsv(request.user, lang=lang)
        resp = HttpResponse(tsv, content_type="text/tab-separated-values; charset=utf-8")
        resp["Content-Disposition"] = 'attachment; filename="jibiki-deck.tsv"'
        return resp


class ApkgExportView(APIView):
    """The user's deck as a portable Anki package."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        lang = getattr(getattr(request.user, "profile", None), "mnemonic_language", "en")
        package = export_apkg(request.user, lang=lang)
        resp = HttpResponse(package, content_type="application/zip")
        resp["Content-Disposition"] = 'attachment; filename="jibiki-deck.apkg"'
        return resp
