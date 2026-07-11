import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../models/deck.dart';
import '../../models/enums.dart';
import '../../models/study.dart';
import '../../services/study_service.dart';
import '../../services/study_store.dart';
import '../../srs/deck_catalog.dart';
import '../../srs/fsrs.dart';
import '../../srs/local_scheduler.dart';
import '../packs/pack_manager.dart';
import '../user_db_handle.dart';
import 'local_dictionary_data_source.dart';

class LocalStudyStore implements StudyStore {
  LocalStudyStore(
    this._user,
    this._packs,
    this._dictionary, {
    required void Function() onLocalMutation,
  }) : _onLocalMutation = onLocalMutation;

  final UserDbHandle _user;
  final PackManager _packs;
  final LocalDictionaryDataSource _dictionary;
  final void Function() _onLocalMutation;
  static const _uuid = Uuid();

  int get _now => DateTime.now().toUtc().millisecondsSinceEpoch;
  String _id() => _uuid.v4();

  @override
  Future<StudyCard> addCard(ItemType type, String ref) async {
    final now = _now;
    await _user.execute(
      'INSERT INTO cards (item_type, item_ref, state, due, created_at, updated_at, deleted) '
      'VALUES (?, ?, 0, ?, ?, ?, 0) ON CONFLICT(item_type, item_ref) DO UPDATE SET '
      'state = 0, step = NULL, stability = NULL, difficulty = NULL, due = excluded.due, '
      'last_review = NULL, reps = 0, lapses = 0, updated_at = excluded.updated_at, deleted = 0',
      [type.wire, ref, now, now, now],
    );
    await _op('bulk_add', {
      'items': [
        {'item_type': type.wire, 'ref': ref},
      ],
      'known': false,
    });
    return _card((await _row(type, ref))!);
  }

  @override
  Future<String> setStatus(ItemType type, String ref, String status) async {
    if (status == 'none') {
      await _user.execute(
        'DELETE FROM cards WHERE item_type = ? AND item_ref = ?',
        [type.wire, ref],
      );
    } else if (status == 'known') {
      await _upsert(type, ref, known: true);
    } else {
      await _upsert(type, ref, known: false);
    }
    await _op('set_status', {
      'item_type': type.wire,
      'ref': ref,
      'status': status,
    });
    return status;
  }

  Future<void> _upsert(ItemType type, String ref, {required bool known}) async {
    final now = _now;
    await _user.execute(
      'INSERT INTO cards (item_type, item_ref, state, stability, difficulty, due, reps, '
      'created_at, updated_at, deleted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0) '
      'ON CONFLICT(item_type, item_ref) DO UPDATE SET state = excluded.state, '
      'step = NULL, stability = excluded.stability, difficulty = excluded.difficulty, '
      'due = excluded.due, last_review = NULL, reps = excluded.reps, lapses = 0, '
      'updated_at = excluded.updated_at, deleted = 0',
      [
        type.wire,
        ref,
        known ? stateReview : stateNew,
        known ? 30.0 : null,
        known ? 5.0 : null,
        known ? now + const Duration(days: 30).inMilliseconds : now,
        known ? 1 : 0,
        now,
        now,
      ],
    );
  }

  @override
  Future<Map<String, dynamic>> bulkAdd(
    List<({ItemType type, String ref})> items, {
    bool known = false,
  }) async {
    for (final item in items) {
      await _upsert(item.type, item.ref, known: known);
    }
    await _op('bulk_add', {
      'items': [
        for (final item in items)
          {'item_type': item.type.wire, 'ref': item.ref},
      ],
      'known': known,
    });
    return {
      'requested': items.length,
      'resolved': items.length,
      'created': items.length,
      'known': known ? items.length : 0,
    };
  }

  @override
  Future<Map<String, int>> states({ItemType? type}) async {
    final rows = await _user.select(
      'SELECT item_ref, state FROM cards WHERE deleted = 0 '
      '${type == null ? '' : 'AND item_type = ?'}',
      [if (type != null) type.wire],
    );
    return {
      for (final row in rows) row['item_ref'] as String: row['state'] as int,
    };
  }

  @override
  Future<StudyQueue> queue({int? newLimit}) => _queue(newLimit: newLimit);

  Future<StudyQueue> _queue({int? newLimit, Set<String>? only}) async {
    await _packs.ensureReady();
    final now = _now;
    final profile = await _profile();
    final limit =
        newLimit ?? (profile['new_cards_per_day'] as num?)?.toInt() ?? 15;
    var rows = await _user.select(
      'SELECT rowid AS id, * FROM cards WHERE deleted = 0 '
      'ORDER BY state = 0, due, created_at',
    );
    if (only != null) {
      rows = rows
          .where(
            (row) => only.contains('${row['item_type']}:${row['item_ref']}'),
          )
          .toList();
    }
    final dueRows = rows
        .where((row) => row['state'] != 0 && (row['due'] as int) <= now)
        .toList();
    final newRows = rows.where((row) => row['state'] == 0).toList()
      ..sort((a, b) => _priority(a).compareTo(_priority(b)));
    final due = <StudyCard>[];
    final fresh = <StudyCard>[];
    for (final row in dueRows) {
      due.add(await _card(row));
    }
    for (final row in newRows.take(limit)) {
      fresh.add(await _card(row));
    }
    return StudyQueue(
      due: due,
      newCards: fresh,
      counts: {
        'due': dueRows.length,
        'new': fresh.length,
        'new_available': newRows.length,
      },
    );
  }

