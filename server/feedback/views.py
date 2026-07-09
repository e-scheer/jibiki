from __future__ import annotations

from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from .serializers import FeedbackSerializer


class FeedbackView(APIView):
    """Accept an in-app feedback submission. Open to everyone - the app works
    without an account, and a bug report from a signed-out user is exactly as
    valuable - but write-throttled like every mutating endpoint."""

    permission_classes = [AllowAny]
    throttle_scope = "write"

    def post(self, request):
        serializer = FeedbackSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        item = serializer.save(user=request.user if request.user.is_authenticated else None)
        return Response({"id": item.id}, status=status.HTTP_201_CREATED)
