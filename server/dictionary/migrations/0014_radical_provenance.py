from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("dictionary", "0013_word_canonical_alias")]
    operations = [
        migrations.AddField(
            model_name="radical",
            name="provenance",
            field=models.JSONField(default=dict, blank=True),
        )
    ]
