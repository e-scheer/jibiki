import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("dictionary", "0011_explicit_example_sense_links")]
    operations = [
        migrations.CreateModel(
            name="KanaWordExample",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("reading", models.CharField(max_length=64)),
                ("order", models.PositiveSmallIntegerField(default=0)),
                ("provenance", models.JSONField(blank=True, default=dict)),
                (
                    "kana",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="word_examples",
                        to="dictionary.kana",
                    ),
                ),
                (
                    "word",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="kana_examples",
                        to="dictionary.word",
                    ),
                ),
            ],
            options={
                "db_table": "dict_kana_word_examples",
                "ordering": ["kana", "order", "id"],
                "constraints": [
                    models.UniqueConstraint(
                        fields=("kana", "word", "reading"), name="uq_kana_word_reading"
                    )
                ],
            },
        )
    ]
