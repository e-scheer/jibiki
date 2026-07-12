import 'package:flutter/material.dart';
import 'package:jibiki/l10n/l10n.dart';

import '../../models/mnemonic_deck.dart';
import '../../theme/app_theme.dart';
import '../widgets/neo_pop.dart';
import '../widgets/net_image.dart';
import '../widgets/pressable.dart';

/// Compact community row matching the NeoPop exploration's community cards.
class DeckCard extends StatelessWidget {
  const DeckCard({
    super.key,
    required this.deck,
    required this.onTap,
    this.onLike,
  });

  final MnemonicDeck deck;
  final VoidCallback onTap;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return NeoCard(
      padding: const EdgeInsets.all(12),
      shadow: 4,
      onTap: onTap,
      child: Row(
        children: [
          SizedBox.square(
            dimension: 58,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _Cover(deck: deck),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        deck.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (!deck.isPublic)
                      _StatusChip(status: deck.status)
                    else if (deck.score >= 100)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: jc.brand,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: jc.ink, width: 2),
                        ),
                        child: Text(
                          context.trText('Verified'),
                          style: TextStyle(
                            color: jc.surface,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  context.trText(
                    'by ${deck.authorName} · ${deck.itemCount} cards',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: jc.body,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.arrow_upward_rounded, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${deck.score}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(
                      deck.kind == 'kanji'
                          ? Icons.translate_rounded
                          : Icons.grid_view_rounded,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      deck.kind == 'kanji' ? 'Kanji' : 'Kana',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (deck.isPublic)
                      Pressable(
                        label: context.trText('Like this pack'),
                        onTap: onLike,
                        child: SizedBox.square(
                          dimension: 40,
                          child: Center(
                            child: Icon(
                              deck.liked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 19,
                              color: deck.liked ? jc.ratingAgain : jc.ink,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.deck});
  final MnemonicDeck deck;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    if (deck.hasCover) {
      return NetImage(
        url: deck.coverUrl,
        cacheWidth: 180,
        errorBuilder: (_) => _fallback(jc),
      );
    }
    return _fallback(jc);
  }

  Widget _fallback(JibikiColors jc) => ColoredBox(
        color: jc.magenta,
        child: Center(
          child: Text(
            deck.kind == 'kanji' ? '漢' : 'あ',
            style: TextStyle(
              color: jc.ink,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final label = status == 'draft'
        ? 'Draft'
        : status == 'pending'
            ? 'In review'
            : status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: jc.acid,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: jc.ink, width: 2),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: jc.ink,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
