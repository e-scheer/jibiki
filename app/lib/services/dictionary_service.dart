import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/kana.dart';
import '../models/kanji.dart';
import '../models/word.dart';

class DictionaryService {
  DictionaryService(this._api);
  final ApiClient _api;

  Future<SearchResults> search(String q, {String lang = 'en', int limit = 25}) async {
    final data = (await _api.get(ApiConfig.dictSearch, query: {'q': q, 'lang': lang, 'limit': limit})) as Map;
    final words = ((data['results'] as List?) ?? const [])
        .map((e) => WordEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final names = ((data['names'] as List?) ?? const [])
        .map((e) => NameItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return SearchResults(words: words, names: names);
  }

  Future<WordEntry> word(int id) async {
    final data = await _api.get(ApiConfig.dictWord(id));
    return WordEntry.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<KanjiEntry> kanji(String literal) async {
    final data = await _api.get(ApiConfig.dictKanji(literal));
    return KanjiEntry.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Browse words by category (common / JLPT). Paginated (limit/offset).
  Future<List<WordEntry>> words({
    bool common = false,
    int? jlpt,
    int limit = 60,
    int offset = 0,
  }) async {
    final data = await _api.get(ApiConfig.dictWords, query: {
      if (common) 'common': 1,
      if (jlpt != null) 'jlpt': jlpt,
      'limit': limit,
      'offset': offset,
    });
    final results = (data is Map) ? (data['results'] as List? ?? const []) : (data as List);
    return results.map((e) => WordEntry.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<List<KanjiEntry>> kanjiList({
    int? jlpt,
    int? grade,
    String? contains,
    int limit = 120,
    int offset = 0,
  }) async {
    final data = await _api.get(ApiConfig.dictKanjiList, query: {
      if (jlpt != null) 'jlpt': jlpt,
      if (grade != null) 'grade': grade,
      if (contains != null) 'contains': contains,
      'limit': limit,
      'offset': offset,
    });
    // LimitOffsetPagination wraps the list in {count, results}.
    final results = (data is Map) ? (data['results'] as List? ?? const []) : (data as List);
    return results.map((e) => KanjiEntry.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  /// Radicals (keys) for the "browse kanji by radical" picker.
  Future<List<Map<String, dynamic>>> radicals() async {
    final data = await _api.get(ApiConfig.dictRadicals);
    final list = (data is Map) ? (data['results'] as List? ?? const []) : (data as List);
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<List<KanaEntry>> kana({String? script}) async {
    final data = await _api.get(ApiConfig.dictKana, query: {if (script != null) 'script': script});
    final list = (data as List);
    return list.map((e) => KanaEntry.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<KanaEntry> kanaDetail(String char) async {
    final data = await _api.get(ApiConfig.dictKanaDetail(char));
    return KanaEntry.fromJson((data as Map).cast<String, dynamic>());
  }
}
