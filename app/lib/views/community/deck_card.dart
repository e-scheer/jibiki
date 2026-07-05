import 'package:flutter/material.dart';

import '../../models/mnemonic_deck.dart';
import '../../theme/app_theme.dart';
import '../widgets/net_image.dart';

/// An Instagram-explore-style tile for a community pack: square cover, title,
/// author and an engagement row.
class DeckCard extends StatelessWidget {
  const DeckCard({super.key, required this.deck, required this.onTap, this.onLike});
  final MnemonicDeck deck;
  final VoidCallback onTap;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Material(
      color: jc.surface,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: jc.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Cover(deck: deck),
                    if (!deck.isPublic)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _StatusChip(status: deck.status),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deck.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text('by ${deck.authorName} · ${deck.itemCount} cards',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: jc.muted, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: jc.surfaceAlt,
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                          child: Text(deck.kind == 'kanji' ? 'Kanji' : 'Kana',
                              style: TextStyle(color: jc.body, fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ),
                        const Spacer(),
                        if (deck.isPublic)
                          InkWell(
                            onTap: onLike,
                            borderRadius: BorderRadius.circular(Radii.pill),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Row(
                                children: [
                                  Icon(deck.liked ? Icons.favorite : Icons.favorite_border,
                                      size: 18, color: deck.liked ? jc.ratingAgain : jc.ink),
                                  if (deck.score > 0) ...[
                                    const SizedBox(width: 4),
                                    Text('${deck.score}',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                  ],
                                ],
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
        ),
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
      return NetImage(url: deck.coverUrl, cacheWidth: 500, errorBuilder: (_) => _fallback(jc));
    }
    return _fallback(jc);
  }

  Widget _fallback(JibikiColors jc) {
    return Container(
      decoration: BoxDecoration(gradient: jc.instaLinear),
      alignment: Alignment.center,
      child: Text(deck.kind == 'kanji' ? '漢' : 'あ',
          style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: jc.ink.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
