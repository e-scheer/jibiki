"""Django settings — 12-factor (mirrors the tusorsou stack): everything configurable
lives in env vars, read once here.

jibiki is an API server for a Flutter client, so this is DRF-first: no server-rendered
templates, token auth, JSON everywhere. The dictionary data (JMdict/KANJIDIC/kana) and
the community mnemonics live in Postgres; user mnemonic images go to Cloudflare R2 (or
any S3-compatible store) in prod, or the local media volume in dev — the same swappable
storage pattern tusorsou uses for Hetzner Object Storage.
"""

import os
from pathlib import Path

import dj_database_url

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "dev-only-insecure-key")
DEBUG = os.environ.get("DJANGO_DEBUG", "1") == "1"

# Fail fast rather than serve prod with the dev key (12-factor).
if not DEBUG and SECRET_KEY == "dev-only-insecure-key":
    raise RuntimeError("DJANGO_SECRET_KEY must be set when DJANGO_DEBUG=0")

ALLOWED_HOSTS = os.environ.get("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1,*").split(",")
CSRF_TRUSTED_ORIGINS = [
    o for o in os.environ.get("DJANGO_CSRF_TRUSTED_ORIGINS", "").split(",") if o
]

# Transport security — production only (DEBUG=0), where Caddy terminates TLS and
# forwards X-Forwarded-Proto (identical posture to tusorsou).
if not DEBUG:
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_SSL_REDIRECT = True
    SECURE_HSTS_SECONDS = 31_536_000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.sites",  # allauth requires the sites framework
    "rest_framework",
    "corsheaders",
    # allauth — headless mode exposes the auth REST API the Flutter client uses.
    "allauth",
    "allauth.account",
    "allauth.headless",
    "allauth.socialaccount",
    "allauth.socialaccount.providers.google",
    "allauth.socialaccount.providers.apple",
    "allauth.mfa",
    "accounts",
    "dictionary",
    "srs",
    "mnemonics",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",  # before CommonMiddleware, so preflight is answered
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    # After AuthenticationMiddleware — resolves the allauth session for every
    # request (including the headless app-client X-Session-Token path).
    "allauth.account.middleware.AccountMiddleware",
]

ROOT_URLCONF = "jibiki_server.urls"
WSGI_APPLICATION = "jibiki_server.wsgi.application"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,  # admin needs it
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

DATABASES = {
    "default": dj_database_url.config(
        env="DATABASE_URL",
        default="postgres://jibiki:jibiki@localhost:5432/jibiki",
        conn_max_age=60,
    )
}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
AUTH_USER_MODEL = "accounts.User"
SITE_ID = 1

AUTHENTICATION_BACKENDS = [
    "django.contrib.auth.backends.ModelBackend",
    "allauth.account.auth_backends.AuthenticationBackend",
]

# ── DRF ──────────────────────────────────────────────────────────────────────
# The domain API authenticates with allauth-headless' app-client session token:
# the app logs in via /_allauth/app/v1/auth/login, gets `meta.session_token`, and
# sends it back as `X-Session-Token`. XSessionTokenAuthentication bridges that
# same token into DRF so /api/v1/* is authenticated by the very token allauth
# issued (one auth system, not two). SessionAuthentication stays on for the
# browsable API in dev.
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "allauth.headless.contrib.rest_framework.authentication.XSessionTokenAuthentication",
        "rest_framework.authentication.SessionAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.LimitOffsetPagination",
    "PAGE_SIZE": 25,
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.ScopedRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {
        "search": "120/min",  # dictionary search is hot but bounded
        "write": "60/min",  # mnemonic/vote/review submissions
    },
}

# CORS — the Flutter web build (dev) is a different origin than the API. Native
# builds are unaffected. In prod, lock this down to the app's web origin(s).
CORS_ALLOWED_ORIGINS = [o for o in os.environ.get("CORS_ALLOWED_ORIGINS", "").split(",") if o]
CORS_ALLOW_ALL_ORIGINS = DEBUG and not CORS_ALLOWED_ORIGINS
# Let the headless app-client token header through cross-origin (dev web build).
from corsheaders.defaults import default_headers  # noqa: E402

CORS_ALLOW_HEADERS = (*default_headers, "x-session-token")

