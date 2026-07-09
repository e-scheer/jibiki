/// Web stand-in for the native pack database. The web build keeps the HTTP
/// dictionary path, so nothing ever calls this - it only satisfies the
/// compiler where `dart:ffi` doesn't exist.
library;

class DictDb {
  DictDb._();

  static Future<DictDb> spawn() =>
      throw UnsupportedError('Content packs are not available on web.');

  Future<void> open(String main, {Map<String, String> attach = const {}}) =>
      throw UnsupportedError('Content packs are not available on web.');

  Future<List<Map<String, Object?>>> select(String sql,
          [List<Object?> params = const []]) =>
      throw UnsupportedError('Content packs are not available on web.');

  Future<void> close() =>
      throw UnsupportedError('Content packs are not available on web.');
}