  int _priority(Map<String, Object?> row) => switch (row['item_type']) {
        'kanji' => 0,
        'kana' => 1,
        _ => 2,
      };

  @override
  Future<StudyCard> review(
    int cardId,
    Rating rating, {
    int durationMs = 0,
  }) async {
    final rows = await _user.select(
      'SELECT rowid AS id, * FROM cards WHERE rowid = ?',
      [cardId],
    );
    if (rows.isEmpty) throw StateError('Unknown card $cardId');
    final row = rows.single;
    final profile = await _profile();
    final parameters = (profile['fsrs_parameters'] as List?)
        ?.map((value) => (value as num).toDouble())
        .toList();
    final scheduler = Fsrs(
      parameters: parameters,
      desiredRetention:
          (profile['desired_retention'] as num?)?.toDouble() ?? 0.9,
    );
    final card = SrsCard(
      itemType: row['item_type'] as String,
      itemRef: row['item_ref'] as String,
      state: row['state'] as int,
      step: row['step'] as int?,
      stability: (row['stability'] as num?)?.toDouble(),
      difficulty: (row['difficulty'] as num?)?.toDouble(),
      due: DateTime.fromMillisecondsSinceEpoch(row['due'] as int, isUtc: true),
      lastReview: row['last_review'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              row['last_review'] as int,
              isUtc: true,
            ),
      reps: row['reps'] as int,
      lapses: row['lapses'] as int,
      favorite: row['favorite'] == 1,
    );
    final now = DateTime.now().toUtc();
    final outcome = applyReview(scheduler, card, rating.value, now);
    final reviewId = _id();
    await _user.tx([
      (
        'UPDATE cards SET stability = ?, difficulty = ?, state = ?, step = ?, due = ?, '
            'last_review = ?, reps = ?, lapses = ?, updated_at = ? WHERE rowid = ?',
        [
          card.stability,
          card.difficulty,
          card.state,
          card.step,
          card.due.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch,
          card.reps,
          card.lapses,
          now.millisecondsSinceEpoch,
          cardId,
        ],
      ),
      (
        'INSERT INTO review_log (client_review_id, item_type, item_ref, rating, '
            'state_before, duration_ms, reviewed_at, synced) VALUES (?, ?, ?, ?, ?, ?, ?, 0)',
        [
          reviewId,
          card.itemType,
          card.itemRef,
          rating.value,
          outcome.stateBefore,
          durationMs,
          now.millisecondsSinceEpoch,
        ],
      ),
    ]);
    _onLocalMutation();
    return _card(
      (await _row(ItemType.fromString(card.itemType), card.itemRef))!,
    );
  }

  @override
  Future<List<StudyCard>> cards({ItemType? type}) async {
    final rows = await _user.select(
      'SELECT rowid AS id, * FROM cards WHERE deleted = 0 '
      '${type == null ? '' : 'AND item_type = ?'} ORDER BY created_at',
      [if (type != null) type.wire],
    );
    return [for (final row in rows) await _card(row)];
  }

  @override
  Future<void> deleteCard(int id) async {
    final rows = await _user.select(
      'SELECT item_type, item_ref FROM cards WHERE rowid = ?',
      [id],
    );
    if (rows.isEmpty) return;
    await setStatus(
      ItemType.fromString(rows.single['item_type'] as String),
      rows.single['item_ref'] as String,
      'none',
    );
  }

  @override
  Future<StudyStats> stats() async {
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final rows = await _user.select(
      'SELECT count(*) AS total, '
      'sum(CASE WHEN state = 0 THEN 1 ELSE 0 END) AS new_count, '
      'sum(CASE WHEN state != 0 AND due <= ? THEN 1 ELSE 0 END) AS due_count '
      'FROM cards WHERE deleted = 0',
      [now.millisecondsSinceEpoch],
    );
    final reviews = await _user.select(
      'SELECT count(*) AS n FROM review_log WHERE reviewed_at >= ?',
      [start],
    );
    final states = await _user.select(
      'SELECT state, count(*) AS n FROM cards WHERE deleted = 0 GROUP BY state',
    );
    final byState = <String, int>{
      'new': 0,
      'learning': 0,
      'review': 0,
      'relearning': 0,
    };
    const names = ['new', 'learning', 'review', 'relearning'];
    for (final state in states) {
      byState[names[state['state'] as int]] = state['n'] as int;
    }
    return StudyStats(
      dueNow: rows.single['due_count'] as int? ?? 0,
      newRemaining: rows.single['new_count'] as int? ?? 0,
      reviewsToday: reviews.single['n'] as int,
      streak: reviews.single['n'] == 0 ? 0 : 1,
      totalCards: rows.single['total'] as int,
      byState: byState,
    );
  }

