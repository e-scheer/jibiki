import '../core/languages.dart';
import '../core/api_exception.dart';
import '../infrastructure/packs/pack_manager.dart';
import '../infrastructure/packs/pack_manifest.dart';
import '../models/enums.dart';
import '../repositories/dictionary_repository.dart';
import '../repositories/study_repository.dart';
import 'app_state.dart';
import 'base_view_model.dart';

enum OnboardingPlacement {
  fresh,
  hiragana,
  katakana,
  allKana,
  specific,
  jlpt5,
  jlpt4,
  jlpt3,
  jlpt2,
  jlpt1;

  int? get jlptLevel => switch (this) {
        jlpt5 => 5,
        jlpt4 => 4,
        jlpt3 => 3,
        jlpt2 => 2,
        jlpt1 => 1,
        _ => null,
      };
}

/// One optional download offered on the onboarding data step.
class PackOffer {
  PackOffer(
      {required this.id, required this.title, required this.blurb, this.info});

  final String id;
  final String title;
  final String blurb;

  /// Manifest entry when the server was reachable - carries the real sizes.
  final PackInfo? info;
  bool selected = false;
}

class OnboardingViewModel extends BaseViewModel {
  OnboardingViewModel(
    this._app,
    this._packs,
    this._study,
    this._dictionary,
  ) {
    _mode = _app.mode;
    _language = _app.mnemonicLanguage;
  }

  final AppState _app;
  final PackManager? _packs;
  final StudyRepository _study;
  final DictionaryRepository _dictionary;

  late AppMode _mode;
  late String _language;
  int _step = 0;
  OnboardingPlacement _placement = OnboardingPlacement.fresh;
  String _knownCharacters = '';
  List<PackOffer> _offers = [];
  bool _offersLoaded = false;

  AppMode get mode => _mode;
  String get language => _language;
  int get step => _step;
  List<PackOffer> get offers => _offers;
  bool get offersLoaded => _offersLoaded;

  /// The data step only exists where packs do (mobile).
  bool get hasDataStep => _packs != null;
  OnboardingPlacement get placement => _placement;
  String get knownCharacters => _knownCharacters;
  int get specificCharacterCount => _specificItems().length;
  bool get canContinuePlacement =>
      !isLoading &&
      (_placement != OnboardingPlacement.specific ||
          specificCharacterCount > 0);

  void selectMode(AppMode m) {
    if (isLoading) return;
    _mode = m;
    notifyListeners();
  }

  void selectLanguage(String code) {
    if (isLoading) return;
    _language = code;
    notifyListeners();
  }

  void selectPlacement(OnboardingPlacement value) {
    if (isLoading) return;
    _placement = value;
    if (hasError) clearError();
    notifyListeners();
  }

  void setKnownCharacters(String value) {
    if (isLoading) return;
    _knownCharacters = value;
    if (hasError) clearError();
    notifyListeners();
  }

  void toggleOffer(PackOffer offer, bool value) {
    if (isLoading) return;
    offer.selected = value;
    notifyListeners();
  }

  /// Advance to the data step and (re)build the offers for the chosen
  /// language. Manifest sizes come in when the server answers; the offers
  /// render immediately either way.
  Future<void> goToPlacementStep() async {
    if (isLoading) return;
    _step = 1;
    notifyListeners();
  }

