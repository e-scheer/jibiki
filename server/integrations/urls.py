from django.urls import path

from .views import (
    WaniKaniCancelView,
    WaniKaniConnectView,
    WaniKaniImportView,
    WaniKaniStatusView,
    WaniKaniSyncView,
)

urlpatterns = [
    path("wanikani", WaniKaniStatusView.as_view(), name="wanikani_status"),
    path("wanikani/connect", WaniKaniConnectView.as_view(), name="wanikani_connect"),
    path("wanikani/sync", WaniKaniSyncView.as_view(), name="wanikani_sync"),
    path("wanikani/import", WaniKaniImportView.as_view(), name="wanikani_import"),
    path("wanikani/cancel", WaniKaniCancelView.as_view(), name="wanikani_cancel"),
]
