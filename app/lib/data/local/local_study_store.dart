/// Offline-first study: every StudyRepository operation served from the local
/// user DB, scheduled by the Dart FSRS port, with dictionary items joined in
/// from the content packs at read time (the server used to embed them).
///
/// Semantics mirror server/srs/services.py exactly - same queue shape
/// (per-session new batch + "Study more", never a daily wall), same
/// mark-known/set-status transitions, same review fold (locked by the shared
/// parity vectors). Every mutation lands in the outbox tables; the sync
/// engine replays them and the server re-derives canonical state from the
/// review log, so local scheduling can never lose data.
library;

import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/db/dict_db.dart';
import '../../core/japanese_text.dart';
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

const _uuid = Uuid();
const _dueLimit = 500; // one session never materializes more (server parity)

class LocalStudyStore implements StudyStore {
  LocalStudyStore(this._user, this._packs, this._dict, {this.onLocalMutation});

  final UserDbHandle _user;
  final PackManager _packs;
  final LocalDictionaryDataSource _dict;

  /// Poked after every local write - the sync engine debounces an upload.
  final void Function()? onLocalMutation;

  Future<DictDb> get _content => _packs.whenReady();

  DateTime _now() => DateTime.now().toUtc();
  int _ms(DateTime t) => t.millisecondsSinceEpoch;
  String _iso(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();

  // ── profile-driven scheduler ────────────────────────────────────────────────

  Future<Map<String, dynamic>> _profile() async {
    final rows =
        await _user.select('SELECT value FROM kv WHERE key = ?', ['profile']);
    if (rows.isEmpty) return const {};
    return (jsonDecode(rows.single['value'] as String) as Map)
        .cast<String, dynamic>();
  }

  Future<Fsrs> _scheduler() async {
    final profile = await _profile();
    final params = profile['fsrs_parameters'];
    final retention = (profile['desired_retention'] as num?)?.toDouble() ?? 0.9;
    if (params is List && params.length == 21) {
      return Fsrs(
        parameters: [for (final p in params) (p as num).toDouble()],
        desiredRetention: retention,
      );
    }
    return Fsrs(desiredRetention: retention);
  }

  Future<int> _newPerSession() async =>
      ((await _profile())['new_cards_per_day'] as num?)?.toInt() ?? 15;

  // ── card row helpers ────────────────────────────────────────────────────────

  static const _cardCols =
      'rowid AS rid, item_type, item_ref, server_id, stability, difficulty, '
      'state, step, due, last_review, reps, lapses, favorite, created_at, '
      'updated_at, deleted';

  SrsCard _toCard(Map<String, Object?> r) => SrsCard(
        itemType: r['item_type'] as String,
        itemRef: r['item_ref'] as String,
        state: r['state'] as int,
        step: r['step'] as int?,
        stability: (r['stability'] as num?)?.toDouble(),
        difficulty: (r['difficulty'] as num?)?.toDouble(),
        due: DateTime.fromMillisecondsSinceEpoch(r['due'] as int, isUtc: true),
        lastReview: r['last_review'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r['last_review'] as int,
                isUtc: true),
        reps: r['reps'] as int,
        lapses: r['lapses'] as int,
        favorite: r['favorite'] == 1,
      );

  /// Rows → StudyCards with their dictionary item joined from the packs.
  Future<List<StudyCard>> _assemble(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return const [];
    final db = await _content;
    final wordIds = <int>[];
    final kanjiLits = <String>[];
    final kanaChars = <String>[];
    for (final r in rows) {
      final ref = r['item_ref'] as String;
      switch (r['item_type']) {
        case 'word':
          wordIds.add(int.parse(ref));
        case 'kanji':
          kanjiLits.add(ref);
        default:
          kanaChars.add(ref);
      }
    }
    final wordMaps = {
      for (final m in await _dict.wordMapsByIds(db, wordIds)) '${m['id']}': m,
    };
    final kanjiMaps = {
      for (final m in await _dict.kanjiMapsByLiterals(db, kanjiLits))
        m['literal'] as String: m,
    };
    final kanaMaps = {
      for (final m in await _dict.kanaMapsByChars(db, kanaChars))
        m['char'] as String: m,
    };

    return [
      for (final r in rows)
        StudyCard.fromJson({
          'id': r['rid'],
          'item_type': r['item_type'],
          'item_ref': r['item_ref'],
          'state': r['state'],
          'due': _iso(r['due'] as int),
          'reps': r['reps'],
          'lapses': r['lapses'],
          'item': switch (r['item_type']) {
            'word' => wordMaps[r['item_ref']],
            'kanji' => kanjiMaps[r['item_ref']],
            _ => kanaMaps[r['item_ref']],
          },
        }),
    ];
  }

  Future<Map<String, Object?>?> _rowById(int rid) async {
    final rows = await _user
        .select('SELECT $_cardCols FROM cards WHERE rowid = ?', [rid]);
    return rows.isEmpty ? null : rows.single;
  }

  Future<Map<String, Object?>?> _rowByKey(String type, String ref) async {
    final rows = await _user.select(
      'SELECT $_cardCols FROM cards WHERE item_type = ? AND item_ref = ?',
      [type, ref],
    );
    return rows.isEmpty ? null : rows.single;
  }

  /// Does the item exist in the installed packs? Mirrors services.resolve_item
  /// - a card must point at a real dictionary row.
  Future<bool> _resolves(String type, String ref) async {
    final db = await _content;
    final rows = await switch (type) {
      'word' => int.tryParse(ref) == null
          ? Future.value(const <Map<String, Object?>>[])
          : db.select('SELECT 1 FROM words WHERE id = ?', [int.parse(ref)]),
      'kanji' => db.select('SELECT 1 FROM kanji WHERE literal = ?', [ref]),
      _ => db.select('SELECT 1 FROM kana WHERE char = ?', [ref]),
    };
    return rows.isNotEmpty;
  }

  List<(String, List<Object?>)> _upsertNew(
          String type, String ref, int nowMs) =>
      [
        (
          'INSERT INTO cards (item_type, item_ref, due, created_at, updated_at) '
              'VALUES (?, ?, ?, ?, ?) '
              'ON CONFLICT(item_type, item_ref) DO UPDATE SET '
              // Re-adding a locally-deleted card resurrects it as new.
              'deleted = 0, state = CASE WHEN cards.deleted = 1 THEN 0 ELSE cards.state END, '
              'updated_at = excluded.updated_at',
          [type, ref, nowMs, nowMs, nowMs],
        ),
      ];

  Future<void> _enqueueOp(String kind, Map<String, dynamic> payload) async {
    await _user.execute(
      'INSERT INTO op_outbox (client_op_id, kind, payload, performed_at) '
      'VALUES (?, ?, ?, ?)',
      [_uuid.v4(), kind, jsonEncode(payload), _ms(_now())],
    );
    onLocalMutation?.call();
  }

  // ── queue / session ─────────────────────────────────────────────────────────

  @override
  Future<StudyQueue> queue({int? newLimit}) => _buildQueue(null, newLimit);

  @override
  Future<StudyQueue> deckQueue(String id, {int? newLimit}) async {
    final spec = deckById(id);
    if (spec == null) throw StateError('unknown deck: $id');
    return _buildQueue(spec, newLimit);
  }

  Future<StudyQueue> _buildQueue(DeckSpec? spec, int? newLimit) async {
    final nowMs = _ms(_now());
    final perSession = await _newPerSession();
    final take = (newLimit ?? perSession).clamp(0, _dueLimit);

    var due = await _user.select(
      'SELECT $_cardCols FROM cards '
      'WHERE deleted = 0 AND state != 0 AND due <= ? ORDER BY due',
      [nowMs],
    );
    var newRows = await _user.select(
      'SELECT $_cardCols FROM cards '
      'WHERE deleted = 0 AND state = 0 ORDER BY created_at, rowid',
    );

    if (spec != null) {
      final member = await _deckFilter(spec, [...due, ...newRows]);
      due = [
        for (final r in due)
          if (member(r)) r
      ];
      newRows = [
        for (final r in newRows)
          if (member(r)) r
      ];
    }

    // Prerequisite-first ordering: within the batch we're about to surface,
    // a kanji's components lead the kanji, and a word's kanji lead the word,
    // so a new card always builds on something already seen (the WK/jpdb
    // effect, without their locked pace). Bounded to a window so a huge deck
    // doesn't pay an O(n) graph build every queue.
    newRows = await _prerequisiteOrder(newRows, take);

    final counts = {
      'due': due.length,
      'new_remaining': take,
      'new_available': newRows.length,
      'new_per_session': perSession,
    };
    return StudyQueue(
      due: await _assemble(due.take(_dueLimit).toList()),
      newCards: await _assemble(newRows.take(take).toList()),
      counts: counts,
    );
  }

  /// Reorder new-card rows so prerequisites lead their dependents (components
  /// → kanji → words). Operates on a bounded window (the surfaced batch plus a
  /// little headroom) so cost stays flat on huge decks; edges come from the
  /// content pack (`kanji_components`, and each word's kanji via its headword).
  /// Original enrollment order is the stable tiebreak, and a dependency cycle
  /// or a prerequisite outside the window can never drop a card.
  Future<List<Map<String, Object?>>> _prerequisiteOrder(
      List<Map<String, Object?>> rows, int take) async {
    final windowSize =
        rows.length < (take + 60) ? rows.length : (take + 60).clamp(0, 500);
    if (windowSize < 2) return rows;
    final window = rows.sublist(0, windowSize);
    final tail = rows.sublist(windowSize);

    String keyOf(Map<String, Object?> r) =>
        '${r['item_type']}:${r['item_ref']}';
    final inWindow = {for (final r in window) keyOf(r)};
    final kanjiLits = [
      for (final r in window)
        if (r['item_type'] == 'kanji') r['item_ref'] as String,
    ];
    final wordIds = [
      for (final r in window)
        if (r['item_type'] == 'word') int.parse(r['item_ref'] as String),
    ];
    if (kanjiLits.isEmpty && wordIds.isEmpty) {
      return rows; // kana only: nothing to order
    }

    final db = await _content;
    // prereqs[key] = keys that must come before it (only those also in-window).
    final prereqs = <String, Set<String>>{};

    if (kanjiLits.isNotEmpty) {
      final marks = List.filled(kanjiLits.length, '?').join(',');
      final comps = await db.select(
        'SELECT kanji, component FROM kanji_components WHERE kanji IN ($marks)',
        kanjiLits,
      );
      for (final c in comps) {
        final self = 'kanji:${c['kanji']}';
        final dep = 'kanji:${c['component']}';
        if (dep != self && inWindow.contains(dep)) {
          prereqs.putIfAbsent(self, () => {}).add(dep);
        }
      }
    }
    if (wordIds.isNotEmpty) {
      final marks = List.filled(wordIds.length, '?').join(',');
      final words = await db.select(
          'SELECT id, headword FROM words WHERE id IN ($marks)', wordIds);
      for (final w in words) {
        final self = 'word:${w['id']}';
        for (final lit in kanjiIn(w['headword'] as String? ?? '')) {
          final dep = 'kanji:$lit';
          if (inWindow.contains(dep)) {
            prereqs.putIfAbsent(self, () => {}).add(dep);
          }
        }
      }
    }
    if (prereqs.isEmpty) return rows; // no in-window dependencies

    // Kahn-style: repeatedly emit the earliest node whose prerequisites are all
    // placed; a cycle falls back to emitting the earliest remaining node.
    final placed = <String>{};
    final ordered = <Map<String, Object?>>[];
    final pending = [...window];
    while (pending.isNotEmpty) {
      var idx = pending.indexWhere(
          (r) => (prereqs[keyOf(r)] ?? const {}).every(placed.contains));
      if (idx < 0) idx = 0; // cycle: break by original order
      final row = pending.removeAt(idx);
      placed.add(keyOf(row));
      ordered.add(row);
    }
    return [...ordered, ...tail];
  }

  /// A predicate over card rows for deck membership (see deck_catalog.dart).
  Future<bool Function(Map<String, Object?>)> _deckFilter(
      DeckSpec spec, List<Map<String, Object?>> candidates) async {
    if (spec.id == 'favorites') return (r) => r['favorite'] == 1;
    if (spec.id == 'struggling') return (r) => (r['lapses'] as int) >= 1;
    final type = spec.itemType!.wire;
    final refs = [
      for (final r in candidates)
        if (r['item_type'] == type) r['item_ref'] as String,
    ];
    final members = await deckMembership(await _content, spec, refs);
    return (r) => r['item_type'] == type && members.contains(r['item_ref']);
  }

  // ── reviews ─────────────────────────────────────────────────────────────────

  @override
  Future<StudyCard> review(int cardId, Rating rating,
      {int durationMs = 0}) async {
    final row = await _rowById(cardId);
    if (row == null) throw StateError('card $cardId not found');
    final card = _toCard(row);
    final now = _now();
    final outcome = applyReview(await _scheduler(), card, rating.value, now);

    await _user.tx([
      (
        'UPDATE cards SET stability = ?, difficulty = ?, state = ?, step = ?, '
            'due = ?, last_review = ?, reps = ?, lapses = ?, updated_at = ? '
            'WHERE rowid = ?',
        [
          card.stability,
          card.difficulty,
          card.state,
          card.step,
          _ms(card.due),
          _ms(card.lastReview!),
          card.reps,
          card.lapses,
          _ms(now),
          cardId,
        ],
      ),
      (
        'INSERT INTO review_log (client_review_id, item_type, item_ref, rating, '
            'state_before, duration_ms, reviewed_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          _uuid.v4(),
          card.itemType,
          card.itemRef,
          rating.value,
          outcome.stateBefore,
          durationMs < 0 ? 0 : durationMs,
          _ms(now),
        ],
      ),
    ]);
    onLocalMutation?.call();

    final updated = await _rowById(cardId);
    return (await _assemble([updated!])).single;
  }

