#!/usr/bin/env python3
"""Generate the shared FSRS parity vectors (server fsrs.py <-> app fsrs.dart).

The app ships a Dart port of the in-repo FSRS-6 scheduler; scheduling must stay
bit-compatible or offline devices and the server would drift apart. This script
replays seeded pseudo-random review sequences through ``srs.fsrs.FSRS`` plus the
``services.review_card`` side-state rules (reps/lapses/scheduled_days) and dumps
every intermediate state. Both test suites assert against the same file:

  server/tests/data/fsrs_vectors.json   (pytest: tests/test_fsrs_vectors.py)
  app/test/srs/fixtures/fsrs_vectors.json  (flutter: test/srs/fsrs_parity_test.dart)

Regenerate ONLY when the scheduler changes on purpose (`make sync-vectors`),
and bump VERSION so the Dart side fails loudly until its port catches up.
No Django required - fsrs.py is dependency-free.
"""

from __future__ import annotations

import json
import random
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "server"))

from srs.fsrs import (  # noqa: E402
    DEFAULT_PARAMETERS,
    FSRS,
    MemoryState,
    NEW,
    RELEARNING,
    REVIEW,
)

VERSION = 1
SEED = 20260707
T0 = datetime(2026, 1, 1, 0, 0, tzinfo=timezone.utc)

OUTPUTS = (
    ROOT / "server" / "tests" / "data" / "fsrs_vectors.json",
    ROOT / "app" / "test" / "srs" / "fixtures" / "fsrs_vectors.json",
)


def perturbed_parameters(rng: random.Random) -> list[float]:
    """A plausible trained-weights shape: defaults scaled per-weight. Keeps every
    weight positive; w20 (decay) stays in a sane band so intervals don't explode."""
    params = [w * rng.uniform(0.7, 1.3) for w in DEFAULT_PARAMETERS]
    params[20] = min(max(params[20], 0.1), 0.8)
    return [round(p, 6) for p in params]


def sample_gap_s(rng: random.Random, prev_due_offset_s: int) -> int:
    """Seconds between consecutive reviews. The mix deliberately covers the
    scheduler's branch points: sub-day (short-term stability path), the exact
    1-day boundary, on-time reviews (retrievability == desired retention) and
    long overdue gaps."""
    roll = rng.random()
    if roll < 0.20:
        return rng.randint(30, 3600)  # within the hour (learning steps)
    if roll < 0.35:
        return rng.randint(3600, 72000)  # same day
    if roll < 0.45:
        return rng.randint(86400 - 3600, 86400 + 3600)  # around the 1-day boundary
    if roll < 0.65 and prev_due_offset_s > 0:
        return prev_due_offset_s  # exactly on time
    return rng.randint(1, 400) * 86400 + rng.randint(0, 86399)  # overdue / spaced


def fold_review(
    fsrs: FSRS, before: MemoryState, reps: int, lapses: int, rating: int, now: datetime
):
    """Mirror of services.review_card's state fold (the parts beyond pure FSRS):
    reps always increments; lapses only on Again from review/relearning;
    scheduled_days floors the due delta. tests/test_fsrs_vectors.py re-checks a
    subset against the real review_card so this replica can't silently drift."""
    after = fsrs.review(before, rating, now)
    scheduled_days = max(0, (after.due - now).days)
    reps += 1
    if rating == 1 and before.state in (REVIEW, RELEARNING):
        lapses += 1
    return after, reps, lapses, scheduled_days


def build_cases() -> list[dict]:
    rng = random.Random(SEED)
    parameter_sets: list[list[float] | None] = [None]  # None == defaults
    parameter_sets += [perturbed_parameters(rng) for _ in range(5)]

    cases = []
    case_id = 0
    for params in parameter_sets:
        for retention in (0.7, 0.9, 0.97):
            for _ in range(17):
                fsrs = FSRS(parameters=params, desired_retention=retention)
                state = MemoryState(state=NEW, due=T0)
                reps = lapses = 0
                now = T0
                prev_offset = 0
                steps = []
                for i in range(rng.randint(1, 30)):
                    gap = 0 if i == 0 else sample_gap_s(rng, prev_offset)
                    now = now + timedelta(seconds=gap)
                    rating = rng.choices((1, 2, 3, 4), weights=(15, 15, 50, 20))[0]
                    state, reps, lapses, scheduled = fold_review(
                        fsrs, state, reps, lapses, rating, now
                    )
                    offset = (state.due - now).total_seconds()
                    assert offset == int(offset), "due offsets must be whole seconds"
                    prev_offset = int(offset)
                    steps.append(
                        {
                            "gap_s": gap,
                            "rating": rating,
                            "state": state.state,
                            "step": state.step,
                            "stability": state.stability,
                            "difficulty": state.difficulty,
                            "due_offset_s": prev_offset,
                            "scheduled_days": scheduled,
                            "reps": reps,
                            "lapses": lapses,
                        }
                    )
                cases.append(
                    {
                        "id": case_id,
                        "parameters": params,
                        "desired_retention": retention,
                        "steps": steps,
                    }
                )
                case_id += 1
    return cases


def main() -> None:
    doc = {
        "version": VERSION,
        "seed": SEED,
        "start": T0.isoformat(),
        "cases": build_cases(),
    }
    payload = json.dumps(doc, indent=1)
    for path in OUTPUTS:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(payload + "\n", encoding="utf-8")
        print(f"wrote {path.relative_to(ROOT)} ({len(payload) // 1024} KiB)")
    n_steps = sum(len(c["steps"]) for c in doc["cases"])
    print(f"{len(doc['cases'])} cases, {n_steps} steps, version {VERSION}")


if __name__ == "__main__":
    main()
