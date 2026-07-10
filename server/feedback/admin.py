from django.contrib import admin

from .models import ContentReport, Feedback


@admin.register(Feedback)
class FeedbackAdmin(admin.ModelAdmin):
    list_display = ["id", "kind", "short_message", "user", "email", "status", "created_at"]
    list_filter = ["kind", "status", "created_at"]
    search_fields = ["message", "email", "user__email"]
    list_editable = ["status"]
    readonly_fields = ["user", "kind", "message", "email", "context", "created_at"]

    @admin.display(description="message")
    def short_message(self, obj: Feedback) -> str:
        return obj.message[:80]


@admin.register(ContentReport)
class ContentReportAdmin(admin.ModelAdmin):
    list_display = ["id", "item_type", "item_ref", "reason", "reporter", "status", "created_at"]
    list_filter = ["item_type", "reason", "status", "created_at"]
    search_fields = ["item_ref", "message", "reporter__email"]
    list_editable = ["status"]
    readonly_fields = ["reporter", "item_type", "item_ref", "reason", "message", "context", "created_at"]

    @admin.display(description="message")
    def short_message(self, obj: ContentReport) -> str:
        return obj.message[:80]
