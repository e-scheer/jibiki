/// Replays the local outbox to POST /study/sync and applies the server's
/// delta. Single-flight with exponential backoff; triggers (app start/resume,
/// connectivity regained, debounced after reviews, manual) all funnel into
/// [requestSync]. The review flow itself never touches this - ratings are
/// pure local writes, and this engine drains them later.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/user_db_handle.dart';
import '../services/sync_service.dart';

class SyncEngine extends ChangeNotifier {
  SyncEngine(this._user, this._service, {required this.canSync});

  final UserDbHandle _user;
  final SyncService _service;

  /// Sync only makes sense with a signed-in session (local-only users study
  /// without one; their outbox uploads wholesale when they create an account).
  final bool Function() canSync;

  bool _syncing = false;
  Object? _lastError;
  DateTime? _lastSyncedAt;
  int _pendingCount = 0;
  Timer? _debounce;
  Timer? _retry;
  Duration _backoff = const Duration(seconds: 5);
  bool _disposed = false;

  bool get syncing => _syncing;
  Object? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  int get pendingCount => _pendingCount;

  static const _maxBackoff = Duration(minutes: 10);
  static const _reviewPage = 500;
  static const _opPage = 200;

  Future<void> init() async {
    final rows = await _user
        .select('SELECT value FROM kv WHERE key = ?', ['last_synced_at']);
    if (rows.isNotEmpty) {
      _lastSyncedAt = DateTime.tryParse(rows.single['value'] as String);
    }
    await _refreshPending();
  }

  /// Debounced entry point for every trigger. A shorter debounce batches the
  /// burst of ratings at the end of a study session into one request.
  void requestSync({Duration debounce = const Duration(seconds: 20)}) {
    if (_disposed || !canSync()) return;
    _debounce?.cancel();
    _debounce = Timer(debounce, () => unawaited(syncNow()));
  }

  Future<void> syncNow() async {
    if (_disposed || _syncing || !canSync()) return;
    _syncing = true;
    _lastError = null;
    _retry?.cancel();
    notifyListeners();
    try {
      var cursor = _lastSyncedAt?.toUtc().toIso8601String();
      // Page until the outbox is drained; each response also carries the
      // delta past our cursor (including changes this very upload caused).
      while (true) {
        final reviews = await _pendingReviews();
        final ops = await _pendingOps();
        final response = await _service.sync(
          lastSyncedAt: cursor,
          reviews: [for (final r in reviews) _reviewWire(r)],
          ops: [for (final o in ops) _opWire(o)],
        );
        await _apply(response);
        cursor = response['synced_at'] as String?;
        if (reviews.length < _reviewPage && ops.length < _opPage) break;
      }
      _backoff = const Duration(seconds: 5);
    } catch (e) {
      _lastError = e;
      // Try again later - outbox rows are durable, nothing is lost.
      _retry?.cancel();
      _retry = Timer(_backoff, () => unawaited(syncNow()));
      final doubled = _backoff * 2;
      _backoff = doubled > _maxBackoff ? _maxBackoff : doubled;
    } finally {
      _syncing = false;
      await _refreshPending();
      if (!_disposed) notifyListeners();
    }
  }

  Future<List<Map<String, Object?>>> _pendingReviews() => _user.select(
      'SELECT * FROM review_log WHERE synced = 0 ORDER BY seq LIMIT $_reviewPage');

  Future<List<Map<String, Object?>>> _pendingOps() =>
      _user.select('SELECT * FROM op_outbox ORDER BY seq LIMIT $_opPage');

  Map<String, dynamic> _reviewWire(Map<String, Object?> r) => {
        'client_review_id': r['client_review_id'],
        'item_type': r['item_type'],
        'ref': r['item_ref'],
        'rating': r['rating'],
        'duration_ms': r['duration_ms'],
        'state_before': r['state_before'],
        'reviewed_at': _iso(r['reviewed_at'] as int),
      };

  Map<String, dynamic> _opWire(Map<String, Object?> o) => {
        'client_op_id': o['client_op_id'],
        'kind': o['kind'],
        'payload': jsonDecode(o['payload'] as String),
        'performed_at': _iso(o['performed_at'] as int),
      };

