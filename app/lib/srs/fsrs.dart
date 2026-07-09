/// A faithful Dart port of the server's FSRS-6 scheduler (server/srs/fsrs.py).
///
/// Offline devices schedule reviews locally with this port while the server
/// stays the canonical store; the two implementations MUST stay bit-compatible
/// or schedules would drift between devices. Parity is locked by shared test
/// vectors (scripts/gen_fsrs_vectors.py → test/srs/fsrs_parity_test.dart);
/// [fsrsVectorsVersion] must match the fixture's version - if the server
/// scheduler changes, regenerate the vectors AND update this port in the same
/// change.
///
/// Rating scale (Anki/FSRS standard): 1=Again, 2=Hard, 3=Good, 4=Easy.
library;

import 'dart:math' as math;

/// Version of the shared parity vectors this port was verified against.
const int fsrsVectorsVersion = 1;

// States (match Anki/py-fsrs and srs/models.py).
const int stateNew = 0;
const int stateLearning = 1;
const int stateReview = 2;
const int stateRelearning = 3;

const int ratingAgain = 1;
const int ratingHard = 2;
const int ratingGood = 3;
const int ratingEasy = 4;

/// FSRS-6 default parameters (open-spaced-repetition, 21 weights w0..w20).
const List<double> defaultParameters = [
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
];

/// Sub-day steps before a card graduates to day-granularity review intervals.
const List<Duration> learningSteps = [Duration(minutes: 1), Duration(minutes: 10)];
const List<Duration> relearningSteps = [Duration(minutes: 10)];
const int maxIntervalDays = 36500;
const double minStability = 0.01;
const double stabilityMinClamp = 0.01;

/// The card fields the scheduler reads and writes. Mirrors the server Card row.
class MemoryState {
  const MemoryState({
    this.state = stateNew,
    this.step,
    this.stability,
    this.difficulty,
    this.due,
    this.lastReview,
  });

  final int state;

  /// Index into learning/relearning steps, null once in review.
  final int? step;
  final double? stability;
  final double? difficulty;
  final DateTime? due;
  final DateTime? lastReview;
}

double _clamp(double x, double lo, double hi) => math.max(lo, math.min(hi, x));

/// Python's round() rounds half to even (banker's rounding); Dart's .round()
/// rounds half away from zero. interval_days must round exactly like the
/// server. Only called with positive values.
int _pyRound(double x) {
  final floor = x.floorToDouble();
  final diff = x - floor;
  if (diff > 0.5) return floor.toInt() + 1;
  if (diff < 0.5) return floor.toInt();
  final f = floor.toInt();
  return f.isEven ? f : f + 1;
}

class Fsrs {
  Fsrs({List<double>? parameters, this.desiredRetention = 0.9})
      : w = List.unmodifiable(parameters ?? defaultParameters) {
    if (w.length != 21) {
      throw ArgumentError('FSRS-6 requires exactly 21 parameters');
    }
    decay = -w[20];
    factor = math.pow(0.9, 1.0 / decay) - 1.0;
  }

  final List<double> w;
  final double desiredRetention;
  late final double decay;
  late final double factor;

  // ── forgetting curve ───────────────────────────────────────────────────────

  double retrievability(double elapsedDays, double stability) {
    final elapsed = math.max(0.0, elapsedDays);
    return math.pow(1.0 + factor * elapsed / stability, decay).toDouble();
  }

  int intervalDays(double stability) {
    final raw = (stability / factor) *
        (math.pow(desiredRetention, 1.0 / decay).toDouble() - 1.0);
    final rounded = _pyRound(raw);
    if (rounded < 1) return 1;
    if (rounded > maxIntervalDays) return maxIntervalDays;
    return rounded;
  }

  // ── initial state ────────────────────────────────────────────────────────

  double _initialStability(int rating) => math.max(w[rating - 1], minStability);

  double _initialDifficulty(int rating) =>
      _clamp(w[4] - math.exp(w[5] * (rating - 1)) + 1.0, 1.0, 10.0);

  // ── updates ────────────────────────────────────────────────────────────────

  double _nextDifficulty(double d, int rating) {
    final delta = -w[6] * (rating - 3);
    final dPrime = d + delta * (10.0 - d) / 9.0; // linear damping
    // mean-reversion toward the difficulty of an initial "Easy" (rating 4)
    final reverted = w[7] * _initialDifficulty(ratingEasy) + (1.0 - w[7]) * dPrime;
    return _clamp(reverted, 1.0, 10.0);
  }