  Future<void> goToDataStep() async {
    if (!canContinuePlacement) return;
    _step = 2;
    notifyListeners();
    _offersLoaded = false;
    await runGuarded(() async {
      final packs = _packs;
      if (packs == null) return;
      PacksManifest? manifest;
      try {
        manifest = await packs.checkUpdates();
      } catch (_) {
        manifest = null; // offline first launch: sizes show as estimates
      }
      // A mnemonic language without a packaged dictionary (community language)
      // falls back to offering the English gloss pack.
      var gloss = 'dict-locale-$_language';
      if (manifest != null && manifest.byId(gloss) == null) {
        gloss = 'dict-locale-$fallbackLanguage';
      }
      final core = manifest?.byId(corePackId);
      final glossInfo = manifest?.byId(gloss);
      var examples = 'examples-$_language';
      if (manifest != null && manifest.byId(examples) == null) {
        examples = 'examples-$fallbackLanguage';
      }
      // The core rides along with the first gloss pack; present them as one
      // "full dictionary" choice with the combined download size.
      final combined = glossInfo == null || core == null
          ? glossInfo
          : PackInfo(
              id: glossInfo.id,
              version: glossInfo.version,
              schemaVersion: glossInfo.schemaVersion,
              datasetRev: glossInfo.datasetRev,
              file: glossInfo.file,
              bytes: glossInfo.bytes + (packs.hasCore ? 0 : core.bytes),
              installedBytes: glossInfo.installedBytes +
                  (packs.hasCore ? 0 : core.installedBytes),
              sha256: glossInfo.sha256,
              sha256Db: glossInfo.sha256Db,
            );
      final glossLang = gloss.substring('dict-locale-'.length);
      _offers = [
        PackOffer(
          id: gloss,
          title: 'Full dictionary - ${mnemonicLanguageName(glossLang)}',
          blurb: glossLang == _language
              ? 'Every word and kanji with definitions, fully offline.'
              : 'Every word and kanji, fully offline (definitions in English - '
                  '${mnemonicLanguageName(_language)} isn\'t packaged yet).',
          info: combined,
        )..selected = true,
        PackOffer(
          id: examples,
          title: 'Example sentences',
          blurb: 'Real sentences on word pages, offline.',
          info: manifest?.byId(examples),
        )..selected = _mode == AppMode.dictionary,
        PackOffer(
          id: 'names',
          title: 'Proper names',
          blurb: 'People and place names in search results.',
          info: manifest?.byId('names'),
        )..selected = _mode == AppMode.dictionary,
      ];
      _offersLoaded = true;
    });
  }

  void backToProfileStep() {
    if (isLoading) return;
    _step = 0;
    notifyListeners();
  }

  void backToPlacementStep() {
    if (isLoading) return;
    _step = 1;
    notifyListeners();
  }

  /// Persist the profile; when [download] is set, fire the selected pack
  /// downloads and let them run in the background (progress lives in
  /// Settings → Offline & storage). Navigation home happens immediately.
  Future<bool> finish({bool download = false}) async {
    if (isLoading || !canContinuePlacement) return false;
    final completed = await runGuarded(() async {
      final items = await _placementItems();
      if (_placement != OnboardingPlacement.fresh && items.isEmpty) {
        throw ApiException(
          'We could not load this level. Check your connection and try again.',
        );
      }
      if (items.isNotEmpty) {
        await _study.bulkAdd(items, known: true);
      }
      await _app.completeOnboarding(
        mode: _mode,
        mnemonicLanguage: _language,
      );
      return true;
    });
    if (completed != true) return false;
    final packs = _packs;
    if (download && packs != null) {
      for (final offer in _offers) {
        if (offer.selected) {
          // Fire and forget - failures surface later on the storage screen.
          // ignore: discarded_futures
          packs.download(offer.id).catchError((_) {});
        }
      }
    }
    return true;
  }

  Future<List<({ItemType type, String ref})>> _placementItems() async {
    if (_placement == OnboardingPlacement.fresh) return const [];
    if (_placement == OnboardingPlacement.specific) return _specificItems();

    final jlpt = _placement.jlptLevel;
    if (jlpt != null) {
      // A learner placed at N3 also knows the earlier N5 and N4 sets. The
      // dictionary pack is the canonical source imported by import_jlpt.py.
      final batches = await Future.wait([
        for (var level = 5; level >= jlpt; level--)
          _dictionary.kanjiList(jlpt: level, limit: 1500),
      ]);
      final literals = <String>{
        for (final batch in batches)
          for (final entry in batch)
            if (entry.literal.isNotEmpty) entry.literal,
      };
      return [
        for (final literal in literals) (type: ItemType.kanji, ref: literal),
      ];
    }

    final kana = await _dictionary.kana();
    final refs = <String>{
      for (final entry in kana)
        if (entry.char.isNotEmpty &&
            (_placement == OnboardingPlacement.allKana ||
                (_placement == OnboardingPlacement.hiragana &&
                    entry.script == 'hiragana') ||
                (_placement == OnboardingPlacement.katakana &&
                    entry.script == 'katakana')))
          entry.char,
    };
    return [
      for (final ref in refs) (type: ItemType.kana, ref: ref),
    ];
  }

  List<({ItemType type, String ref})> _specificItems() {
    final items = <({ItemType type, String ref})>[];
    for (final char
        in _knownCharacters.runes.map(String.fromCharCode).toSet()) {
      final code = char.runes.single;
      final isKana = code >= 0x3040 && code <= 0x30ff;
      final isKanji = code >= 0x3400 && code <= 0x9fff;
      if (!isKana && !isKanji) continue;
      items.add((type: isKana ? ItemType.kana : ItemType.kanji, ref: char));
    }
    return items;
  }
}
