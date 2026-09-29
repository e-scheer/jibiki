import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/study_calendar.dart';
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
  Future<void> _reviewTail = Future<void>.value();

  int get _now => DateTime.now().toUtc().millisecondsSinceEpoch;
  String _id() => _uuid.v4();

  @override
  Future<StudyCard> addCard(
    ItemType type,
    String ref, {
    String sourceSentence = '',
    String sourceUrl = '',
    String sourceTitle = '',
    String sourceMedia = '',
  }) async {
    final now = _now;
    await _commit(
        [
          (
            'INSERT INTO cards (item_type, item_ref, state, due, source_sentence, source_url, source_title, source_media, created_at, updated_at, deleted) '
                'VALUES (?, ?, 0, ?, ?, ?, ?, ?, ?, ?, 0) ON CONFLICT(item_type, item_ref) DO UPDATE SET '
                'source_sentence = CASE WHEN cards.source_sentence = \'\' THEN excluded.source_sentence ELSE cards.source_sentence END, source_url = CASE WHEN cards.source_url = \'\' THEN excluded.source_url ELSE cards.source_url END, source_title = CASE WHEN cards.source_title = \'\' THEN excluded.source_title ELSE cards.source_title END, source_media = CASE WHEN cards.source_media = \'\' THEN excluded.source_media ELSE cards.source_media END, updated_at = excluded.updated_at, deleted = 0',
            [
              type.wire,
              ref,
              now,
              sourceSentence,
              sourceUrl,
              sourceTitle,
              sourceMedia,
              now,
              now
            ],
          ),
        ],
        'bulk_add',
        {
          'items': [
            {'item_type': type.wire, 'ref': ref},
          ],
          'known': false,
          'source_sentence': sourceSentence,
          'source_url': sourceUrl,
          'source_title': sourceTitle,
          'source_media': sourceMedia,
        });
    return _card((await _row(type, ref))!);
  }

  @override
  Future<String> setStatus(ItemType type, String ref, String status) async {
    if (!{'none', 'known', 'learning'}.contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    final statements = <(String, List<Object?>)>[];
    if (status == 'none') {
      statements.add((
        'DELETE FROM cards WHERE item_type = ? AND item_ref = ?',
        [type.wire, ref],
      ));
    } else {
      statements.addAll(await _upsert(type, ref, known: status == 'known'));
      if (status == 'learning') {
        // Explicitly toggling Study demotes a mature card, while repeating
        // the action on a learning card preserves its step and history.
        statements.add((
          'UPDATE cards SET state = 0, due = ?, updated_at = ? '
              'WHERE item_type = ? AND item_ref = ? AND state IN (2, 3)',
          [_now, _now, type.wire, ref],
        ));
      }
    }
    await _commit(statements, 'set_status', {
      'item_type': type.wire,
      'ref': ref,
      'status': status,
    });
    return status;
  }

  Future<List<(String, List<Object?>)>> _upsert(ItemType type, String ref,
      {required bool known}) async {
    final now = _now;
    final statements = <(String, List<Object?>)>[
      (
        'INSERT INTO cards (item_type, item_ref, state, due, created_at, updated_at) '
            'VALUES (?, ?, 0, ?, ?, ?) ON CONFLICT(item_type, item_ref) DO NOTHING',
        [type.wire, ref, now, now, now],
      ),
    ];
    if (!known) return statements;
    final row = await _row(type, ref);
    if (row != null &&
        row['state'] != stateNew &&
        row['state'] != stateLearning) {
      return statements;
    }
    final at = DateTime.fromMillisecondsSinceEpoch(now, isUtc: true);
    final before =
        row == null ? MemoryState(due: at) : _srsCard(row).toMemoryState();
    final after = (await _scheduler()).review(before, ratingEasy, at);
    // Prior knowledge is an FSRS Easy seed, not a fabricated review. Preserve
    // existing reps/lapses and do not create a review log.
    statements.add((
      'UPDATE cards SET state = ?, step = ?, stability = ?, difficulty = ?, '
          'due = ?, last_review = ?, updated_at = ? '
          'WHERE item_type = ? AND item_ref = ? AND state IN (0, 1)',
      [
        after.state,
        after.step,
        after.stability,
        after.difficulty,
        after.due!.millisecondsSinceEpoch,
        after.lastReview?.millisecondsSinceEpoch,
        now,
        type.wire,
        ref
      ],
    ));
    return statements;
  }

  @override
  Future<Map<String, dynamic>> bulkAdd(
    List<({ItemType type, String ref})> items, {
    bool known = false,
  }) async {
    final statements = <(String, List<Object?>)>[];
    final unique = items.toSet();
    var created = 0;
    for (final item in unique) {
      if (await _row(item.type, item.ref) == null) created++;
      statements.addAll(await _upsert(item.type, item.ref, known: known));
    }
    await _commit(statements, 'bulk_add', {
      'items': [
        for (final item in items)
          {'item_type': item.type.wire, 'ref': item.ref},
      ],
      'known': known,
    });
    return {
      'requested': items.length,
      'resolved': items.length,
      'created': created,
      'known': known,
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
        (newLimit ?? (profile['new_cards_per_day'] as num?)?.toInt() ?? 15)
            .clamp(0, 500);
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
    String? clientReviewId,
  }) {
    final result = _reviewTail.then((_) => _review(cardId, rating,
        durationMs: durationMs, clientReviewId: clientReviewId));
    // Read/compute/write must be serialized as a unit, including retries.
    _reviewTail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<StudyCard> _review(int cardId, Rating rating,
      {required int durationMs, String? clientReviewId}) async {
    final rows = await _user.select(
      'SELECT rowid AS id, * FROM cards WHERE rowid = ?',
      [cardId],
    );
    if (rows.isEmpty) throw StateError('Unknown card $cardId');
    final row = rows.single;
    if (clientReviewId != null) {
      final existing = await _user.select(
        'SELECT seq FROM review_log WHERE client_review_id = ?',
        [clientReviewId],
      );
      if (existing.isNotEmpty) return _card(row);
    }
    final scheduler = await _scheduler();
    final card = _srsCard(row);
    final now = DateTime.now().toUtc();
    final outcome = applyReview(scheduler, card, rating.value, now);
    final reviewId = clientReviewId ?? _id();
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
          durationMs.clamp(0, 86400000),
          now.millisecondsSinceEpoch
        ],
      ),
    ]);
    _onLocalMutation();
    return _card(
      (await _row(ItemType.fromString(card.itemType), card.itemRef))!,
    );
  }

  SrsCard _srsCard(Map<String, Object?> row) => SrsCard(
        itemType: row['item_type'] as String,
        itemRef: row['item_ref'] as String,
        state: row['state'] as int,
        step: row['step'] as int?,
        stability: (row['stability'] as num?)?.toDouble(),
        difficulty: (row['difficulty'] as num?)?.toDouble(),
        due:
            DateTime.fromMillisecondsSinceEpoch(row['due'] as int, isUtc: true),
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
    final calendar = StudyCalendar((await _profile())['timezone'] as String?);
    final start = calendar.startOfDay(now).millisecondsSinceEpoch;
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
    final streak = await _streak(calendar, now);
    final reviewSummary = await _user.select(
      'SELECT count(*) AS total, '
      'sum(CASE WHEN rating >= 2 THEN 1 ELSE 0 END) AS correct, '
      'sum(duration_ms) AS duration, '
      'sum(CASE WHEN state_before = 2 THEN 1 ELSE 0 END) AS mature, '
      'sum(CASE WHEN state_before = 2 AND rating >= 2 THEN 1 ELSE 0 END) AS mature_correct '
      'FROM review_log',
    );
    final ratings = await _user.select(
      'SELECT rating, count(*) AS n FROM review_log GROUP BY rating',
    );
    final historyRows = await _user.select(
      'SELECT reviewed_at, rating FROM review_log WHERE reviewed_at >= ? ORDER BY reviewed_at',
      [calendar.startOfDay(now, offsetDays: -13).millisecondsSinceEpoch],
    );
    final history = <String, ({int reviews, int correct})>{};
    for (final row in historyRows) {
      final date = calendar
          .day(DateTime.fromMillisecondsSinceEpoch(
            row['reviewed_at'] as int,
            isUtc: true,
          ))
          .toIso8601String()
          .substring(0, 10);
      final previous = history[date] ?? (reviews: 0, correct: 0);
      history[date] = (
        reviews: previous.reviews + 1,
        correct: previous.correct + ((row['rating'] as int) >= 2 ? 1 : 0),
      );
    }
    final byTypeRows = await _user.select(
      'SELECT item_type, count(*) AS n FROM cards WHERE deleted = 0 GROUP BY item_type',
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
      streak: streak,
      totalCards: rows.single['total'] as int,
      byState: byState,
      totalReviews: reviewSummary.single['total'] as int? ?? 0,
      correctReviews: reviewSummary.single['correct'] as int? ?? 0,
      studyTimeMs: reviewSummary.single['duration'] as int? ?? 0,
      matureReviews: reviewSummary.single['mature'] as int? ?? 0,
      matureCorrectReviews: reviewSummary.single['mature_correct'] as int? ?? 0,
      reviewsByRating: {
        for (final row in ratings) '${row['rating']}': row['n'] as int,
      },
      cardsByType: {
        for (final row in byTypeRows) '${row['item_type']}': row['n'] as int,
      },
      history: [
        for (final entry in history.entries)
          StudyStatsDay(
            date: DateTime.parse(entry.key),
            reviews: entry.value.reviews,
            correct: entry.value.correct,
          ),
      ],
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
    await _packs.ensureReady();
    final spec = deckById(id);
    if (spec == null || spec.itemType == null) {
      throw StateError('Unknown content deck $id');
    }
    final refs = await deckUniverseRefs(_packs.db, spec);
    await bulkAdd([for (final ref in refs) (type: spec.itemType!, ref: ref)]);
    return (await decks()).firstWhere((deck) => deck.id == id);
  }

  @override
  Future<StudyQueue> deckQueue(String id, {int? newLimit}) async {
    await _packs.ensureReady();
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
    await _commit(
        [
          (
            'UPDATE cards SET favorite = ?, updated_at = ? WHERE rowid = ?',
            [value ? 1 : 0, _now, cardId],
          ),
        ],
        'favorite',
        {
          'item_type': rows.single['item_type'],
          'ref': rows.single['item_ref'],
          'value': value,
        });
    return value;
  }

  /// Consecutive account-calendar dates, using the same timezone as the server.
  Future<int> _streak(StudyCalendar calendar, DateTime now) async {
    final rows = await _user.select(
      'SELECT DISTINCT reviewed_at FROM review_log',
    );
    if (rows.isEmpty) return 0;
    final days = <DateTime>{};
    for (final row in rows) {
      final instant = DateTime.fromMillisecondsSinceEpoch(
        row['reviewed_at'] as int,
        isUtc: true,
      );
      days.add(calendar.day(instant));
    }
    var cursor = calendar.day(now);
    if (!days.contains(cursor)) {
      cursor = DateTime.utc(cursor.year, cursor.month, cursor.day - 1);
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak += 1;
      cursor = DateTime.utc(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
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

  Future<Fsrs> _scheduler() async {
    final profile = await _profile();
    final raw = profile['fsrs_parameters'];
    final weights = raw is List &&
            raw.length == 21 &&
            raw.every((v) => v is num && v.isFinite) &&
            (raw[20] as num) > 0
        ? raw.map((v) => (v as num).toDouble()).toList()
        : null;
    final retention = profile['desired_retention'];
    return Fsrs(
      parameters: weights,
      desiredRetention: retention is num &&
              retention.isFinite &&
              retention > 0 &&
              retention < 1
          ? retention.toDouble()
          : 0.9,
    );
  }

  Future<void> _commit(List<(String, List<Object?>)> statements, String kind,
      Map<String, dynamic> payload) async {
    await _user.tx([
      ...statements,
      (
        'INSERT INTO op_outbox (client_op_id, kind, payload, performed_at) VALUES (?, ?, ?, ?)',
        [_id(), kind, jsonEncode(payload), _now],
      ),
    ]);
    _onLocalMutation();
  }
}
