from __future__ import annotations

from typing import Any
from urllib.parse import urlsplit, urlunsplit

from .redaction import REDACTED, redact_value

_SAFE_REQUEST_HEADERS = {"accept", "accept-language", "content-type", "x-request-id"}


def scrub_sentry_event(
    event: dict[str, Any], _hint: dict[str, Any] | None = None
) -> dict[str, Any]:
    request = event.get("request")
    if isinstance(request, dict):
        if "url" in request:
            # Route grouping remains available through Sentry's transaction.
            # The concrete path can contain password reset keys or user text.
            parts = urlsplit(str(request["url"]))
            request["url"] = urlunsplit((parts.scheme, parts.netloc, "", "", ""))
        for field in ("cookies", "data", "env", "query_string"):
            if field in request:
                request[field] = REDACTED
        headers = request.get("headers")
        if isinstance(headers, dict):
            request["headers"] = {
                str(key): redact_value(value, key=key)
                for key, value in headers.items()
                if str(key).lower() in _SAFE_REQUEST_HEADERS
            }

    user = event.get("user")
    if isinstance(user, dict):
        event["user"] = {}

    for field in ("breadcrumbs", "contexts", "extra", "spans", "tags"):
        if field in event:
            event[field] = redact_value(event[field])

    exception = event.get("exception")
    if isinstance(exception, dict):
        event["exception"] = redact_value(exception)
    if "message" in event:
        event["message"] = redact_value(event["message"])
    return event


def initialize_sentry(
    *,
    dsn: str,
    environment: str,
    release: str | None,
    traces_sample_rate: float,
) -> bool:
    if not dsn:
        return False

    import sentry_sdk
    from sentry_sdk.integrations.django import DjangoIntegration

    sentry_sdk.init(
        dsn=dsn,
        environment=environment,
        release=release,
        integrations=[DjangoIntegration(transaction_style="url")],
        send_default_pii=False,
        max_request_body_size="never",
        traces_sample_rate=traces_sample_rate,
        before_send=scrub_sentry_event,
        before_send_transaction=scrub_sentry_event,
    )
    return True
