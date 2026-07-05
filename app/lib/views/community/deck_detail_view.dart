import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/mnemonic.dart';
import '../../models/mnemonic_deck.dart';
import '../../repositories/mnemonic_deck_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/mnemonic_deck_viewmodel.dart';
import '../widgets/net_image.dart';
import '../widgets/status_views.dart';

class DeckDetailView extends StatelessWidget {
  const DeckDetailView({super.key, required this.deckId, this.owned = false});
  final int deckId;
  final bool owned;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => DeckDetailViewModel(ctx.read<MnemonicDeckRepository>(), deckId)..load(),
      child: _DeckDetail(owned: owned),
    );
  }
}

class _DeckDetail extends StatelessWidget {
  const _DeckDetail({required this.owned});
  final bool owned;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DeckDetailViewModel>();
    final deck = vm.deck;
    return Scaffold(
      appBar: AppBar(title: Text(deck?.title ?? 'Pack')),
      bottomNavigationBar: deck == null ? null : _BottomBar(deck: deck, owned: owned, vm: vm),
      body: vm.isLoading && deck == null
          ? const LoadingView()
          : vm.hasError
              ? ErrorRetry(message: vm.error!, onRetry: vm.load)
              : deck == null
                  ? const SizedBox.shrink()
                  : _content(context, deck, vm),
    );
  }

  Widget _content(BuildContext context, MnemonicDeck deck, DeckDetailViewModel vm) {
    final jc = context.jc;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (deck.hasCover)
          AspectRatio(
            aspectRatio: 1.6,
            child: NetImage(url: deck.coverUrl, cacheWidth: 900),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(deck.title, style: context.text.headlineSmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('by ${deck.authorName}', style: TextStyle(color: jc.muted, fontSize: 13.5)),
                  const Spacer(),
                  if (deck.isPublic)
                    InkWell(
                      onTap: () {
                        Haptics.light();
                        vm.like();
                      },
                      borderRadius: BorderRadius.circular(Radii.pill),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Icon(deck.liked ? Icons.favorite : Icons.favorite_border,
                                size: 20, color: deck.liked ? jc.ratingAgain : jc.ink),
                            if (deck.score > 0) ...[
                              const SizedBox(width: 5),
                              Text('${deck.score}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (deck.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(deck.description, style: TextStyle(color: jc.body, fontSize: 14.5, height: 1.4)),
              ],
              if (owned && !deck.isPublic) ...[
                const SizedBox(height: 12),
                _DraftBanner(deck: deck, vm: vm),
              ],
              const SizedBox(height: 18),
              Text('${deck.itemCount} ${deck.kind == 'kanji' ? 'kanji' : 'kana'}', style: context.text.titleMedium),
              const SizedBox(height: 12),
            ],
          ),
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [for (final m in deck.items) _ItemTile(mnemonic: m)],
        ),
      ],
    );
  }
}

class _DraftBanner extends StatelessWidget {
  const _DraftBanner({required this.deck, required this.vm});
  final MnemonicDeck deck;
  final DeckDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final pending = deck.isPending;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: jc.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        children: [
          Icon(pending ? Icons.hourglass_top : Icons.lock_outline, size: 20, color: jc.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pending
                  ? 'Submitted, waiting for review before it goes public.'
                  : 'This is a private draft. Publish it to share with the community.',
              style: TextStyle(color: jc.body, fontSize: 13),
            ),
          ),
          if (deck.isDraft) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                final status = await vm.publish();
                if (context.mounted && status != null) {
                  final msg = status == 'visible' ? 'Published, thank you!' : 'Submitted for review, thank you!';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
              child: const Text('Publish'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.mnemonic});
  final Mnemonic mnemonic;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Container(
        color: jc.surfaceAlt,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (mnemonic.hasImage)
              NetImage(
                  url: mnemonic.imageUrl,
                  cacheWidth: 300,
                  semanticLabel: 'Mnemonic drawing for ${mnemonic.character}',
                  errorBuilder: (_) => _glyph(jc))
            else
              _glyph(jc),
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: jc.ink.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(mnemonic.character,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glyph(JibikiColors jc) => Center(
        child: Text(mnemonic.character, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: jc.brand)),
      );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.deck, required this.owned, required this.vm});
  final MnemonicDeck deck;
  final bool owned;
  final DeckDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    // A private draft can't be studied by others; owners publish first.
    final canStudy = deck.isPublic || owned;
    return Container(
      decoration: BoxDecoration(
        color: jc.canvas,
        border: Border(top: BorderSide(color: jc.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: !canStudy || vm.enrolled
                  ? null
                  : () async {
                      final n = await vm.enroll();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(n > 0 ? 'Added $n cards to your study' : 'Already in your study')),
                        );
                      }
                    },
              style: vm.enrolled
                  ? FilledButton.styleFrom(
                      backgroundColor: jc.success,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: jc.success,
                      disabledForegroundColor: Colors.white,
                    )
                  : null,
              icon: Icon(vm.enrolled ? Icons.check : Icons.school_outlined, size: 20),
              label: Text(vm.enrolled ? 'In your study' : 'Study this pack'),
            ),
          ),
        ),
      ),
    );
  }
}
