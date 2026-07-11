from django.db import migrations, models


def copy_choice_readings(apps, schema_editor):
    Choice = apps.get_model("mnemonics", "UserMnemonicChoice")
    for choice in Choice.objects.select_related("mnemonic").iterator():
        reading = choice.mnemonic.reading if choice.mnemonic_id else ""
        if reading:
            Choice.objects.filter(pk=choice.pk).update(reading=reading)


class Migration(migrations.Migration):
    dependencies = [("mnemonics", "0004_mnemonic_reading_alter_mnemonic_kind_and_more")]

    operations = [
        migrations.AddField(
            model_name="usermnemonicchoice",
            name="reading",
            field=models.CharField(blank=True, default="", max_length=32),
        ),
        migrations.RunPython(copy_choice_readings, migrations.RunPython.noop),
        migrations.RemoveConstraint(
            model_name="usermnemonicchoice", name="uq_choice_per_char"
        ),
        migrations.AddConstraint(
            model_name="usermnemonicchoice",
            constraint=models.UniqueConstraint(
                fields=("user", "kind", "character", "language", "reading"),
                name="uq_choice_per_target",
            ),
        ),
        migrations.AddConstraint(
            model_name="mnemonic",
            constraint=models.CheckConstraint(
                condition=(
                    models.Q(("kind", "kanji_reading"), ("reading__gt", ""))
                    | (~models.Q(("kind", "kanji_reading")) & models.Q(("reading", "")))
                ),
                name="mnemonic_reading_matches_kind",
            ),
        ),
    ]
