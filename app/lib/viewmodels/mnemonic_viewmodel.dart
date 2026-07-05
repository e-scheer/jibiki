import '../models/enums.dart';
import '../models/mnemonic.dart';
import '../repositories/mnemonic_repository.dart';
import '../repositories/study_repository.dart';
import 'base_view_model.dart';

/// Character-centric: the ranked, language-segmented mnemonics for one kana/kanji,
/// plus voting, reporting, contributing, and adding the character itself to study.
class MnemonicViewModel extends BaseViewModel {
  MnemonicViewModel(
    this._mnemonics,
    this._study, {
    required this.character,
    required this.kind,
    required this.language,
  });

  final MnemonicRepository _mnemonics;
  final StudyRepository _study;
  final String character;
  final String kind; // 'kana' | 'kanji'
  final String language;

  List<Mnemonic> _items = [];
  List<Mnemonic> get items => _items;

  bool _added = false;
  bool get added => _added;

  Future<void> load() async {
    final r = await runGuarded(
      () => _mnemonics.list(character: character, language: language, kind: kind),
    );
    if (r != null) _items = r;
  }

  void _replace(Mnemonic updated) {
    // In place, no re-sort, so a liked post doesn't jump under the user's finger.
    _items = [for (final e in _items) e.id == updated.id ? updated : e];
    notifyListeners();
  }

  /// Optimistic like: the heart fills + the count moves the instant you tap, then
  /// the server's authoritative numbers reconcile (or we revert on failure).
  Future<void> vote(Mnemonic m, int direction) async {
    final target = m.myVote == direction ? 0 : direction;
    final prev = m;
    _replace(m.copyWith(myVote: target, score: m.score + (target - m.myVote)));

    final res = await runGuarded(() => _mnemonics.vote(m.id, target), silent: true);
    if (res != null) {
      final (score, myVote) = res;
      _replace(prev.copyWith(score: score, myVote: myVote));
    } else {
      _replace(prev); // network/validation failed: undo the optimistic change
    }
  }

  Future<void> report(Mnemonic m, String reason, {String detail = ''}) async {
    await runGuarded(() => _mnemonics.report(m.id, reason, detail: detail), silent: true);
  }

  /// Optimistic bookmark: flips the instant you tap, reconciles / reverts after.
  Future<void> toggleSave(Mnemonic m) async {
    final prev = m;
    _replace(m.copyWith(saved: !m.saved));

    final res = await runGuarded(() => _mnemonics.save(m.id), silent: true);
    if (res != null) {
      _replace(prev.copyWith(saved: res));
    } else {
      _replace(prev);
    }
  }

  /// Submit a new mnemonic. Returns the created one (VISIBLE or PENDING) or null.
  Future<Mnemonic?> contribute(String story, {List<int>? imageBytes, String? imageFilename}) async {
    final m = await runGuarded(
      () => _mnemonics.create(
        character: character,
        kind: kind,
        language: language,
        story: story,
        imageBytes: imageBytes,
        imageFilename: imageFilename,
      ),
    );
    if (m != null && m.status == 'visible') {
      _items = [..._items, m]..sort((a, b) => b.score.compareTo(a.score));
      notifyListeners();
    }
    return m;
  }

  Future<bool> addToStudy() async {
    final type = kind == 'kanji' ? ItemType.kanji : ItemType.kana;
    await runGuarded(() => _study.addCard(type, character), silent: true);
    if (!hasError) {
      _added = true;
      notifyListeners();
    }
    return !hasError;
  }
}
