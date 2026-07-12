import 'package:flutter/material.dart';
import 'package:jibiki/l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../models/mnemonic.dart';
import '../../models/mnemonic_deck.dart';
import '../../repositories/mnemonic_deck_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/mnemonic_deck_viewmodel.dart';
import '../widgets/neo_pop.dart';
import '../widgets/net_image.dart';
import '../widgets/status_views.dart';

class DeckDetailView extends StatelessWidget {
  const DeckDetailView({super.key, required this.deckId, this.owned = false});

  final int deckId;
  final bool owned;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          DeckDetailViewModel(ctx.read<MnemonicDeckRepository>(), deckId)
            ..load(),
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
      body: Column(
        children: [
          NeoPageHeader(
            title: deck?.title ?? context.trText('Pack'),
            subtitle: deck == null
                ? context.trText('Community mnemonic pack')
                : context.trText('by ${deck.authorName}'),
            tone: NeoTone.magenta,
            leading: NeoIconButton(
              icon: Icons.arrow_back,
              label: context.trText('Back'),
              onTap: () => Navigator.of(context).pop(),
            ),
            trailing: deck != null && deck.isPublic
                ? _LikeButton(deck: deck, vm: vm)
                : null,
          ),
          Expanded(
            child: vm.isLoading && deck == null
                ? const LoadingView()
                : vm.hasError
                    ? ErrorRetry(message: vm.error!, onRetry: vm.load)
                    : deck == null
                        ? const SizedBox.shrink()
                        : _DeckContent(deck: deck, owned: owned, vm: vm),
          ),
          if (deck != null) _BottomBar(deck: deck, owned: owned, vm: vm),
        ],
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.deck, required this.vm});

  final MnemonicDeck deck;
  final DeckDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: NeoCard(
        tone: deck.liked ? NeoTone.acid : NeoTone.paper,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        radius: 10,
        semanticLabel: context.trText('Like'),
        onTap: vm.like,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              deck.liked ? Icons.favorite : Icons.favorite_border,
              size: 20,
            ),
            if (deck.score > 0) ...[
              const SizedBox(width: 5),
              Text(
                '${deck.score}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeckContent extends StatelessWidget {
  const _DeckContent({
    required this.deck,
    required this.owned,
    required this.vm,
  });

  final MnemonicDeck deck;
  final bool owned;
  final DeckDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return ListView(
      children: [
        NeoContent(
          maxWidth: 820,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (deck.hasCover) ...[
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: jc.lavender,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: jc.ink, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: jc.ink,
                        blurRadius: 0,
                        offset: const Offset(6, 6),
                      ),
                    ],
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.8,
                    child: NetImage(url: deck.coverUrl, cacheWidth: 1000),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      deck.title,
                      style: context.text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  NeoBadge(
                    '${deck.itemCount} ${deck.kind == 'kanji' ? 'kanji' : 'kana'}',
                    tone: NeoTone.acid,
                    rotate: 2,
                  ),
                ],
              ),
              if (deck.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                NeoCard(
                  tone: NeoTone.lavender,
                  shadow: 0,
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    deck.description,
                    style: TextStyle(
                      color: jc.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              if (owned && !deck.isPublic) ...[
                const SizedBox(height: 14),
                _DraftBanner(deck: deck, vm: vm),
              ],
              const SizedBox(height: 24),
              NeoSectionTitle(context.trText('Inside this pack')),
              if (deck.items.isEmpty)
                const EmptyHint(
                  icon: Icons.collections_bookmark_outlined,
                  title: 'This pack is empty',
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: deck.items.length,
                  itemBuilder: (context, index) =>
                      _ItemTile(mnemonic: deck.items[index]),
                ),
            ],
          ),
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
    final pending = deck.isPending;
    return NeoCard(
      tone: pending ? NeoTone.lavender : NeoTone.acid,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.jc.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.jc.ink, width: 2.5),
                ),
                child: Icon(
                  pending ? Icons.hourglass_top : Icons.lock_outline,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pending ? 'WAITING FOR REVIEW' : 'PRIVATE DRAFT',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            pending
                ? 'Submitted, waiting for review before it goes public.'
                : 'Publish this draft to share it with the community.',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (deck.isDraft) ...[
            const SizedBox(height: 12),
            NeoPrimaryButton(
              label: context.trText('Publish'),
              icon: Icons.rocket_launch_outlined,
              tone: NeoTone.lime,
              onTap: () async {
                final status = await vm.publish();
                if (context.mounted && status != null) {
                  final msg = status == 'visible'
                      ? 'Published, thank you!'
                      : 'Submitted for review, thank you!';
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(msg)));
                }
              },
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: jc.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: jc.ink, width: 2.5),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (mnemonic.hasImage)
            NetImage(
              url: mnemonic.imageUrl,
              cacheWidth: 300,
              semanticLabel: 'Mnemonic drawing for ${mnemonic.character}',
              errorBuilder: (_) => _glyph(jc),
            )
          else
            _glyph(jc),
          Positioned(
            left: 5,
            bottom: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: jc.acid,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: jc.ink, width: 2),
              ),
              child: Text(
                mnemonic.character,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glyph(JibikiColors jc) => Center(
        child: Text(
          mnemonic.character,
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: jc.ink,
          ),
        ),
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
    final canStudy = deck.isPublic || owned;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: jc.surface,
        border: Border(top: BorderSide(color: jc.ink, width: 3)),
      ),
      child: SafeArea(
        top: false,
        child: Align(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: NeoPrimaryButton(
                label: vm.enrolled ? 'In your study' : 'Study this pack',
                icon: vm.enrolled ? Icons.check : Icons.school_outlined,
                tone: vm.enrolled ? NeoTone.lime : NeoTone.acid,
                onTap: !canStudy || vm.enrolled
                    ? null
                    : () async {
                        final count = await vm.enroll();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                count > 0
                                    ? 'Added $count cards to your study'
                                    : 'Already in your study',
                              ),
                            ),
                          );
                        }
                      },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
