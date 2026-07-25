import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/session_store.dart';
import '../core/telemetry.dart';

enum ThemePalette { neopop, harmonie, sakura, neon }

enum ThemeModeSetting { light, dark, system }

extension ThemePaletteX on ThemePalette {
  String get label => switch (this) {
        ThemePalette.neopop => 'Neo-pop',
        ThemePalette.harmonie => 'Harmonie',
        ThemePalette.sakura => 'Sakura',
        ThemePalette.neon => 'Neon',
      };

  /// Palettes shipped unlocked. The others are cosmetic rewards, unlocked by
  /// the matching consumable collection card (docs/REWARDS.md); they are never
  /// purchasable and never gate any functionality.
  bool get isBase => switch (this) {
        ThemePalette.neopop || ThemePalette.harmonie => true,
        ThemePalette.sakura || ThemePalette.neon => false,
      };
}

class ThemeController extends ChangeNotifier {
  ThemeController(this._store, {TelemetrySink? telemetry})
      : _palette = ThemePalette.values.firstWhere(
          (value) => value.name == _store.themePalette,
          orElse: () => ThemePalette.neopop,
        ),
        _mode = ThemeModeSetting.values.firstWhere(
          (value) => value.name == _store.themeMode,
          orElse: () => ThemeModeSetting.system,
        ),
        _unlocked = _store.unlockedPalettes.toSet(),
        _telemetry = telemetry ?? Telemetry.instance {
    // A stored selection that is no longer unlocked (e.g. after a data reset)
    // falls back to the default instead of rendering a locked cosmetic.
    if (!isUnlocked(_palette)) _palette = ThemePalette.neopop;
  }

  final SessionStore _store;
  final TelemetrySink _telemetry;
  ThemePalette _palette;
  ThemeModeSetting _mode;
  Set<String> _unlocked;

  ThemePalette get palette => _palette;
  ThemeModeSetting get mode => _mode;

  bool isUnlocked(ThemePalette value) =>
      value.isBase || _unlocked.contains(value.name);

  Future<void> setPalette(ThemePalette value) async {
    if (_palette == value || !isUnlocked(value)) return;
    _palette = value;
    notifyListeners();
    await _store.setThemePalette(value.name);
    unawaited(_telemetry.logEvent(
      TelemetryEvent.themeChanged,
      parameters: {'palette': value.name, 'source': 'palette'},
    ));
  }

  /// Called by the rewards layer with the palette ids currently unlocked by
  /// the collection (the collection is the source of truth; this mirror is
  /// persisted so cold start renders correctly before the catalog loads).
  Future<void> setUnlockedPalettes(Set<String> values) async {
    if (setEquals(values, _unlocked)) return;
    _unlocked = {...values};
    // A reset can revoke the palette currently in use (e.g. the dev tools
    // wiping the collection): fall back instead of rendering a locked one.
    if (!isUnlocked(_palette)) {
      _palette = ThemePalette.neopop;
      await _store.setThemePalette(_palette.name);
    }
    notifyListeners();
    await _store.setUnlockedPalettes(_unlocked.toList()..sort());
  }

  Future<void> setMode(ThemeModeSetting value) async {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
    await _store.setThemeMode(value.name);
    unawaited(_telemetry.logEvent(
      TelemetryEvent.themeChanged,
      parameters: {'theme_mode': value.name, 'source': 'mode'},
    ));
  }
}
