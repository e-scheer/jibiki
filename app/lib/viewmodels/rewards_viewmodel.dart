import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/session_store.dart';
import '../core/telemetry.dart';
import '../infrastructure/local/local_rewards_store.dart';
import '../infrastructure/user_db_handle.dart';
import '../models/collection.dart';
import '../services/collection_catalog_loader.dart';
import '../theme/theme_controller.dart';

/// App-level state for the burn, booster shelf and card collection.
///
/// Native-only for now (the store lives in user.db); on web [available] stays
/// false and every surface hides itself. The collection is the source of
/// truth for cosmetic unlocks: after every refresh the unlocked palette ids
/// are pushed to the ThemeController.
class RewardsViewModel extends ChangeNotifier {
  RewardsViewModel({
    required UserDbHandle? userDb,
    required CollectionCatalogLoader loader,
    required ThemeController theme,
    required SessionStore session,
    void Function()? onLocalMutation,
    TelemetrySink? telemetry,
  })  : _userDb = userDb,
        _loader = loader,
        _theme = theme,
        _session = session,
        _onLocalMutation = onLocalMutation,
        _telemetry = telemetry ?? Telemetry.instance;

  final UserDbHandle? _userDb;
  final CollectionCatalogLoader _loader;
  final ThemeController _theme;
  final SessionStore _session;
  final void Function()? _onLocalMutation;
  final TelemetrySink _telemetry;
  LocalRewardsStore? _store;
  CollectionCatalog? _catalog;

  /// Loads the catalog and opens the store. Safe to call once at startup;
  /// failures leave the feature hidden rather than breaking the app.
  Future<void> init() async {
    final userDb = _userDb;
    if (userDb == null) return;
    try {
      final catalog = await _loader.load();
      _catalog = catalog;
      _store = LocalRewardsStore(
        userDb,
        catalog,
        onLocalMutation: _onLocalMutation,
      );
      await refresh();
    } catch (error, stack) {
      debugPrint('rewards init failed: $error\n$stack');
    }
  }

  BurnState _burn = BurnState.empty;
  List<BoosterGrant> _unopened = const [];
  Map<String, CollectionEntry> _collection = const {};
  BoosterGrant? _justEarned;
  bool _loaded = false;

  bool get available => _store != null && _catalog != null;
  CollectionCatalog? get catalog => _catalog;
  BurnState get burn => _burn;
  List<BoosterGrant> get unopened => _unopened;
  Map<String, CollectionEntry> get collection => _collection;
  bool get loaded => _loaded;

  /// The most recent grant not yet announced to the user. The session summary
  /// reads it once and consumes it, so the celebration shows exactly once.
  BoosterGrant? get justEarned => _justEarned;
  void consumeJustEarned() {
    if (_justEarned == null) return;
    _justEarned = null;
    notifyListeners();
  }

  /// Whether the full tear animation already played once; later openings get
  /// a skip button (spectacular the first time, quick every next time).
  bool get hasOpenedBefore => _session.boosterOpenedOnce;

  int ownedCount(String cardId) => _collection[cardId]?.count ?? 0;

  CollectionSetDef? get activeSet => _catalog?.activeSet;

  /// Distinct owned cards in [set] (duplicates count once).
  int ownedInSet(CollectionSetDef set) =>
      set.cards.where((card) => ownedCount(card.id) > 0).length;

  Future<void> refresh() async {
    final store = _store;
    if (store == null || _catalog == null) return;
    _burn = await store.burnState();
    _unopened = await store.grants(status: BoosterStatus.unopened);
    _collection = await store.collection();
    _loaded = true;
    await _pushUnlocks();
    notifyListeners();
  }

  /// Call after real study activity (a finished review session). Recomputes
  /// the burn, honors any newly reached milestone and stages the celebration.
  Future<void> onStudyActivity() async {
    final store = _store;
    if (store == null) return;
    final created = await store.evaluateMilestones();
    if (created.isNotEmpty) {
      _justEarned = created.last;
      for (final grant in created) {
        unawaited(_telemetry.logEvent(
          TelemetryEvent.boosterEarned,
          parameters: {'milestone': grant.milestone},
        ));
      }
    }
    await refresh();
  }

  Future<BoosterOpening> openBooster(String grantId) async {
    final store = _store;
    if (store == null) throw StateError('rewards unavailable');
    final opening = await store.open(grantId);
    await _session.setBoosterOpenedOnce();
    unawaited(_telemetry.logEvent(
      TelemetryEvent.boosterOpened,
      parameters: {
        'new_cards': opening.newCards.length,
        'duplicates': opening.duplicateCards.length,
      },
    ));
    await refresh();
    return opening;
  }

  /// Palette ids granted by owned consumable cards.
  Set<String> get unlockedPaletteIds {
    final catalog = _catalog;
    if (catalog == null) return const {};
    return {
      for (final entry in _collection.values)
        if (catalog.cardsById[entry.cardId]?.unlock case final unlock?
            when unlock.isPalette)
          unlock.value,
    };
  }

  Future<void> _pushUnlocks() =>
      _theme.setUnlockedPalettes(unlockedPaletteIds);

  /// Dev tools (debug builds only, no-op otherwise): backdate qualified days
  /// then run the real milestone evaluation, so grants come from the actual
  /// engine rather than being faked.
  Future<void> devSeedBurn(int days) async {
    final store = _store;
    if (!kDebugMode || store == null) return;
    await store.devSeedQualifiedDays(days);
    await onStudyActivity();
  }

  /// Dev tools (debug builds only): wipe seeded days, boosters and the whole
  /// collection on this device, then recompute (palette unlocks revoke too).
  Future<void> devResetRewards() async {
    final store = _store;
    if (!kDebugMode || store == null) return;
    await store.devReset();
    _justEarned = null;
    await refresh();
  }

  /// The consumable card that unlocks [paletteId], for the settings screen to
  /// explain how a locked palette is earned.
  CollectionCardDef? unlockCardForPalette(String paletteId) {
    final catalog = _catalog;
    if (catalog == null) return null;
    for (final card in catalog.cardsById.values) {
      final unlock = card.unlock;
      if (unlock != null && unlock.isPalette && unlock.value == paletteId) {
        return card;
      }
    }
    return null;
  }
}
