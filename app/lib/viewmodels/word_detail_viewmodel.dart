import '../models/enums.dart';
import '../models/word.dart';
import '../repositories/dictionary_repository.dart';
import '../repositories/study_repository.dart';
import 'base_view_model.dart';

class WordDetailViewModel extends BaseViewModel {
  WordDetailViewModel(this._dict, this._study, this.wordId);
  final DictionaryRepository _dict;
  final StudyRepository _study;
  final int wordId;

  WordEntry? _word;
  WordEntry? get word => _word;

  bool _added = false;
  bool get added => _added;

  Future<void> load() async {
    final w = await runGuarded(() => _dict.word(wordId));
    if (w != null) _word = w;
  }

  Future<bool> addToStudy() async {
    await runGuarded(() => _study.addCard(ItemType.word, wordId.toString()));
    if (!hasError) _added = true;
    return !hasError;
  }
}
