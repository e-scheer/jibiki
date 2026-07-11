import '../core/languages.dart';
import '../infrastructure/packs/pack_manager.dart';
import '../infrastructure/packs/pack_manifest.dart';
import '../models/enums.dart';
import 'app_state.dart';
import 'base_view_model.dart';

/// One optional download offered on the onboarding data step.
class PackOffer {
  PackOffer({required this.id, required this.title, required this.blurb, this.info});

  final String id;
  final String title;
  final String blurb;

  /// Manifest entry when the server was reachable - carries the real sizes.
  final PackInfo? info;
  bool selected = false;
}

class OnboardingViewModel extends BaseViewModel {
  OnboardingViewModel(this._app, this._packs) {
    _mode = _app.mode;
    _language = _app.mnemonicLanguage;
  }

  final AppState _app;
  final PackManager? _packs;

  late AppMode _mode;
  late String _language;
  int _step = 0;
  List<PackOffer> _offers = [];
  bool _offersLoaded = false;

  AppMode get mode => _mode;
  String get language => _language;
  int get step => _step;
  List<PackOffer> get offers => _offers;
  bool get offersLoaded => _offersLoaded;

  /// The data step only exists where packs do (mobile).
  bool get hasDataStep => _packs != null;

  void selectMode(AppMode m) {
    _mode = m;
    notifyListeners();
  }

  void selectLanguage(String code) {
    _language = code;
    notifyListeners();
  }

  void toggleOffer(PackOffer offer, bool value) {
    offer.selected = value;
    notifyListeners();
  }

  /// Advance to the data step and (re)build the offers for the chosen
  /// language. Manifest sizes come in when the server answers; the offers
  /// render immediately either way.
  Future<void> goToDataStep() async {
    _step = 1;
    notifyListeners();
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
    notifyListeners();
  }

  void backToProfileStep() {
    _step = 0;
    notifyListeners();
  }

  /// Persist the profile; when [download] is set, fire the selected pack
  /// downloads and let them run in the background (progress lives in
  /// Settings → Offline & storage). Navigation home happens immediately.
  Future<bool> finish({bool download = false}) async {
    await runGuarded(
        () => _app.completeOnboarding(mode: _mode, mnemonicLanguage: _language));
    if (hasError) return false;
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
}
