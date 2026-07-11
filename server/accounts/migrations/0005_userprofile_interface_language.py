from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("accounts", "0004_userprofile_plan_userprofile_plan_expires_at")]

    operations = [
        migrations.AddField(
            model_name="userprofile",
            name="interface_language",
            field=models.CharField(default="en", max_length=8),
        ),
    ]
