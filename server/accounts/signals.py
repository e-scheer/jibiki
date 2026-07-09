"""Auto-provision the per-user profile on user creation, so no endpoint ever has
to guard against a missing profile. (allauth manages auth/session tokens itself -
there is no separate DRF token to mint.)"""

from __future__ import annotations

from django.conf import settings
from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import UserProfile


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def create_profile(sender, instance, created, **kwargs):
    if created:
        UserProfile.objects.get_or_create(user=instance)
