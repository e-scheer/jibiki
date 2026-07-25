import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/telemetry.dart';
import '../../l10n/l10n.dart';
import '../../models/collection.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/rewards_viewmodel.dart';
import '../widgets/neo_pop.dart';
import 'collection_card_art.dart';
import 'collection_card_detail.dart';

enum _CollectionFilter { all, owned, missing, duplicates }

/// The album: progression per set, filters, and the card grid. The same
/// composition scales from a 2-column phone grid to a wide tablet grid; the
/// card detail opens as a sheet (phone) or dialog (tablet).
class CollectionView extends StatefulWidget {
  const CollectionView({super.key});

  @override
  State<CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<CollectionView> {
  _CollectionFilter _filter = _CollectionFilter.all;

  @override
  void initState() {
    super.initState();
    unawaited(
        Telemetry.instance.logEvent(TelemetryEvent.collectionViewed));
    // Recompute burn + shelf when landing here (cheap, local).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<RewardsViewModel>().refresh());
    });
  }

  @override
  Widget build(BuildContext context) {
    final rewards = context.watch<RewardsViewModel>();
    final l10n = context.l10n;
    final jc = context.jc;
    final set = rewards.activeSet;
    final language = Localizations.localeOf(context).languageCode;

    if (!rewards.available || set == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Insets.xl),
              child: Text(
                l10n.collectionEmptyBody,
                textAlign: TextAlign.center,
                style: TextStyle(color: jc.body, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      );
    }

    final cards = _filtered(set, rewards);
    final ownedDistinct = rewards.ownedInSet(set);
    final shinyOwned = set
        .byRarity(CardRarity.shiny)
        .where((card) => rewards.ownedCount(card.id) > 0)
        .length;

    return Scaffold(
      body: SafeArea(
        child: NeoContent(
          padding: EdgeInsets.zero,
          maxWidth: 1080,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NeoIconButton(
                            icon: Icons.arrow_back_rounded,
                            label: MaterialLocalizations.of(context)
                                .backButtonTooltip,
                            onTap: () {
                              final navigator = Navigator.of(context);
                              if (navigator.canPop()) {
                                navigator.pop();
                              } else {
                                context.go('/');
                              }
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.collectionTitle,
                                  style:
                                      context.text.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  set.name.resolve(language),
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
                      const SizedBox(height: 14),
                      NeoCard(
                        padding: const EdgeInsets.all(Insets.base),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l10n.collectionSetProgress(
                                        ownedDistinct, set.cards.length),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                NeoBadge(
                                  l10n.collectionShinyCount(shinyOwned),
                                  tone: NeoTone.magenta,
                                  icon: Icons.auto_awesome_rounded,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            NeoProgress(
                              value: set.cards.isEmpty
                                  ? 0
                                  : ownedDistinct / set.cards.length,
                              tone: NeoTone.magenta,
                            ),
                            if (rewards.unopened.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              NeoPrimaryButton(
                                label: l10n
                                    .boosterToOpen(rewards.unopened.length),
                                icon: Icons.card_giftcard_rounded,
                                onTap: () => context.push(
                                    '/booster/${rewards.unopened.first.id}'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      NeoSegmentedControl<_CollectionFilter>(
                        height: 48,
                        segments: [
                          NeoSegment(
                              _CollectionFilter.all, l10n.collectionFilterAll),
                          NeoSegment(_CollectionFilter.owned,
                              l10n.collectionFilterOwned),
                          NeoSegment(_CollectionFilter.missing,
                              l10n.collectionFilterMissing),
                          NeoSegment(_CollectionFilter.duplicates,
                              l10n.collectionFilterDuplicates),
                        ],
                        selected: _filter,
                        onChanged: (value) => setState(() => _filter = value),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: kCollectionCardAspect,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final card = cards[index];
                      final copies = rewards.ownedCount(card.id);
                      return _CollectionTile(card: card, copies: copies);
                    },
                    childCount: cards.length,
                  ),
                ),
              ),
              if (cards.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.xxl),
                    child: Text(
                      l10n.collectionEmptyBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: jc.muted, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<CollectionCardDef> _filtered(
      CollectionSetDef set, RewardsViewModel rewards) {
    return [
      for (final card in set.cards)
        if (switch (_filter) {
          _CollectionFilter.all => true,
          _CollectionFilter.owned => rewards.ownedCount(card.id) > 0,
          _CollectionFilter.missing => rewards.ownedCount(card.id) == 0,
          _CollectionFilter.duplicates => rewards.ownedCount(card.id) > 1,
        })
          card,
    ];
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.card, required this.copies});

  final CollectionCardDef card;
  final int copies;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final owned = copies > 0;
    return Semantics(
      button: true,
      label: owned
          ? card.nameJa
          : '${card.nameJa}, ${l10n.collectionCardNotOwned}',
      child: GestureDetector(
        onTap: () {
          Haptics.tick();
          showCollectionCardDetail(context, card: card, copies: copies);
        },
        child: Stack(
          children: [
            CollectionCardFace(
                card: card, owned: owned, copies: copies, dense: true),
            if (copies > 1)
              Positioned(
                top: 6,
                left: 6,
                child: NeoBadge('×$copies', tone: NeoTone.lime),
              ),
          ],
        ),
      ),
    );
  }
}
