import '../core/db/user_db.dart';

/// Lazily-opened handle over the user-state database, so the composition root
/// stays synchronous (the path needs an async platform call) and the file is
/// only created once study features are actually touched.
class UserDbHandle {
  UserDbHandle(this._open);

  final Future<UserDb> Function() _open;
  Future<UserDb>? _db;

  Future<UserDb> get _resolved => _db ??= _open();

  Future<List<Map<String, Object?>>> select(String sql,
          [List<Object?> params = const []]) async =>
      (await _resolved).select(sql, params);

  Future<int> execute(String sql, [List<Object?> params = const []]) async =>
      (await _resolved).execute(sql, params);

  Future<void> tx(List<(String, List<Object?>)> statements) async =>
      (await _resolved).tx(statements);

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) await (await db).close();
  }
}
