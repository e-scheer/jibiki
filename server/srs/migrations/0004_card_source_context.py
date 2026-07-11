from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("srs", "0003_cardtombstone_syncedop_card_updated_at_and_more")]

    operations = [
        migrations.AddField(
            model_name="card",
            name="source_sentence",
            field=models.TextField(blank=True),
        ),
        migrations.AddField(
            model_name="card",
            name="source_url",
            field=models.URLField(blank=True),
        ),
        migrations.AddField(
            model_name="card",
            name="source_title",
            field=models.CharField(blank=True, max_length=200),
        ),
        migrations.AddField(
            model_name="card",
            name="source_media",
            field=models.CharField(blank=True, max_length=200),
        ),
    ]
