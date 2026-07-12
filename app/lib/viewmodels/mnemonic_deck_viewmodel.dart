import '../models/mnemonic.dart';
import '../models/mnemonic_deck.dart';
import '../repositories/dictionary_repository.dart';
import '../repositories/mnemonic_deck_repository.dart';
import '../repositories/mnemonic_repository.dart';
import 'base_view_model.dart';

/// Browse the community packs (or the signed-in user's own), with liking.
class CommunityDecksViewModel extends BaseViewModel {
  CommunityDecksViewModel(this._repo, {this.language, this.mine = false});
  final MnemonicDeckRepository _repo;
  final String? language;
  final bool mine;

  List<MnemonicDeck> _decks = [];
  List<MnemonicDeck> get decks => _decks;

  Future<void> load() async {
    final r =
        await runGuarded(() => _repo.list(language: language, mine: mine));
    if (r != null) _decks = r;
  }

  /// Optimistic like toggle (public decks only).
  Future<void> like(MnemonicDeck d) async {
    final target = d.liked ? 0 : 1;
    final res = await runGuarded(() => _repo.vote(d.id, target), silent: true);
    if (res != null) {
      final (score, myVote) = res;
      _decks = _decks
          .map((e) =>
              e.id == d.id ? e.copyWith(score: score, myVote: myVote) : e)
          .toList();
      notifyListeners();
    }
  }
}

/// One community pack: its ordered mnemonics, plus like / enroll / publish.
class DeckDetailViewModel extends BaseViewModel {
  DeckDetailViewModel(this._repo, this.deckId);
  final MnemonicDeckRepository _repo;
  final int deckId;

  MnemonicDeck? _deck;
  MnemonicDeck? get deck => _deck;

  bool _enrolled = false;
  bool get enrolled => _enrolled;

  Future<void> load() async {
    final r = await runGuarded(() => _repo.detail(deckId));
    if (r != null) _deck = r;
  }

  Future<void> like() async {
    final d = _deck;
    if (d == null) return;
    final target = d.liked ? 0 : 1;
    final res = await runGuarded(() => _repo.vote(d.id, target), silent: true);
    if (res != null) {
      final (score, myVote) = res;
      _deck = d.copyWith(score: score, myVote: myVote);
      notifyListeners();
    }
  }

  Future<int> enroll() async {
    final n = await runGuarded(() => _repo.enroll(deckId), silent: true);
    if (n != null) {
      _enrolled = true;
      notifyListeners();
      return n;
    }
    return 0;
  }

  /// Publish a draft; returns the new status or null on failure.
  Future<String?> publish() async {
    final status = await runGuarded(() => _repo.publish(deckId), silent: true);
    if (status != null && _deck != null) {
      _deck = _deck!.copyWith(status: status);
      notifyListeners();
    }
    return status;
  }
}

/// Assemble a pack from the user's own drawings, then create / publish it.
class DeckBuilderViewModel extends BaseViewModel {
  DeckBuilderViewModel(
    this._decks,
    this._mnemonics, {
    required this.language,
    DictionaryRepository? dictionary,
  }) : _dictionary = dictionary;
  final MnemonicDeckRepository _decks;
  final MnemonicRepository _mnemonics;
  final DictionaryRepository? _dictionary;
  final String language;

  String kind = 'kana';
  String kanaScriptFilter = 'both';
  String jlptFilter = 'all';
  List<Mnemonic> _available = [];
  List<Mnemonic> _filtered =
      const []; // cached: own drawings of the current kind
  final List<int> _selected = []; // ordered selection
  final Map<int, Set<String>> _jlptCharacters = {};
  bool _jlptLoading = false;

  /// The user's own drawings matching the current kind (image-bearing first).
  List<Mnemonic> get available => _filtered;

  List<int> get selected => _selected;
  int get selectedCount => _selected.length;
  bool isSelected(int id) => _selected.contains(id);
  bool get isJlptLoading => _jlptLoading;
  bool get allVisibleSelected =>
      _filtered.isNotEmpty && _filtered.every((m) => _selected.contains(m.id));

  Future<void> load() async {
    final r = await runGuarded(() => _mnemonics.mine());
    if (r != null) {
      _available = r;
      _recomputeFiltered();
    }
  }

  void setKind(String k) {
    if (kind == k) return;
    kind = k;
    jlptFilter = 'all';
    _selected.clear();
    _recomputeFiltered();
    notifyListeners();
  }

  /// Uses the dictionary's canonical JLPT metadata rather than a hand-written
  /// character list. The first choice loads one compact set, then subsequent
  /// changes are instant and work offline from the dictionary pack.
  void setJlptFilter(String filter) {
    if (kind != 'kanji' || jlptFilter == filter) return;
    jlptFilter = filter;
    _selected.clear();
    if (filter == 'all' || _jlptCharacters.containsKey(int.tryParse(filter))) {
      _recomputeFiltered();
      notifyListeners();
      return;
    }
    _jlptLoading = true;
    _filtered = const [];
    notifyListeners();
    _loadJlpt(int.parse(filter));
  }

  Future<void> _loadJlpt(int level) async {
    try {
      final dictionary = _dictionary;
      if (dictionary == null) return;
      final entries = await dictionary.kanjiList(jlpt: level, limit: 1500);
      _jlptCharacters[level] = entries.map((entry) => entry.literal).toSet();
      _recomputeFiltered();
    } catch (error) {
      setError('Unable to load JLPT N$level right now.');
      _filtered = const [];
    } finally {
      _jlptLoading = false;
      notifyListeners();
    }
  }

  void setKanaScriptFilter(String filter) {
    if (kanaScriptFilter == filter) return;
    kanaScriptFilter = filter;
    _selected.clear();
    _recomputeFiltered();
    notifyListeners();
  }

  void _recomputeFiltered() {
    _filtered = _available.where((m) {
      if (m.kind != kind) return false;
      if (kind != 'kana' || kanaScriptFilter == 'both') return true;
      final rune = m.character.runes.isEmpty ? null : m.character.runes.first;
      if (rune == null) return false;
      final hiragana = rune >= 0x3040 && rune <= 0x309f;
      return kanaScriptFilter == 'hiragana' ? hiragana : !hiragana;
    }).where((m) {
      if (kind != 'kanji' || jlptFilter == 'all') return true;
      return _jlptCharacters[int.parse(jlptFilter)]?.contains(m.character) ??
          false;
    }).toList()
      ..sort((a, b) => (b.hasImage ? 1 : 0).compareTo(a.hasImage ? 1 : 0));
  }

  void toggle(int id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    notifyListeners();
  }

  /// Select or clear the current filtered set in one deliberate action.
  /// Keeping this on the view model makes the "some / all" affordance work
  /// identically on phone and tablet without walking the grid from the UI.
  void toggleAllVisible() {
    if (allVisibleSelected) {
      _selected.removeWhere((id) => _filtered.any((m) => m.id == id));
    } else {
      for (final mnemonic in _filtered) {
        if (!_selected.contains(mnemonic.id)) _selected.add(mnemonic.id);
      }
    }
    notifyListeners();
  }

  Future<MnemonicDeck?> create({
    required String title,
    String description = '',
    required bool publish,
  }) {
    return runGuarded(() => _decks.create(
          title: title,
          description: description,
          language: language,
          kind: kind,
          mnemonicIds: _selected,
          publish: publish,
        ));
  }
}
