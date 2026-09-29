import pytest

from dictionary.search import is_japanese, kanji_in


@pytest.mark.parametrize("character", ["㐀", "𠮷", "﨑", "丽"])
def test_cjk_extensions_and_compatibility_are_searchable_japanese(character):
    assert is_japanese(character)
    assert kanji_in(f"あ{character}日{character}A") == [character, "日"]


def test_latin_query_does_not_become_japanese():
    assert not is_japanese("water")
    assert kanji_in("water") == []
