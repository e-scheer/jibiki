from __future__ import annotations

import json
import logging
import re
from urllib.parse import urlsplit

from django.http import HttpRequest, HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

logger = logging.getLogger("jibiki.security")

_MAX_REPORT_BYTES = 32 * 1024
_DIRECTIVE = re.compile(r"^[a-z0-9-]{1,64}$")


def _safe_directive(value: object) -> str:
    candidate = str(value).lower()
    return candidate if _DIRECTIVE.fullmatch(candidate) else "unknown"


def _safe_origin(value: object) -> str:
    candidate = str(value).strip()
    if candidate in {"", "inline", "eval", "self"}:
        return candidate or "unknown"
    try:
        parsed = urlsplit(candidate)
    except ValueError:
        return "unknown"
    if parsed.scheme in {"data", "blob"}:
        return f"{parsed.scheme}:"
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        return "unknown"
    port = f":{parsed.port}" if parsed.port else ""
    return f"{parsed.scheme}://{parsed.hostname}{port}"


@csrf_exempt
@require_POST
def csp_report(request: HttpRequest) -> HttpResponse:
    """Receive a bounded CSP report without retaining URLs or page content."""
    try:
        content_length = int(request.headers.get("Content-Length", "0"))
    except ValueError:
        content_length = 0
    if content_length > _MAX_REPORT_BYTES:
        return HttpResponse(status=413)

    try:
        payload = json.loads(request.body or b"{}")
    except (json.JSONDecodeError, UnicodeDecodeError):
        return HttpResponse(status=400)

    report = payload.get("csp-report", payload) if isinstance(payload, dict) else {}
    if not isinstance(report, dict):
        return HttpResponse(status=400)

    directive = _safe_directive(
        report.get("effective-directive") or report.get("violated-directive")
    )
    disposition = str(report.get("disposition", "report")).lower()
    if disposition not in {"enforce", "report"}:
        disposition = "report"

    logger.warning(
        "security.csp_violation",
        extra={
            "event": "security.csp_violation",
            "directive": directive,
            "blocked_origin": _safe_origin(report.get("blocked-uri", "")),
            "disposition": disposition,
        },
    )
    return HttpResponse(status=204)
