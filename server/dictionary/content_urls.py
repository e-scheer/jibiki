from django.urls import path

from .content_views import manifest, pack_file

urlpatterns = [
    path("manifest", manifest, name="content_manifest"),
    path("file/<str:name>", pack_file, name="content_file"),
]
