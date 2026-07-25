import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/breakpoints.dart';
import '../../l10n/l10n.dart';
import '../../models/collection.dart';
import '../../theme/app_theme.dart';
import '../widgets/neo_pop.dart';
import 'collection_card_art.dart';

/// Opens the recto/verso card sheet: a bottom sheet on phones, a centered
/// dialog on tablets. Owned cards flip; missing cards show the muted face and
/// how to get cards in general (no dark pattern, no purchase).
Future<void> showCollectionCardDetail(
  BuildContext context, {
  required CollectionCardDef card,
  required int copies,
}) {
  final content = _CardDetail(card: card, copies: copies);
  if (context.isWide) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: NeoCard(
            padding: const EdgeInsets.all(Insets.xl),
            child: content,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .86,
      maxChildSize: .95,
      minChildSize: .5,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: context.jc.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(Radii.lg)),
          border: Border.all(color: context.jc.ink, width: 2.5),
        ),
        padding: const EdgeInsets.fromLTRB(
            Insets.base, Insets.md, Insets.base, Insets.xl),
        child: SingleChildScrollView(
          controller: controller,
          child: content,
        ),
      ),
    ),
  );
}

class _CardDetail extends StatefulWidget {
  const _CardDetail({required this.card, required this.copies});

  final CollectionCardDef card;
  final int copies;

  @override
  State<_CardDetail> createState() => _CardDetailState();
}

class _CardDetailState extends State<_CardDetail> {
  bool _showBack = false;

  bool get _owned => widget.copies > 0;

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final face = _CardFlip(
      showBack: _showBack && _owned,
      front: CollectionCardFace(
        card: widget.card,
        owned: _owned,
        copies: widget.copies,
      ),
      back: _CardBack(card: widget.card),
      onFlip: _owned ? () => setState(() => _showBack = !_showBack) : null,
    );
    final info = _CardInfo(card: widget.card, copies: widget.copies);
    if (wide) {
      // Tablet: card and reading panel side by side, no flipping needed to
      // compare both faces with the metadata.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: face,
          ),
          const SizedBox(width: Insets.xl),
          Expanded(child: info),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: face,
          ),
        ),
        const SizedBox(height: Insets.base),
        info,
      ],
    );
  }
}

/// A continuous 3D flip: one controller drives the card from front (0) to back
/// (π). The reverse face is counter-rotated so its content stays readable, and
/// a glare sweeps across the surface at the mid-point where the card is edge-on.
class _CardFlip extends StatefulWidget {
  const _CardFlip({
    required this.showBack,
    required this.front,
    required this.back,
    this.onFlip,
  });

  final bool showBack;
  final Widget front;
  final Widget back;
  final VoidCallback? onFlip;

  @override
  State<_CardFlip> createState() => _CardFlipState();
}

