import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../repositories/mnemonic_deck_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/mnemonic_deck_viewmodel.dart';
import '../widgets/status_views.dart';
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
          title: Text(context.trText('Packs')),
          actions: [
            IconButton(
              tooltip: context.trText('Create a pack'),
              icon: const Icon(Icons.add_box_outlined),
              onPressed: () => context.push('/decks/new'),
            ),
          ],
          bottom: TabBar(
            labelColor: context.jc.ink,
            unselectedLabelColor: context.jc.muted,
            indicatorColor: context.jc.ink,
            indicatorWeight: 1.5,
            tabs: const [Tab(text: 'Community'), Tab(text: 'Mine')],
          ),
        ),
        body: TabBarView(
          children: [
            _DecksTab(language: lang, mine: false),
            const _DecksTab(language: null, mine: true),
          ],
        ),
      ),
    );
  }
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
          count: 6, crossAxisCount: 2, childAspectRatio: 0.72);
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
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.72,
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
