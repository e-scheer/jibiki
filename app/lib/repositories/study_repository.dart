import 'dart:async';

import '../core/telemetry.dart';
import '../models/deck.dart';
import '../models/enums.dart';
import '../models/study.dart';
import '../services/study_service.dart';
import '../services/study_store.dart';

/// Study operations go through a [StudyStore] - the local offline-first store
/// on mobile, the HTTP service on web. Anki export and FSRS optimization are
/// server-side by nature and always use the HTTP service.
class StudyRepository {
  StudyRepository(
    this._store,
    this._remote, {
    TelemetrySink? telemetry,
  }) : _telemetry = telemetry ?? Telemetry.instance;

  final StudyStore _store;
  final StudyService _remote;
  final TelemetrySink _telemetry;

  Future<StudyQueue> queue({int? newLimit}) => _store.queue(newLimit: newLimit);
  Future<StudyStats> stats() => _store.stats();
  Future<StudyCard> addCard(
    ItemType type,
    String ref, {
    String sourceSentence = '',
    String sourceUrl = '',
    String sourceTitle = '',
    String sourceMedia = '',
  }) async {
    final card = await _store.addCard(
      type,
      ref,
      sourceSentence: sourceSentence,
      sourceUrl: sourceUrl,
      sourceTitle: sourceTitle,
      sourceMedia: sourceMedia,
    );
    unawaited(_telemetry.logEvent(
      TelemetryEvent.studyCardAdded,
      parameters: {
        'item_type': type.wire,
        'source': sourceSentence.isNotEmpty || sourceUrl.isNotEmpty
            ? 'capture'
            : 'detail',
      },
    ));
    return card;
  }

  Future<String> setStatus(ItemType type, String ref, String status) =>
      _store.setStatus(type, ref, status);
  Future<Map<String, dynamic>> bulkAdd(
      List<({ItemType type, String ref})> items,
      {bool known = false}) async {
    final result = await _store.bulkAdd(items, known: known);
    if (items.isNotEmpty) {
      unawaited(_telemetry.logEvent(
        TelemetryEvent.studyCardAdded,
        parameters: {
          'count': items.length,
          'card_state': known ? 'known' : 'learning',
          'source': 'bulk',
        },
      ));
    }
    return result;
  }

  Future<Map<String, int>> studyStates({ItemType? type}) =>
      _store.states(type: type);
  Future<StudyCard> review(int cardId, Rating rating, {int durationMs = 0}) =>
      _store.review(cardId, rating, durationMs: durationMs);
  Future<List<StudyCard>> cards({ItemType? type}) => _store.cards(type: type);
  Future<void> deleteCard(int id) async {
    await _store.deleteCard(id);
    unawaited(_telemetry.logEvent(
      TelemetryEvent.studyCardRemoved,
      parameters: const {'source': 'library'},
    ));
  }

  Future<String> exportTsv() => _remote.exportTsv();
  Future<Map<String, dynamic>> optimizeStatus() => _remote.optimizeStatus();
  Future<Map<String, dynamic>> runOptimize() => _remote.runOptimize();

  Future<List<Deck>> decks() => _store.decks();
  Future<Deck> enrollDeck(String id) async {
    final deck = await _store.enrollDeck(id);
    unawaited(_telemetry.logEvent(
      TelemetryEvent.deckEnrolled,
      parameters: {
        'deck_kind': deck.kind,
        'count': deck.enrolled,
        'source': 'study_catalog',
      },
    ));
    return deck;
  }

  Future<StudyQueue> deckQueue(String id, {int? newLimit}) =>
      _store.deckQueue(id, newLimit: newLimit);
  Future<bool> setFavorite(int cardId, bool value) =>
      _store.setFavorite(cardId, value);
}
