"""Update bundled English context without deleting other languages or examples."""

from django.db import transaction
from django.db.models import Max

from .models import (
    KanaExplanation,
    KanaUsage,
    KanaUsageExample,
    KanaUsageExampleTranslation,
    KanaUsageTranslation,
)


@transaction.atomic
def set_kana_content(kana, origin_note, label, explanation, examples):
    if origin_note:
        KanaExplanation.objects.update_or_create(
            kana=kana, language="en", defaults={"origin_note": origin_note}
        )
    if not (label or explanation or examples):
        return
    usage, _ = KanaUsage.objects.get_or_create(kana=kana)
    if label or explanation:
        KanaUsageTranslation.objects.update_or_create(
            usage=usage,
            language="en",
            defaults={"label": label, "explanation": explanation},
        )
    for position, item in enumerate(examples):
        segments = {key: item.get(key, "") for key in ("before", "particle", "after")}
        example = usage.examples.filter(**segments).first()
        if example is None:
            # A translated/custom example at this position must not be replaced.
            order = position
            if usage.examples.filter(order=order).exists():
                order = (usage.examples.aggregate(last=Max("order"))["last"] or 0) + 1
            example = KanaUsageExample.objects.create(
                usage=usage,
                order=order,
                pronunciation=item.get("romaji", ""),
                **segments,
            )
        if item.get("en"):
            KanaUsageExampleTranslation.objects.update_or_create(
                example=example, language="en", defaults={"text": item["en"]}
            )
