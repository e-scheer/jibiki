"""Domain profile endpoint. Authentication (signup/login/logout/verify/reset/
social/MFA) is handled entirely by allauth headless under /_allauth/app/v1/;
this only exposes the jibiki-specific product profile (mode, mnemonic language,
SRS knobs) that allauth's session endpoint does not know about.

The request is authenticated by allauth's app-client token via DRF's
XSessionTokenAuthentication (see settings.REST_FRAMEWORK), i.e. the same
X-Session-Token the app got from /_allauth/app/v1/auth/login.
"""

from __future__ import annotations

from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import UserProfile
from .serializers import ProfileSerializer, UserSerializer


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user).data)

    def patch(self, request):
        """Update the product profile (mode, mnemonic language, SRS knobs)."""
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        serializer = ProfileSerializer(profile, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(UserSerializer(request.user).data)
