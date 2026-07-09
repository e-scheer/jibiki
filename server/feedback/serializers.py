from __future__ import annotations

from rest_framework import serializers

from .models import Feedback, FeedbackKind


class FeedbackSerializer(serializers.ModelSerializer):
    kind = serializers.ChoiceField(choices=FeedbackKind.choices)
    message = serializers.CharField(max_length=4000, allow_blank=False, trim_whitespace=True)
    email = serializers.EmailField(required=False, allow_blank=True)
    context = serializers.JSONField(required=False)

    class Meta:
        model = Feedback
        fields = ["id", "kind", "message", "email", "context", "created_at"]
        read_only_fields = ["id", "created_at"]

    def validate_message(self, value: str) -> str:
        if len(value.strip()) < 3:
            raise serializers.ValidationError("Tell us a little more.")
        return value.strip()
