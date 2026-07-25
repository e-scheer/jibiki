import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/rewards_viewmodel.dart';
import '../widgets/neo_pop.dart';
import '../widgets/pressable.dart';

/// The burn card: current burn, best burn, the last 7 days as a short chain,
/// distance to the next booster and the shelf of unopened boosters.
///
/// Tone rules (ANALYSIS_AND_PLAN.md): invite, never guilt. A missed day keeps
/// the best burn and the collection; the copy says "come back", not "you will
/// lose everything".
class BurnBoosterPanel extends StatelessWidget {
  const BurnBoosterPanel({super.key, this.compact = false});

  /// Compact keeps the panel one row high (for dense dashboard columns).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Nullable lookup: hosting surfaces (stats, dashboards) also render in
    // contexts without the rewards layer (web, isolated tests).
    final rewards = context.watch<RewardsViewModel?>();
    if (rewards == null || !rewards.available || !rewards.loaded) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final jc = context.jc;
    final burn = rewards.burn;

    return NeoCard(
      padding: const EdgeInsets.all(Insets.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department_rounded,
                  color: burn.qualifiedToday ? jc.coral : jc.muted, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.burnTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
              NeoBadge(l10n.burnBest(burn.best)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                l10n.burnDays(burn.current),
                style: context.text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: jc.ink,
                  height: 1,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _WeekChain(days: burn.recentDays)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            burn.qualifiedToday
                ? l10n.burnTodayCounted
                : l10n.burnComeBackToday,
            style: TextStyle(
              color: burn.qualifiedToday ? jc.success : jc.body,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            Text(
              l10n.burnNextBooster(burn.daysToNextMilestone),
              style: TextStyle(
                color: jc.muted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
          if (rewards.unopened.isNotEmpty) ...[
            const SizedBox(height: 12),
            NeoPrimaryButton(
              label: l10n.boosterToOpen(rewards.unopened.length),
              icon: Icons.card_giftcard_rounded,
              tone: NeoTone.magenta,
              onTap: () =>
                  context.push('/booster/${rewards.unopened.first.id}'),
            ),
            if (rewards.unopened.length >= 3) ...[
              const SizedBox(height: 6),
              Text(
                l10n.boosterShelfFull,
                style: TextStyle(
                  color: jc.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
          if (!compact) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Pressable(
                label: l10n.collectionTitle,
                onTap: () => context.push('/collection'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.grid_view_rounded, size: 16, color: jc.brand),
                    const SizedBox(width: 6),
                    Text(
                      l10n.collectionTitle,
                      style: TextStyle(
                        color: jc.brand,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact burn indicator for the home headers (brand background): flame,
/// day count and, when boosters wait on the shelf, a gift badge. Tapping it
/// opens the collection. Falls back to nothing while rewards are unavailable
/// (web) so the header keeps its plain streak text there.
class BurnChip extends StatelessWidget {
  const BurnChip({super.key});

  @override
  Widget build(BuildContext context) {
    final rewards = context.watch<RewardsViewModel?>();
    if (rewards == null || !rewards.available || !rewards.loaded) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final jc = context.jc;
    final burn = rewards.burn;
    final waiting = rewards.unopened.length;
    return Pressable(
      label: '${l10n.burnTitle}: ${l10n.burnDays(burn.current)}',
      onTap: () => context.push('/collection'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: jc.ink.withValues(alpha: .22),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 16,
              color: burn.qualifiedToday
                  ? jc.acid
                  : jc.surface.withValues(alpha: .85),
            ),
            const SizedBox(width: 5),
            Text(
              '${burn.current}',
              style: TextStyle(
                color: jc.surface,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (waiting > 0) ...[
              const SizedBox(width: 8),
              Icon(Icons.card_giftcard_rounded, size: 15, color: jc.acid),
              const SizedBox(width: 3),
              Text(
                '$waiting',
                style: TextStyle(
                  color: jc.surface,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekChain extends StatelessWidget {
  const _WeekChain({required this.days});

  /// Oldest first, true = qualified day.
  final List<bool> days;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (final qualified in days)
            Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(left: 5),
              decoration: BoxDecoration(
                color: qualified ? jc.coral : jc.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: jc.ink, width: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
