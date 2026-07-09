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
  DictionaryRepository(this._source, {DictionaryDataSource? fallback})
      : _fallback = fallback;

  final DictionaryDataSource _source;
  final DictionaryDataSource? _fallback;

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
    final cached = _kanjiCache[literal];
    if (cached != null) return cached;
    final k = await _read((s) => s.kanji(literal));
    _kanjiCache[literal] = k;
    return k;
  }

  Future<List<KanjiEntry>> kanjiList({int? jlpt, int? grade, String? contains, int limit = 120, int offset = 0}) =>
      _read((s) => s.kanjiList(jlpt: jlpt, grade: grade, contains: contains, limit: limit, offset: offset));

  Future<List<WordEntry>> words({bool common = false, int? jlpt, int limit = 60, int offset = 0}) =>
      _read((s) => s.words(common: common, jlpt: jlpt, limit: limit, offset: offset));

  List<Map<String, dynamic>>? _radicalCache;
  Future<List<Map<String, dynamic>>> radicals() async =>
      _radicalCache ??= await _read<List<Map<String, dynamic>>>((s) => s.radicals());

  Future<List<KanaEntry>> kana() async =>
      _kanaCache ??= await _read<List<KanaEntry>>((s) => s.kana());

  final Map<String, KanaEntry> _kanaDetailCache = {};
  Future<KanaEntry> kanaDetail(String char) async =>
      _kanaDetailCache[char] ??= await _read((s) => s.kanaDetail(char));
}
