import hashlib

import pytest
from django.core.exceptions import ValidationError

from mnemonics.source_validation import language_catalogue, story_provenance


def test_language_catalogue_rejects_uppercase_aliases():
    # pycountry accepts EN, but DB language keys and locale lookups are lowercase.
    with pytest.raises(ValidationError, match="lowercase"):
        language_catalogue({"languages": ["EN"]})


@pytest.mark.parametrize("value", ["20260906", "2026-W37-1", "2026-02-30"])
def test_review_date_is_an_exact_calendar_date(tmp_path, value):
    path = tmp_path / "story.json"
    path.write_text("{}", encoding="utf-8")
    story = "A test story."
    entry = {
        "en": story,
        "reviews": {
            "en": {
                "status": "verified",
                "reviewer": "Editor",
                "reviewed_at": value,
                "story_sha256": hashlib.sha256(story.encode()).hexdigest(),
            }
        },
    }
    with pytest.raises(ValidationError, match="YYYY-MM-DD"):
        story_provenance(path, {"strategy": "phonetic"}, entry, "en")
