import 'dart:async';

import '../core/telemetry.dart';
import '../models/enums.dart';
import '../models/kanji.dart';
import '../models/word.dart';
import '../repositories/dictionary_repository.dart';
import '../repositories/study_repository.dart';
import 'base_view_model.dart';

class KanjiDetailViewModel extends BaseViewModel {
  KanjiDetailViewModel(
    this._dict,
    this._study,
    this.literal, {
    required bool loadStudyState,
    TelemetrySink? telemetry,
  })  : _loadStudyState = loadStudyState,
        _telemetry = telemetry ?? Telemetry.instance;
  final DictionaryRepository _dict;
  final StudyRepository _study;
  final bool _loadStudyState;
  final TelemetrySink _telemetry;
  final String literal;

  KanjiEntry? _kanji;
  KanjiEntry? get kanji => _kanji;

  // Parse the kanji's associated words once (the detail view rebuilds on every
  // notify, parsing this JSON in build() would re-run each time).
  List<WordEntry>? _words;
  List<WordEntry> get words {
    final k = _kanji;
    if (k == null) return const [];
    return _words ??= k.words
        .map((e) => WordEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // none | learning | known - drives the detail Study / I-know-it toggles.
  String _status = 'none';
  String get status => _status;

  Future<void> load() async {
    final k = await runGuarded(() => _dict.kanji(literal));
    if (k != null) {
      _kanji = k;
      _words = null; // invalidate cache for the new kanji
    }
    if (_loadStudyState && k != null) {
      final states = await runGuarded(
        () => _study.studyStates(type: ItemType.kanji),
        silent: true,
      );
      if (states != null) {
        final s = states[literal];
        _status = s == null ? 'none' : (s >= 2 ? 'known' : 'learning');
        notifyListeners();
      }
    }
  }

  /// Toggle this kanji to [target] (none | learning | known); optimistic, then
  /// reconciles with the server (or reverts on failure).
  Future<void> setStatus(String target) async {
    final prev = _status;
    _status = target;
    notifyListeners();
    final res = await runGuarded(
        () => _study.setStatus(ItemType.kanji, literal, target),
        silent: true);
    _status = res ?? prev;
    if (res != null && prev == 'none' && res != 'none') {
      unawaited(_telemetry.logEvent(
        TelemetryEvent.studyCardAdded,
        parameters: {
          'item_type': ItemType.kanji.wire,
          'card_state': res,
          'source': 'detail_status',
        },
      ));
    } else if (res == 'none' && prev != 'none') {
      unawaited(_telemetry.logEvent(
        TelemetryEvent.studyCardRemoved,
        parameters: const {
          'item_type': 'kanji',
          'source': 'detail_status',
        },
      ));
    }
    notifyListeners();
  }
}