# ── allauth (headless) ─────────────────────────────────────────────────────────
# Email-only accounts (no username — the product never shows one), same as the
# tusorsou stack. HEADLESS_ONLY: this server has no server-rendered account pages;
# the Flutter app is the only frontend, reached via deep links for the email flows.
ACCOUNT_LOGIN_METHODS = {"email"}
ACCOUNT_SIGNUP_FIELDS = ["email*", "password1*", "password2*"]
ACCOUNT_EMAIL_VERIFICATION = os.environ.get("ACCOUNT_EMAIL_VERIFICATION", "optional")
ACCOUNT_USER_MODEL_USERNAME_FIELD = None
ACCOUNT_UNIQUE_EMAIL = True

HEADLESS_ONLY = True
# Deep links the app registers; allauth builds email links (verify / reset) and
# social callbacks against these. Override in prod with the real scheme/host.
_APP_URL = os.environ.get("HEADLESS_FRONTEND_BASE", "jibiki://auth")
HEADLESS_FRONTEND_URLS = {
    "account_confirm_email": f"{_APP_URL}/verify-email/{{key}}",
    "account_reset_password": f"{_APP_URL}/reset-password",
    "account_reset_password_from_key": f"{_APP_URL}/reset-password/{{key}}",
    "account_signup": f"{_APP_URL}/signup",
    "socialaccount_login_error": f"{_APP_URL}/social-error",
}

# MFA — TOTP + recovery codes (no WebAuthn → no fido2 dependency), mirrors tusorsou.
MFA_SUPPORTED_TYPES = ["recovery_codes", "totp"]
MFA_TOTP_ISSUER = "jibiki"

# Social login. Credentials come from env vars (no DB SocialApp rows) so the repo
# stays secret-free; providers render inert until configured. Google + Apple are
# the two that matter for a mobile app store presence.
SOCIALACCOUNT_EMAIL_REQUIRED = True  # the user model is email-only
SOCIALACCOUNT_EMAIL_VERIFICATION = "none"  # trust the provider's verification
SOCIALACCOUNT_STORE_TOKENS = False
SOCIALACCOUNT_PROVIDERS = {
    "google": {
        "APPS": [
            {
                "name": "Google",
                "client_id": os.environ.get("SOCIALACCOUNT_GOOGLE_CLIENT_ID", ""),
                "secret": os.environ.get("SOCIALACCOUNT_GOOGLE_CLIENT_SECRET", ""),
            }
        ],
        "SCOPE": ["profile", "email"],
        "AUTH_PARAMS": {"access_type": "online"},
        "VERIFIED_EMAIL": True,
    },
    "apple": {
        "APPS": [
            {
                "name": "Apple",
                "client_id": os.environ.get("SOCIALACCOUNT_APPLE_CLIENT_ID", ""),
                "secret": os.environ.get("SOCIALACCOUNT_APPLE_SECRET", ""),
                "key": os.environ.get("SOCIALACCOUNT_APPLE_KEY_ID", ""),
                "settings": {
                    "certificate_key": os.environ.get("SOCIALACCOUNT_APPLE_PRIVATE_KEY", "")
                },
            }
        ],
    },
}

# Prod must not boot half-wired: a live provider needs BOTH id and secret (mirrors
# the SECRET_KEY guard). Apple's cert flow is exempt (its secret is derived).
if not DEBUG:
    _g = SOCIALACCOUNT_PROVIDERS["google"]["APPS"][0]
    if bool(_g["client_id"]) != bool(_g["secret"]):
        raise RuntimeError("social provider 'google': set BOTH client_id and secret, or neither")

# Email — allauth sends verification / password-reset / notification mail here.
# Dev prints to stdout (console backend); set EMAIL_HOST in prod and it switches
# to SMTP automatically (same pattern as tusorsou).
EMAIL_HOST = os.environ.get("EMAIL_HOST", "")
EMAIL_PORT = int(os.environ.get("EMAIL_PORT", "587"))
EMAIL_HOST_USER = os.environ.get("EMAIL_HOST_USER", "")
EMAIL_HOST_PASSWORD = os.environ.get("EMAIL_HOST_PASSWORD", "")
EMAIL_USE_SSL = os.environ.get("EMAIL_USE_SSL", "0") == "1"
EMAIL_USE_TLS = not EMAIL_USE_SSL and os.environ.get("EMAIL_USE_TLS", "1") == "1"
EMAIL_TIMEOUT = 10
DEFAULT_FROM_EMAIL = os.environ.get("DEFAULT_FROM_EMAIL", "jibiki <noreply@jibiki.app>")
SERVER_EMAIL = DEFAULT_FROM_EMAIL
ACCOUNT_EMAIL_SUBJECT_PREFIX = "[jibiki] "
EMAIL_BACKEND = os.environ.get(
    "DJANGO_EMAIL_BACKEND",
    "django.core.mail.backends.smtp.EmailBackend"
    if EMAIL_HOST
    else "django.core.mail.backends.console.EmailBackend",
)

