from __future__ import annotations

from django.contrib.auth import get_user_model
from django.utils.translation import gettext as _
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
            "interface_language",
            "desired_retention",
            "new_cards_per_day",
            "timezone",
            "notifications_enabled",
            "notify_threshold",
            "active_pack",
            "fsrs_parameters",
            "plan",
            "plan_expires_at",
        ]
        # active_pack is set via the "apply pack" endpoint, not a direct PATCH;
        # fsrs_parameters are trained server-side (optimize) and only read by
        # clients so their local scheduler uses the same weights; plan is an
        # entitlement, set only by admin / store webhooks (accounts.entitlements).
        read_only_fields = ["active_pack", "fsrs_parameters", "plan", "plan_expires_at"]

    def validate_mnemonic_language(self, value: str) -> str:
        from .languages import validate_language_code

        return validate_language_code(value)

    def validate_interface_language(self, value: str) -> str:
        value = value.lower().split("-")[0].split("_")[0]
        if value not in {"en", "fr"}:
            raise serializers.ValidationError(_("Unsupported interface language."))
        return value

    def validate_desired_retention(self, value: float) -> float:
        # FSRS is only sane in this band; outside it the interval solver degenerates.
        if not (0.7 <= value <= 0.97):
            raise serializers.ValidationError(
                _("Desired retention must be between 0.70 and 0.97.")
            )
        return value


class UserSerializer(serializers.ModelSerializer):
    profile = ProfileSerializer(read_only=True)

    class Meta:
        model = User
        fields = ["id", "email", "date_joined", "profile"]
        read_only_fields = ["id", "date_joined"]
