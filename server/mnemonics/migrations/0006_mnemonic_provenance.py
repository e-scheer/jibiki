from django.db import migrations, models


def mark_legacy_seeds(apps, schema_editor):
    Mnemonic = apps.get_model("mnemonics", "Mnemonic")
    Mnemonic.objects.filter(is_seed=True).update(
        provenance={
            "source_type": "bundled",
            "review_status": "unverified",
            "generation_method": "unknown",
            "note": "Legacy seed: no per-story review evidence was recorded.",
        }
    )


class Migration(migrations.Migration):
    dependencies = [("mnemonics", "0005_language_native_targets")]
    operations = [
        migrations.AddField(
            model_name="mnemonic",
            name="provenance",
            field=models.JSONField(blank=True, default=dict),
        ),
        migrations.RunPython(mark_legacy_seeds, migrations.RunPython.noop),
    ]
