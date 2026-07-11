from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True
    dependencies = [("accounts", "0005_userprofile_interface_language")]

    operations = [
        migrations.CreateModel(
            name="WaniKaniConnection",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("token_ciphertext", models.TextField()),
                ("username", models.CharField(blank=True, max_length=120)),
                ("mastery_threshold", models.PositiveSmallIntegerField(default=5)),
                ("pending_preview", models.JSONField(blank=True, default=dict)),
                ("last_synced_at", models.DateTimeField(blank=True, null=True)),
                ("last_imported_at", models.DateTimeField(blank=True, null=True)),
                ("last_error", models.TextField(blank=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("user", models.OneToOneField(on_delete=models.deletion.CASCADE, related_name="wanikani_connection", to=settings.AUTH_USER_MODEL)),
            ],
            options={"db_table": "integrations_wanikani_connection"},
        ),
    ]
