from django.urls import path

from .views import packs_file, packs_manifest

urlpatterns = [
    path("packs/manifest", packs_manifest, name="content_packs_manifest"),
    path("packs/file/<str:name>", packs_file, name="content_packs_file"),
]
