import '../models/deck.dart';
import '../models/enums.dart';
import '../models/study.dart';
import 'study_service.dart';

/// The study surface behind StudyRepository - implemented by StudyService
/// (HTTP, web) and LocalStudyStore (offline-first, mobile). Anki export and
/// FSRS optimization are inherently server-side and stay on StudyService.
abstract class StudyStore {
  Future<StudyQueue> queue({int? newLimit});
  Future<StudyStats> stats();
  Future<StudyCard> addCard(
    ItemType type,
    String ref, {
    String sourceSentence = '',
    String sourceUrl = '',
    String sourceTitle = '',
    String sourceMedia = '',
  });
  Future<String> setStatus(ItemType type, String ref, String status);
  Future<Map<String, dynamic>> bulkAdd(
    List<({ItemType type, String ref})> items, {
    bool known = false,
  });
  Future<Map<String, int>> states({ItemType? type});
  Future<StudyCard> review(int cardId, Rating rating, {int durationMs = 0});
  Future<List<StudyCard>> cards({ItemType? type});
  Future<void> deleteCard(int id);
  Future<List<Deck>> decks();
  Future<Deck> enrollDeck(String id);
  Future<StudyQueue> deckQueue(String id, {int? newLimit});
  Future<bool> setFavorite(int cardId, bool value);
}
