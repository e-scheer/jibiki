from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path

from feedback.views import ContentReportView


def healthz(_request):
    """Liveness probe (Caddy/uptime ping - mirrors tusorsou's /healthz)."""
    return JsonResponse({"status": "ok"})


def api_root(_request):
    """A discoverable index of the versioned API surface."""
    return JsonResponse(
        {
            "service": "jibiki",
            "version": "v1",
            "endpoints": {
                # Auth is allauth headless (app client). The Flutter app POSTs to
                # /_allauth/app/v1/auth/{signup,login} and reuses the returned
                # session token as X-Session-Token on everything below.
                "auth": "/_allauth/app/v1/",
                "profile": "/api/v1/auth/me",
                "dictionary": "/api/v1/dict/",
                "study": "/api/v1/study/",
                "mnemonics": "/api/v1/mnemonics/",
            },
        }
    )


urlpatterns = [
    path("", api_root),
    path("healthz", healthz, name="healthz"),
    path("admin/", admin.site.urls),
    # allauth headless: mounts both browser/ and app/ client routers under _allauth/.
    path("_allauth/", include("allauth.headless.urls")),
    # Provider redirect/callback endpoints (social login) live under allauth.urls.
    path("accounts/", include("allauth.urls")),
    path("api/v1/auth/", include("accounts.urls")),  # domain profile (me)
    path("api/v1/dict/", include("dictionary.urls")),
    path("api/v1/content/", include("contentpacks.urls")),
    path("api/v1/study/", include("srs.urls")),
    path("api/v1/mnemonics/", include("mnemonics.urls")),
    # Content correction reports (sign-in required) sit beside open feedback.
    # Declared before the include so the no-trailing-slash prefix doesn't swallow it.
    path("api/v1/feedback/report", ContentReportView.as_view(), name="content_report"),
    path("api/v1/feedback", include("feedback.urls")),
    # DRF browsable-API login (dev convenience only).
    path("api-auth/", include("rest_framework.urls")),
]

if settings.DEBUG:
    # Prod: Caddy serves the media volume / R2 serves uploads directly.
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
