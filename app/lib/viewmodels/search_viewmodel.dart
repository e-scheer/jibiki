import 'dart:async';

import '../models/word.dart';
import '../repositories/dictionary_repository.dart';
import 'base_view_model.dart';

class SearchViewModel extends BaseViewModel {
  SearchViewModel(this._repo, {required this.glossLanguage});
  final DictionaryRepository _repo;
  final String glossLanguage;

  List<WordEntry> _results = [];
  List<WordEntry> get results => _results;

  List<NameItem> _names = [];
  List<NameItem> get names => _names;

  String _query = '';
  String get query => _query;
  bool get hasSearched => _query.trim().isNotEmpty;

  Timer? _debounce;

  /// Debounced search-as-you-type. The view calls this on every keystroke.
  void onQueryChanged(String q) {
    _query = q;
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      _results = [];
      _names = [];
      notifyListeners();
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
