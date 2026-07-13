import 'dart:async';

import '../core/telemetry.dart';
import '../models/mnemonic_deck.dart';
import '../services/mnemonic_deck_service.dart';

class MnemonicDeckRepository {
  MnemonicDeckRepository(this._service, {TelemetrySink? telemetry})
      : _telemetry = telemetry ?? Telemetry.instance;
  final MnemonicDeckService _service;
  final TelemetrySink _telemetry;

  Future<List<MnemonicDeck>> list(
          {String? language, String? kind, bool mine = false}) =>
      _service.list(language: language, kind: kind, mine: mine);

  Future<MnemonicDeck> detail(int id) => _service.detail(id);

  Future<MnemonicDeck> create({
    required String title,
    String description = '',
    required String language,
    required String kind,
    required List<int> mnemonicIds,
    bool publish = false,
  }) async {
    final deck = await _service.create(
      title: title,
      description: description,
      language: language,
      kind: kind,
      mnemonicIds: mnemonicIds,
      publish: publish,
    );
    if (publish) {
      unawaited(_telemetry.logEvent(
        TelemetryEvent.deckPublished,
        parameters: {
          'deck_kind': kind,
          'mnemonic_language': language,
          'count': mnemonicIds.length,
          'source': 'deck_builder',
        },
      ));
    }
    return deck;
  }

  Future<String> publish(int id) async {
    final status = await _service.publish(id);
    unawaited(_telemetry.logEvent(
      TelemetryEvent.deckPublished,
      parameters: {'status': status, 'source': 'deck_detail'},
    ));
    return status;
  }

  Future<(int, int)> vote(int id, int value) => _service.vote(id, value);
  Future<int> enroll(int id) async {
    final count = await _service.enroll(id);
    unawaited(_telemetry.logEvent(
      TelemetryEvent.deckEnrolled,
      parameters: {'count': count, 'source': 'community'},
    ));
    return count;
  }
}
