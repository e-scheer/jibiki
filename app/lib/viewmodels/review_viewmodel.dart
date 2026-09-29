import 'dart:async';
import 'package:uuid/uuid.dart';

import '../core/telemetry.dart';
import '../models/enums.dart';
import '../models/study.dart';
import '../repositories/study_repository.dart';
import 'base_view_model.dart';

/// Drives one study session (swipe or quiz) over a queue, the global due queue
/// or a specific deck. A card advances only once its rating is persisted by the
/// study store (a local transaction on native platforms, the API on web).
class ReviewViewModel extends BaseViewModel {
  ReviewViewModel(this._study, {this.deckId});
  final StudyRepository _study;
  final String? deckId;

  final List<StudyCard> _queue = [];
  final Set<int> _seen = {}; // every card id pulled into this session (dedup)
  int _index = 0;
  bool _answerShown = false;
  int _reviewed = 0;
  final Stopwatch _cardTimer = Stopwatch();
  bool _moreNewLikely = false; // the pool has new cards we haven't loaded yet
  bool _loadingMore = false;
  bool _sessionCompletionLogged = false;
  bool _saving = false;
  final Map<int, ({String id, Rating rating, int duration})> _pendingRatings =
      {};

  int get index => _index;
  int get reviewed => _reviewed;
  int get total => _queue.length;
  bool get answerShown => _answerShown;
  bool get finished => _queue.isEmpty || _index >= _queue.length;
  StudyCard? get current => finished ? null : _queue[_index];
  StudyCard? get next =>
      (_index + 1 < _queue.length) ? _queue[_index + 1] : null;
  double get progress => _queue.isEmpty ? 0 : _index / _queue.length;

  /// Whether "Study more" can pull additional new cards, so the end-of-session
  /// screen offers to keep going instead of walling the user off.
  bool get hasMoreNew => _moreNewLikely;
  bool get loadingMore => _loadingMore;

  /// The full session, used to build distractors in quiz mode.
  List<StudyCard> get sessionCards => List.unmodifiable(_queue);

  Future<void> load() async {
    final q = await runGuarded(
      () => deckId == null ? _study.queue() : _study.deckQueue(deckId!),
    );
    if (q != null) {
      _queue
        ..clear()
        ..addAll(q.session);
      _seen
        ..clear()
        ..addAll(q.session.map((c) => c.id));
      _index = 0;
      _reviewed = 0;
      _sessionCompletionLogged = false;
      _answerShown = false;
      _moreNewLikely = q.newCards.length < q.newAvailable;
      _startCard();
      notifyListeners();
      unawaited(Telemetry.instance.logEvent(
        'study_session_started',
        parameters: {
          'source': deckId == null ? 'review_queue' : 'deck',
          'card_count': q.session.length,
          'new_count': q.newCards.length,
        },
      ));
    }
  }

  /// Pull the rest of the new-card pool and append whatever hasn't been seen yet,
  /// resuming the session in place. Robust to reviews mutating the new set: we
  /// request the whole remaining pool and dedup by id rather than paging.
  Future<void> studyMore() async {
    if (_loadingMore || _saving || isLoading || !finished) return;
    _loadingMore = true;
    notifyListeners();
    const all = 100000; // server clamps to its payload cap
    final q = await runGuarded(
      () => deckId == null
          ? _study.queue(newLimit: all)
          : _study.deckQueue(deckId!, newLimit: all),
      silent: true,
    );
    if (q != null) {
      var added = 0;
      for (final c in q.session) {
        if (_seen.add(c.id)) {
          _queue.add(c);
          added++;
        }
      }
      // Still more only if the payload was capped below the true pool size.
      _moreNewLikely = added > 0 && q.newCards.length < q.newAvailable;
      // _index already sits at the old length (the first appended card), so the
      // session simply resumes; just restart the per-card timer.
      if (added > 0) {
        _sessionCompletionLogged = false;
        _startCard();
      }
      unawaited(Telemetry.instance.logEvent(
        'study_more',
        parameters: {'added_count': added},
      ));
    }
    _loadingMore = false;
    notifyListeners();
  }

  void reveal() {
    _answerShown = true;
    notifyListeners();
  }

  Future<void> rate(Rating rating) async {
    final card = current;
    if (card == null || _saving || isLoading) return;
    final elapsed = _cardTimer.elapsedMilliseconds;
    _saving = true;
    await runGuarded(() async {
      await _persistRating(card, rating, elapsed);
      _reviewed += 1;
      _index += 1;
      _answerShown = false;
      _startCard();
      unawaited(Telemetry.instance.logEvent(
        'card_rated',
        parameters: {
          'item_type': card.itemType.wire,
          'rating': rating.name,
          'card_state': card.isNew ? 'new' : 'scheduled',
          'duration_bucket': _durationBucket(elapsed),
        },
      ));
      _logCompletionIfNeeded();
    });
    _saving = false;
  }

  /// Grade a whole batch at once and advance past it in a single step. The Match
  /// game plays a round over several cards, then reports them all together; done
  /// card-by-card it would move [current] mid-round and rebuild the board.
  Future<void> rateMany(List<StudyCard> cards, Rating rating) async {
    if (cards.isEmpty || _saving || isLoading) return;
    // Retry can include the successful prefix of a partially saved round.
    // Filter it out, then require the remaining cards to match the queue.
    final completed = _queue.take(_index).map((c) => c.id).toSet();
    final pending = cards.where((c) => !completed.contains(c.id)).toList();
    if (pending.isEmpty || _index + pending.length > _queue.length) return;
    for (var i = 0; i < pending.length; i++) {
      if (pending[i].id != _queue[_index + i].id) return;
    }
    final duration = (_cardTimer.elapsedMilliseconds / pending.length).round();
    _saving = true;
    await runGuarded(() async {
      for (final card in pending) {
        await _persistRating(card, rating, duration);
        _reviewed += 1;
        _index += 1;
      }
      _answerShown = false;
      _startCard();
      unawaited(Telemetry.instance.logEvent(
        'card_rated',
        parameters: {
          'item_type': 'mixed_batch',
          'rating': rating.name,
          'count': pending.length,
        },
      ));
      _logCompletionIfNeeded();
    });
    _saving = false;
  }

  void _startCard() => _cardTimer
    ..reset()
    ..start();

  Future<void> _persistRating(
      StudyCard card, Rating rating, int duration) async {
    // An HTTP error can arrive after the server committed. A retry must carry
    // the same event identity and contents so it cannot count twice.
    final pending = _pendingRatings.putIfAbsent(card.id,
        () => (id: const Uuid().v4(), rating: rating, duration: duration));
    await _study.review(card.id, pending.rating,
        durationMs: pending.duration, clientReviewId: pending.id);
    _pendingRatings.remove(card.id);
  }

  void _logCompletionIfNeeded() {
    if (!finished || _sessionCompletionLogged) return;
    _sessionCompletionLogged = true;
    unawaited(Telemetry.instance.logEvent(
      'study_session_completed',
      parameters: {
        'reviewed_count': _reviewed,
        'source': deckId == null ? 'review_queue' : 'deck',
      },
    ));
  }

  static String _durationBucket(int milliseconds) => switch (milliseconds) {
        < 2000 => 'under_2s',
        < 5000 => '2_5s',
        < 10000 => '5_10s',
        < 30000 => '10_30s',
        _ => '30s_plus',
      };
}
