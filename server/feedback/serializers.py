from __future__ import annotations

from rest_framework import serializers

from .models import (
    ContentItemType,
    ContentReport,
    ContentReportReason,
    Feedback,
    FeedbackKind,
)


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


class ContentReportSerializer(serializers.Serializer):
    """A flag on a dictionary entry. The reason is enough on its own; a message
    is welcome but optional (the reason already routes it)."""

    item_type = serializers.ChoiceField(choices=ContentItemType.choices)
    item_ref = serializers.CharField(max_length=64, allow_blank=False, trim_whitespace=True)
    reason = serializers.ChoiceField(choices=ContentReportReason.choices)
    message = serializers.CharField(
        max_length=2000, required=False, allow_blank=True, default="", trim_whitespace=True
    )
    context = serializers.JSONField(required=False, default=dict)

    def save(self, reporter) -> ContentReport:
        data = self.validated_data
        report, _ = ContentReport.objects.update_or_create(
            reporter=reporter,
            item_type=data["item_type"],
            item_ref=data["item_ref"],
            defaults={
                "reason": data["reason"],
                "message": data.get("message", ""),
                "context": data.get("context", {}),
                "status": ContentReport._meta.get_field("status").default,
            },
        )
        return report
