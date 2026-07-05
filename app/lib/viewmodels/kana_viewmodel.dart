import '../models/kana.dart';
import '../repositories/dictionary_repository.dart';
import 'base_view_model.dart';

/// The kana chart. Loads the full set once, then filters by script + groups the
/// gojūon into rows for the grid. The filtered list and per-kind grouping are
/// computed once on load/setScript and exposed as O(1) getters (the chart build
/// reads them many times per frame).
class KanaViewModel extends BaseViewModel {
  KanaViewModel(this._repo);
  final DictionaryRepository _repo;

  List<KanaEntry> _all = [];
  String _script = 'hiragana';
  String get script => _script;

  List<KanaEntry> _current = [];
  Map<String, List<KanaEntry>> _byKind = const {};

  List<KanaEntry> get current => _current;
  List<KanaEntry> byKind(String kind) => _byKind[kind] ?? const [];

  Future<void> load() async {
    final list = await runGuarded(() => _repo.kana());
    if (list != null) {
      _all = list;
      _recompute();
    }
  }

  void setScript(String s) {
    if (_script == s) return;
    _script = s;
    _recompute();
    notifyListeners();
  }

  void _recompute() {
    // 'both' keeps every script (the matrix pairs hiragana + katakana per cell).
    _current = (_script == 'both' ? _all.toList() : _all.where((k) => k.script == _script).toList())
      ..sort((a, b) => a.order.compareTo(b.order));
    final map = <String, List<KanaEntry>>{};
    for (final k in _current) {
      (map[k.kind] ??= <KanaEntry>[]).add(k);
    }
    _byKind = map;
  }
}
