from __future__ import annotations

import re
from collections.abc import Mapping, Sequence
from typing import Any
from urllib.parse import urlsplit, urlunsplit

REDACTED = "[REDACTED]"

_EMAIL = re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.IGNORECASE)
_BEARER = re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+")
_URL_QUERY = re.compile(r"(?P<path>(?:https?://|/)[^\s?]*)\?[^\s]+", re.IGNORECASE)
_SECRET_ASSIGNMENT = re.compile(
    r"(?i)\b(password|passwd|secret|token|api[_-]?key|authorization|cookie|session|dsn)"
    r"(\s*[=:]\s*|\s+)(['\"]?)([^,\s;&'\"]+)"
)

_SENSITIVE_EXACT = {
    "authorization",
    "body",
    "cookie",
    "cookies",
    "data",
    "dsn",
    "email",
    "files",
    "form",
    "mnemonic",
    "password",
    "payload",
    "query",
    "querystring",
    "rawuri",
    "searchterm",
    "session",
    "story",
    "username",
    "xsessiontoken",
}
_SENSITIVE_PARTS = ("apikey", "password", "passwd", "privatekey", "secret", "token")


def is_sensitive_key(key: object) -> bool:
    normalized = re.sub(r"[^a-z0-9]", "", str(key).lower())
    return normalized in _SENSITIVE_EXACT or any(part in normalized for part in _SENSITIVE_PARTS)


def redact_text(value: object) -> str:
    text = str(value)
    text = _EMAIL.sub("[REDACTED_EMAIL]", text)
    text = _BEARER.sub("Bearer [REDACTED]", text)
    text = _URL_QUERY.sub(r"\g<path>?[REDACTED]", text)

    def replace_secret(match: re.Match[str]) -> str:
        return f"{match.group(1)}{match.group(2)}{REDACTED}"

    return _SECRET_ASSIGNMENT.sub(replace_secret, text)


def redact_value(value: Any, *, key: object | None = None) -> Any:
    if key is not None and is_sensitive_key(key):
        return REDACTED
    if isinstance(value, Mapping):
        return {
            str(child_key): redact_value(child, key=child_key) for child_key, child in value.items()
        }
    if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
        return [redact_value(child) for child in value]
    if isinstance(value, str):
        return redact_text(value)
    return value


def strip_url_query(value: object) -> str:
    text = str(value)
    try:
        parts = urlsplit(text)
    except ValueError:
        return redact_text(text.split("?", 1)[0])
    return urlunsplit((parts.scheme, parts.netloc, parts.path, "", ""))