  String _iso(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();

  Future<void> _apply(Map<String, dynamic> response) async {
    final statements = <(String, List<Object?>)>[];

    // Acked reviews (applied or rejected) leave the outbox but stay in the
    // log - they are the local history.
    final acked = [
      ...(response['applied_review_ids'] as List? ?? const []),
      for (final r in (response['rejected'] as List? ?? const [])) (r as Map)['id'],
    ];
    for (var i = 0; i < acked.length; i += 500) {
      final chunk = acked.sublist(i, i + 500 > acked.length ? acked.length : i + 500);
      statements.add((
        'UPDATE review_log SET synced = 1 WHERE client_review_id IN '
        '(${List.filled(chunk.length, '?').join(',')})',
        chunk.cast<Object?>(),
      ));
    }

    final ackedOps = [
      ...(response['applied_op_ids'] as List? ?? const []),
      for (final o in (response['rejected_ops'] as List? ?? const []))
        (o as Map)['id'],
    ];
    for (var i = 0; i < ackedOps.length; i += 500) {
      final chunk =
          ackedOps.sublist(i, i + 500 > ackedOps.length ? ackedOps.length : i + 500);
      statements.add((
        'DELETE FROM op_outbox WHERE client_op_id IN '
        '(${List.filled(chunk.length, '?').join(',')})',
        chunk.cast<Object?>(),
      ));
    }

    // Cards the server declares gone (deleted on another device).
    for (final d in (response['deleted'] as List? ?? const [])) {
      final t = (d as Map).cast<String, dynamic>();
      statements.add((
        'DELETE FROM cards WHERE item_type = ? AND item_ref = ?',
        [t['item_type'], t['ref']],
      ));
    }

    // Authoritative card states - but never clobber a card that has reviews
    // still waiting in the outbox (rated while this request was in flight);
    // the next loop iteration uploads them and receives the newer state. The
    // rows this very response acks don't count: their synced flag flips in
    // the same transaction below.
    final ackedSet = {...acked};
    final stillPending = {
      for (final r in await _user.select(
          'SELECT client_review_id, item_type, item_ref FROM review_log WHERE synced = 0'))
        if (!ackedSet.contains(r['client_review_id']))
          '${r['item_type']}:${r['item_ref']}',
    };
    for (final c in (response['cards'] as List? ?? const [])) {
      final card = (c as Map).cast<String, dynamic>();
      if (stillPending.contains('${card['item_type']}:${card['item_ref']}')) {
        continue;
      }
      statements.add((
        'INSERT INTO cards (item_type, item_ref, server_id, stability, difficulty, '
        'state, step, due, last_review, reps, lapses, favorite, created_at, '
        'updated_at, deleted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0) '
        'ON CONFLICT(item_type, item_ref) DO UPDATE SET '
        'server_id = excluded.server_id, stability = excluded.stability, '
        'difficulty = excluded.difficulty, state = excluded.state, '
        'step = excluded.step, due = excluded.due, last_review = excluded.last_review, '
        'reps = excluded.reps, lapses = excluded.lapses, favorite = excluded.favorite, '
        'updated_at = excluded.updated_at, deleted = 0',
        [
          card['item_type'],
          card['item_ref'],
          card['id'],
          card['stability'],
          card['difficulty'],
          card['state'],
          card['step'],
          _parseMs(card['due']),
          _parseMs(card['last_review']),
          card['reps'],
          card['lapses'],
          card['favorite'] == true ? 1 : 0,
          _parseMs(card['created_at']) ?? 0,
          _parseMs(card['updated_at']) ?? 0,
        ],
      ));
    }

    // Fresh profile (incl. server-trained FSRS weights) + watermark.
    final profile = response['profile'];
    if (profile is Map) {
      statements.add((
        'INSERT INTO kv (key, value) VALUES (?, ?) '
        'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        ['profile', jsonEncode(profile)],
      ));
    }
    final syncedAt = response['synced_at'] as String?;
    if (syncedAt != null) {
      statements.add((
        'INSERT INTO kv (key, value) VALUES (?, ?) '
        'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        ['last_synced_at', syncedAt],
      ));
      _lastSyncedAt = DateTime.tryParse(syncedAt);
    }

    await _user.tx(statements);
  }

  int? _parseMs(Object? iso) =>
      iso == null ? null : DateTime.tryParse(iso as String)?.millisecondsSinceEpoch;

  Future<void> _refreshPending() async {
    final rows = await _user.select(
        'SELECT (SELECT count(*) FROM review_log WHERE synced = 0) + '
        '(SELECT count(*) FROM op_outbox) AS n');
    _pendingCount = rows.single['n'] as int;
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _retry?.cancel();
    super.dispose();
  }
}
