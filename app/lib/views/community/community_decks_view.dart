import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../repositories/mnemonic_deck_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/mnemonic_deck_viewmodel.dart';
import '../widgets/status_views.dart';
import '../widgets/neo_pop.dart';
import 'deck_card.dart';

/// Browse community packs of mnemonics, or your own. A pack is a shareable set of
/// drawings, the "propose as a deck" side of the drawing ecosystem.
class CommunityDecksView extends StatelessWidget {
  const CommunityDecksView({super.key, this.initialTab = 0});

  /// 0 = Community, 1 = Mine (deep-linked from "My submissions").
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final lang = context.read<AppState>().mnemonicLanguage;
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: context.jc.magenta,
          foregroundColor: context.jc.ink,
          toolbarHeight: 82,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.trText('Community')),
              const SizedBox(height: 3),
              Text(
                context.trText('Shared packs. Take, rate and improve.'),
                style: TextStyle(
                  color: context.jc.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: context.trText('Create a pack'),
              icon: const Icon(Icons.add_box_outlined),
              onPressed: () => context.push('/decks/new'),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: context.jc.canvas,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TabBar(
                labelColor: context.jc.ink,
                unselectedLabelColor: context.jc.ink,
                labelPadding: EdgeInsets.zero,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: context.jc.acid,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: context.jc.ink,
                      blurRadius: 0,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                tabs: [
                  _FilterTab(label: context.trText('Popular')),
                  _FilterTab(label: context.trText('My packs')),
                ],
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.jc.ink, width: 2.5),
        ),
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
    final jc = context.jc;

    if (vm.hasError) {
      return ListView(
          children: [ErrorRetry(message: vm.error!, onRetry: vm.load)]);
    }
    if (vm.isLoading && vm.decks.isEmpty) {
      return const SkeletonCardGrid(
        count: 6,
        maxCrossAxisExtent: 540,
        childAspectRatio: 3.45,
      );
    }
    if (vm.decks.isEmpty) {
      return EmptyHint(
        icon:
            mine ? Icons.collections_bookmark_outlined : Icons.explore_outlined,
        title: mine ? 'No packs yet' : 'No community packs yet',
        subtitle: mine
            ? 'Bundle your drawings into a pack and share it.'
            : 'Be the first to publish a pack of mascots.',
      );
    }
    return RefreshIndicator(
      color: jc.brand,
      onRefresh: vm.load,
      child: GridView.builder(
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
      ),
    );
  }
}
