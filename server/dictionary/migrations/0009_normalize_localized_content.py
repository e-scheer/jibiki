import django.db.models.deletion
from django.db import migrations, models


def move_localized_content(apps, schema_editor):
    Sense = apps.get_model("dictionary", "Sense")
    SenseNote = apps.get_model("dictionary", "SenseNote")
    Radical = apps.get_model("dictionary", "Radical")
    RadicalMeaning = apps.get_model("dictionary", "RadicalMeaning")
    Kanji = apps.get_model("dictionary", "Kanji")
    KanjiExplanation = apps.get_model("dictionary", "KanjiExplanation")
    Kana = apps.get_model("dictionary", "Kana")
    KanaExplanation = apps.get_model("dictionary", "KanaExplanation")
    KanaUsage = apps.get_model("dictionary", "KanaUsage")
    KanaUsageTranslation = apps.get_model("dictionary", "KanaUsageTranslation")
    KanaUsageExample = apps.get_model("dictionary", "KanaUsageExample")
    KanaUsageExampleTranslation = apps.get_model(
        "dictionary", "KanaUsageExampleTranslation"
    )
    ExampleSentence = apps.get_model("dictionary", "ExampleSentence")
    ExampleTranslation = apps.get_model("dictionary", "ExampleTranslation")
    Name = apps.get_model("dictionary", "Name")
    NameTranslation = apps.get_model("dictionary", "NameTranslation")

    SenseNote.objects.bulk_create(
        SenseNote(sense_id=row.id, language="en", text=row.info)
        for row in Sense.objects.exclude(info="").iterator()
    )
    RadicalMeaning.objects.bulk_create(
        RadicalMeaning(radical_id=row.id, language="en", text=row.meaning)
        for row in Radical.objects.exclude(meaning="").iterator()
    )
    KanjiExplanation.objects.bulk_create(
        KanjiExplanation(kanji_id=row.id, language="en", origin=row.origin)
        for row in Kanji.objects.exclude(origin="").iterator()
    )

    for kana in Kana.objects.iterator():
        if kana.origin_note:
            KanaExplanation.objects.create(
                kana_id=kana.id, language="en", origin_note=kana.origin_note
            )
        examples = kana.usage_examples or []
        if not (kana.usage_label or kana.usage or examples):
            continue
        usage = KanaUsage.objects.create(kana_id=kana.id)
        if kana.usage_label or kana.usage:
            KanaUsageTranslation.objects.create(
                usage=usage,
                language="en",
                label=kana.usage_label,
                explanation=kana.usage,
            )
        for order, item in enumerate(examples):
            example = KanaUsageExample.objects.create(
                usage=usage,
                order=order,
                before=item.get("before", ""),
                particle=item.get("particle", ""),
                after=item.get("after", ""),
                pronunciation=item.get("romaji", ""),
            )
            text = item.get("en", "")
            if text:
                KanaUsageExampleTranslation.objects.create(
                    example=example, language="en", text=text
                )

    ExampleTranslation.objects.bulk_create(
        ExampleTranslation(example_id=row.id, language="en", text=row.english)
        for row in ExampleSentence.objects.exclude(english="").iterator()
    )
    translations = []
    for name in Name.objects.iterator():
        translations.extend(
            NameTranslation(name_id=name.id, language="en", text=text, order=order)
            for order, text in enumerate(name.translations or [])
            if text
        )
        if len(translations) >= 2000:
            NameTranslation.objects.bulk_create(translations)
            translations = []
    if translations:
        NameTranslation.objects.bulk_create(translations)