class _CardFlipState extends State<_CardFlip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 540),
    value: widget.showBack ? 1 : 0,
  );

  @override
  void didUpdateWidget(_CardFlip old) {
    super.didUpdateWidget(old);
    if (widget.showBack == old.showBack) return;
    if (!Motion.enabled(context)) {
      _c.value = widget.showBack ? 1 : 0;
    } else {
      _c.animateTo(widget.showBack ? 1 : 0, curve: Curves.easeInOutCubic);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flip = AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final angle = _c.value * math.pi;
        final showingFront = angle <= math.pi / 2;
        // A soft lift and a glare that peaks edge-on.
        final glare = math.sin(_c.value * math.pi);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0012)
            ..scaleByDouble(1 + glare * 0.04, 1 + glare * 0.04, 1, 1)
            ..rotateY(angle),
          child: Stack(
            children: [
              Transform(
                alignment: Alignment.center,
                // Keep the back readable rather than mirrored.
                transform: Matrix4.identity()
                  ..rotateY(showingFront ? 0 : math.pi),
                child: showingFront ? widget.front : widget.back,
              ),
              if (glare > 0.02)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: glare * .5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Radii.md),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0x00FFFFFF),
                              Color(0x66FFFFFF),
                              Color(0x00FFFFFF),
                            ],
                            stops: [.3, .5, .7],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
    if (widget.onFlip == null) return flip;
    return Semantics(
      button: true,
      label: context.l10n.collectionFlipCard,
      child: GestureDetector(
        onTap: () {
          Haptics.medium();
          widget.onFlip!();
        },
        child: flip,
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.card});

  final CollectionCardDef card;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final language = Localizations.localeOf(context).languageCode;
    return AspectRatio(
      aspectRatio: kCollectionCardAspect,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [jc.surface, jc.surfaceAlt],
          ),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: jc.ink, width: 2.5),
          boxShadow: [
            BoxShadow(color: jc.ink, blurRadius: 0, offset: const Offset(3, 3)),
          ],
        ),
        child: Stack(
          children: [
            // Faint subject watermark for texture.
            Positioned(
              right: -18,
              bottom: -18,
              child: Icon(
                motifIcon(card.art.motif),
                size: 120,
                color: jc.ink.withValues(alpha: .05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.nameJa,
                    style: TextStyle(
                      fontFamily: 'NotoSansJP',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: jc.ink,
                    ),
                  ),
                  Text(
                    card.reading,
                    style: TextStyle(
                      fontFamily: 'NotoSansJP',
                      fontSize: 12,
                      color: jc.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        card.body.resolve(language),
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: jc.body,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardInfo extends StatelessWidget {
  const _CardInfo({required this.card, required this.copies});

  final CollectionCardDef card;
  final int copies;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final owned = copies > 0;
    final fallback =
        !card.body.authoredIn(language) || !card.name.authoredIn(language);
    final unlock = card.unlock;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            NeoBadge(
              card.rarity.label(context),
              tone: switch (card.rarity) {
                CardRarity.common => NeoTone.paper,
                CardRarity.rare => NeoTone.lavender,
                CardRarity.special => NeoTone.acid,
                CardRarity.shiny => NeoTone.magenta,
              },
            ),
            NeoBadge(categoryLabel(context, card.category)),
            if (owned && copies > 1)
              NeoBadge(l10n.boosterDuplicate(copies), tone: NeoTone.lime),
            if (!owned) NeoBadge(l10n.collectionCardNotOwned),
          ],
        ),
        const SizedBox(height: Insets.md),
        Text(
          card.name.resolve(language),
          style: context.text.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: jc.ink,
          ),
        ),
        Text(
          card.context.resolve(language),
          style: TextStyle(color: jc.muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: Insets.sm),
        Text(
          card.body.resolve(language),
          style: TextStyle(color: jc.body, height: 1.45),
        ),
        if (fallback) ...[
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Icon(Icons.translate_rounded, size: 15, color: jc.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.contentFallbackEnglish,
                  style: TextStyle(
                      fontSize: 12, color: jc.muted, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ],
        if (unlock != null) ...[
          const SizedBox(height: Insets.md),
          NeoCard(
            tone: owned ? NeoTone.lime : NeoTone.paper,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                    owned
                        ? Icons.lock_open_rounded
                        : Icons.lock_outline_rounded,
                    size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    owned
                        ? '${l10n.collectionUnlocked} · ${unlock.label.resolve(language)}'
                        : l10n.collectionUnlocks(unlock.label.resolve(language)),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (card.vocab.isNotEmpty) ...[
          const SizedBox(height: Insets.base),
          NeoSectionTitle(l10n.collectionVocab),
          for (final vocab in card.vocab)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    vocab.ja,
                    style: TextStyle(
                      fontFamily: 'NotoSansJP',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: jc.ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    vocab.reading,
                    style: TextStyle(
                      fontFamily: 'NotoSansJP',
                      fontSize: 12,
                      color: jc.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      vocab.gloss.resolve(language),
                      style: TextStyle(fontSize: 13, color: jc.body),
                    ),
                  ),
                ],
              ),
            ),
        ],
        // The photo's author and license, honoring the source's terms.
        if (owned && card.art.credit != null) ...[
          const SizedBox(height: Insets.sm),
          Text(
            l10n.collectionPhotoCredit(card.art.credit!),
            style: TextStyle(
              fontSize: 10.5,
              color: jc.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