# Containers run UTC; localization is a client concern (the app renders in the
# device locale). The API speaks ISO-8601 UTC everywhere.
LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = os.environ.get("DJANGO_STATIC_ROOT", str(BASE_DIR / "staticfiles"))

# Community mnemonic images. Dev → local /media volume (served by Caddy in the
# container stack, by Django's static() in DEBUG). Prod → set MEDIA_S3_* to push
# to Cloudflare R2 (zero egress — the DEEP_SEARCH recommendation) or any
# S3-compatible store. Same swappable pattern as tusorsou's Hetzner offload.
MEDIA_URL = "media/"
MEDIA_ROOT = os.environ.get("MEDIA_STORE", str(BASE_DIR.parent / "data" / "media"))

# Ingest guardrails for uploaded mnemonic images (community.imaging re-encodes to
# WebP, strips EXIF/GPS, caps dimensions — the DEEP_SEARCH moderation-pipeline rule).
MNEMONIC_IMAGE_MAX_BYTES = int(os.environ.get("MNEMONIC_IMAGE_MAX_BYTES", str(6 * 1024 * 1024)))
MNEMONIC_IMAGE_MAX_DIM = int(os.environ.get("MNEMONIC_IMAGE_MAX_DIM", "1200"))

MEDIA_S3_BUCKET = os.environ.get("MEDIA_S3_BUCKET", "")
if MEDIA_S3_BUCKET:
    STORAGES = {
        "default": {
            "BACKEND": "storages.backends.s3.S3Storage",
            "OPTIONS": {
                "bucket_name": MEDIA_S3_BUCKET,
                "endpoint_url": os.environ[
                    "MEDIA_S3_ENDPOINT_URL"
                ],  # https://<acct>.r2.cloudflarestorage.com
                "region_name": os.environ.get("MEDIA_S3_REGION", "auto"),
                "access_key": os.environ["MEDIA_S3_ACCESS_KEY"],
                "secret_key": os.environ["MEDIA_S3_SECRET_KEY"],
                "addressing_style": "virtual",
                "location": os.environ.get("MEDIA_S3_LOCATION", "media"),
                "default_acl": None,  # R2 ignores ACLs; bucket policy controls public read
                "querystring_auth": False,
                # Point this at your R2 public bucket domain / custom CDN domain.
                "custom_domain": os.environ.get("MEDIA_S3_CUSTOM_DOMAIN") or None,
                # Mnemonic images are immutable (Storage.save uniquifies names) → cache hard.
                "object_parameters": {"CacheControl": "public, max-age=31536000, immutable"},
                "file_overwrite": False,
            },
        },
        "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
    }

# The jibiki content pack the API serves for download / offline use (built once by
# scripts/build_content_pack.py, loaded by manage.py load_pack). Defaults to the
# committed seed pack at the repo root.
CONTENT_PACK_DIR = os.environ.get("CONTENT_PACK_DIR", str(BASE_DIR.parent / "content"))

# FSRS per-user optimization only helps past this many reviews (DEEP_SEARCH); below
# it the default weights are used and perform ~like SM-2.
FSRS_OPTIMIZE_MIN_REVIEWS = int(os.environ.get("FSRS_OPTIMIZE_MIN_REVIEWS", "1000"))

# Community-content trust: mnemonics from users below this many net upvotes across
# their contributions post as PENDING (held for review); trusted contributors post
# straight to VISIBLE (the Discourse/Stack-Overflow reputation rule from DEEP_SEARCH).
MNEMONIC_TRUST_THRESHOLD = int(os.environ.get("MNEMONIC_TRUST_THRESHOLD", "10"))
# Distinct reporters that auto-hide a mnemonic pending staff review (Koohii-style).
MNEMONIC_AUTO_HIDE_REPORTS = int(os.environ.get("MNEMONIC_AUTO_HIDE_REPORTS", "3"))

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "root": {"handlers": ["console"], "level": os.environ.get("DJANGO_LOG_LEVEL", "INFO")},
}
