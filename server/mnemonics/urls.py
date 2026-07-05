from django.urls import path

from .views import (
    MnemonicActiveView,
    MnemonicChooseView,
    MnemonicCreateView,
    MnemonicDeckApplyView,
    MnemonicDeckCreateView,
    MnemonicDeckDetailView,
    MnemonicDeckEnrollView,
    MnemonicDeckListView,
    MnemonicDeckPublishView,
    MnemonicDeckVoteView,
    MnemonicListView,
    MnemonicReportView,
    MnemonicResetView,
    MnemonicSaveView,
    MnemonicVoteView,
    MyMnemonicsView,
    SavedMnemonicsView,
)

urlpatterns = [
    path("", MnemonicListView.as_view(), name="mnemonic_list"),
    path("create", MnemonicCreateView.as_view(), name="mnemonic_create"),
    path("mine", MyMnemonicsView.as_view(), name="mnemonic_mine"),
    path("saved", SavedMnemonicsView.as_view(), name="mnemonic_saved"),
    # Active-mnemonic resolution + per-character override.
    path("active", MnemonicActiveView.as_view(), name="mnemonic_active"),
    path("choose", MnemonicChooseView.as_view(), name="mnemonic_choose"),
    path("reset", MnemonicResetView.as_view(), name="mnemonic_reset"),
    # Community decks (drawing → pack → propose). Declared before the <int:pk>
    # routes so the "decks" prefix is never swallowed by the integer converter.
    path("decks", MnemonicDeckListView.as_view(), name="deck_list"),
    path("decks/create", MnemonicDeckCreateView.as_view(), name="deck_create"),
    path("decks/<int:pk>", MnemonicDeckDetailView.as_view(), name="deck_detail"),
    path("decks/<int:pk>/publish", MnemonicDeckPublishView.as_view(), name="deck_publish"),
    path("decks/<int:pk>/vote", MnemonicDeckVoteView.as_view(), name="deck_vote"),
    path("decks/<int:pk>/enroll", MnemonicDeckEnrollView.as_view(), name="deck_enroll"),
    path("decks/<int:pk>/apply", MnemonicDeckApplyView.as_view(), name="deck_apply"),
    path("<int:pk>/vote", MnemonicVoteView.as_view(), name="mnemonic_vote"),
    path("<int:pk>/save", MnemonicSaveView.as_view(), name="mnemonic_save"),
    path("<int:pk>/report", MnemonicReportView.as_view(), name="mnemonic_report"),
]
