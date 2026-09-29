import '../models/kana.dart';
import '../models/kanji.dart';
import '../models/word.dart';
import '../services/dictionary_data_source.dart';

/// Reference data changes rarely, so this repository memoizes the kana chart and
/// per-kanji detail for the lifetime of the app session.
///
/// It reads through a [DictionaryDataSource] - local content packs on mobile,
/// the HTTP service on web. During the offline-first transition a [fallback]
/// (the HTTP service) answers when the local source fails, so the worst case
/// behaves exactly like the online-only app; the shim goes away once the
/// local path is proven.
class DictionaryRepository {
  DictionaryRepository(this._source,
      {DictionaryDataSource? fallback, Object? Function()? cacheRevision})
      : _fallback = fallback,
        _cacheRevision = cacheRevision;

  final DictionaryDataSource _source;
  final DictionaryDataSource? _fallback;
  final Object? Function()? _cacheRevision;
  Object? _revision;

  Object? _checkCache() {
    final revision = _cacheRevision?.call();
    if (_revision != revision) {
      _kanaCache = null;
      _radicalCache = null;
      _kanjiCache.clear();
      _kanaDetailCache.clear();
      _revision = revision;
    }
    return revision;
  }

  Future<T> _read<T>(Future<T> Function(DictionaryDataSource) op) async {
    try {
      return await op(_source);
    } catch (_) {
      final fallback = _fallback;
      if (fallback == null) rethrow;
      return op(fallback);
    }
  }

  List<KanaEntry>? _kanaCache;
  final Map<String, KanjiEntry> _kanjiCache = {};

  Future<SearchResults> search(String q, {String lang = 'en'}) =>
      _read((s) => s.search(q, lang: lang));

  Future<WordEntry> word(int id) => _read((s) => s.word(id));

  Future<KanjiEntry> kanji(String literal) async {
    final revision = _checkCache();
    final cached = _kanjiCache[literal];
    if (cached != null) return cached;
    final k = await _read((s) => s.kanji(literal));
    if (_checkCache() == revision) _kanjiCache[literal] = k;
    return k;
  }

  Future<List<KanjiEntry>> kanjiList(
          {int? jlpt,
          int? grade,
          String? contains,
          int limit = 120,
          int offset = 0}) =>
      _read((s) => s.kanjiList(
          jlpt: jlpt,
          grade: grade,
          contains: contains,
          limit: limit,
          offset: offset));

  Future<List<WordEntry>> words(
          {bool common = false, int? jlpt, int limit = 60, int offset = 0}) =>
      _read((s) =>
          s.words(common: common, jlpt: jlpt, limit: limit, offset: offset));

  List<Map<String, dynamic>>? _radicalCache;
  Future<List<Map<String, dynamic>>> radicals() async {
    final revision = _checkCache();
    if (_radicalCache != null) return _radicalCache!;
    final value = await _read<List<Map<String, dynamic>>>((s) => s.radicals());
    if (_checkCache() == revision) _radicalCache = value;
    return value;
  }

  Future<List<KanaEntry>> kana() async {
    final revision = _checkCache();
    if (_kanaCache != null) return _kanaCache!;
    final value = await _read<List<KanaEntry>>((s) => s.kana());
    if (_checkCache() == revision) _kanaCache = value;
    return value;
  }

  final Map<String, KanaEntry> _kanaDetailCache = {};
  Future<KanaEntry> kanaDetail(String char) async {
    final revision = _checkCache();
    if (_kanaDetailCache.containsKey(char)) return _kanaDetailCache[char]!;
    final value = await _read((s) => s.kanaDetail(char));
    if (_checkCache() == revision) _kanaDetailCache[char] = value;
    return value;
  }
}
