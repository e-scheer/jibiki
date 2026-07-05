import '../models/kana.dart';
import '../models/kanji.dart';
import '../models/word.dart';
import '../services/dictionary_service.dart';

/// Reference data changes rarely, so this repository memoizes the kana chart and
/// per-kanji detail for the lifetime of the app session.
class DictionaryRepository {
  DictionaryRepository(this._service);
  final DictionaryService _service;

  List<KanaEntry>? _kanaCache;
  final Map<String, KanjiEntry> _kanjiCache = {};

  Future<SearchResults> search(String q, {String lang = 'en'}) =>
      _service.search(q, lang: lang);

  Future<WordEntry> word(int id) => _service.word(id);

  Future<KanjiEntry> kanji(String literal) async {
    final cached = _kanjiCache[literal];
    if (cached != null) return cached;
    final k = await _service.kanji(literal);
    _kanjiCache[literal] = k;
    return k;
  }

  Future<List<KanjiEntry>> kanjiList({int? jlpt, int? grade, String? contains, int limit = 120, int offset = 0}) =>
      _service.kanjiList(jlpt: jlpt, grade: grade, contains: contains, limit: limit, offset: offset);

  Future<List<WordEntry>> words({bool common = false, int? jlpt, int limit = 60, int offset = 0}) =>
      _service.words(common: common, jlpt: jlpt, limit: limit, offset: offset);

  List<Map<String, dynamic>>? _radicalCache;
  Future<List<Map<String, dynamic>>> radicals() async => _radicalCache ??= await _service.radicals();

  Future<List<KanaEntry>> kana() async => _kanaCache ??= await _service.kana();

  final Map<String, KanaEntry> _kanaDetailCache = {};
  Future<KanaEntry> kanaDetail(String char) async =>
      _kanaDetailCache[char] ??= await _service.kanaDetail(char);
}
