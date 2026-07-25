import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/rewards_viewmodel.dart';
import '../rewards/burn_booster_panel.dart';
import '../widgets/neo_pop.dart';

/// Debug-only playground for the burn/booster/collection system: backdate
/// qualified days through the real engine and reset everything. The route
/// exists in every build, but outside debug mode the screen renders nothing
/// actionable, and the settings entry that leads here is debug-gated.
class DevToolsView extends StatelessWidget {
  const DevToolsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final jc = context.jc;
    final rewards = context.watch<RewardsViewModel>();

    return Scaffold(
      body: SafeArea(
        child: BoundedContent(
          maxWidth: 640,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              Row(
                children: [
                  NeoIconButton(
                    icon: Icons.arrow_back_rounded,
                    label: MaterialLocalizations.of(context).backButtonTooltip,
                    onTap: () {
                      final navigator = Navigator.of(context);
                      navigator.canPop() ? navigator.pop() : context.go('/');
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.devToolsTitle,
                          style: context.text.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.devToolsHelp,
                          style: TextStyle(
                            color: jc.body,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (!kDebugMode || !rewards.available) ...[
                NeoCard(
                  padding: const EdgeInsets.all(Insets.base),
                  child: Text(
                    l10n.devNativeOnly,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ] else ...[
                const BurnBoosterPanel(),
                const SizedBox(height: 18),
                for (final days in const [3, 7, 30]) ...[
                  NeoPrimaryButton(
                    label: l10n.devAddBurnDays(days),
                    icon: Icons.local_fire_department_rounded,
                    tone: NeoTone.acid,
                    onTap: () => _seed(context, days),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                NeoPrimaryButton(
                  label: l10n.devResetRewards,
                  icon: Icons.restart_alt_rounded,
                  tone: NeoTone.paper,
                  onTap: () => _reset(context),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.devResetRewardsHelp,
                  style: TextStyle(
                    color: jc.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: jc.muted),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        l10n.devSyncNote,
                        style: TextStyle(
                          color: jc.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _seed(BuildContext context, int days) async {
    final rewards = context.read<RewardsViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.devSeedApplied;
    await rewards.devSeedBurn(days);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reset(BuildContext context) async {
    final rewards = context.read<RewardsViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.devResetDone;
    await rewards.devResetRewards();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
