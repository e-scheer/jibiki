# Backend observability

The Django API writes one compact JSON object per line to stdout. Logs are
designed for container collection and include a timestamp, severity, service,
environment, logger and message. HTTP completion records also include the
logical route, method, status class, duration and request ID.

Request IDs can arrive in `X-Request-ID`. Only a UUID or a 32-character
hexadecimal trace ID is accepted. Invalid or missing values are replaced with a
random server value.
Every response returns the effective ID in `X-Request-ID`, and CORS exposes that
header so the Web client can attach it to a diagnostic report.

The logger never records request bodies, query strings, raw paths, IP addresses
or authentication headers. Email addresses and secret-shaped values that reach
an exception message are redacted before serialization. Sentry applies the same
policy and additionally removes cookies, request data, user PII and concrete URL
paths.

## Environment

- `DJANGO_LOG_LEVEL`: stdout threshold, normally `INFO` in production.
- `SENTRY_DSN`: enables Sentry when non-empty. Empty means no SDK initialization
  and no Sentry network traffic.
- `SENTRY_ENVIRONMENT`: deployment name such as `production` or `staging`.
- `SENTRY_RELEASE`: immutable build identifier, ideally the deployed git SHA.
- `SENTRY_TRACES_SAMPLE_RATE`: number from `0` to `1`. `0` disables performance
  traces without disabling error reports.

No secret belongs in source control. Inject production values through the
deployment environment. Keep trace sampling low until event volume and cost are
known.

## Health probes

- `GET /healthz` checks process liveness without touching external services.
- `GET /readyz` runs a minimal database query and returns HTTP 503 when the API
  cannot safely accept traffic.

Both responses use `Cache-Control: no-store`. Failure responses are generic and
never expose database details.
