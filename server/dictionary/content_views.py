"""Serve the jibiki content pack for the app to download (offline dictionary).

The pack is built once (scripts/build_content_pack.py) and served here as static
JSON + a manifest whose version + sha256 let the app cache and update. Public —
the dictionary needs no account.
"""

from __future__ import annotations

import json
from pathlib import Path

from django.conf import settings
from django.http import FileResponse, Http404, JsonResponse


def _pack_dir() -> Path:
    return Path(settings.CONTENT_PACK_DIR)


def _manifest() -> dict | None:
    path = _pack_dir() / "manifest.json"
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def manifest(_request):
    m = _manifest()
    if m is None:
        return JsonResponse({"detail": "No content pack available."}, status=404)
    return JsonResponse(m)


def pack_file(_request, name: str):
    m = _manifest()
    # Only serve files the manifest declares — no path traversal.
    allowed = {f["name"] for f in (m or {}).get("files", [])}
    if name not in allowed:
        raise Http404("unknown pack file")
    path = _pack_dir() / name
    if not path.exists():
        raise Http404("missing pack file")
    return FileResponse(path.open("rb"), content_type="application/json")