def restore_legacy_content(apps, schema_editor):
    Sense = apps.get_model("dictionary", "Sense")
    Radical = apps.get_model("dictionary", "Radical")
    Kanji = apps.get_model("dictionary", "Kanji")
    Kana = apps.get_model("dictionary", "Kana")
    ExampleSentence = apps.get_model("dictionary", "ExampleSentence")
    Name = apps.get_model("dictionary", "Name")

    for row in apps.get_model("dictionary", "SenseNote").objects.filter(language="en"):
        Sense.objects.filter(pk=row.sense_id).update(info=row.text)
    for row in apps.get_model("dictionary", "RadicalMeaning").objects.filter(language="en"):
        Radical.objects.filter(pk=row.radical_id).update(meaning=row.text)
    for row in apps.get_model("dictionary", "KanjiExplanation").objects.filter(language="en"):
        Kanji.objects.filter(pk=row.kanji_id).update(origin=row.origin)
    for row in apps.get_model("dictionary", "KanaExplanation").objects.filter(language="en"):
        Kana.objects.filter(pk=row.kana_id).update(origin_note=row.origin_note)
    for usage in apps.get_model("dictionary", "KanaUsage").objects.all():
        translation = usage.translations.filter(language="en").first()
        examples = []
        for example in usage.examples.order_by("order"):
            translated = example.translations.filter(language="en").first()
            examples.append(
                {
                    "before": example.before,
                    "particle": example.particle,
                    "after": example.after,
                    "romaji": example.pronunciation,
                    "en": translated.text if translated else "",
                }
            )
        Kana.objects.filter(pk=usage.kana_id).update(
            usage_label=translation.label if translation else "",
            usage=translation.explanation if translation else "",
            usage_examples=examples,
        )
    for row in apps.get_model("dictionary", "ExampleTranslation").objects.filter(language="en"):
        ExampleSentence.objects.filter(pk=row.example_id).update(english=row.text)
    for name in Name.objects.all():
        values = list(
            name.localized_names.filter(language="en")
            .order_by("order")
            .values_list("text", flat=True)
        )
        Name.objects.filter(pk=name.pk).update(translations=values)


