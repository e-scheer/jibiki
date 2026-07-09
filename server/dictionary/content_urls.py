from django.urls import path

from .content_views import manifest, pack_file, packs_file, packs_manifest

urlpatterns = [
    path("manifest", manifest, name="content_manifest"),
    path("file/<str:name>", pack_file, name="content_file"),
    # v2: prebuilt SQLite packs (manage.py build_packs).
    path("packs/manifest", packs_manifest, name="content_packs_manifest"),
    path("packs/file/<str:name>", packs_file, name="content_packs_file"),
]
