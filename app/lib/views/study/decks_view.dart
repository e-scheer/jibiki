import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../models/deck.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/decks_viewmodel.dart';
import '../widgets/status_views.dart';

/// The Study home: pick a whole set to study, no adding items one by one.
class DecksView extends StatelessWidget {
  const DecksView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => DecksViewModel(ctx.read<StudyRepository>())..load(),
      child: const _Decks(),
    );
  }
}

class _Decks extends StatelessWidget {
  const _Decks();

  Future<void> _open(BuildContext context, DecksViewModel vm, Deck deck) async {
    Haptics.light();
    final ok = await vm.enroll(deck);
    if (!ok || !context.mounted) return;
    await context.push('/session?deck=${deck.id}&title=${Uri.encodeComponent(deck.title)}');
    if (context.mounted) vm.load();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DecksViewModel>();
    final jc = context.jc;
    final due = vm.stats.dueNow;
    final loading = vm.isLoading && vm.decks.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Study')),
      body: BoundedContent(
        child: RefreshIndicator(
        color: jc.brand,
        onRefresh: vm.load,
        child: vm.hasError
            ? ListView(children: [ErrorRetry(message: vm.error!, onRetry: vm.load)])
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  loading
                      ? const Skeleton(height: 82, radius: Radii.lg)
                      : _DueHero(due: due, streak: vm.stats.streak),
                  const SizedBox(height: 22),
                  Text('Decks', style: context.text.titleLarge),
                  const SizedBox(height: 4),
                  Text('Study a whole set. It paces itself.',
                      style: TextStyle(color: jc.muted, fontSize: 13.5)),
                  const SizedBox(height: 14),
                  if (loading)
                    const SkeletonCardGrid(
                      shrinkWrap: true,
                      maxCrossAxisExtent: 220,
                      childAspectRatio: 0.98,
                      count: 4,
                      padding: EdgeInsets.zero,
                    )
                  else
                    GridView.extent(
                      maxCrossAxisExtent: 220, // 2 cols on phones, more as the screen widens
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.98,
                      children: [
                        for (final deck in vm.decks)
                          _DeckCard(deck: deck, busy: vm.busyDeck == deck.id, onTap: () => _open(context, vm, deck)),
                      ],
                    ),
                  const SizedBox(height: 26),
                  const _CommunityPacksCard(),
                ],
              ),
        ),
      ),
    );
  }
}

/// A community entry point in the Study tab: browse or create shareable packs of
/// hand-drawn mnemonics.
class _CommunityPacksCard extends StatelessWidget {
  const _CommunityPacksCard();

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: jc.instaLinear,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Community packs',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 2),
          const Text('Draw mascots, bundle them into a pack, and share it, or study one someone else made.',
              style: TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: jc.ink),
                  onPressed: () {
                    Haptics.light();
                    context.push('/decks/community');
                  },
                  child: const Text('Browse'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                  ),
                  onPressed: () {
                    Haptics.light();
                    context.push('/decks/new');
                  },
                  child: const Text('Create'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DueHero extends StatelessWidget {
  const _DueHero({required this.due, required this.streak});
  final int due;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final nothing = due == 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: nothing ? null : jc.instaLinear,
        color: nothing ? jc.surface : null,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: nothing ? jc.hairline : Colors.transparent),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nothing ? 'All caught up' : '$due due now',
                  style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800,
                    color: nothing ? jc.ink : Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                if (streak > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department_rounded,
                          size: 15, color: nothing ? jc.warn : Colors.white),
                      const SizedBox(width: 4),
                      Text('$streak day streak',
                          style: TextStyle(
                              color: nothing ? jc.body : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5)),
                    ],
                  )
                else
                  Text('Build a streak today',
                      style: TextStyle(
                          color: nothing ? jc.muted : Colors.white,
                          fontWeight: nothing ? FontWeight.w400 : FontWeight.w500,
                          fontSize: 13.5)),
              ],
            ),
          ),
          if (!nothing)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: jc.brand),
              onPressed: () async {
                Haptics.light();
                await context.push('/session');
              },
              child: const Text('Review'),
            ),
        ],
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.deck, required this.busy, required this.onTap});
  final Deck deck;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Material(
      color: jc.surface,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: jc.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(color: jc.brandSoft, borderRadius: BorderRadius.circular(Radii.md)),
                    alignment: Alignment.center,
                    child: Text(deck.icon, style: TextStyle(fontSize: 24, color: jc.brand, fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  if (busy)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  else if (deck.due > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: jc.brand, borderRadius: BorderRadius.circular(Radii.pill)),
                      child: Text('${deck.due}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                ],
              ),
              const Spacer(),
              Text(deck.title, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(deck.subtitle, style: TextStyle(color: jc.muted, fontSize: 12.5), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              _Progress(deck: deck),
            ],
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.deck});
  final Deck deck;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final label = deck.total == 0
        ? (deck.isFilter ? '-' : 'empty')
        : '${deck.studied}/${deck.total}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: LinearProgressIndicator(
            value: deck.progress,
            minHeight: 6,
            backgroundColor: jc.surfaceAlt,
            color: jc.ratingGood,
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(color: jc.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
