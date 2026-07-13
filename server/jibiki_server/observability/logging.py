from __future__ import annotations

import json
import logging
from contextvars import ContextVar
from datetime import UTC, datetime
from typing import Any

from .redaction import redact_text, redact_value

current_request_id: ContextVar[str | None] = ContextVar("request_id", default=None)

_EXTRA_FIELDS = (
    "authenticated",
    "blocked_origin",
    "directive",
    "disposition",
    "duration_ms",
    "event",
    "method",
    "request_id",
    "route",
    "status_code",
    "status_class",
)


class RequestContextFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        if not getattr(record, "request_id", None):
            record.request_id = current_request_id.get()
        # Django's built-in request and runserver messages contain the raw path.
        # Our middleware emits the normalized route separately, so keep these
        # records useful for their level and stack without retaining user input.
        if record.name in {"django.request", "django.server"}:
            record.msg = "django.request"
            record.args = ()
        return True


class JsonFormatter(logging.Formatter):
    def __init__(self, *, service: str = "jibiki-api", environment: str = "development"):
        super().__init__()
        self.service = service
        self.environment = environment

    def format(self, record: logging.LogRecord) -> str:
        timestamp = datetime.fromtimestamp(record.created, UTC).isoformat(timespec="milliseconds")
        payload: dict[str, Any] = {
            "timestamp": timestamp.replace("+00:00", "Z"),
            "level": record.levelname.lower(),
            "service": self.service,
            "environment": self.environment,
            "logger": record.name,
            "message": redact_text(record.getMessage()),
        }
        for field in _EXTRA_FIELDS:
            value = getattr(record, field, None)
            if value is not None:
                payload[field] = redact_value(value, key=field)
        if record.exc_info:
            payload["exception"] = redact_text(self.formatException(record.exc_info))
        return json.dumps(payload, ensure_ascii=False, separators=(",", ":"), default=str)
