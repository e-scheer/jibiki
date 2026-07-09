"""FSRS parity vectors - the scheduler contract shared with the app's Dart port.

``scripts/gen_fsrs_vectors.py`` dumps seeded review sequences with every
intermediate state; the same JSON is checked into the app fixtures and replayed
by ``app/test/srs/fsrs_parity_test.dart``. If this test fails, the scheduler
changed: either revert, or regenerate with ``make sync-vectors`` AND bump the
vector VERSION so the Dart port is forced to catch up in the same change.
"""

import json
from datetime import datetime, timedelta
from pathlib import Path

import pytest

from srs.fsrs import FSRS, NEW, RELEARNING, REVIEW, MemoryState

VECTORS = Path(__file__).parent / "data" / "fsrs_vectors.json"

# Floats cross machines/libms (and later Dart), so compare with a tolerance far
# tighter than any behavioural difference yet immune to last-ulp exp/pow noise.
REL_TOL = 1e-12


@pytest.fixture(scope="module")
def vectors() -> dict:
    return json.loads(VECTORS.read_text(encoding="utf-8"))


def _replay_pure(case: dict, start: datetime) -> None:
    fsrs = FSRS(parameters=case["parameters"], desired_retention=case["desired_retention"])
    state = MemoryState(state=NEW, due=start)
    reps = lapses = 0
    now = start
    for i, step in enumerate(case["steps"]):
        now = now + timedelta(seconds=step["gap_s"])
        before_state = state.state
        state = fsrs.review(state, step["rating"], now)
        scheduled = max(0, (state.due - now).days)
        reps = i + 1
        if step["rating"] == 1 and before_state in (REVIEW, RELEARNING):
            lapses += 1

        where = f"case {case['id']} step {i}"
        assert state.state == step["state"], where
        assert state.step == step["step"], where
        assert (state.due - now).total_seconds() == step["due_offset_s"], where
        assert scheduled == step["scheduled_days"], where
        assert reps == step["reps"], where
        assert lapses == step["lapses"], where
        assert state.stability == pytest.approx(step["stability"], rel=REL_TOL), where
        assert state.difficulty == pytest.approx(step["difficulty"], rel=REL_TOL), where


def test_all_cases_match_pure_scheduler(vectors):
    for case in vectors["cases"]:
        _replay_pure(case, datetime.fromisoformat(vectors["start"]))


@pytest.mark.django_db
def test_subset_matches_real_review_card(vectors, user):
    """Guard the generator's fold replica against services.review_card itself:
    replay a slice of cases through the real Card + ReviewLog path."""
    from dictionary.models import Kana
    from srs import services
    from srs.models import Card, ItemType, State

    kana = Kana.objects.create(char="あ", romaji="a", script="hiragana")
    start = datetime.fromisoformat(vectors["start"])

    for case in vectors["cases"][::25]:
        profile = user.profile
        profile.desired_retention = case["desired_retention"]
        profile.fsrs_parameters = case["parameters"]
        profile.save(update_fields=["desired_retention", "fsrs_parameters"])

        Card.objects.filter(user=user).delete()
        card = Card.objects.create(
            user=user, item_type=ItemType.KANA, kana=kana, due=start, state=State.NEW
        )
        now = start
        for i, step in enumerate(case["steps"]):
            now = now + timedelta(seconds=step["gap_s"])
            log = services.review_card(card, step["rating"], now=now)
            card.refresh_from_db()

            where = f"case {case['id']} step {i}"
            assert card.state == step["state"], where
            assert card.step == step["step"], where
            assert (card.due - now).total_seconds() == step["due_offset_s"], where
            assert log.scheduled_days == step["scheduled_days"], where
            assert card.reps == step["reps"], where
            assert card.lapses == step["lapses"], where
            assert card.stability == pytest.approx(step["stability"], rel=REL_TOL), where
            assert card.difficulty == pytest.approx(step["difficulty"], rel=REL_TOL), where
