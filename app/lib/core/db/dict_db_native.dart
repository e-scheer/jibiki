/// A single read-only SQLite connection owned by a long-lived background
/// isolate, so a slow query (the ~50 ms contains-scan over 460k word forms)
/// can never jank the UI thread. All pack reads in the app funnel through
/// here; queries are serialized on the one connection, which is plenty for a
/// debounced-search workload.
library;

import 'dart:async';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

class DictDb {
  DictDb._(this._commands);

  final SendPort _commands;

  static Future<DictDb> spawn() async {
    final handshake = ReceivePort();
    await Isolate.spawn(_worker, handshake.sendPort, debugName: 'jibiki-dict-db');
    final commands = await handshake.first as SendPort;
    return DictDb._(commands);
  }

  /// (Re)open the pack topology: [main] plus schemas ATTACHed under fixed
  /// names (g_en, nm, …). The main file is opened read-only and SQLite applies
  /// the same flags to every ATTACH.
  Future<void> open(String main, {Map<String, String> attach = const {}}) =>
      _request<void>({'op': 'open', 'main': main, 'attach': attach});

  Future<List<Map<String, Object?>>> select(String sql,
      [List<Object?> params = const []]) async {
    final rows = await _request<List>({'op': 'select', 'sql': sql, 'params': params});
    return rows.cast<Map<String, Object?>>();
  }

  /// Closes the database and ends the worker isolate.
  Future<void> close() => _request<void>({'op': 'close'});

  Future<T> _request<T>(Map<String, Object?> message) async {
    final reply = ReceivePort();
    _commands.send({...message, 'reply': reply.sendPort});
    final response = await reply.first as Map;
    reply.close();
    final error = response['error'];
    if (error != null) throw StateError('dict db: $error');
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
            db = null;
            final opened = sqlite3.open(msg['main'] as String, mode: OpenMode.readOnly);
            try {
              for (final entry in (msg['attach'] as Map).entries) {
                // Schema names come from our own registry (fixed identifiers),
                // never from user input; only the path is a parameter.
                opened.execute('ATTACH DATABASE ? AS ${entry.key}', [entry.value]);
              }
            } catch (_) {
              opened.dispose();
              rethrow;
            }
            db = opened;
            reply.send(const {'result': null});
          case 'select':
            final d = db;
            if (d == null) throw StateError('no pack open');
            final rows = d.select(msg['sql'] as String, (msg['params'] as List).cast<Object?>());
            reply.send({
              'result': [for (final row in rows) Map<String, Object?>.of(row)],
            });
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
}
