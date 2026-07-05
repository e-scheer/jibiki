"""Test settings — inherit everything, force an offline SQLite DB.

pytest-django imports the settings module before subpackage conftests load, so the
DB choice can't be pinned from a conftest reliably; a dedicated settings module is
the standard, order-independent way. Referenced by pyproject's pytest config.
"""

import os
import tempfile

# Point media at a throwaway dir *before* settings.py computes MEDIA_ROOT, so the
# file storage caches the temp location on its very first access — otherwise seed
# art / upload tests leak WebP files into the repo's data/media tree.
os.environ.setdefault("MEDIA_STORE", tempfile.mkdtemp(prefix="jibiki-test-media-"))

from .settings import *  # noqa: F403

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": ":memory:",
    }
}

# Signup should log the user in immediately in tests (return a session token).
ACCOUNT_EMAIL_VERIFICATION = "optional"

# Keep password hashing cheap so the auth tests are fast.
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]
