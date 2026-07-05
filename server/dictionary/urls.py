from django.urls import path

from .views import (
    KanaDetailView,
    KanaListView,
    KanjiDetailView,
    KanjiListView,
    RadicalListView,
    SearchView,
    WordDetailView,
    WordListView,
)

urlpatterns = [
    path("search", SearchView.as_view(), name="dict_search"),
    path("words", WordListView.as_view(), name="dict_word_list"),
    path("words/<int:pk>", WordDetailView.as_view(), name="dict_word_detail"),
    path("kanji", KanjiListView.as_view(), name="dict_kanji_list"),
    path("kanji/<str:literal>", KanjiDetailView.as_view(), name="dict_kanji_detail"),
    path("kana", KanaListView.as_view(), name="dict_kana_list"),
    path("kana/<str:char>", KanaDetailView.as_view(), name="dict_kana_detail"),
    path("radicals", RadicalListView.as_view(), name="dict_radical_list"),
]
