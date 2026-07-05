import '../models/enums.dart';
import '../models/study.dart';
import '../repositories/study_repository.dart';
import 'base_view_model.dart';

/// Drives one study session (swipe or quiz) over a queue, the global due queue
/// or a specific deck. Server is authoritative for scheduling; this only walks
/// the session and submits ratings.
class ReviewViewModel extends BaseViewModel {
  ReviewViewModel(this._study, {this.deckId});
  final StudyRepository _study;
  final String? deckId;

  final List<StudyCard> _queue = [];
  final Set<int> _seen = {}; // every card id pulled into this session (dedup)
  int _index = 0;
  bool _answerShown = false;
  int _reviewed = 0;
  int _startedMs = 0;
  bool _moreNewLikely = false; // the pool has new cards we haven't loaded yet
  bool _loadingMore = false;

  int get index => _index;
  int get reviewed => _reviewed;
  int get total => _queue.length;
  bool get answerShown => _answerShown;
  bool get finished => _queue.isEmpty || _index >= _queue.length;
  StudyCard? get current => finished ? null : _queue[_index];
  StudyCard? get next => (_index + 1 < _queue.length) ? _queue[_index + 1] : null;
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
      _answerShown = false;
      _moreNewLikely = q.newCards.length < q.newAvailable;
      _startCard();
    }
  }

  /// Pull the rest of the new-card pool and append whatever hasn't been seen yet,
  /// resuming the session in place. Robust to reviews mutating the new set: we
  /// request the whole remaining pool and dedup by id rather than paging.
  Future<void> studyMore() async {
    if (_loadingMore) return;
    _loadingMore = true;
    notifyListeners();
    const all = 100000; // server clamps to its payload cap
    final q = await runGuarded(
      () => deckId == null ? _study.queue(newLimit: all) : _study.deckQueue(deckId!, newLimit: all),
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
      if (added > 0) _startCard();
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
    if (card == null) return;
    final elapsed = _nowMs() - _startedMs;
    await runGuarded(() => _study.review(card.id, rating, durationMs: elapsed), silent: true);
    _reviewed += 1;
    _index += 1;
    _answerShown = false;
    _startCard();
    notifyListeners();
  }

  void _startCard() => _startedMs = _nowMs();
  int _nowMs() => DateTime.now().millisecondsSinceEpoch;
}