  // ── add / status ────────────────────────────────────────────────────────────

  @override
  Future<StudyCard> addCard(
    ItemType type,
    String ref, {
    String sourceSentence = '',
    String sourceUrl = '',
    String sourceTitle = '',
    String sourceMedia = '',
  }) async {
    if (!await _resolves(type.wire, ref)) {
      throw StateError('unknown study item: ${type.wire}:$ref');
    }
    await _user.tx(_upsertNew(type.wire, ref, _ms(_now())));
    await _enqueueOp('bulk_add', {
      'items': [
        {'item_type': type.wire, 'ref': ref},
      ],
      'source_sentence': sourceSentence,
      'source_url': sourceUrl,
      'source_title': sourceTitle,
      'source_media': sourceMedia,
    });
    final row = await _rowByKey(type.wire, ref);
    return (await _assemble([row!])).single;
  }

  @override
  Future<String> setStatus(ItemType type, String ref, String status) async {
    if (!await _resolves(type.wire, ref)) return 'none';
    final now = _now();
    if (status == 'none') {
      await _user.execute(
        'UPDATE cards SET deleted = 1, updated_at = ? WHERE item_type = ? AND item_ref = ?',
        [_ms(now), type.wire, ref],
      );
    } else if (status == 'known') {
      await _markKnown(type.wire, ref, now);
    } else {
      // learning: ensure the card sits in the new queue; demote a "known" card
      // back to new so toggling Study on is honest (services.set_status).
      await _user.tx(_upsertNew(type.wire, ref, _ms(now)));
      await _user.execute(
        'UPDATE cards SET state = 0, step = NULL, due = ?, updated_at = ? '
        'WHERE item_type = ? AND item_ref = ? AND state IN (2, 3)',
        [_ms(now), _ms(now), type.wire, ref],
      );
    }
    await _enqueueOp(
        'set_status', {'item_type': type.wire, 'ref': ref, 'status': status});
    return status;
  }

