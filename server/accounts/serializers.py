from __future__ import annotations

from django.contrib.auth import get_user_model
from rest_framework import serializers

from .models import UserProfile

User = get_user_model()


class ProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = [
            "mode",
            "display_name",
            "mnemonic_language",
            "desired_retention",
            "new_cards_per_day",
            "timezone",
            "notifications_enabled",
            "notify_threshold",
            "active_pack",
        ]
        # active_pack is set via the "apply pack" endpoint, not a direct PATCH.
        read_only_fields = ["active_pack"]

    def validate_desired_retention(self, value: float) -> float:
        # FSRS is only sane in this band; outside it the interval solver degenerates.
        if not (0.7 <= value <= 0.97):
            raise serializers.ValidationError("desired_retention must be between 0.70 and 0.97")
        return value


class UserSerializer(serializers.ModelSerializer):
    profile = ProfileSerializer(read_only=True)

    class Meta:
        model = User
        fields = ["id", "email", "date_joined", "profile"]
        read_only_fields = ["id", "date_joined"]
