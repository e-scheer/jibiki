import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jibiki/l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../models/deck.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/decks_viewmodel.dart';
import '../widgets/pressable.dart';
import '../widgets/jibiki_brand.dart';
import '../widgets/status_views.dart';
import 'study_chrome.dart';

/// The review hub follows the NeoPop "Paquets" screen: a dense, readable list
/// of actionable packs first, then community discovery. Cards are rows rather
/// than a dashboard grid so due counts and the next action scan immediately.
class DecksView extends StatelessWidget {
  const DecksView({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (ctx) => DecksViewModel(ctx.read<StudyRepository>())..load(),
        child: const _Decks(),
      );
}

class _Decks extends StatelessWidget {
  const _Decks();

  Future<void> _open(BuildContext context, DecksViewModel vm, Deck deck) async {
    Haptics.light();
    final ok = await vm.enroll(deck);
    if (!ok || !context.mounted) return;
    await context.push(
      '/session?deck=${deck.id}&title=${Uri.encodeComponent(deck.title)}',
    );
    if (context.mounted) vm.load();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DecksViewModel>();
    final loading = vm.isLoading && vm.decks.isEmpty;
    final minutes = (vm.stats.dueNow * 0.65).ceil().clamp(1, 99);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: context.jc.brand,
          onRefresh: vm.load,
          child: vm.hasError
              ? ListView(
                  children: [ErrorRetry(message: vm.error!, onRetry: vm.load)],
                )
              : BoundedContent(
                  maxWidth: context.isExpanded ? 1040 : Breakpoints.maxContent,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      context.isExpanded ? 24 : 16,
                      16,
                      context.isExpanded ? 24 : 16,
                      28,
                    ),
                    children: [
                      _Header(
                        due: vm.stats.dueNow,
                        newCards: vm.stats.newRemaining,
                        minutes: minutes,
                      ),
                      const SizedBox(height: 18),
                      if (context.isExpanded)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _DeckList(
                                decks: vm.decks,
                                loading: loading,
                                busyDeck: vm.busyDeck,
                                onOpen: (deck) => _open(context, vm, deck),
                              ),
                            ),
                            const SizedBox(width: 28),
                            const Expanded(flex: 2, child: _CommunityColumn()),
                          ],
                        )
                      else ...[
                        _DeckList(
                          decks: vm.decks,
                          loading: loading,
                          busyDeck: vm.busyDeck,
                          onOpen: (deck) => _open(context, vm, deck),
                        ),
                        const SizedBox(height: 22),
                        const _CommunityColumn(),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.due,
    required this.newCards,
    required this.minutes,
  });

  final int due;
  final int newCards;
  final int minutes;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.trText('Review'),
                  style: context.text.headlineMedium?.copyWith(
                    color: context.jc.ink,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  due == 0
                      ? context.trText(
                          'Everything is up to date. Come back tomorrow.')
                      : context.trText(
                          '$due due in total. About $minutes minutes.',
                        ),
                  style: TextStyle(
                    color: context.jc.body,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                if (newCards > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    context.trText('$newCards new cards are available.'),
                    style: TextStyle(
                      color: context.jc.brand,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox.square(
            dimension: 46,
            child: Pressable(
              label: context.trText('Statistics'),
              onTap: () => context.push('/stats'),
              child: StudyPanel(
                shadow: 4,
                radius: 10,
                padding: EdgeInsets.zero,
                child: Icon(Icons.insights_outlined, color: context.jc.ink),
              ),
            ),
          ),
        ],
      );
}

class _DeckList extends StatelessWidget {
  const _DeckList({
    required this.decks,
    required this.loading,
    required this.busyDeck,
    required this.onOpen,
  });

  final List<Deck> decks;
  final bool loading;
  final String? busyDeck;
  final ValueChanged<Deck> onOpen;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Column(
        children: [
          Skeleton(height: 84, radius: 14),
          SizedBox(height: 12),
          Skeleton(height: 84, radius: 14),
          SizedBox(height: 12),
          Skeleton(height: 84, radius: 14),
        ],
      );
    }
    if (decks.isEmpty) {
      return StudyPanel(
        color: context.jc.lime,
        child: Row(
          children: [
            const Icon(Icons.done_all_rounded, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.trText('No packs need your attention right now.'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < decks.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _DeckRow(
            deck: decks[i],
            busy: busyDeck == decks[i].id,
            onTap: () => onOpen(decks[i]),
          ),
        ],
      ],
    );
  }
}

class _DeckRow extends StatelessWidget {
  const _DeckRow({
    required this.deck,
    required this.busy,
    required this.onTap,
  });

  final Deck deck;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = deck.due == 0 && deck.studied > 0;
    return Pressable(
      label: context.trText('Review ${deck.title}'),
      haptic: false,
      onTap: busy || done ? null : onTap,
      child: StudyPanel(
        shadow: 4,
        radius: 14,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done ? context.jc.lime : context.jc.acid,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.jc.ink, width: 2.5),
              ),
              child: busy
                  ? const NeoChaseLoader.small()
                  : Text(
                      done ? '✓' : '${deck.due}',
                      style: TextStyle(
                        color: context.jc.ink,
                        fontSize: done ? 22 : 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deck.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    done
                        ? context.trText('Up to date. Next batch tomorrow.')
                        : deck.due > 0
                            ? context.trText(
                                '${deck.due} due · ${deck.total - deck.studied} not studied',
                              )
                            : deck.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.jc.body,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (!done) ...[
              const SizedBox(width: 10),
              Container(
                constraints: const BoxConstraints(minHeight: 46),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.jc.ink,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  context.trText('Review'),
                  style: TextStyle(
                    color: context.jc.acid,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommunityColumn extends StatelessWidget {
  const _CommunityColumn();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.trText('Community packs'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _CommunityPack(
            title: context.trText('Kanji from train station signs'),
            meta: context.trText('by TokyoLine · 214 cards'),
            saves: '412',
          ),
          const SizedBox(height: 10),
          _CommunityPack(
            title: context.trText('Everyday onomatopoeia'),
            meta: context.trText('by MojiMoji · 120 cards'),
            saves: '286',
          ),
          const SizedBox(height: 12),
          StudyActionButton(
            label: context.trText('Browse all packs'),
            icon: Icons.chevron_right_rounded,
            color: context.jc.surface,
            shadow: 4,
            onTap: () => context.push('/decks/community'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => context.push('/decks/new'),
            icon: const Icon(Icons.add_rounded),
            label: Text(context.trText('Create a pack')),
          ),
        ],
      );
}

class _CommunityPack extends StatelessWidget {
  const _CommunityPack({
    required this.title,
    required this.meta,
    required this.saves,
  });

  final String title;
  final String meta;
  final String saves;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: () => context.push('/decks/community'),
        child: StudyPanel(
          radius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                meta,
                style: TextStyle(
                  color: context.jc.body,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.bookmark_border_rounded, size: 16),
                  const SizedBox(width: 5),
                  Text(
                    saves,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
