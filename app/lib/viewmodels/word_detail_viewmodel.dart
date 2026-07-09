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

  // none | learning | known - drives the detail Study / I-know-it toggles.
  String _status = 'none';
  String get status => _status;

  Future<void> load() async {
    final w = await runGuarded(() => _dict.word(wordId));
    if (w != null) _word = w;
    final states = await runGuarded(() => _study.studyStates(type: ItemType.word), silent: true);
    if (states != null) {
      final s = states[wordId.toString()];
      _status = s == null ? 'none' : (s >= 2 ? 'known' : 'learning');
      notifyListeners();
    }
  }

  /// Toggle this word to [target] (none | learning | known); optimistic, then
  /// reconciles with the server (or reverts on failure).
  Future<void> setStatus(String target) async {
    final prev = _status;
    _status = target;
    notifyListeners();
    final res = await runGuarded(
        () => _study.setStatus(ItemType.word, wordId.toString(), target), silent: true);
    _status = res ?? prev;
    notifyListeners();
  }
}
