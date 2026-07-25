/// Cosmetic palette unlocks: base palettes are always available, reward
/// palettes stay locked until the matching consumable card is owned, and a
/// stale locked selection falls back to the default at startup.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/core/telemetry.dart';
import 'package:jibiki/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NullTelemetry implements TelemetrySink {
  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async {}
}

Future<SessionStore> _store([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return SessionStore(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('base palettes are unlocked, reward palettes are not', () async {
    final controller =
        ThemeController(await _store(), telemetry: _NullTelemetry());
    expect(controller.isUnlocked(ThemePalette.neopop), isTrue);
    expect(controller.isUnlocked(ThemePalette.harmonie), isTrue);
    expect(controller.isUnlocked(ThemePalette.sakura), isFalse);
    expect(controller.isUnlocked(ThemePalette.neon), isFalse);
  });

  test('selecting a locked palette is refused until it is unlocked', () async {
    final controller =
        ThemeController(await _store(), telemetry: _NullTelemetry());

    await controller.setPalette(ThemePalette.sakura);
    expect(controller.palette, ThemePalette.neopop);

    await controller.setUnlockedPalettes({'sakura'});
    expect(controller.isUnlocked(ThemePalette.sakura), isTrue);
    await controller.setPalette(ThemePalette.sakura);
    expect(controller.palette, ThemePalette.sakura);
  });

  test('a stored locked selection falls back to the default at startup',
      () async {
    // e.g. preferences kept a reward palette after the local data was reset.
    final controller = ThemeController(
      await _store({'theme_palette': 'neon'}),
      telemetry: _NullTelemetry(),
    );
    expect(controller.palette, ThemePalette.neopop);
  });

  test('revoking the palette in use falls back to the default', () async {
    final store = await _store();
    final controller = ThemeController(store, telemetry: _NullTelemetry());
    await controller.setUnlockedPalettes({'sakura'});
    await controller.setPalette(ThemePalette.sakura);
    expect(controller.palette, ThemePalette.sakura);

    // e.g. the dev tools wiping the collection.
    await controller.setUnlockedPalettes({});
    expect(controller.palette, ThemePalette.neopop);
    expect(store.themePalette, 'neopop');
  });

  test('unlocks persist through the session store mirror', () async {
    final store = await _store();
    final controller = ThemeController(store, telemetry: _NullTelemetry());
    await controller.setUnlockedPalettes({'neon', 'sakura'});
    expect(store.unlockedPalettes, ['neon', 'sakura']);

    // A fresh controller (cold start) sees the mirror before any DB load.
    final restarted = ThemeController(store, telemetry: _NullTelemetry());
    expect(restarted.isUnlocked(ThemePalette.neon), isTrue);
  });
}