  /// services.mark_known: seed a mature REVIEW card via the initial-"Easy"
  /// transition - deliberately NO review_log row and no reps bump (the user is
  /// asserting prior knowledge, not reviewing; the optimizer must not be fed a
  /// synthetic rating). Never downgrades an established card.
  Future<void> _markKnown(String type, String ref, DateTime now) async {
    await _user.tx(_upsertNew(type, ref, _ms(now)));
    final row = await _rowByKey(type, ref);
    final card = _toCard(row!);
    if (card.state != stateNew && card.state != stateLearning) return;
    final after =
        (await _scheduler()).review(card.toMemoryState(), ratingEasy, now);
    await _user.execute(
      'UPDATE cards SET stability = ?, difficulty = ?, state = ?, step = ?, '
      'due = ?, last_review = ?, updated_at = ? WHERE rowid = ?',
      [
        after.stability,
        after.difficulty,
        after.state,
        after.step,
        _ms(after.due!),
        _ms(after.lastReview!),
        _ms(now),
        row['rid'],
      ],
    );
  }

  @override
  Future<Map<String, dynamic>> bulkAdd(
    List<({ItemType type, String ref})> items, {
    bool known = false,
  }) async {
    final now = _now();
    var resolved = 0;
    for (final it in items) {
      if (!await _resolves(it.type.wire, it.ref)) continue;
      resolved++;
      if (known) {
        await _markKnown(it.type.wire, it.ref, now);
      } else {
        await _user.tx(_upsertNew(it.type.wire, it.ref, _ms(now)));
      }
    }
    await _enqueueOp('bulk_add', {
      'items': [
        for (final it in items) {'item_type': it.type.wire, 'ref': it.ref},
      ],
      'known': known,
    });
    return {
      'requested': items.length,
      'resolved': resolved,
      'created': resolved,
      'known': known,
    };
  }

