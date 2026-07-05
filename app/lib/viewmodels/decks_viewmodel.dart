import '../models/deck.dart';
import '../models/study.dart';
import '../repositories/study_repository.dart';
import 'base_view_model.dart';

class DecksViewModel extends BaseViewModel {
  DecksViewModel(this._study);
  final StudyRepository _study;

  List<Deck> _decks = [];
  List<Deck> get decks => _decks;

  StudyStats _stats = StudyStats.empty();
  StudyStats get stats => _stats;

  String? _busyDeck;
  String? get busyDeck => _busyDeck;

  Future<void> load() async {
    final decks = await runGuarded(() => _study.decks());
    if (decks != null) _decks = decks;
    final stats = await _study.stats().catchError((_) => StudyStats.empty());
    _stats = stats;
    notifyListeners();
  }

  /// Ensure the deck's cards exist, then return true so the caller can open it.
  Future<bool> enroll(Deck deck) async {
    if (deck.isFilter) return true; // filter decks study existing cards
    _busyDeck = deck.id;
    notifyListeners();
    final updated = await runGuarded(() => _study.enrollDeck(deck.id), silent: true);
    if (updated != null) {
      _decks = [
        for (final d in _decks)
          if (d.id == deck.id) updated else d
      ];
    }
    _busyDeck = null;
    notifyListeners();
    return updated != null;
  }
}
