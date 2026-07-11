import '../core/db/user_db.dart';

class UserDbHandle {
  UserDbHandle(this._open);

  final Future<UserDb> Function() _open;
  Future<UserDb>? _instance;

  Future<UserDb> get _db => _instance ??= _open();

  Future<List<Map<String, Object?>>> select(
    String sql, [
    List<Object?> params = const [],
  ]) async => (await _db).select(sql, params);

  Future<int> execute(String sql, [List<Object?> params = const []]) async =>
      (await _db).execute(sql, params);

  Future<void> tx(List<(String, List<Object?>)> statements) async =>
      (await _db).tx(statements);

  Future<void> close() async {
    final value = _instance;
    if (value != null) await (await value).close();
    _instance = null;
  }
}
