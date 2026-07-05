from django.contrib import admin
from django.utils import timezone

from .models import (
    DeckStatus,
    Mnemonic,
    MnemonicDeck,
    MnemonicDeckItem,
    MnemonicDeckVote,
    MnemonicReport,
    MnemonicSave,
    MnemonicStatus,
    MnemonicVote,
    UserMnemonicChoice,
)


@admin.action(description="Publish selected mnemonics")
def publish(modeladmin, request, queryset):
    queryset.update(status=MnemonicStatus.VISIBLE, hidden_at=None)


@admin.action(description="Hide selected mnemonics")
def hide(modeladmin, request, queryset):
    queryset.update(status=MnemonicStatus.HIDDEN, hidden_at=timezone.now())


@admin.register(Mnemonic)
class MnemonicAdmin(admin.ModelAdmin):
    list_display = [
        "character",
        "kind",
        "language",
        "status",
        "score",
        "author",
        "is_seed",
        "created_at",
    ]
    list_filter = ["status", "kind", "language", "is_seed"]
    search_fields = ["character", "story", "author__email"]
    actions = [publish, hide]


@admin.register(MnemonicReport)
class MnemonicReportAdmin(admin.ModelAdmin):
    list_display = ["__str__", "reason", "status", "reporter", "created_at"]
    list_filter = ["status", "reason"]
    raw_id_fields = ["mnemonic", "reporter"]


@admin.register(MnemonicVote)
class MnemonicVoteAdmin(admin.ModelAdmin):
    list_display = ["__str__", "value", "created_at"]
    raw_id_fields = ["mnemonic", "user"]


@admin.register(MnemonicSave)
class MnemonicSaveAdmin(admin.ModelAdmin):
    list_display = ["__str__", "created_at"]
    raw_id_fields = ["mnemonic", "user"]


@admin.action(description="Publish selected decks")
def publish_decks(modeladmin, request, queryset):
    queryset.update(status=DeckStatus.VISIBLE, hidden_at=None)


@admin.action(description="Hide selected decks")
def hide_decks(modeladmin, request, queryset):
    queryset.update(status=DeckStatus.HIDDEN, hidden_at=timezone.now())


class MnemonicDeckItemInline(admin.TabularInline):
    model = MnemonicDeckItem
    raw_id_fields = ["mnemonic"]
    extra = 0


@admin.register(MnemonicDeck)
class MnemonicDeckAdmin(admin.ModelAdmin):
    list_display = ["title", "language", "kind", "status", "score", "author", "created_at"]
    list_filter = ["status", "kind", "language", "is_seed"]
    search_fields = ["title", "description", "author__email"]
    inlines = [MnemonicDeckItemInline]
    actions = [publish_decks, hide_decks]


@admin.register(MnemonicDeckVote)
class MnemonicDeckVoteAdmin(admin.ModelAdmin):
    list_display = ["__str__", "value", "created_at"]
    raw_id_fields = ["deck", "user"]


@admin.register(UserMnemonicChoice)
class UserMnemonicChoiceAdmin(admin.ModelAdmin):
    list_display = ["__str__", "user", "kind", "character", "language", "updated_at"]
    list_filter = ["kind", "language"]
    raw_id_fields = ["user", "mnemonic"]
