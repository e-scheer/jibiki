import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/rewards_viewmodel.dart';
import '../widgets/neo_pop.dart';

/// Session-summary hook: re-evaluates the burn once the session is complete
/// and celebrates a newly earned booster in place, without blocking anything.
/// Renders nothing when no milestone was reached.
class RewardsSessionHook extends StatefulWidget {
  const RewardsSessionHook({super.key});

  @override
  State<RewardsSessionHook> createState() => _RewardsSessionHookState();
}

class _RewardsSessionHookState extends State<RewardsSessionHook> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rewards = context.read<RewardsViewModel?>();
      if (rewards != null) unawaited(rewards.onStudyActivity());
    });
  }

  @override
  Widget build(BuildContext context) {
    final rewards = context.watch<RewardsViewModel?>();
    final earned = rewards?.justEarned;
    if (rewards == null || !rewards.available || earned == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: NeoCard(
        tone: NeoTone.acid,
        padding: const EdgeInsets.all(Insets.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.card_giftcard_rounded, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.boosterEarnedTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.boosterEarnedBody(earned.milestone),
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: NeoPrimaryButton(
                    label: l10n.boosterOpenAction,
                    tone: NeoTone.magenta,
                    icon: Icons.card_giftcard_rounded,
                    onTap: () {
                      rewards.consumeJustEarned();
                      context.push('/booster/${earned.id}');
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Consuming hides the banner; the booster stays on the shelf,
                // visible from the dashboard and the collection.
                TextButton(
                  onPressed: rewards.consumeJustEarned,
                  child: Text(
                    l10n.boosterOpenLater,
                    style: TextStyle(
                      color: context.jc.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
