import '../models/kanji.dart';
import '../models/word.dart';
import '../repositories/dictionary_repository.dart';
import 'base_view_model.dart';

/// What to browse: a word category (common / JLPT) or a kanji category
/// (JLPT / grade / contains-a-radical).
class BrowseSpec {
  const BrowseSpec.words({required this.title, this.common = false, this.jlpt})
      : isKanji = false,
        grade = null,
        contains = null;

  const BrowseSpec.kanji(
      {required this.title, this.jlpt, this.grade, this.contains})
      : isKanji = true,
        common = false;

  final String title;
  final bool isKanji;
  final bool common;
  final int? jlpt;
  final int? grade;
  final String? contains;
}

/// Loads a browse category (read-only, no flashcards). Kanji or words.
class BrowseViewModel extends BaseViewModel {
  BrowseViewModel(this._repo, this.spec);
  final DictionaryRepository _repo;
  final BrowseSpec spec;

  List<WordEntry> _words = [];
  List<WordEntry> get words => _words;

  List<KanjiEntry> _kanji = [];
  List<KanjiEntry> get kanji => _kanji;

  static const pageSize = 60;
  bool _hasMore = true;
  bool get hasMore => _hasMore;
  int _offset = 0;

  Future<void> load() => _loadPage(reset: true);

  Future<void> loadMore() => _loadPage(reset: false);

  Future<void> _loadPage({required bool reset}) async {
    if (isLoading || (!reset && !_hasMore)) return;
    final offset = reset ? 0 : _offset;
    if (spec.isKanji) {
      final r = await runGuarded(
        () => _repo.kanjiList(
            jlpt: spec.jlpt,
            grade: spec.grade,
            contains: spec.contains,
            limit: pageSize,
            offset: offset),
      );
      if (r != null) {
        final entries = {
          for (final entry in reset ? <KanjiEntry>[] : _kanji)
            entry.literal: entry
        };
        for (final entry in r) {
          entries[entry.literal] = entry;
        }
        _kanji = entries.values.toList();
        _offset = offset + r.length;
        _hasMore = r.length == pageSize;
      }
    } else {
      final r = await runGuarded(() => _repo.words(
          common: spec.common,
          jlpt: spec.jlpt,
          limit: pageSize,
          offset: offset));
      if (r != null) {
        final entries = {
          for (final entry in reset ? <WordEntry>[] : _words) entry.id: entry
        };
        for (final entry in r) {
          entries[entry.id] = entry;
        }
        _words = entries.values.toList();
        _offset = offset + r.length;
        _hasMore = r.length == pageSize;
      }
    }
    notifyListeners();
  }
}
