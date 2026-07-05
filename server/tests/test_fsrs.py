"""Pure FSRS-6 scheduler tests — no DB, no network."""

from datetime import datetime, timedelta, timezone

from srs.fsrs import AGAIN, EASY, FSRS, GOOD, HARD, NEW, REVIEW, MemoryState

T0 = datetime(2026, 1, 1, 12, 0, tzinfo=timezone.utc)


def fresh() -> MemoryState:
    return MemoryState(state=NEW, due=T0)


def test_first_good_review_sets_state():
    f = FSRS()
    after = f.review(fresh(), GOOD, T0)
    assert after.stability is not None and after.stability > 0
    assert 1.0 <= after.difficulty <= 10.0
    assert after.last_review == T0
    assert after.due > T0


def test_easy_yields_longer_interval_than_good():
    f = FSRS()
    good = f.review(fresh(), GOOD, T0)
    easy = f.review(fresh(), EASY, T0)
    assert easy.stability >= good.stability


def test_again_is_harder_than_easy():
    f = FSRS()
    again = f.review(fresh(), AGAIN, T0)
    easy = f.review(fresh(), EASY, T0)
    assert again.difficulty > easy.difficulty


def test_good_review_grows_stability_over_time():
    f = FSRS()
    s1 = f.review(fresh(), GOOD, T0)
    # graduate through learning steps, then a real spaced review a week later
    s2 = f.review(s1, GOOD, T0 + timedelta(minutes=10))
    later = s2.due + timedelta(days=1)
    s3 = f.review(s2, GOOD, later)
    assert s3.stability > s2.stability
    assert s3.state == REVIEW


def test_lapse_reduces_stability():
    f = FSRS()
    s1 = f.review(fresh(), EASY, T0)  # graduates to review immediately
    assert s1.state == REVIEW
    review_time = s1.due + timedelta(days=1)
    lapsed = f.review(s1, AGAIN, review_time)
    assert lapsed.stability <= s1.stability


def test_higher_retention_shortens_intervals():
    lenient = FSRS(desired_retention=0.80)
    strict = FSRS(desired_retention=0.95)
    s = 20.0
    assert strict.interval_days(s) < lenient.interval_days(s)


def test_retrievability_decreases_with_time():
    f = FSRS()
    r_now = f.retrievability(0.0, 10.0)
    r_later = f.retrievability(10.0, 10.0)
    assert r_now > r_later
    assert 0.0 < r_later < r_now <= 1.0


def test_hard_between_again_and_good():
    f = FSRS()
    again = f.review(fresh(), AGAIN, T0)
    hard = f.review(fresh(), HARD, T0)
    good = f.review(fresh(), GOOD, T0)
    assert again.stability <= hard.stability <= good.stability
