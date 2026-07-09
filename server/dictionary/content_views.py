"""Serve the jibiki content packs for the app to download (offline dictionary).

v1: the JSON pack (scripts/build_content_pack.py) - manifest + per-file download.
v2: prebuilt SQLite packs (manage.py build_packs) under CONTENT_PACK_DIR/packs/ -
same manifest-allowlist rule, plus single-range requests so the app can resume
interrupted downloads. Public - the dictionary needs no account.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

from django.conf import settings
from django.http import (
    FileResponse,
    Http404,
    HttpResponse,
    JsonResponse,
    StreamingHttpResponse,
)


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
    # Only serve files the manifest declares - no path traversal.
    allowed = {f["name"] for f in (m or {}).get("files", [])}
    if name not in allowed:
        raise Http404("unknown pack file")
    path = _pack_dir() / name
    if not path.exists():
        raise Http404("missing pack file")
    return FileResponse(path.open("rb"), content_type="application/json")


# ── v2: SQLite packs ──────────────────────────────────────────────────────────

# Single ranges only (bytes=start- / bytes=start-end); suffix and multi ranges
# don't match and fall back to a full 200 - allowed by RFC 9110.
_RANGE_RE = re.compile(r"^bytes=(\d+)-(\d*)$")


def _packs_manifest() -> dict | None:
    path = _pack_dir() / "packs" / "packs_manifest.json"
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def packs_manifest(_request):
    m = _packs_manifest()
    if m is None:
        return JsonResponse({"detail": "No content packs available."}, status=404)
    return JsonResponse(m)


def _range_body(path: Path, start: int, length: int, chunk: int = 1 << 16):
    with path.open("rb") as fh:
        fh.seek(start)
        while length > 0:
            data = fh.read(min(chunk, length))
            if not data:
                return
            length -= len(data)
            yield data


def packs_file(request, name: str):
    m = _packs_manifest()
    # Only serve files the manifest declares - no path traversal (same rule as v1).
    allowed = {p["file"] for p in (m or {}).get("packs", [])}
    if name not in allowed:
        raise Http404("unknown pack file")
    path = _pack_dir() / "packs" / name
    if not path.exists():
        raise Http404("missing pack file")
    size = path.stat().st_size
    rng = _RANGE_RE.match(request.headers.get("Range", ""))
    if rng:
        start = int(rng.group(1))
        if start >= size:
            return HttpResponse(status=416, headers={"Content-Range": f"bytes */{size}"})
        end = min(int(rng.group(2) or size - 1), size - 1)
        resp = StreamingHttpResponse(
            _range_body(path, start, end - start + 1),
            status=206,
            content_type="application/gzip",
        )
        resp["Content-Length"] = str(end - start + 1)
        resp["Content-Range"] = f"bytes {start}-{end}/{size}"
    else:
        resp = FileResponse(path.open("rb"), content_type="application/gzip")
    resp["Accept-Ranges"] = "bytes"
    return resp
