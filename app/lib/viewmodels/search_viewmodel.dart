import 'dart:async';

import '../models/word.dart';
import '../repositories/dictionary_repository.dart';
import '../services/recent_dictionary_history.dart';
import 'base_view_model.dart';

class SearchViewModel extends BaseViewModel {
  SearchViewModel(
    this._repo, {
    required this.glossLanguage,
    RecentDictionaryHistory? history,
  }) : _history = history ?? RecentDictionaryHistory();

  final DictionaryRepository _repo;
  final RecentDictionaryHistory _history;
  final String glossLanguage;

  List<WordEntry> _results = [];
  List<WordEntry> get results => _results;

  List<NameItem> _names = [];
  List<NameItem> get names => _names;

  String _query = '';
  String get query => _query;
  bool get hasSearched => _query.trim().isNotEmpty;

  WordEntry? _wordOfTheDay;
  WordEntry? get wordOfTheDay => _wordOfTheDay;

  List<RecentDictionaryWord> _recentWords = const [];
  List<RecentDictionaryWord> get recentWords => _recentWords;

  bool _landingLoading = true;
  bool get landingLoading => _landingLoading;

  Timer? _debounce;

  /// Loads the editorial home data independently from live search so a slow
  /// content pack never blocks typing or replaces search results with a loader.
  Future<void> loadLanding() async {
    _landingLoading = true;
    notifyListeners();
    try {
      final values = await Future.wait<Object>([
        _repo.words(common: true, limit: 24),
        _history.read(),
      ]);
      final common = values[0] as List<WordEntry>;
      final visits = values[1] as List<RecentWordVisit>;

      if (common.isNotEmpty) {
        final now = DateTime.now();
        final daySeed = now.year * 372 + now.month * 31 + now.day;
        _wordOfTheDay = common[daySeed % common.length];
      }

      final recent = <RecentDictionaryWord>[];
      for (final visit in visits.take(6)) {
        try {
          final word = await _repo.word(visit.wordId);
          recent
              .add(RecentDictionaryWord(word: word, viewedAt: visit.viewedAt));
          if (recent.length == 3) break;
        } catch (_) {
          // A content-pack update may remove an old id. Skip it quietly.
        }
      }
      _recentWords = recent;
    } catch (_) {
      // Home editorial content is optional. Search remains fully available.
    } finally {
      _landingLoading = false;
      notifyListeners();
    }
  }

  void rememberOpened(WordEntry word) {
    final now = DateTime.now();
    _recentWords = [
      RecentDictionaryWord(word: word, viewedAt: now),
      for (final recent in _recentWords)
        if (recent.word.id != word.id) recent,
    ].take(3).toList(growable: false);
    notifyListeners();
    unawaited(_history.remember(word.id, at: now));
  }

  /// Debounced search-as-you-type. The view calls this on every keystroke.
  void onQueryChanged(String q) {
    _query = q;
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      _results = [];
      _names = [];
      clearError();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () => _run(q));
  }

  Future<void> submit(String q) async {
    _query = q;
    _debounce?.cancel();
    await _run(q);
  }

  Future<void> _run(String q) async {
    if (q.trim().isEmpty) return;
    final r = await runGuarded(() => _repo.search(q, lang: glossLanguage));
    // Ignore a stale response whose query is no longer the current one.
    if (r != null && q == _query) {
      _results = r.words;
      _names = r.names;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

class RecentDictionaryWord {
  const RecentDictionaryWord({required this.word, required this.viewedAt});

  final WordEntry word;
  final DateTime viewedAt;
}
