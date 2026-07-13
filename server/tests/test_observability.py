from __future__ import annotations

import json
import logging
import re
from unittest.mock import MagicMock, patch

import pytest
from django.test import Client, RequestFactory

from jibiki_server.observability.logging import JsonFormatter, RequestContextFilter
from jibiki_server.observability.middleware import (
    RequestObservabilityMiddleware,
    logical_route,
    safe_request_id,
)
from jibiki_server.observability.redaction import REDACTED, redact_value
from jibiki_server.observability.sentry import initialize_sentry, scrub_sentry_event


def test_request_id_is_propagated_and_logged(caplog):
    caplog.set_level(logging.INFO, logger="jibiki.request")
    request_id = "7d182cd6-c9ca-4f98-a8f3-b289f9ba0574"

    response = Client().get("/", HTTP_X_REQUEST_ID=request_id)

    assert response.status_code == 200
    assert response.headers["X-Request-ID"] == request_id
    record = next(record for record in caplog.records if record.name == "jibiki.request")
    assert record.request_id == request_id
    assert record.route == "api_root"
    assert record.method == "GET"
    assert record.status_code == 200
    assert record.status_class == "2xx"
    assert record.duration_ms >= 0


@pytest.mark.parametrize(
    "unsafe",
    ["", "with a space", "line\nbreak", "x" * 65, "slash/not-safe", "web.01:search"],
)
def test_unsafe_request_id_is_replaced(unsafe):
    generated = safe_request_id(unsafe)

    assert generated != unsafe
    assert re.fullmatch(r"[0-9a-f]{32}", generated)


def test_request_log_never_contains_query_string(caplog):
    caplog.set_level(logging.INFO, logger="jibiki.request")

    response = Client().get("/?email=learner@example.com&token=very-secret")

    assert response.status_code == 200
    record = next(record for record in caplog.records if record.name == "jibiki.request")
    assert record.route == "api_root"
    assert "learner@example.com" not in record.getMessage()
    assert "very-secret" not in record.getMessage()
    assert not hasattr(record, "query_string")


def test_log_formatter_outputs_json_and_redacts_pii():
    formatter = JsonFormatter(service="jibiki-api", environment="test")
    record = logging.LogRecord(
        name="jibiki.test",
        level=logging.ERROR,
        pathname=__file__,
        lineno=1,
        msg="Login learner@example.com with Authorization: Bearer abc.def",
        args=(),
        exc_info=None,
    )
    record.request_id = "req-1"

    payload = json.loads(formatter.format(record))

    assert payload["service"] == "jibiki-api"
    assert payload["environment"] == "test"
    assert payload["request_id"] == "req-1"
    assert "learner@example.com" not in payload["message"]
    assert "abc.def" not in payload["message"]
    assert "[REDACTED_EMAIL]" in payload["message"]


def test_django_request_filter_drops_raw_path_and_query():
    record = logging.LogRecord(
        name="django.request",
        level=logging.WARNING,
        pathname=__file__,
        lineno=1,
        msg="Not Found: /reset/private-key?email=learner@example.com",
        args=(),
        exc_info=None,
    )

    assert RequestContextFilter().filter(record)
    assert record.getMessage() == "django.request"


def test_nested_redaction_removes_sensitive_values():
    redacted = redact_value(
        {
            "safe": "visible",
            "password": "never-log-me",
            "nested": {"x_session_token": "secret-token", "count": 2},
            "items": ["learner@example.com"],
        }
    )

    assert redacted == {
        "safe": "visible",
        "password": REDACTED,
        "nested": {"x_session_token": REDACTED, "count": 2},
        "items": ["[REDACTED_EMAIL]"],
    }


def test_sentry_event_is_scrubbed_without_destroying_diagnostics():
    event = {
        "request": {
            "url": "https://api.jibiki.app/api/v1/dict/search?q=private",
            "query_string": "q=private",
            "cookies": {"session": "secret"},
            "data": {"email": "learner@example.com"},
            "headers": {
                "Authorization": "Bearer abc",
                "Accept-Language": "fr",
                "X-Request-ID": "req-1",
            },
        },
        "user": {
            "id": "42",
            "email": "learner@example.com",
            "ip_address": "127.0.0.1",
        },
        "extra": {"password": "secret", "attempt": 2},
        "spans": [{"description": "/search?q=learner@example.com", "data": {"q": "private"}}],
        "exception": {"values": [{"type": "ValueError", "value": "learner@example.com"}]},
    }

    scrubbed = scrub_sentry_event(event)

    assert scrubbed["request"]["url"] == "https://api.jibiki.app"
    assert scrubbed["request"]["query_string"] == REDACTED
    assert scrubbed["request"]["cookies"] == REDACTED
    assert scrubbed["request"]["data"] == REDACTED
    assert scrubbed["request"]["headers"] == {
        "Accept-Language": "fr",
        "X-Request-ID": "req-1",
    }
    assert scrubbed["user"] == {}
    assert scrubbed["extra"] == {"password": REDACTED, "attempt": 2}
    assert scrubbed["spans"] == [{"description": "/search?[REDACTED]", "data": REDACTED}]
    assert scrubbed["exception"]["values"][0]["type"] == "ValueError"
    assert scrubbed["exception"]["values"][0]["value"] == "[REDACTED_EMAIL]"