  @override
  Future<Map<String, int>> states({ItemType? type}) async {
    final rows = await _user.select(
      'SELECT item_ref, state FROM cards WHERE deleted = 0 '
      '${type != null ? 'AND item_type = ?' : ''}',
      [if (type != null) type.wire],
    );
    return {for (final r in rows) r['item_ref'] as String: r['state'] as int};
  }

  @override
  Future<List<StudyCard>> cards({ItemType? type}) async {
    final rows = await _user.select(
      'SELECT $_cardCols FROM cards WHERE deleted = 0 '
      '${type != null ? 'AND item_type = ?' : ''} ORDER BY due',
      [if (type != null) type.wire],
    );
    return _assemble(rows);
  }

  @override
  Future<void> deleteCard(int id) async {
    final row = await _rowById(id);
    if (row == null) return;
    await _user.execute(
      'UPDATE cards SET deleted = 1, updated_at = ? WHERE rowid = ?',
      [_ms(_now()), id],
    );
    await _enqueueOp('set_status', {
      'item_type': row['item_type'],
      'ref': row['item_ref'],
      'status': 'none',
    });
  }

  @override
  Future<bool> setFavorite(int cardId, bool value) async {
    final row = await _rowById(cardId);
    if (row == null) return value;
    await _user.execute(
      'UPDATE cards SET favorite = ?, updated_at = ? WHERE rowid = ?',
      [value ? 1 : 0, _ms(_now()), cardId],
    );
    await _enqueueOp('favorite', {
      'item_type': row['item_type'],
      'ref': row['item_ref'],
      'value': value,
    });
    return value;
  }

