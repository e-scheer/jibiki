from django.contrib import admin

from .models import Gloss, Kana, Kanji, KanjiMeaning, Radical, Sense, Word, WordForm


class WordFormInline(admin.TabularInline):
    model = WordForm
    extra = 0


class SenseInline(admin.StackedInline):
    model = Sense
    extra = 0


@admin.register(Word)
class WordAdmin(admin.ModelAdmin):
    list_display = ["__str__", "is_common", "jlpt", "freq_rank"]
    list_filter = ["is_common", "jlpt"]
    search_fields = ["forms__text", "senses__glosses__text"]
    inlines = [WordFormInline, SenseInline]


class GlossInline(admin.TabularInline):
    model = Gloss
    extra = 0


@admin.register(Sense)
class SenseAdmin(admin.ModelAdmin):
    inlines = [GlossInline]


class KanjiMeaningInline(admin.TabularInline):
    model = KanjiMeaning
    extra = 0


@admin.register(Kanji)
class KanjiAdmin(admin.ModelAdmin):
    list_display = ["literal", "grade", "jlpt", "stroke_count", "freq_rank"]
    list_filter = ["jlpt", "grade"]
    search_fields = ["literal", "meanings__text"]
    inlines = [KanjiMeaningInline]


@admin.register(Kana)
class KanaAdmin(admin.ModelAdmin):
    list_display = ["char", "romaji", "script", "kind", "row"]
    list_filter = ["script", "kind"]


@admin.register(Radical)
class RadicalAdmin(admin.ModelAdmin):
    list_display = ["literal", "strokes", "reading", "meaning"]
