/// Replays the local outbox to POST /study/sync and applies the server's
/// delta. Single-flight with exponential backoff; triggers (app start/resume,
/// connectivity regained, debounced after reviews, manual) all funnel into
/// [requestSync]. The review flow itself never touches this - ratings are
/// pure local writes, and this engine drains them later.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/telemetry.dart';
import '../infrastructure/user_db_handle.dart';
import '../services/sync_service.dart';

enum SyncResolution { cloud, local }

class SyncConflict {
  const SyncConflict({
    required this.accountId,
    required this.localCards,
    required this.localReviews,
    required this.localPending,
    required this.cloudCards,
    required this.cloudReviews,
    this.belongsToAnotherAccount = false,
  });

  final int accountId;
  final int localCards;
  final int localReviews;
  final int localPending;
  final int cloudCards;
  final int cloudReviews;
  final bool belongsToAnotherAccount;
}

class SyncEngine extends ChangeNotifier {
  SyncEngine(
    this._user,
    this._service, {
    required this.canSync,
    TelemetrySink? telemetry,
  }) : _telemetry = telemetry ?? Telemetry.instance;

  final UserDbHandle _user;
  final SyncService _service;
  final TelemetrySink _telemetry;

  /// Sync only makes sense with a signed-in session (local-only users study
  /// without one; their outbox uploads wholesale when they create an account).
  final bool Function() canSync;

  bool _syncing = false;
  Object? _lastError;
  DateTime? _lastSyncedAt;
  int _pendingCount = 0;
  DateTime? _oldestPendingAt;
  bool _online = false;
  bool _initialized = false;
  int? _boundAccountId;
  int? _requestedAccountId;
  bool _preparingAccount = false;
  SyncConflict? _conflict;
  Timer? _debounce;
  Timer? _retry;
  Timer? _periodic;
  Duration _backoff = const Duration(seconds: 5);
  bool _disposed = false;

  bool get syncing => _syncing;
  Object? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  int get pendingCount => _pendingCount;
  DateTime? get oldestPendingAt => _oldestPendingAt;
  bool get online => _online;
  int? get boundAccountId => _boundAccountId;
  SyncConflict? get conflict => _conflict;

  static const _maxBackoff = Duration(minutes: 10);
  static const _reviewPage = 500;
  static const _opPage = 200;
  static const _uuid = Uuid();

  Future<void> init() async {
    await _repairLegacyIds();
    final rows = await _user
        .select('SELECT value FROM kv WHERE key = ?', ['last_synced_at']);
    if (rows.isNotEmpty) {
      _lastSyncedAt = DateTime.tryParse(rows.single['value'] as String);
    }
    final owner = await _user.select(
      'SELECT value FROM kv WHERE key = ?',
      ['sync_owner'],
    );
    if (owner.isNotEmpty) {
      _boundAccountId = int.tryParse(owner.single['value'] as String);
    }
    await _refreshPending();
    _initialized = true;
    _periodic = Timer.periodic(
      const Duration(minutes: 5),
      (_) => requestSync(debounce: Duration.zero),
    );
    unawaited(_prepareAccount());
  }

  void setOnline(bool value) {
    if (_online == value) return;
    _online = value;
    if (value) {
      unawaited(_prepareAccount());
      requestSync(debounce: const Duration(seconds: 1));
    } else {
      _retry?.cancel();
    }
    notifyListeners();
  }

  Future<void> accountChanged(int? accountId) async {
    if (_requestedAccountId == accountId &&
        (accountId == null ||
            _boundAccountId == accountId ||
            _conflict != null)) {
      return;
    }
    _requestedAccountId = accountId;
    if (accountId == null) {
      _conflict = null;
      notifyListeners();
      return;
    }
    await _prepareAccount();
  }

  Future<void> _prepareAccount() async {
    final accountId = _requestedAccountId;
    if (_disposed ||
        !_initialized ||
        _preparingAccount ||
        accountId == null ||
        !_online ||
        !canSync()) {
      return;
    }
    if (_boundAccountId == accountId) {
      requestSync(debounce: const Duration(seconds: 1));
      return;
    }
    _preparingAccount = true;
    try {
      final local = await _localStatus();
      final preview = await _service.sync(mode: 'preview');
      final cloud =
          (preview['cloud'] as Map? ?? const {}).cast<String, dynamic>();
      final cloudCards = (cloud['cards'] as num?)?.toInt() ?? 0;
      final cloudReviews = (cloud['reviews'] as num?)?.toInt() ?? 0;
      final ownerMismatch =
          _boundAccountId != null && _boundAccountId != accountId;
      final hasLocal =
          local.cards > 0 || local.reviews > 0 || local.pending > 0;
      final hasCloud = cloudCards > 0 || cloudReviews > 0;
      if (ownerMismatch || (hasLocal && hasCloud)) {
        _conflict = SyncConflict(
          accountId: accountId,
          localCards: local.cards,
          localReviews: local.reviews,
          localPending: local.pending,
          cloudCards: cloudCards,
          cloudReviews: cloudReviews,
          belongsToAnotherAccount: ownerMismatch,
        );
        notifyListeners();
        return;
      }
      await _bind(accountId);
      await syncNow(source: 'account_binding');
    } catch (error) {
      _lastError = error;
      notifyListeners();
    } finally {
      _preparingAccount = false;
    }
  }