  // ── stats / decks ───────────────────────────────────────────────────────────

  @override
  Future<StudyStats> stats() async {
    final now = _now();
    final nowMs = _ms(now);
    final localMidnight = () {
      final local = DateTime.now();
      return DateTime(local.year, local.month, local.day).toUtc();
    }();

    Future<int> count(String sql, [List<Object?> p = const []]) async =>
        (await _user.select(sql, p)).single['n'] as int;

    final dueNow = await count(
        'SELECT count(*) AS n FROM cards WHERE deleted = 0 AND state != 0 AND due <= ?',
        [nowMs]);
    final perSession = await _newPerSession();
    final newToday = await count(
        'SELECT count(*) AS n FROM review_log WHERE state_before = 0 AND reviewed_at >= ?',
        [_ms(localMidnight)]);
    final reviewsToday = await count(
        'SELECT count(*) AS n FROM review_log WHERE reviewed_at >= ?',
        [_ms(localMidnight)]);
    final byState = {
      'new': await count(
          'SELECT count(*) AS n FROM cards WHERE deleted = 0 AND state = 0'),
      'learning': await count(
          'SELECT count(*) AS n FROM cards WHERE deleted = 0 AND state IN (1, 3)'),
      'review': await count(
          'SELECT count(*) AS n FROM cards WHERE deleted = 0 AND state = 2'),
    };

    return StudyStats(
      dueNow: dueNow,
      newRemaining: (perSession - newToday).clamp(0, perSession),
      reviewsToday: reviewsToday,
      streak: await _streakDays(now),
      totalCards: byState.values.reduce((a, b) => a + b),
      byState: byState,
    );
  }

