/// Writable SQLite for user study state, owned by a background isolate (same
/// pattern as dict_db_native.dart). All writes funnel through here, serialized
/// on one connection; the review path is a single-row transaction (~µs), far
/// faster than the HTTP round-trip it replaces.
///
/// Schema (PRAGMA user_version migrations):
///  * cards       - natural key (item_type, item_ref), same as the server's
///                  per-user uniqueness; rowid doubles as StudyCard.id.
///  * review_log  - append-only; `synced = 0` rows ARE the sync outbox. Never
///                  pruned: it's the local history (stats/streak) and, for
///                  users who sign up later, the first upload.
///  * op_outbox   - last-write-wins ops awaiting replay (set_status, favorite,
///                  bulk_add, deck_enroll, profile_patch, mnemonic_*).
///  * mnemonic_state - optimistic mirror of votes/saves for offline UI.
///  * kv          - user_json, fsrs profile cache, last_synced_at, local_only.
library;

import 'dart:async';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

const _schema = [
  '''
  CREATE TABLE cards(
    item_type    TEXT NOT NULL CHECK (item_type IN ('word','kanji','kana')),
    item_ref     TEXT NOT NULL,
    server_id    INTEGER,
    stability    REAL,
    difficulty   REAL,
    state        INTEGER NOT NULL DEFAULT 0,
    step         INTEGER,
    due          INTEGER NOT NULL,
    last_review  INTEGER,
    reps         INTEGER NOT NULL DEFAULT 0,
    lapses       INTEGER NOT NULL DEFAULT 0,
    favorite     INTEGER NOT NULL DEFAULT 0,
    created_at   INTEGER NOT NULL,
    updated_at   INTEGER NOT NULL,
    deleted      INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (item_type, item_ref)
  )''',
  'CREATE INDEX idx_cards_queue ON cards(deleted, state, due)',
  '''
  CREATE TABLE review_log(
    seq              INTEGER PRIMARY KEY AUTOINCREMENT,
    client_review_id TEXT NOT NULL UNIQUE,
    item_type        TEXT NOT NULL,
    item_ref         TEXT NOT NULL,
    rating           INTEGER NOT NULL,
    state_before     INTEGER NOT NULL,
    duration_ms      INTEGER NOT NULL DEFAULT 0,
    reviewed_at      INTEGER NOT NULL,
    synced           INTEGER NOT NULL DEFAULT 0
  )''',
  'CREATE INDEX idx_review_pending ON review_log(synced, seq)',
  'CREATE INDEX idx_review_day ON review_log(reviewed_at)',
  '''
  CREATE TABLE op_outbox(
    seq          INTEGER PRIMARY KEY AUTOINCREMENT,
    client_op_id TEXT NOT NULL UNIQUE,
    kind         TEXT NOT NULL,
    payload      TEXT NOT NULL,
    performed_at INTEGER NOT NULL,
    attempts     INTEGER NOT NULL DEFAULT 0,
    last_error   TEXT
  )''',
  '''
  CREATE TABLE mnemonic_state(
    mnemonic_id INTEGER PRIMARY KEY,
    my_vote     INTEGER,
    saved       INTEGER,
    updated_at  INTEGER NOT NULL
  )''',
  'CREATE TABLE kv(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
];

class UserDb {
  UserDb._(this._commands);

  final SendPort _commands;

  static Future<UserDb> open(String path) async {
    final handshake = ReceivePort();
    await Isolate.spawn(_worker, handshake.sendPort,
        debugName: 'jibiki-user-db');
    final commands = await handshake.first as SendPort;
    final db = UserDb._(commands);
    await db._request<void>({'op': 'open', 'path': path});
    return db;
  }

  Future<List<Map<String, Object?>>> select(String sql,
      [List<Object?> params = const []]) async {
    final rows =
        await _request<List>({'op': 'select', 'sql': sql, 'params': params});
    return rows.cast<Map<String, Object?>>();
  }

  /// Runs one statement; returns the last inserted rowid.
  Future<int> execute(String sql, [List<Object?> params = const []]) =>
      _request<int>({'op': 'execute', 'sql': sql, 'params': params});

  /// Runs [statements] atomically.
  Future<void> tx(List<(String, List<Object?>)> statements) => _request<void>({
        'op': 'tx',
        'statements': [
          for (final (sql, params) in statements)
            {'sql': sql, 'params': params},
        ],
      });

  Future<void> close() => _request<void>({'op': 'close'});

  Future<T> _request<T>(Map<String, Object?> message) async {
    final reply = ReceivePort();
    _commands.send({...message, 'reply': reply.sendPort});
    final response = await reply.first as Map;
    reply.close();
    final error = response['error'];
    if (error != null) throw StateError('user db: $error');
    return response['result'] as T;
  }

  static void _worker(SendPort handshake) {
    final commands = ReceivePort();
    handshake.send(commands.sendPort);
    Database? db;

    commands.listen((raw) {
      final msg = raw as Map;
      final reply = msg['reply'] as SendPort;
      try {
        switch (msg['op']) {
          case 'open':
            db?.dispose();
            final opened = sqlite3.open(msg['path'] as String);
            opened.execute('PRAGMA journal_mode = WAL');
            opened.execute('PRAGMA foreign_keys = ON');
            _migrate(opened);
            db = opened;
            reply.send(const {'result': null});
          case 'select':
            final rows = _db(db).select(
                msg['sql'] as String, (msg['params'] as List).cast<Object?>());
            reply.send({
              'result': [for (final row in rows) Map<String, Object?>.of(row)],
            });
          case 'execute':
            final d = _db(db);
            d.execute(
                msg['sql'] as String, (msg['params'] as List).cast<Object?>());
            reply.send({'result': d.lastInsertRowId});
          case 'tx':
            final d = _db(db);
            d.execute('BEGIN IMMEDIATE');
            try {
              for (final s in (msg['statements'] as List).cast<Map>()) {
                d.execute(
                    s['sql'] as String, (s['params'] as List).cast<Object?>());
              }
              d.execute('COMMIT');
            } catch (_) {
              d.execute('ROLLBACK');
              rethrow;
            }
            reply.send(const {'result': null});
          case 'close':
            db?.dispose();
            db = null;
            reply.send(const {'result': null});
            commands.close();
          default:
            throw StateError('unknown op ${msg['op']}');
        }
      } catch (e) {
        reply.send({'error': e.toString()});
      }
    });
  }

  static Database _db(Database? db) {
    if (db == null) throw StateError('not open');
    return db;
  }

  static void _migrate(Database db) {
    final version = db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version == 0) {
      db.execute('BEGIN');
      try {
        for (final stmt in _schema) {
          db.execute(stmt);
        }
        db.execute('PRAGMA user_version = 1');
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
    if (version <= 1) {
      db.execute(
          'ALTER TABLE cards ADD COLUMN source_sentence TEXT NOT NULL DEFAULT \'\'');
      db.execute(
          'ALTER TABLE cards ADD COLUMN source_url TEXT NOT NULL DEFAULT \'\'');
      db.execute(
          'ALTER TABLE cards ADD COLUMN source_title TEXT NOT NULL DEFAULT \'\'');
      db.execute(
          'ALTER TABLE cards ADD COLUMN source_media TEXT NOT NULL DEFAULT \'\'');
      db.execute('PRAGMA user_version = 2');
    }
  }
}
