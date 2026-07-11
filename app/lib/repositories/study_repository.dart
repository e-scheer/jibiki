import '../models/deck.dart';
import '../models/enums.dart';
import '../models/study.dart';
import '../services/study_service.dart';
import '../services/study_store.dart';

/// Study operations go through a [StudyStore] - the local offline-first store
/// on mobile, the HTTP service on web. Anki export and FSRS optimization are
/// server-side by nature and always use the HTTP service.
class StudyRepository {
  StudyRepository(this._store, this._remote);

  final StudyStore _store;
  final StudyService _remote;

  Future<StudyQueue> queue({int? newLimit}) => _store.queue(newLimit: newLimit);
  Future<StudyStats> stats() => _store.stats();
  Future<StudyCard> addCard(
    ItemType type,
    String ref, {
    String sourceSentence = '',
    String sourceUrl = '',
    String sourceTitle = '',
    String sourceMedia = '',
  }) =>
      _store.addCard(
        type,
        ref,
        sourceSentence: sourceSentence,
        sourceUrl: sourceUrl,
        sourceTitle: sourceTitle,
        sourceMedia: sourceMedia,
      );
  Future<String> setStatus(ItemType type, String ref, String status) =>
      _store.setStatus(type, ref, status);
  Future<Map<String, dynamic>> bulkAdd(
          List<({ItemType type, String ref})> items,
          {bool known = false}) =>
      _store.bulkAdd(items, known: known);
  Future<Map<String, int>> studyStates({ItemType? type}) =>
      _store.states(type: type);
  Future<StudyCard> review(int cardId, Rating rating, {int durationMs = 0}) =>
      _store.review(cardId, rating, durationMs: durationMs);
  Future<List<StudyCard>> cards({ItemType? type}) => _store.cards(type: type);
  Future<void> deleteCard(int id) => _store.deleteCard(id);

  Future<String> exportTsv() => _remote.exportTsv();
  Future<Map<String, dynamic>> optimizeStatus() => _remote.optimizeStatus();
  Future<Map<String, dynamic>> runOptimize() => _remote.runOptimize();

  Future<List<Deck>> decks() => _store.decks();
  Future<Deck> enrollDeck(String id) => _store.enrollDeck(id);
  Future<StudyQueue> deckQueue(String id, {int? newLimit}) =>
      _store.deckQueue(id, newLimit: newLimit);
  Future<bool> setFavorite(int cardId, bool value) =>
      _store.setFavorite(cardId, value);
}
