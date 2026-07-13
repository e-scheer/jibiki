import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../repositories/mnemonic_deck_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/mnemonic_deck_viewmodel.dart';
import '../auth/auth_required_sheet.dart';
import '../widgets/status_views.dart';
import '../widgets/neo_pop.dart';
import 'deck_card.dart';

/// Browse community packs of mnemonics, or your own. A pack is a shareable set of
/// drawings, the "propose as a deck" side of the drawing ecosystem.
class CommunityDecksView extends StatelessWidget {
  const CommunityDecksView(
      {super.key, this.initialTab = 0, this.showBack = false});

  /// 0 = Community, 1 = Mine (deep-linked from "My submissions").
  final int initialTab;
  final bool showBack;

  Widget? _back(BuildContext context) => showBack
      ? NeoIconButton(
          icon: Icons.arrow_back_rounded,
          label: context.trText('Back'),
          onTap: () => context.canPop() ? context.pop() : context.go('/'),
        )
      : null;

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AppState>().isAuthenticated) {
      return Scaffold(
        body: Column(
          children: [
            NeoPageHeader(
              title: context.trText('Community'),
              subtitle: context.trText('Shared packs. Take, rate and improve.'),
              tone: NeoTone.magenta,
              leading: _back(context),
            ),
            Expanded(
              child: AuthRequiredPanel(
                title: context.trText('Your community starts here'),
                description: context.trText(
                  'Sign in to explore, save and publish mnemonic packs with the community.',
                ),
                icon: Icons.groups_rounded,
              ),
            ),
          ],
        ),
      );
    }
    final lang = context.read<AppState>().mnemonicLanguage;
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        body: Column(
          children: [
            NeoPageHeader(
              title: context.trText('Community'),
              subtitle: context.trText(
                'Shared packs. Take, rate and improve.',
              ),
              tone: NeoTone.magenta,
              leading: _back(context),
              trailing: NeoIconButton(
                icon: Icons.add_box_outlined,
                label: context.trText('Create a pack'),
                onTap: () => context.push('/decks/new'),
              ),
            ),
            Container(
              color: context.jc.canvas,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.jc.surface,
                  border: Border.all(color: context.jc.ink, width: 2.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  labelColor: context.jc.ink,
                  unselectedLabelColor: context.jc.ink,
                  labelPadding: EdgeInsets.zero,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorAnimation: TabIndicatorAnimation.elastic,
                  indicator: BoxDecoration(
                    color: context.jc.acid,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.jc.ink, width: 2.5),
                  ),
                  tabs: [
                    _FilterTab(label: context.trText('Popular')),
                    _FilterTab(label: context.trText('My packs')),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _DecksTab(language: lang, mine: false),
                  const _DecksTab(language: null, mine: true),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: NeoPrimaryButton(
                label: context.trText('Propose a pack'),
                icon: Icons.add_rounded,
                tone: NeoTone.magenta,
                onTap: () => context.push('/decks/new'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        height: 42,
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      );
}

class _DecksTab extends StatelessWidget {
  const _DecksTab({required this.language, required this.mine});
  final String? language;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CommunityDecksViewModel(
          ctx.read<MnemonicDeckRepository>(),
          language: language,
          mine: mine)
        ..load(),
      child: _DecksGrid(mine: mine),
    );
  }
}

class _DecksGrid extends StatelessWidget {
  const _DecksGrid({required this.mine});
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CommunityDecksViewModel>();

    final Widget content;
    if (vm.isLoading && vm.decks.isEmpty) {
      content = const SkeletonCardGrid(
        count: 6,
        maxCrossAxisExtent: 540,
        childAspectRatio: 3.45,
      );
    } else if (vm.hasError) {
      content = CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorRetry(message: vm.error!, onRetry: vm.load),
          ),
        ],
      );
    } else if (vm.decks.isEmpty) {
      content = CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyHint(
              icon: mine
                  ? Icons.collections_bookmark_outlined
                  : Icons.explore_outlined,
              title: mine ? 'No packs yet' : 'No community packs yet',
              subtitle: mine
                  ? 'Bundle your drawings into a pack and share it.'
                  : 'Be the first to publish a pack of mascots.',
            ),
          ),
        ],
      );
    } else {
      content = GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 540,
          mainAxisSpacing: 10,
          crossAxisSpacing: 12,
          mainAxisExtent: 106,
        ),
        itemCount: vm.decks.length,
        itemBuilder: (_, i) {
          final deck = vm.decks[i];
          return DeckCard(
            deck: deck,
            onTap: () => context
                .push('/decks/community/${deck.id}?owned=${mine ? 1 : 0}'),
            onLike: deck.isPublic ? () => vm.like(deck) : null,
          );
        },
      );
    }

    return NeoRefreshIndicator(
      semanticLabel: context.trText('Refresh community packs'),
      onRefresh: vm.load,
      child: content,
    );
  }
}