def test_sentry_is_a_noop_without_dsn():
    assert not initialize_sentry(
        dsn="",
        environment="test",
        release=None,
        traces_sample_rate=0,
    )


def test_sentry_configuration_is_private_and_explicit():
    with patch("sentry_sdk.init") as sentry_init:
        enabled = initialize_sentry(
            dsn="https://public@example.invalid/1",
            environment="staging",
            release="abc123",
            traces_sample_rate=0.05,
        )

    assert enabled
    options = sentry_init.call_args.kwargs
    assert options["send_default_pii"] is False
    assert options["max_request_body_size"] == "never"
    assert options["traces_sample_rate"] == 0.05
    assert options["before_send"] is scrub_sentry_event
    assert options["before_send_transaction"] is scrub_sentry_event


def test_healthz_is_cache_safe_and_does_not_touch_database():
    with patch("jibiki_server.urls.connection.cursor") as cursor:
        response = Client().get("/healthz")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    assert response.headers["Cache-Control"] == "no-store"
    assert response.headers["X-Request-ID"]
    cursor.assert_not_called()


def test_request_id_is_exposed_to_the_web_client():
    response = Client().get("/", HTTP_ORIGIN="https://my.jibiki.app")

    assert "x-request-id" in response.headers["Access-Control-Expose-Headers"].lower()


def test_readyz_checks_database_without_exposing_failure_details():
    cursor = MagicMock()
    cursor.__enter__.return_value = cursor
    with patch("jibiki_server.urls.connection.cursor", return_value=cursor):
        ready = Client().get("/readyz")
    with patch(
        "jibiki_server.urls.connection.cursor",
        side_effect=RuntimeError("db password=bad"),
    ):
        unavailable = Client().get("/readyz")

    assert ready.status_code == 200
    assert ready.json() == {"status": "ok"}
    cursor.execute.assert_called_once_with("SELECT 1")
    assert unavailable.status_code == 503
    assert unavailable.json() == {"status": "unavailable"}
    assert b"password" not in unavailable.content
    assert unavailable.headers["Cache-Control"] == "no-store"


def test_unresolved_route_name_never_falls_back_to_raw_path():
    request = RequestFactory().get("/learner@example.com?token=secret")
    request.resolver_match = None

    assert logical_route(request) == "unresolved"


def test_csp_report_is_bounded_and_logs_only_safe_fields(caplog):
    caplog.set_level(logging.WARNING, logger="jibiki.security")
    response = Client().post(
        "/api/v1/observability/csp-report",
        data=json.dumps(
            {
                "csp-report": {
                    "effective-directive": "script-src-elem",
                    "blocked-uri": "https://tracker.example/private/path?email=learner@example.com",
                    "document-uri": "https://my.jibiki.app/#/private-search",
                    "disposition": "report",
                }
            }
        ),
        content_type="application/csp-report",
    )

    assert response.status_code == 204
    record = next(record for record in caplog.records if record.name == "jibiki.security")
    assert record.event == "security.csp_violation"
    assert record.directive == "script-src-elem"
    assert record.blocked_origin == "https://tracker.example"
    assert record.disposition == "report"
    assert "private" not in record.getMessage()
    assert "learner@example.com" not in record.getMessage()


def test_csp_report_rejects_invalid_json():
    response = Client().post(
        "/api/v1/observability/csp-report",
        data="not-json",
        content_type="application/csp-report",
    )

    assert response.status_code == 400


def test_middleware_logs_direct_failures_and_re_raises(caplog):
    caplog.set_level(logging.ERROR, logger="jibiki.request")
    request = RequestFactory().get("/anything")
    request.resolver_match = None

    def fail(_request):
        raise RuntimeError("learner@example.com token=secret")

    middleware = RequestObservabilityMiddleware(fail)
    with pytest.raises(RuntimeError):
        middleware(request)

    record = next(record for record in caplog.records if record.name == "jibiki.request")
    assert record.request_id == request.request_id
    assert record.route == "unresolved"
    assert record.status_code == 500
