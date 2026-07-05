from django.urls import path

from .views import MeView

urlpatterns = [
    # Auth flows are served by allauth headless (/_allauth/app/v1/…); this is only
    # the jibiki product profile bound to the authenticated user.
    path("me", MeView.as_view(), name="auth_me"),
]
