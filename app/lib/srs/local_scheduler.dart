/// Local SRS scheduling on top of the pure FSRS port (fsrs.dart).
///
/// This is the client-side mirror of server/srs/services.py: FSRS gives the
/// pure memory-state transition; this layer folds in the card bookkeeping the
/// server adds around it (reps, lapses, scheduled_days). The review log stays
/// the source of truth - the server replays it to recompute canonical state on
/// sync, so this fold must match services.review_card exactly (locked by the
/// shared parity vectors, see test/srs/fsrs_parity_test.dart).
library;

import 'dart:math' as math;

import 'fsrs.dart';

/// A user study card, mutable local mirror of the server Card row.
/// `itemRef` is the word id (as string), kanji literal or kana char - the same
/// natural key the server enforces per (user, item).
class SrsCard {
  SrsCard({
    required this.itemType,
    required this.itemRef,
    this.state = stateNew,
    this.step,
    this.stability,
    this.difficulty,
    required this.due,
    this.lastReview,
    this.reps = 0,
    this.lapses = 0,
    this.favorite = false,
  });

  final String itemType; // word | kanji | kana
  final String itemRef;
  int state;
  int? step;
  double? stability;
  double? difficulty;
  DateTime due;
  DateTime? lastReview;
  int reps;
  int lapses;
  bool favorite;

  MemoryState toMemoryState() => MemoryState(
        state: state,
        step: step,
        stability: stability,
        difficulty: difficulty,
        due: due,
        lastReview: lastReview,
      );

  void applyMemoryState(MemoryState ms) {
    state = ms.state;
    step = ms.step;
    stability = ms.stability;
    difficulty = ms.difficulty;
    due = ms.due!;
    lastReview = ms.lastReview;
  }
}

/// What a review produced beyond the card mutation - the fields a ReviewLog
/// row (and the sync outbox) needs.
class ReviewOutcome {
  const ReviewOutcome({
    required this.stateBefore,
    required this.elapsedDays,
    required this.scheduledDays,
  });

  final int stateBefore;
  final double elapsedDays;
  final int scheduledDays;
}

/// Apply a rating to a card in place - the exact fold of services.review_card:
/// advance FSRS state, reps always increment, lapses only on Again from
/// review/relearning, scheduled_days floors the due delta.
ReviewOutcome applyReview(Fsrs scheduler, SrsCard card, int rating, DateTime now) {
  final before = card.toMemoryState();
  var elapsed = 0.0;
  if (before.lastReview != null) {
    elapsed = math.max(
        0.0, now.difference(before.lastReview!).inMicroseconds / 1e6 / 86400.0);
  }

  final after = scheduler.review(before, rating, now);

  final scheduledDays = math.max(0, after.due!.difference(now).inDays);
  final wasReviewOrRelearn =
      card.state == stateReview || card.state == stateRelearning;

  card.applyMemoryState(after);
  card.reps += 1;
  if (rating == ratingAgain && wasReviewOrRelearn) card.lapses += 1;

  return ReviewOutcome(
    stateBefore: before.state,
    elapsedDays: elapsed,
    scheduledDays: scheduledDays,
  );
}
