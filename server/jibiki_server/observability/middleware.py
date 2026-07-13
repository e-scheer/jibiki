from __future__ import annotations

import logging
import re
import time
import uuid
from collections.abc import Callable

from django.http import HttpRequest, HttpResponse

from .logging import current_request_id

logger = logging.getLogger("jibiki.request")

_SAFE_REQUEST_ID = re.compile(
    r"^(?:[0-9a-fA-F]{32}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$"
)
_QUIET_ROUTES = {"healthz", "readyz"}


def safe_request_id(value: object) -> str:
    candidate = str(value or "").strip()
    if _SAFE_REQUEST_ID.fullmatch(candidate):
        return candidate
    return uuid.uuid4().hex


def logical_route(request: HttpRequest) -> str:
    match = getattr(request, "resolver_match", None)
    if match is None:
        return "unresolved"
    route = getattr(match, "route", None)
    if route:
        return str(route)
    view_name = getattr(match, "view_name", None)
    return str(view_name or "root")


class RequestObservabilityMiddleware:
    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]):
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        request_id = safe_request_id(request.headers.get("X-Request-ID"))
        request.request_id = request_id
        context_token = current_request_id.set(request_id)
        started = time.perf_counter()
        try:
            response = self.get_response(request)
        except Exception:
            self._log(request, None, started, failed=True)
            raise
        else:
            response.headers["X-Request-ID"] = request_id
            self._log(request, response, started, failed=False)
            return response
        finally:
            current_request_id.reset(context_token)

    @staticmethod
    def _log(
        request: HttpRequest,
        response: HttpResponse | None,
        started: float,
        *,
        failed: bool,
    ) -> None:
        route = logical_route(request)
        if route in _QUIET_ROUTES:
            return
        status_code = response.status_code if response is not None else 500
        if status_code >= 500:
            level = logging.ERROR
        elif status_code >= 400:
            level = logging.WARNING
        else:
            level = logging.INFO
        user = getattr(request, "user", None)
        authenticated = bool(user is not None and getattr(user, "is_authenticated", False))
        logger.log(
            level,
            "request.failed" if failed else "request.completed",
            exc_info=failed,
            extra={
                "authenticated": authenticated,
                "duration_ms": round((time.perf_counter() - started) * 1000, 2),
                "event": "http_request",
                "method": request.method,
                "request_id": request.request_id,
                "route": route,
                "status_code": status_code,
                "status_class": f"{status_code // 100}xx",
            },
        )
