import pytest

from dictionary.models import Gloss, Name, NameTranslation, Sense, Word, WordForm
from dictionary.search import _gloss_word_ids, _japanese_word_ids, search_names

pytestmark = pytest.mark.django_db


def test_surface_stops_before_broad_scan_when_exact_tier_fills_page(django_assert_num_queries):
    expected = []
    for seq in range(1, 5):
        word = Word.objects.create(seq=seq)
        WordForm.objects.create(word=word, kind="kana", text="みず")
        expected.append(word.pk)
    with django_assert_num_queries(1):
        results = _japanese_word_ids("みず", 3)
    assert len(results) == 3 and set(results).issubset(expected)


def test_gloss_stops_before_infinitive_and_contains_when_exact_tier_fills_page(
    django_assert_num_queries,
):
    expected = []
    for seq in range(1, 5):
        word = Word.objects.create(seq=seq, freq_rank=seq)
        Gloss.objects.create(sense=Sense.objects.create(word=word), text="water", language="en")
        expected.append(word.pk)
    with django_assert_num_queries(1):
        assert _gloss_word_ids("water", "en", 3) == expected[:3]


def test_name_search_union_preserves_translation_only_matches_and_deduplicates():
    first = Name.objects.create(seq=1, kanji="水", reading="みず")
    NameTranslation.objects.create(name=first, language="en", text="Mizu")
    NameTranslation.objects.create(name=first, language="en", text="Mizu alternative", order=1)
    second = Name.objects.create(seq=2, kanji="別", reading="べつ")
    NameTranslation.objects.create(name=second, language="en", text="Mizu surname")
    third = Name.objects.create(seq=3, reading="mizu")
    foreign = Name.objects.create(seq=4, reading="other")
    NameTranslation.objects.create(name=foreign, language="fr", text="Mizu français")
    assert [name.pk for name in search_names("mizu", lang="en", limit=3)] == [
        first.pk,
        second.pk,
        third.pk,
    ]


def test_french_name_search_can_find_english_only_source_translation():
    name = Name.objects.create(seq=1, kanji="東京", reading="とうきょう")
    NameTranslation.objects.create(name=name, language="en", text="Tokyo")
    assert [result.pk for result in search_names("Tokyo", lang="fr")] == [name.pk]
