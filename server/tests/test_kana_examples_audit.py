import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "audit_kana_examples", Path(__file__).resolve().parents[2] / "scripts/audit_kana_examples.py"
)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


def test_related_voiced_sound_cannot_masquerade_as_target_example():
    assert audit.audit_example("ひゃ", {"word": "さんびゃく", "meaning": "three hundred"}) == [
        "target_kana_not_in_word"
    ]
    assert audit.audit_example("ヂ", {"word": "メディア", "meaning": "media"}) == [
        "target_kana_not_in_word"
    ]


def test_combining_marks_are_normalized_before_target_check():
    assert audit.audit_example("が", {"word": "か\u3099くせい", "meaning": "student"}) == []


def test_empty_or_mislabelled_example_is_quarantined():
    assert "missing_translation" in audit.audit_example("あ", {"word": "あめ"})
    assert "highlight_mismatches_target" in audit.audit_example(
        "あ", {"word": "あめ", "meaning": "rain", "highlight": "め"}
    )
