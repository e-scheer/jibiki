import '../models/kana.dart';
import '../models/kanji.dart';
import '../models/word.dart';

/// The dictionary read surface - exactly DictionaryService's methods, so the
/// repository (and every viewmodel above it) can't tell whether entries come
/// from the HTTP API (web) or the local content packs (mobile, offline-first).
abstract class DictionaryDataSource {
  Future<SearchResults> search(String q, {String lang = 'en', int limit = 25});

  Future<WordEntry> word(int id);

  Future<KanjiEntry> kanji(String literal);

  Future<List<WordEntry>> words({
    bool common = false,
    int? jlpt,
    int limit = 60,
    int offset = 0,
  });

  Future<List<KanjiEntry>> kanjiList({
    int? jlpt,
    int? grade,
    String? contains,
    int limit = 120,
    int offset = 0,
  });

  Future<List<Map<String, dynamic>>> radicals();

  Future<List<KanaEntry>> kana({String? script});

  Future<KanaEntry> kanaDetail(String char);
}
