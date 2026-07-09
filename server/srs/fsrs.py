"""A self-contained FSRS-6 scheduler.

FSRS (Free Spaced Repetition Scheduler) is the modern, benchmarked SRS the
DEEP_SEARCH blueprint selects over SM-2/Leitner. This is a faithful, dependency-
free implementation of FSRS-6 (21 parameters, w0..w20) with the standard learning
/ relearning step machine - the same behaviour as py-fsrs, kept in-repo so the
scheduling logic is inspectable and version-stable.

The scheduler is pure: it takes a card's memory state + a rating + a timestamp and
returns the next state. Persistence (Card / ReviewLog rows) lives in models.py; the
per-user `desired_retention` comes from the profile.

Rating scale (Anki/FSRS standard): 1=Again, 2=Hard, 3=Good, 4=Easy.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import datetime, timedelta

# States (match Anki/py-fsrs).
NEW = 0
LEARNING = 1
REVIEW = 2
RELEARNING = 3

AGAIN, HARD, GOOD, EASY = 1, 2, 3, 4

# FSRS-6 default parameters (open-spaced-repetition, 21 weights w0..w20).
DEFAULT_PARAMETERS: tuple[float, ...] = (
    0.2172,
    1.1771,
    3.2602,
    16.1507,
    7.0114,
    0.57,
    2.0966,
    0.0069,
    1.5261,
    0.112,
    1.0178,
    1.849,
    0.1133,
    0.3127,
    2.2934,
    0.2191,
    3.0004,
    0.7536,
    0.3332,
    0.1437,
    0.2,
)

# Sub-day steps before a card graduates to day-granularity review intervals.
LEARNING_STEPS = (timedelta(minutes=1), timedelta(minutes=10))
RELEARNING_STEPS = (timedelta(minutes=10),)
MAX_INTERVAL_DAYS = 36500
MIN_STABILITY = 0.01
STABILITY_MIN_CLAMP = 0.01


@dataclass
class MemoryState:
    """The card fields the scheduler reads and writes. Mirrors the Card model."""

    state: int = NEW
    step: int | None = None  # index into LEARNING/RELEARNING steps, None once in review
    stability: float | None = None
    difficulty: float | None = None
    due: datetime | None = None
    last_review: datetime | None = None


def _clamp(x: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, x))


class FSRS:
    def __init__(
        self,
        parameters: tuple[float, ...] | list[float] | None = None,
        desired_retention: float = 0.9,
    ):
        self.w = tuple(parameters or DEFAULT_PARAMETERS)
        if len(self.w) != 21:
            raise ValueError("FSRS-6 requires exactly 21 parameters")
        self.desired_retention = desired_retention
        self.decay = -self.w[20]
        self.factor = 0.9 ** (1.0 / self.decay) - 1.0

    # ── forgetting curve ───────────────────────────────────────────────────────

    def retrievability(self, elapsed_days: float, stability: float) -> float:
        elapsed_days = max(0.0, elapsed_days)
        return (1.0 + self.factor * elapsed_days / stability) ** self.decay

    def interval_days(self, stability: float) -> int:
        raw = (stability / self.factor) * (self.desired_retention ** (1.0 / self.decay) - 1.0)
        return int(_clamp(round(raw), 1, MAX_INTERVAL_DAYS))

    # ── initial state ────────────────────────────────────────────────────────

    def _initial_stability(self, rating: int) -> float:
        return max(self.w[rating - 1], MIN_STABILITY)

    def _initial_difficulty(self, rating: int) -> float:
        return _clamp(self.w[4] - math.exp(self.w[5] * (rating - 1)) + 1.0, 1.0, 10.0)

    # ── updates ────────────────────────────────────────────────────────────────

    def _next_difficulty(self, d: float, rating: int) -> float:
        delta = -self.w[6] * (rating - 3)
        d_prime = d + delta * (10.0 - d) / 9.0  # linear damping
        # mean-reversion toward the difficulty of an initial "Easy" (rating 4)
        reverted = self.w[7] * self._initial_difficulty(EASY) + (1.0 - self.w[7]) * d_prime
        return _clamp(reverted, 1.0, 10.0)

    def _short_term_stability(self, stability: float, rating: int) -> float:
        sinc = math.exp(self.w[17] * (rating - 3 + self.w[18])) * stability ** (-self.w[19])
        if rating >= GOOD:
            sinc = max(sinc, 1.0)
        return _clamp(stability * sinc, STABILITY_MIN_CLAMP, MAX_INTERVAL_DAYS)

    def _next_recall_stability(self, d: float, s: float, r: float, rating: int) -> float:
        hard_penalty = self.w[15] if rating == HARD else 1.0
        easy_bonus = self.w[16] if rating == EASY else 1.0
        new_s = s * (
            1.0
            + math.exp(self.w[8])
            * (11.0 - d)
            * (s ** -self.w[9])
            * (math.exp(self.w[10] * (1.0 - r)) - 1.0)
            * hard_penalty
            * easy_bonus
        )
        return _clamp(new_s, STABILITY_MIN_CLAMP, MAX_INTERVAL_DAYS)

    def _next_forget_stability(self, d: float, s: float, r: float) -> float:
        new_s = (
            self.w[11]
            * (d ** -self.w[12])
            * (((s + 1.0) ** self.w[13]) - 1.0)
            * math.exp(self.w[14] * (1.0 - r))
        )
        # A lapse must not raise stability above where it was.
        return _clamp(min(new_s, s), STABILITY_MIN_CLAMP, MAX_INTERVAL_DAYS)

    # ── the review transition ───────────────────────────────────────────────────

    def review(self, card: MemoryState, rating: int, now: datetime) -> MemoryState:
        """Return the card's next memory state after `rating` at time `now`."""
        elapsed_days = 0.0
        if card.last_review is not None:
            elapsed_days = max(0.0, (now - card.last_review).total_seconds() / 86400.0)

        first_review = card.stability is None or card.difficulty is None
        if first_review:
            stability = self._initial_stability(rating)
            difficulty = self._initial_difficulty(rating)
        else:
            r = self.retrievability(elapsed_days, card.stability)
            difficulty = self._next_difficulty(card.difficulty, rating)
            if elapsed_days < 1.0:
                stability = self._short_term_stability(card.stability, rating)
            elif rating == AGAIN:
                stability = self._next_forget_stability(difficulty, card.stability, r)
            else:
                stability = self._next_recall_stability(difficulty, card.stability, r, rating)

        state, step, interval = self._schedule(card, rating, stability)

        return MemoryState(
            state=state,
            step=step,
            stability=stability,
            difficulty=difficulty,
            due=now + interval,
            last_review=now,
        )

    def _schedule(self, card: MemoryState, rating: int, stability: float):
        """Decide the next (state, step, due-interval) using the step machine."""
        cur_state = card.state if card.state != NEW else LEARNING
        step = card.step or 0

        if cur_state in (LEARNING, NEW):
            return self._step_through(LEARNING_STEPS, step, rating, stability, RELEARNING_STEPS)
        if cur_state == RELEARNING:
            return self._step_through(RELEARNING_STEPS, step, rating, stability, RELEARNING_STEPS)

        # REVIEW state
        if rating == AGAIN and RELEARNING_STEPS:
            return RELEARNING, 0, RELEARNING_STEPS[0]
        return REVIEW, None, timedelta(days=self.interval_days(stability))

    def _step_through(self, steps, step, rating, stability, relearn_steps):
        """Learning/relearning step progression (mirrors py-fsrs)."""
        if not steps:
            return REVIEW, None, timedelta(days=self.interval_days(stability))

        if rating == AGAIN:
            return (LEARNING if steps is LEARNING_STEPS else RELEARNING), 0, steps[0]
        if rating == HARD:
            state = LEARNING if steps is LEARNING_STEPS else RELEARNING
            if step == 0 and len(steps) == 1:
                return state, 0, steps[0] * 1.5
            if step == 0 and len(steps) >= 2:
                return state, 0, (steps[0] + steps[1]) / 2
            return state, step, steps[min(step, len(steps) - 1)]
        if rating == GOOD:
            if step + 1 >= len(steps):
                return REVIEW, None, timedelta(days=self.interval_days(stability))
            state = LEARNING if steps is LEARNING_STEPS else RELEARNING
            return state, step + 1, steps[step + 1]
        # EASY graduates immediately
        return REVIEW, None, timedelta(days=self.interval_days(stability))
