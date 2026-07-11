from __future__ import annotations

from django.utils.translation import gettext as _
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import WaniKaniConnection
from .serializers import WaniKaniConnectSerializer
from .services import (
    WaniKaniError,
    import_wanikani_preview,
    refresh_wanikani_preview,
    save_wanikani_preview,
)


def _status(connection: WaniKaniConnection | None) -> dict:
    if connection is None:
        return {"connected": False, "provider": "wanikani"}
    pending = connection.pending_preview or {}
    return {
        "connected": True,
        "provider": "wanikani",
        "username": connection.username,
        "threshold": pending.get("threshold") or "guru",
        "last_synced_at": connection.last_synced_at,
        "last_imported_at": connection.last_imported_at,
        "last_error": connection.last_error,
        "pending": bool(pending.get("items")),
        "preview": {
            key: pending.get(key, 0)
            for key in (
                "recognized",
                "ambiguous",
                "ignored",
                "new_cards",
                "known_cards",
                "learning_cards",
                "estimated_new_reviews",
            )
        }
        if pending
        else None,
    }


class WaniKaniStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(_status(WaniKaniConnection.objects.filter(user=request.user).first()))

    def delete(self, request):
        WaniKaniConnection.objects.filter(user=request.user).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class WaniKaniConnectView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request):
        serializer = WaniKaniConnectSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            connection, preview = save_wanikani_preview(
                request.user,
                serializer.validated_data["token"],
                serializer.validated_data["threshold"],
            )
        except WaniKaniError as exc:
            return Response({"detail": _(str(exc))}, status=status.HTTP_400_BAD_REQUEST)
        return Response({**_status(connection), "preview": preview}, status=status.HTTP_200_OK)


class WaniKaniSyncView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request):
        connection = WaniKaniConnection.objects.filter(user=request.user).first()
        if connection is None:
            return Response({"detail": _("WaniKani is not connected.")}, status=404)
        try:
            preview = refresh_wanikani_preview(connection)
        except WaniKaniError as exc:
            return Response({"detail": _(str(exc))}, status=status.HTTP_400_BAD_REQUEST)
        return Response({**_status(connection), "preview": preview})


class WaniKaniImportView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_scope = "write"

    def post(self, request):
        connection = WaniKaniConnection.objects.filter(user=request.user).first()
        if connection is None or not (connection.pending_preview or {}).get("items"):
            return Response({"detail": _("There is no pending WaniKani import.")}, status=409)
        return Response(import_wanikani_preview(connection), status=status.HTTP_200_OK)


class WaniKaniCancelView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        connection = WaniKaniConnection.objects.filter(user=request.user).first()
        if connection:
            connection.clear_preview()
        return Response({"cancelled": True})

