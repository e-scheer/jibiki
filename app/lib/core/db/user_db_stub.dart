/// Web stand-in for the native user-state database - never constructed there.
library;

class UserDb {
  UserDb._();

  static Future<UserDb> open(String path) =>
      throw UnsupportedError('Local study is not available on web.');

  Future<List<Map<String, Object?>>> select(String sql,
          [List<Object?> params = const []]) =>
      throw UnsupportedError('Local study is not available on web.');

  Future<int> execute(String sql, [List<Object?> params = const []]) =>
      throw UnsupportedError('Local study is not available on web.');

  Future<void> tx(List<(String, List<Object?>)> statements) =>
      throw UnsupportedError('Local study is not available on web.');

  Future<void> close() =>
      throw UnsupportedError('Local study is not available on web.');
}
