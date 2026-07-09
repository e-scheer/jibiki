import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/deck.dart';
import '../models/enums.dart';
import '../models/study.dart';
import 'study_store.dart';

class StudyQueue {
  StudyQueue({required this.due, required this.newCards, required this.counts});
  final List<StudyCard> due;
  final List<StudyCard> newCards;
  final Map<String, int> counts;

  /// The session order: due reviews first, then new cards.
  List<StudyCard> get session => [...due, ...newCards];

  /// Total new cards in the pool (regardless of the per-session batch), lets the
  /// client tell whether more new cards remain to be studied.
  int get newAvailable => counts['new_available'] ?? newCards.length;
}

class StudyService implements StudyStore {
  StudyService(this._api);
  final ApiClient _api;

  @override
  Future<StudyQueue> queue({int? newLimit}) async {
    final data = (await _api.get(ApiConfig.studyQueue, query: {if (newLimit != null) 'new_limit': newLimit})) as Map;
    List<StudyCard> parse(String key) => ((data[key] as List?) ?? const [])
        .map((e) => StudyCard.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return StudyQueue(
      due: parse('due'),
      newCards: parse('new'),
      counts: ((data['counts'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
    );
  }

  @override
  Future<StudyStats> stats() async {
    final data = (await _api.get(ApiConfig.studyStats)) as Map;
    return StudyStats.fromJson(data.cast<String, dynamic>());
  }

  @override
  Future<StudyCard> addCard(ItemType type, String ref) async {
    final data = await _api.post(ApiConfig.studyAdd, data: {'item_type': type.wire, 'ref': ref});
    return StudyCard.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Set one item's study status to exactly [status] (none | learning | known) -
  /// the detail-screen Study / I-know-it toggles. Returns the resulting status.
  @override
  Future<String> setStatus(ItemType type, String ref, String status) async {
    final data = await _api.post(
      ApiConfig.studySet,
      data: {'item_type': type.wire, 'ref': ref, 'status': status},
    );
    return (data as Map)['status'] as String? ?? status;
  }

  /// Add many items at once. [known] seeds them as already-known (mature) cards
  /// so they count as studied and stay out of the new-learning queue. Returns the
  /// server summary ({requested, resolved, created, known}).
  @override
  Future<Map<String, dynamic>> bulkAdd(
    List<({ItemType type, String ref})> items, {
    bool known = false,
  }) async {
    final data = await _api.post(ApiConfig.studyAddBulk, data: {
      'items': [for (final it in items) {'item_type': it.type.wire, 'ref': it.ref}],
      'known': known,
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// A compact {item_ref: state} map of the user's cards, so the dictionary can
  /// mark which items are already seen (state 0-1) or known (state >= 2).
  @override
  Future<Map<String, int>> states({ItemType? type}) async {
    final data = await _api.get(ApiConfig.studyStates, query: {if (type != null) 'item_type': type.wire});
    return (data as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
  }

  @override
  Future<StudyCard> review(int cardId, Rating rating, {int durationMs = 0}) async {
    final data = await _api.post(
      ApiConfig.studyCardReview(cardId),
      data: {'rating': rating.value, 'duration_ms': durationMs},
    );
    final card = (data as Map)['card'] as Map;
    return StudyCard.fromJson(card.cast<String, dynamic>());
  }

  @override
  Future<List<StudyCard>> cards({ItemType? type}) async {
    final data = await _api.get(ApiConfig.studyCards, query: {if (type != null) 'item_type': type.wire});
    return (data as List).map((e) => StudyCard.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  @override
  Future<void> deleteCard(int id) => _api.delete(ApiConfig.studyCard(id));

  /// Anki-importable TSV of the whole deck.
  Future<String> exportTsv() => _api.getText(ApiConfig.studyExport);

  Future<Map<String, dynamic>> optimizeStatus() async {
    final data = await _api.get(ApiConfig.studyOptimize);
    return (data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> runOptimize() async {
    final data = await _api.post(ApiConfig.studyOptimize);
    return (data as Map).cast<String, dynamic>();
  }

  @override
  Future<List<Deck>> decks() async {
    final data = await _api.get(ApiConfig.studyDecks);
    return (data as List).map((e) => Deck.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  @override
  Future<Deck> enrollDeck(String id) async {
    final data = await _api.post(ApiConfig.deckEnroll(id));
    return Deck.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<StudyQueue> deckQueue(String id, {int? newLimit}) async {
    final data =
        (await _api.get(ApiConfig.deckQueue(id), query: {if (newLimit != null) 'new_limit': newLimit})) as Map;
    List<StudyCard> parse(String key) => ((data[key] as List?) ?? const [])
        .map((e) => StudyCard.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return StudyQueue(
      due: parse('due'),
      newCards: parse('new'),
      counts: ((data['counts'] as Map?) ?? const {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
    );
  }

  @override
  Future<bool> setFavorite(int cardId, bool value) async {
    final data = await _api.post(ApiConfig.cardFavorite(cardId), data: {'value': value});
    return (data as Map)['favorite'] as bool? ?? value;
  }
}
