from django.contrib import admin

from .models import Card, ReviewLog


@admin.register(Card)
class CardAdmin(admin.ModelAdmin):
    list_display = ["__str__", "user", "item_type", "state", "due", "reps", "lapses"]
    list_filter = ["item_type", "state"]
    search_fields = ["user__email"]
    raw_id_fields = ["word", "kanji", "kana"]


@admin.register(ReviewLog)
class ReviewLogAdmin(admin.ModelAdmin):
    list_display = ["__str__", "user", "rating", "state_before", "scheduled_days", "reviewed_at"]
    list_filter = ["rating"]
    search_fields = ["user__email"]
    raw_id_fields = ["card"]