  double _shortTermStability(double stability, int rating) {
    var sinc = math.exp(w[17] * (rating - 3 + w[18])) *
        math.pow(stability, -w[19]).toDouble();
    if (rating >= ratingGood) sinc = math.max(sinc, 1.0);
    return _clamp(stability * sinc, stabilityMinClamp, maxIntervalDays.toDouble());
  }

  double _nextRecallStability(double d, double s, double r, int rating) {
    final hardPenalty = rating == ratingHard ? w[15] : 1.0;
    final easyBonus = rating == ratingEasy ? w[16] : 1.0;
    final newS = s *
        (1.0 +
            math.exp(w[8]) *
                (11.0 - d) *
                math.pow(s, -w[9]).toDouble() *
                (math.exp(w[10] * (1.0 - r)) - 1.0) *
                hardPenalty *
                easyBonus);
    return _clamp(newS, stabilityMinClamp, maxIntervalDays.toDouble());
  }

  double _nextForgetStability(double d, double s, double r) {
    final newS = w[11] *
        math.pow(d, -w[12]).toDouble() *
        (math.pow(s + 1.0, w[13]).toDouble() - 1.0) *
        math.exp(w[14] * (1.0 - r));
    // A lapse must not raise stability above where it was.
    return _clamp(math.min(newS, s), stabilityMinClamp, maxIntervalDays.toDouble());
  }

  // ── the review transition ───────────────────────────────────────────────────

  /// Return the card's next memory state after [rating] at time [now].
  MemoryState review(MemoryState card, int rating, DateTime now) {
    var elapsedDays = 0.0;
    if (card.lastReview != null) {
      // Mirrors Python's timedelta.total_seconds()/86400 (µs → s, then days).
      elapsedDays = math.max(
          0.0, now.difference(card.lastReview!).inMicroseconds / 1e6 / 86400.0);
    }

    final firstReview = card.stability == null || card.difficulty == null;
    double stability;
    double difficulty;
    if (firstReview) {
      stability = _initialStability(rating);
      difficulty = _initialDifficulty(rating);
    } else {
      final r = retrievability(elapsedDays, card.stability!);
      difficulty = _nextDifficulty(card.difficulty!, rating);
      if (elapsedDays < 1.0) {
        stability = _shortTermStability(card.stability!, rating);
      } else if (rating == ratingAgain) {
        stability = _nextForgetStability(difficulty, card.stability!, r);
      } else {
        stability = _nextRecallStability(difficulty, card.stability!, r, rating);
      }
    }

    final (state, step, interval) = _schedule(card, rating, stability);

    return MemoryState(
      state: state,
      step: step,
      stability: stability,
      difficulty: difficulty,
      due: now.add(interval),
      lastReview: now,
    );
  }

  /// Decide the next (state, step, due-interval) using the step machine.
  (int, int?, Duration) _schedule(MemoryState card, int rating, double stability) {
    final curState = card.state != stateNew ? card.state : stateLearning;
    final step = card.step ?? 0;

    if (curState == stateLearning || curState == stateNew) {
      return _stepThrough(learningSteps, step, rating, stability, learning: true);
    }
    if (curState == stateRelearning) {
      return _stepThrough(relearningSteps, step, rating, stability, learning: false);
    }

    // REVIEW state
    if (rating == ratingAgain && relearningSteps.isNotEmpty) {
      return (stateRelearning, 0, relearningSteps[0]);
    }
    return (stateReview, null, Duration(days: intervalDays(stability)));
  }

  /// Learning/relearning step progression (mirrors py-fsrs).
  (int, int?, Duration) _stepThrough(
    List<Duration> steps,
    int step,
    int rating,
    double stability, {
    required bool learning,
  }) {
    if (steps.isEmpty) {
      return (stateReview, null, Duration(days: intervalDays(stability)));
    }

    final state = learning ? stateLearning : stateRelearning;
    if (rating == ratingAgain) {
      return (state, 0, steps[0]);
    }
    if (rating == ratingHard) {
      if (step == 0 && steps.length == 1) return (state, 0, steps[0] * 1.5);
      if (step == 0 && steps.length >= 2) return (state, 0, (steps[0] + steps[1]) ~/ 2);
      return (state, step, steps[math.min(step, steps.length - 1)]);
    }
    if (rating == ratingGood) {
      if (step + 1 >= steps.length) {
        return (stateReview, null, Duration(days: intervalDays(stability)));
      }
      return (state, step + 1, steps[step + 1]);
    }
    // EASY graduates immediately
    return (stateReview, null, Duration(days: intervalDays(stability)));
  }
}
