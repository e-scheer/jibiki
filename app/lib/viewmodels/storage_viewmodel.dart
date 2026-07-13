import 'package:flutter/foundation.dart';

import '../core/languages.dart';
import '../infrastructure/packs/pack_manager.dart';
import '../infrastructure/packs/pack_manifest.dart';
import '../sync/sync_engine.dart';

/// One row on the Offline & storage screen: a pack the user can hold locally,
/// merged from the server manifest (what exists) and the registry (what is
/// installed).
class PackRow {
  const PackRow({
    required this.id,
    required this.title,
    required this.subtitle,
    this.installed,
    this.available,
    this.progress,
  });

  final String id;
  final String title;
  final String subtitle;
  final InstalledPack? installed;
  final PackInfo? available;
  final PackProgress? progress;

  bool get isInstalled => installed != null;
  bool get isBusy => progress != null;
  bool get updateAvailable =>
      installed != null &&
      available != null &&
      available!.version != installed!.version;
  bool get canDownload => !isInstalled && available != null && !isBusy;
  bool get canDelete => isInstalled && id != basePackId;
}

/// Wraps PackManager + SyncEngine for the storage screen - pure presentation
/// state, all behavior stays in the managers.
class StorageViewModel extends ChangeNotifier {
  StorageViewModel(this._packs, this._sync) {
    _packs.addListener(notifyListeners);
    _sync?.addListener(notifyListeners);
  }

  final PackManager _packs;
  final SyncEngine? _sync;
  Object? _updateError;
  bool _checking = false;

  bool get checking => _checking;
  Object? get updateError => _updateError;
  SyncEngine? get sync => _sync;
  int get installedBytesTotal => _packs.installedBytesTotal;
  DateTime? get lastUpdateCheck => _packs.lastUpdateCheck;

  static String humanSize(int bytes) {
    if (bytes <= 0) return '-';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(bytes < 100 << 20 ? 1 : 0)} MB';
  }

  /// The rows to render: everything the manifest offers plus anything
  /// installed that the manifest no longer lists (still deletable), the
  /// bundled base first.
  List<PackRow> get rows {
    final available = _packs.available?.packs ?? const <PackInfo>[];
    final ids = <String>[
      basePackId,
      for (final p in available) p.id,
      for (final p in _packs.installed)
        if (p.id != basePackId && available.every((a) => a.id != p.id)) p.id,
    ];
    return [
      for (final id in {...ids}) _row(id)
    ];
  }

  PackRow _row(String id) {
    final installed = [
      for (final p in _packs.installed)
        if (p.id == id) p,
    ].firstOrNull;
    final available = _packs.available?.byId(id);
    return PackRow(
      id: id,
      title: _title(id, available),
      subtitle: _subtitle(id, installed, available),
      installed: installed,
      available: available,
      progress: _packs.progress[id],
    );
  }

  String _title(String id, PackInfo? info) {
    final fromManifest = info?.title['en'];
    if (fromManifest != null && fromManifest.isNotEmpty) return fromManifest;
    return switch (id) {
      basePackId => 'Essentials (built in)',
      corePackId => 'Dictionary core (Japanese data)',
      'names' => 'Proper names',
      _ when id.startsWith('examples-') => 'Example sentences',
      _ when id.startsWith('dict-locale-') =>
        'Definitions - ${mnemonicLanguageName(id.substring('dict-locale-'.length))}',
      _ when id.startsWith('mnemonics-') =>
        'Mnemonics - ${mnemonicLanguageName(id.substring('mnemonics-'.length))}',
      _ => id,
    };
  }

  String _subtitle(String id, InstalledPack? installed, PackInfo? available) {
    if (id == basePackId) {
      return 'Kana, JLPT kanji and common words. Always on your phone.';
    }
    if (installed != null) {
      return 'Installed · ${humanSize(installed.installedBytes)} · v${installed.version}';
    }
    if (available != null) {
      return 'Download ${humanSize(available.bytes)} · ${humanSize(available.installedBytes)} installed';
    }
    return '';
  }

  Future<void> checkUpdates() async {
    _checking = true;
    _updateError = null;
    notifyListeners();
    try {
      await _packs.checkUpdates(force: true);
    } catch (e) {
      _updateError = e;
    }
    _checking = false;
    notifyListeners();
  }

  Future<void> download(String id) async {
    _updateError = null;
    try {
      await _packs.download(id);
    } catch (e) {
      _updateError = e;
      notifyListeners();
    }
  }

  void cancel(String id) => _packs.cancelDownload(id);

  Future<void> delete(String id) async {
    _updateError = null;
    try {
      await _packs.delete(id);
    } catch (e) {
      _updateError = e;
      notifyListeners();
    }
  }

  Future<void> syncNow() async => _sync?.syncNow(source: 'manual');

  @override
  void dispose() {
    _packs.removeListener(notifyListeners);
    _sync?.removeListener(notifyListeners);
    super.dispose();
  }
}
