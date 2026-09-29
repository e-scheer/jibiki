import re
from pathlib import Path

import pytest

from dictionary.romaji import ROMAJI_KANA, romaji_to_hiragana


@pytest.mark.parametrize(
    ("query", "expected"),
    [
        ("mizu", "みず"),
        ("tabemono", "たべもの"),
        ("gakkou", "がっこう"),
        ("shinjuku", "しんじゅく"),
        ("kan'ichi", "かんいち"),
        ("gare", "がれ"),
        ("ou", "おう"),
        ("water", None),
        ("eat", None),
        ("école", None),
    ],
)
def test_romaji_transliteration_matches_desktop(query, expected):
    assert romaji_to_hiragana(query) == expected


def test_romaji_mapping_table_matches_dart():
    source = (Path(__file__).parents[2] / "app/lib/core/japanese_text.dart").read_text(
        encoding="utf-8"
    )
    table = source.split("const Map<String, String> _romajiKana = {", 1)[1]
    pairs = re.findall(r"""(['"])([a-z']+)\1:\s*['"]([^'"]+)['"]""", table)
    assert {key: value for _, key, value in pairs} == ROMAJI_KANA


@pytest.mark.django_db
def test_english_infinitive_precedes_prefix_and_incidental_substring():
    from dictionary.models import Gloss, Sense, Word
    from dictionary.search import search_words

    words = []
    for rank, gloss in enumerate(["weather", "eating", "to eat"], 1):
        word = Word.objects.create(seq=100 + rank, freq_rank=rank)
        Gloss.objects.create(sense=Sense.objects.create(word=word), language="en", text=gloss)
        words.append(word)
    assert [w.pk for w in search_words("eat")] == [words[2].pk, words[1].pk, words[0].pk]


@pytest.mark.django_db
@pytest.mark.parametrize(("query", "reading"), [("gare", "がれ"), ("ou", "おう")])
def test_french_meaning_survives_full_romaji_result_page(query, reading):
    from dictionary.models import Gloss, Sense, Word, WordForm
    from dictionary.search import search_words

    for offset in range(6):
        word = Word.objects.create(seq=100 + offset)
        WordForm.objects.create(word=word, kind="kana", text=reading + "る" * offset)
    meaning = Word.objects.create(seq=200)
    Gloss.objects.create(sense=Sense.objects.create(word=meaning), language="fr", text=query)
    results = search_words(query, lang="fr", limit=4)
    assert len(results) == 4 and meaning.pk in [word.pk for word in results]


@pytest.mark.django_db
def test_search_romaji_finds_canonical_reading():
    from dictionary.models import Word, WordForm
    from dictionary.search import search_words

    water = Word.objects.create(seq=100)
    WordForm.objects.create(word=water, kind="kana", text="みず")
    assert [word.pk for word in search_words("mizu")] == [water.pk]