  @override
  Future<List<Deck>> decks() async {
    await _packs.ensureReady();
    final result = <Deck>[];
    for (final spec in deckCatalog) {
      final cardRows = await _user.select(
        'SELECT item_ref, state, due, favorite, lapses FROM cards WHERE deleted = 0 '
        '${spec.itemType == null ? '' : 'AND item_type = ?'}',
        [if (spec.itemType != null) spec.itemType!.wire],
      );
      int total;
      List<Map<String, Object?>> members;
      if (spec.id == 'favorites') {
        members = cardRows.where((row) => row['favorite'] == 1).toList();
        total = members.length;
      } else if (spec.id == 'struggling') {
        members = cardRows.where((row) => (row['lapses'] as int) > 0).toList();
        total = members.length;
      } else {
        total = await deckUniverseCount(_packs.db, spec);
        final refs = await deckMembership(_packs.db, spec, [
          for (final row in cardRows) row['item_ref'] as String,
        ]);
        members =
            cardRows.where((row) => refs.contains(row['item_ref'])).toList();
      }
      result.add(
        Deck(
          id: spec.id,
          title: spec.title,
          subtitle: spec.subtitle,
          icon: spec.icon,
          kind: spec.kind,
          total: total,
          enrolled: members.length,
          studied: members.where((row) => row['state'] != 0).length,
          due: members
              .where((row) => row['state'] != 0 && (row['due'] as int) <= _now)
              .length,
        ),
      );
    }
    return result;
  }

  @override
  Future<Deck> enrollDeck(String id) async {
    final spec = deckById(id);
    if (spec == null || spec.itemType == null) {
      throw StateError('Unknown content deck $id');
    }
    final refs = await deckUniverseRefs(_packs.db, spec);
    await bulkAdd([for (final ref in refs) (type: spec.itemType!, ref: ref)]);
    await _op('deck_enroll', {'deck_id': id});
    return (await decks()).firstWhere((deck) => deck.id == id);
  }

  @override
  Future<StudyQueue> deckQueue(String id, {int? newLimit}) async {
    final spec = deckById(id);
    if (spec == null) throw StateError('Unknown deck $id');
    Set<String> keys;
    if (spec.itemType == null) {
      final rows = await _user.select(
        'SELECT item_type, item_ref FROM cards WHERE deleted = 0 AND '
        '${id == 'favorites' ? 'favorite = 1' : 'lapses > 0'}',
      );
      keys = {for (final row in rows) '${row['item_type']}:${row['item_ref']}'};
    } else {
      final refs = await deckUniverseRefs(_packs.db, spec);
      keys = {for (final ref in refs) '${spec.itemType!.wire}:$ref'};
    }
    return _queue(newLimit: newLimit, only: keys);
  }

  @override
  Future<bool> setFavorite(int cardId, bool value) async {
    final rows = await _user.select(
      'SELECT item_type, item_ref FROM cards WHERE rowid = ?',
      [cardId],
    );
    if (rows.isEmpty) return false;
    await _user.execute(
      'UPDATE cards SET favorite = ?, updated_at = ? WHERE rowid = ?',
      [value ? 1 : 0, _now, cardId],
    );
    await _op('favorite', {
      'item_type': rows.single['item_type'],
      'ref': rows.single['item_ref'],
      'value': value,
    });
    return value;
  }

  Future<Map<String, Object?>?> _row(ItemType type, String ref) async {
    final rows = await _user.select(
      'SELECT rowid AS id, * FROM cards WHERE item_type = ? AND item_ref = ?',
      [type.wire, ref],
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<StudyCard> _card(Map<String, Object?> row) async {
    final type = ItemType.fromString(row['item_type'] as String);
    final ref = row['item_ref'] as String;
    return StudyCard(
      id: row['id'] as int,
      itemType: type,
      itemRef: ref,
      state: row['state'] as int,
      due: DateTime.fromMillisecondsSinceEpoch(row['due'] as int, isUtc: true),
      reps: row['reps'] as int,
      lapses: row['lapses'] as int,
      word:
          type == ItemType.word ? await _dictionary.word(int.parse(ref)) : null,
      kanji: type == ItemType.kanji ? await _dictionary.kanji(ref) : null,
      kana: type == ItemType.kana ? await _dictionary.kanaDetail(ref) : null,
      sourceSentence: row['source_sentence'] as String? ?? '',
      sourceUrl: row['source_url'] as String? ?? '',
      sourceTitle: row['source_title'] as String? ?? '',
      sourceMedia: row['source_media'] as String? ?? '',
    );
  }

  Future<Map<String, dynamic>> _profile() async {
    final rows = await _user.select('SELECT value FROM kv WHERE key = ?', [
      'profile',
    ]);
    return rows.isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(rows.single['value'] as String) as Map)
            .cast<String, dynamic>();
  }

  Future<void> _op(String kind, Map<String, dynamic> payload) async {
    await _user.execute(
      'INSERT INTO op_outbox (client_op_id, kind, payload, performed_at) VALUES (?, ?, ?, ?)',
      [_id(), kind, jsonEncode(payload), _now],
    );
    _onLocalMutation();
  }
}