  Future<void> resolveConflict(SyncResolution resolution) async {
    final conflict = _conflict;
    if (conflict == null || _syncing) return;
    if (resolution == SyncResolution.local &&
        conflict.belongsToAnotherAccount) {
      throw StateError('Local data belongs to another account.');
    }
    _conflict = null;
    _lastError = null;
    if (resolution == SyncResolution.cloud) {
      await _clearLocalUserData();
      await _bind(conflict.accountId);
      notifyListeners();
      await syncNow(source: 'conflict_cloud');
    } else {
      await _prepareCompleteLocalUpload();
      await _resetCursor();
      await _bind(conflict.accountId);
      notifyListeners();
      await syncNow(replaceCloud: true, source: 'conflict_local');
    }
  }

  Future<void> _repairLegacyIds() async {
    final statements = <(String, List<Object?>)>[];
    final reviews = await _user.select(
      'SELECT seq, client_review_id FROM review_log',
    );
    for (final row in reviews) {
      final value = row['client_review_id'] as String;
      if (!_looksLikeUuid(value)) {
        statements.add((
          'UPDATE review_log SET client_review_id = ? WHERE seq = ?',
          [_uuid.v4(), row['seq']],
        ));
      }
    }
    final ops = await _user.select('SELECT seq, client_op_id FROM op_outbox');
    for (final row in ops) {
      final value = row['client_op_id'] as String;
      if (!_looksLikeUuid(value)) {
        statements.add((
          'UPDATE op_outbox SET client_op_id = ? WHERE seq = ?',
          [_uuid.v4(), row['seq']],
        ));
      }
    }
    if (statements.isNotEmpty) await _user.tx(statements);
  }

