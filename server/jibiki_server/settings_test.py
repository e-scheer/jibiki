"""Test settings - inherit everything, override only what keeps the suite fast
and deterministic. The database is **Postgres** (the same engine as dev and prod),
so tests exercise the real migrations, trigram search indexes and SQL behaviour
rather than a divergent engine.

pytest-django imports this module before subpackage conftests load, so the config
is pinned here (order-independent); referenced by pyproject's pytest config.

Requires a reachable Postgres - `make db` (`docker compose up -d db`) brings one up
on localhost:5432. The test runner creates and drops its own `test_jibiki` database.
"""

import os
import tempfile

# Point media at a throwaway dir *before* settings.py computes MEDIA_ROOT, so the
# file storage caches the temp location on its very first access - otherwise seed
# art / upload tests leak WebP files into the repo's var/media tree.
os.environ.setdefault("MEDIA_STORE", tempfile.mkdtemp(prefix="jibiki-test-media-"))
# A developer may have a production DSN in their shell. Tests must never send
# errors or traces outside the process, regardless of that ambient environment.
os.environ["SENTRY_DSN"] = ""
os.environ["SENTRY_ENVIRONMENT"] = "test"
os.environ["SENTRY_TRACES_SAMPLE_RATE"] = "0"

from .settings import *  # noqa: F403

# DATABASES is inherited from settings (DATABASE_URL, default Postgres on
# localhost:5432); Django runs the suite against a throwaway `test_jibiki` database.

# Signup should log the user in immediately in tests (return a session token).
ACCOUNT_EMAIL_VERIFICATION = "optional"

# Keep password hashing cheap so the auth tests are fast.
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]
