import '../models/enums.dart';
import '../models/kanji.dart';
import '../models/word.dart';
import '../repositories/dictionary_repository.dart';
import '../repositories/study_repository.dart';
import 'base_view_model.dart';

class KanjiDetailViewModel extends BaseViewModel {
  KanjiDetailViewModel(this._dict, this._study, this.literal);
  final DictionaryRepository _dict;
  final StudyRepository _study;
  final String literal;

  KanjiEntry? _kanji;
  KanjiEntry? get kanji => _kanji;

  // Parse the kanji's associated words once (the detail view rebuilds on every
  // notify, parsing this JSON in build() would re-run each time).
  List<WordEntry>? _words;
  List<WordEntry> get words {
    final k = _kanji;
    if (k == null) return const [];
    return _words ??= k.words.map((e) => WordEntry.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  bool _added = false;
  bool get added => _added;

  Future<void> load() async {
    final k = await runGuarded(() => _dict.kanji(literal));
    if (k != null) {
      _kanji = k;
      _words = null; // invalidate cache for the new kanji
    }
  }

  Future<bool> addToStudy() async {
    await runGuarded(() => _study.addCard(ItemType.kanji, literal));
    if (!hasError) _added = true;
    return !hasError;
  }
}