  bool _looksLikeUuid(String value) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
        r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      ).hasMatch(value);

  Future<void> _prepareCompleteLocalUpload() async {
    final statements = <(String, List<Object?>)>[
      ('UPDATE review_log SET synced = 0', const []),
    ];
    final cards = await _user.select(
      'SELECT c.*, EXISTS('
      'SELECT 1 FROM review_log r WHERE r.item_type = c.item_type '
      'AND r.item_ref = c.item_ref) AS has_reviews '
      'FROM cards c WHERE c.deleted = 0',
    );
    var performedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final card in cards) {
      if (card['has_reviews'] == 0) {
        statements.add((
          'INSERT INTO op_outbox '
              '(client_op_id, kind, payload, performed_at) VALUES (?, ?, ?, ?)',
          [
            _uuid.v4(),
            'set_status',
            jsonEncode({
              'item_type': card['item_type'],
              'ref': card['item_ref'],
              'status': card['state'] == 0 ? 'learning' : 'known',
            }),
            performedAt++,
          ],
        ));
      }
      if (card['favorite'] == 1) {
        statements.add((
          'INSERT INTO op_outbox '
              '(client_op_id, kind, payload, performed_at) VALUES (?, ?, ?, ?)',
          [
            _uuid.v4(),
            'favorite',
            jsonEncode({
              'item_type': card['item_type'],
              'ref': card['item_ref'],
              'value': true,
            }),
            performedAt++,
          ],
        ));
      }
    }
    final profile = await _user.select(
      'SELECT value FROM kv WHERE key = ?',
      ['profile'],
    );
    if (profile.isNotEmpty) {
      statements.add((
        'INSERT INTO op_outbox '
            '(client_op_id, kind, payload, performed_at) VALUES (?, ?, ?, ?)',
        [
          _uuid.v4(),
          'profile_patch',
          profile.single['value'],
          performedAt,
        ],
      ));
    }
    await _user.tx(statements);
    await _refreshPending();
  }

  Future<({int cards, int reviews, int pending})> _localStatus() async {
    final rows = await _user.select(
      'SELECT (SELECT count(*) FROM cards WHERE deleted = 0) AS cards, '
      '(SELECT count(*) FROM review_log) AS reviews, '
      '(SELECT count(*) FROM review_log WHERE synced = 0) + '
      '(SELECT count(*) FROM op_outbox) AS pending',
    );
    final row = rows.single;
    return (
      cards: row['cards'] as int,
      reviews: row['reviews'] as int,
      pending: row['pending'] as int,
    );
  }

  Future<void> _bind(int accountId) async {
    await _user.execute(
      'INSERT INTO kv (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      ['sync_owner', '$accountId'],
    );
    _boundAccountId = accountId;
  }

  Future<void> _resetCursor() async {
    await _user.execute('DELETE FROM kv WHERE key = ?', ['last_synced_at']);
    _lastSyncedAt = null;
  }

  Future<void> _clearLocalUserData() async {
    await _user.tx([
      ('DELETE FROM review_log', const []),
      ('DELETE FROM op_outbox', const []),
      ('DELETE FROM cards', const []),
      ('DELETE FROM mnemonic_state', const []),
      ('DELETE FROM kv WHERE key IN (?, ?)', ['last_synced_at', 'profile']),
    ]);
    _lastSyncedAt = null;
    await _refreshPending();
  }

  /// Debounced entry point for every trigger. A shorter debounce batches the
  /// burst of ratings at the end of a study session into one request.
  void requestSync({Duration debounce = const Duration(seconds: 20)}) {
    unawaited(
      _refreshPending().then((_) {
        if (!_disposed) notifyListeners();
      }),
    );
    if (_disposed ||
        !_online ||
        !canSync() ||
        _conflict != null ||
        _requestedAccountId == null ||
        _boundAccountId != _requestedAccountId) {
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(debounce, () => unawaited(syncNow()));
  }

  Future<void> syncNow({
    bool replaceCloud = false,
    String source = 'automatic',
  }) async {
    if (_disposed ||
        _syncing ||
        !_online ||
        !canSync() ||
        _conflict != null ||
        _requestedAccountId == null ||
        _boundAccountId != _requestedAccountId) {
      return;
    }
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
          mode: replaceCloud ? 'replace_cloud' : 'sync',
          reviews: [for (final r in reviews) _reviewWire(r)],
          ops: [for (final o in ops) _opWire(o)],
        );
        await _apply(response);
        replaceCloud = false;
        cursor = response['synced_at'] as String?;
        if (reviews.length < _reviewPage && ops.length < _opPage) break;
      }
      _backoff = const Duration(seconds: 5);
      unawaited(_telemetry.logEvent(
        TelemetryEvent.syncCompleted,
        parameters: {'source': source},
      ));
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
      for (final r in (response['rejected'] as List? ?? const []))
        (r as Map)['id'],
    ];
    for (var i = 0; i < acked.length; i += 500) {
      final chunk =
          acked.sublist(i, i + 500 > acked.length ? acked.length : i + 500);
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
      final chunk = ackedOps.sublist(
          i, i + 500 > ackedOps.length ? ackedOps.length : i + 500);
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
            'state, step, due, last_review, reps, lapses, favorite, source_sentence, '
            'source_url, source_title, source_media, created_at, updated_at, deleted) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0) '
            'ON CONFLICT(item_type, item_ref) DO UPDATE SET '
            'server_id = excluded.server_id, stability = excluded.stability, '
            'difficulty = excluded.difficulty, state = excluded.state, '
            'step = excluded.step, due = excluded.due, last_review = excluded.last_review, '
            'reps = excluded.reps, lapses = excluded.lapses, favorite = excluded.favorite, '
            'source_sentence = excluded.source_sentence, source_url = excluded.source_url, '
            'source_title = excluded.source_title, source_media = excluded.source_media, '
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
          card['source_sentence'] ?? '',
          card['source_url'] ?? '',
          card['source_title'] ?? '',
          card['source_media'] ?? '',
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

  int? _parseMs(Object? iso) => iso == null
      ? null
      : DateTime.tryParse(iso as String)?.millisecondsSinceEpoch;

  Future<void> _refreshPending() async {
    final rows = await _user
        .select('SELECT (SELECT count(*) FROM review_log WHERE synced = 0) + '
            '(SELECT count(*) FROM op_outbox) AS n, '
            '(SELECT min(at) FROM ('
            'SELECT reviewed_at AS at FROM review_log WHERE synced = 0 '
            'UNION ALL SELECT performed_at AS at FROM op_outbox'
            ')) AS oldest');
    _pendingCount = rows.single['n'] as int;
    final oldest = rows.single['oldest'] as int?;
    _oldestPendingAt = oldest == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(oldest, isUtc: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _retry?.cancel();
    _periodic?.cancel();
    super.dispose();
  }
}
