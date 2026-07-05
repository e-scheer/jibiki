import '../models/deck.dart';
import '../models/enums.dart';
import '../models/study.dart';
import '../services/study_service.dart';

class StudyRepository {
  StudyRepository(this._service);
  final StudyService _service;

  Future<StudyQueue> queue({int? newLimit}) => _service.queue(newLimit: newLimit);
  Future<StudyStats> stats() => _service.stats();
  Future<StudyCard> addCard(ItemType type, String ref) => _service.addCard(type, ref);
  Future<Map<String, dynamic>> bulkAdd(List<({ItemType type, String ref})> items, {bool known = false}) =>
      _service.bulkAdd(items, known: known);
  Future<Map<String, int>> studyStates({ItemType? type}) => _service.states(type: type);
  Future<StudyCard> review(int cardId, Rating rating, {int durationMs = 0}) =>
      _service.review(cardId, rating, durationMs: durationMs);
  Future<List<StudyCard>> cards({ItemType? type}) => _service.cards(type: type);
  Future<void> deleteCard(int id) => _service.deleteCard(id);

  Future<String> exportTsv() => _service.exportTsv();
  Future<Map<String, dynamic>> optimizeStatus() => _service.optimizeStatus();
  Future<Map<String, dynamic>> runOptimize() => _service.runOptimize();

  Future<List<Deck>> decks() => _service.decks();
  Future<Deck> enrollDeck(String id) => _service.enrollDeck(id);
  Future<StudyQueue> deckQueue(String id, {int? newLimit}) => _service.deckQueue(id, newLimit: newLimit);
  Future<bool> setFavorite(int cardId, bool value) => _service.setFavorite(cardId, value);
}