class Migration(migrations.Migration):
    dependencies = [("dictionary", "0008_kana_usage_examples")]

    operations = [
        migrations.RenameField(model_name="gloss", old_name="lang", new_name="language"),
        migrations.RenameField(
            model_name="kanjimeaning", old_name="lang", new_name="language"
        ),
        migrations.RemoveIndex(
            model_name="gloss", name="dict_glosse_lang_d7fe9f_idx"
        ),
        migrations.RemoveIndex(
            model_name="kanjimeaning", name="dict_kanji__lang_53ea8b_idx"
        ),
        migrations.AddIndex(
            model_name="gloss",
            index=models.Index(
                fields=["language", "text"], name="dict_glosse_lang_d7fe9f_idx"
            ),
        ),
        migrations.AddIndex(
            model_name="kanjimeaning",
            index=models.Index(
                fields=["language", "text"], name="dict_kanji__lang_53ea8b_idx"
            ),
        ),
        migrations.CreateModel(
            name="SenseNote",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("language", models.CharField(default="en", max_length=8)),
                ("text", models.CharField(max_length=255)),
                (
                    "sense",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="notes",
                        to="dictionary.sense",
                    ),
                ),
            ],
            options={"db_table": "dict_sense_notes"},
        ),
        migrations.CreateModel(
            name="RadicalMeaning",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("language", models.CharField(default="en", max_length=8)),
                ("text", models.CharField(max_length=64)),
                (
                    "radical",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="meanings",
                        to="dictionary.radical",
                    ),
                ),
            ],
            options={"db_table": "dict_radical_meanings"},
        ),
        migrations.CreateModel(
            name="KanjiExplanation",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("language", models.CharField(default="en", max_length=8)),
                ("origin", models.TextField(blank=True)),
                (
                    "kanji",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="explanations",
                        to="dictionary.kanji",
                    ),
                ),
            ],
            options={"db_table": "dict_kanji_explanations"},
        ),
        migrations.CreateModel(
            name="KanaExplanation",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("language", models.CharField(default="en", max_length=8)),
                ("origin_note", models.CharField(max_length=255)),
                (
                    "kana",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="explanations",
                        to="dictionary.kana",
                    ),
                ),
            ],
            options={"db_table": "dict_kana_explanations"},
        ),
        migrations.CreateModel(
            name="KanaUsage",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                (
                    "kana",
                    models.OneToOneField(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="grammatical_usage",
                        to="dictionary.kana",
                    ),
                ),
            ],
            options={"db_table": "dict_kana_usages"},
        ),
        migrations.CreateModel(
            name="KanaUsageTranslation",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("language", models.CharField(default="en", max_length=8)),
                ("label", models.CharField(max_length=48)),
                ("explanation", models.CharField(max_length=255)),
                (
                    "usage",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="translations",
                        to="dictionary.kanausage",
                    ),
                ),
            ],
            options={"db_table": "dict_kana_usage_translations"},
        ),
        migrations.CreateModel(
            name="KanaUsageExample",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("order", models.PositiveSmallIntegerField(default=0)),
                ("before", models.TextField(blank=True)),
                ("particle", models.CharField(max_length=8)),
                ("after", models.TextField(blank=True)),
                ("pronunciation", models.CharField(blank=True, max_length=255)),
                (
                    "usage",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="examples",
                        to="dictionary.kanausage",
                    ),
                ),
            ],
            options={
                "db_table": "dict_kana_usage_examples",
                "ordering": ["usage", "order"],
            },
        ),
        migrations.CreateModel(
            name="KanaUsageExampleTranslation",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("language", models.CharField(default="en", max_length=8)),
                ("text", models.TextField()),
                (
                    "example",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="translations",
                        to="dictionary.kanausageexample",
                    ),
                ),
            ],
            options={"db_table": "dict_kana_usage_example_translations"},
        ),
        migrations.CreateModel(
            name="ExampleTranslation",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("language", models.CharField(default="en", max_length=8)),
                ("text", models.TextField()),
                (
                    "example",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="translations",
                        to="dictionary.examplesentence",
                    ),
                ),
            ],
            options={"db_table": "dict_example_translations"},
        ),
        migrations.CreateModel(
            name="NameTranslation",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("language", models.CharField(default="en", max_length=8)),
                ("text", models.CharField(max_length=255)),
                ("order", models.PositiveSmallIntegerField(default=0)),
                (
                    "name",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="localized_names",
                        to="dictionary.name",
                    ),
                ),
            ],
            options={
                "db_table": "dict_name_translations",
                "ordering": ["name", "language", "order"],
            },
        ),
        migrations.AddConstraint(
            model_name="gloss",
            constraint=models.UniqueConstraint(
                fields=("sense", "language", "order"), name="uq_gloss_language_order"
            ),
        ),
        migrations.AddConstraint(
            model_name="kanjimeaning",
            constraint=models.UniqueConstraint(
                fields=("kanji", "language", "order"),
                name="uq_kanji_meaning_language_order",
            ),
        ),
        migrations.AddConstraint(
            model_name="sensenote",
            constraint=models.UniqueConstraint(
                fields=("sense", "language"), name="uq_sense_note_language"
            ),
        ),
        migrations.AddConstraint(
            model_name="radicalmeaning",
            constraint=models.UniqueConstraint(
                fields=("radical", "language"), name="uq_radical_meaning_language"
            ),
        ),
        migrations.AddIndex(
            model_name="radicalmeaning",
            index=models.Index(
                fields=["language", "text"], name="dict_radica_languag_8f2c77_idx"
            ),
        ),
        migrations.AddConstraint(
            model_name="kanjiexplanation",
            constraint=models.UniqueConstraint(
                fields=("kanji", "language"), name="uq_kanji_explanation_language"
            ),
        ),
        migrations.AddConstraint(
            model_name="kanaexplanation",
            constraint=models.UniqueConstraint(
                fields=("kana", "language"), name="uq_kana_explanation_language"
            ),
        ),
        migrations.AddConstraint(
            model_name="kanausagetranslation",
            constraint=models.UniqueConstraint(
                fields=("usage", "language"), name="uq_kana_usage_translation_language"
            ),
        ),
        migrations.AddConstraint(
            model_name="kanausageexample",
            constraint=models.UniqueConstraint(
                fields=("usage", "order"), name="uq_kana_usage_example_order"
            ),
        ),
        migrations.AddConstraint(
            model_name="kanausageexampletranslation",
            constraint=models.UniqueConstraint(
                fields=("example", "language"), name="uq_kana_example_translation_language"
            ),
        ),
        migrations.AddConstraint(
            model_name="exampletranslation",
            constraint=models.UniqueConstraint(
                fields=("example", "language"), name="uq_example_translation_language"
            ),
        ),
        migrations.AddIndex(
            model_name="nametranslation",
            index=models.Index(
                fields=["language", "text"], name="dict_name_t_languag_f34c86_idx"
            ),
        ),
        migrations.AddConstraint(
            model_name="nametranslation",
            constraint=models.UniqueConstraint(
                fields=("name", "language", "order"),
                name="uq_name_translation_language_order",
            ),
        ),
        migrations.RunPython(move_localized_content, restore_legacy_content),
        migrations.RemoveField(model_name="sense", name="info"),
        migrations.RemoveField(model_name="radical", name="meaning"),
        migrations.RemoveField(model_name="kanji", name="origin"),
        migrations.RemoveField(model_name="kana", name="origin_note"),
        migrations.RemoveField(model_name="kana", name="usage_label"),
        migrations.RemoveField(model_name="kana", name="usage"),
        migrations.RemoveField(model_name="kana", name="usage_examples"),
        migrations.RemoveField(model_name="examplesentence", name="english"),
        migrations.RemoveField(model_name="name", name="translations"),
    ]
