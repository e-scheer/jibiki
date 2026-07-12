import 'package:flutter/foundation.dart';

import '../core/session_store.dart';

enum ThemePalette { neopop, harmonie }

enum ThemeModeSetting { light, dark, system }

extension ThemePaletteX on ThemePalette {
  String get label => switch (this) {
        ThemePalette.neopop => 'Neo-pop',
        ThemePalette.harmonie => 'Harmonie',
      };
}

class ThemeController extends ChangeNotifier {
  ThemeController(this._store)
      : _palette = ThemePalette.values.firstWhere(
          (value) => value.name == _store.themePalette,
          orElse: () => ThemePalette.neopop,
        ),
        _mode = ThemeModeSetting.values.firstWhere(
          (value) => value.name == _store.themeMode,
          orElse: () => ThemeModeSetting.system,
        );

  final SessionStore _store;
  ThemePalette _palette;
  ThemeModeSetting _mode;

  ThemePalette get palette => _palette;
  ThemeModeSetting get mode => _mode;

  Future<void> setPalette(ThemePalette value) async {
    if (_palette == value) return;
    _palette = value;
    notifyListeners();
    await _store.setThemePalette(value.name);
  }

  Future<void> setMode(ThemeModeSetting value) async {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
    await _store.setThemeMode(value.name);
  }
}
