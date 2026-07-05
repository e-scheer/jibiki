# jibiki API image — gunicorn behind Caddy in prod (mirrors tusorsou/web).
FROM python:3.13-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

# Dependency layer (cached unless the lockfile changes).
COPY pyproject.toml uv.lock* ./
RUN uv sync --frozen --no-install-project --no-dev 2>/dev/null || uv sync --no-install-project --no-dev

# Application
COPY . .
RUN uv sync --no-dev

ENV PATH="/app/.venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=jibiki_server.settings

# migrate + collectstatic are idempotent; safe on every container start. Seed the
# demo dataset only if the dictionary is empty (the command is a no-op otherwise).
CMD ["sh", "-c", "python manage.py migrate --noinput && python manage.py collectstatic --noinput && python manage.py seed_demo --if-empty && gunicorn jibiki_server.wsgi:application --bind 0.0.0.0:8000 --workers 3"]
