"""Lightweight, dependency-free per-user FSRS parameter fitting.

DEEP_SEARCH: FSRS only beats its defaults once a user has ~1000 reviews, and the
canonical trainer is fsrs-rs (Rust + the Burn ML framework). This is the pure-
Python, no-torch stand-in: it replays each card's review history under a candidate
parameter set, scores the predicted recall against what actually happened
(log-loss), and runs a bounded coordinate descent — keeping a new value only when
it lowers the loss. The result is adopted only if it beats the defaults on the
user's own data, so it can never make scheduling worse.
"""

from __future__ import annotations

import math

from .fsrs import DEFAULT_PARAMETERS, FSRS, NEW, MemoryState

# One "session" = one card's chronologically-ordered reviews as (rating, when).
Session = list[tuple[int, "object"]]

_EPS = 1e-6


def mean_log_loss(sessions: list[Session], params, retention: float) -> tuple[float, int]:
    """Replay every card and return (mean log-loss, scored-review count). Only
    genuine spaced reviews (≥ 1 day since the last one) are scored — same-day
    learning steps carry no retention signal."""
    try:
        f = FSRS(parameters=list(params), desired_retention=retention)
    except (TypeError, ValueError):
        return math.inf, 0

    total, n = 0.0, 0
    for session in sessions:
        state = MemoryState(state=NEW)
        for rating, when in session:
            if state.last_review is not None and state.stability is not None:
                elapsed = (when - state.last_review).total_seconds() / 86400.0
                if elapsed >= 1.0:
                    try:
                        p = f.retrievability(elapsed, state.stability)
                    except (ValueError, OverflowError, ZeroDivisionError):
                        return math.inf, 0
                    p = min(1.0 - _EPS, max(_EPS, p))
                    y = 1.0 if rating >= 2 else 0.0
                    total += -(y * math.log(p) + (1.0 - y) * math.log(1.0 - p))
                    n += 1
            try:
                state = f.review(state, rating, when)
            except (ValueError, OverflowError, ZeroDivisionError):
                return math.inf, 0
    if n == 0:
        return math.inf, 0
    return total / n, n


def optimize(sessions: list[Session], retention: float, *, passes: int = 2) -> dict:
    """Coordinate-descent from the FSRS-6 defaults. Bounded: passes × 21 params ×
    2 directions evaluations. Returns metrics + best parameters."""
    best = list(DEFAULT_PARAMETERS)
    best_loss, scored = mean_log_loss(sessions, best, retention)
    baseline_loss = best_loss

    if scored > 0 and math.isfinite(best_loss):
        for _ in range(passes):
            for i in range(len(best)):
                step = max(abs(best[i]) * 0.1, 0.02)
                for direction in (1, -1):
                    cand = best[:]
                    cand[i] = best[i] + direction * step
                    if i == 20 and cand[i] <= 0:  # DECAY exponent must stay positive
                        continue
                    loss, n = mean_log_loss(sessions, cand, retention)
                    if n > 0 and loss < best_loss - 1e-9:
                        best, best_loss = cand, loss

    improved = math.isfinite(best_loss) and best_loss < baseline_loss - 1e-6
    return {
        "scored_reviews": scored,
        "baseline_log_loss": None if not math.isfinite(baseline_loss) else round(baseline_loss, 5),
        "optimized_log_loss": None if not math.isfinite(best_loss) else round(best_loss, 5),
        "improved": improved,
        "parameters": best if improved else list(DEFAULT_PARAMETERS),
    }