  /// Consecutive local days (ending today or yesterday) with ≥1 review.
  Future<int> _streakDays(DateTime nowUtc) async {
    final windowStart = _ms(nowUtc.subtract(const Duration(days: 400)));
    final rows = await _user.select(
        'SELECT reviewed_at FROM review_log WHERE reviewed_at >= ?',
        [windowStart]);
    final days = <String>{};
    for (final r in rows) {
      final local = DateTime.fromMillisecondsSinceEpoch(r['reviewed_at'] as int,
              isUtc: true)
          .toLocal();
      days.add('${local.year}-${local.month}-${local.day}');
    }
    if (days.isEmpty) return 0;
    String key(DateTime d) => '${d.year}-${d.month}-${d.day}';
    var cursor = DateTime.now();
    if (!days.contains(key(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(key(cursor))) return 0;
    }
    var streak = 0;
    while (days.contains(key(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Future<List<Deck>> decks() async {
    final nowMs = _ms(_now());
    final rows =
        await _user.select('SELECT $_cardCols FROM cards WHERE deleted = 0');
    final content = await _content;

    final out = <Deck>[];
    for (final spec in deckCatalog) {
      final member = await _deckFilter(spec, rows);
      final mine = [
        for (final r in rows)
          if (member(r)) r
      ];
      final studied = [
        for (final r in mine)
          if (r['state'] != 0) r
      ];
      final due = [
        for (final r in studied)
          if ((r['due'] as int) <= nowMs) r,
      ];
      final total =
          spec.isFilter ? mine.length : await deckUniverseCount(content, spec);
      out.add(Deck(
        id: spec.id,
        title: spec.title,
        subtitle: spec.subtitle,
        icon: spec.icon,
        kind: spec.kind,
        total: total,
        enrolled: mine.length,
        studied: studied.length,
        due: due.length,
      ));
    }
    return out;
  }

  @override
  Future<Deck> enrollDeck(String id) async {
    final spec = deckById(id);
    if (spec == null) throw StateError('unknown deck: $id');
    if (!spec.isFilter) {
      final refs = await deckUniverseRefs(await _content, spec);
      final nowMs = _ms(_now());
      final type = spec.itemType!.wire;
      final statements = <(String, List<Object?>)>[];
      for (var i = 0; i < refs.length; i += 100) {
        final chunk =
            refs.sublist(i, i + 100 > refs.length ? refs.length : i + 100);
        statements.add((
          'INSERT OR IGNORE INTO cards (item_type, item_ref, due, created_at, updated_at) '
              'VALUES ${List.filled(chunk.length, '(?, ?, ?, ?, ?)').join(', ')}',
          [
            for (final ref in chunk) ...[type, ref, nowMs, nowMs, nowMs],
          ],
        ));
      }
      if (statements.isNotEmpty) await _user.tx(statements);
      await _enqueueOp('deck_enroll', {'deck_id': id});
    }
    return (await decks()).firstWhere((d) => d.id == id);
  }
}
