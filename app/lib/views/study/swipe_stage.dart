import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../core/breakpoints.dart';
import '../../models/enums.dart';
import '../../models/study.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/review_viewmodel.dart';
import '../widgets/pressable.dart';
import '../widgets/speech_button.dart';
import '../widgets/swipe_card.dart';
import 'study_chrome.dart';

/// The Japanese to read aloud for a card: the glyph for kana/kanji, the kana
/// reading for words (romaji readings never go to a JA voice).
String _cardSpeech(StudyCard c) => switch (c.itemType) {
      ItemType.word => c.reading.isNotEmpty ? c.reading : c.front,
      ItemType.kana => c.front,
      ItemType.kanji => c.front,
    };

/// Swipe study over one card (fresh state per card via the parent's ValueKey).
class SwipeStage extends StatefulWidget {
  const SwipeStage({
    super.key,
    required this.vm,
    required this.lang,
    this.onRated,
  });
  final ReviewViewModel vm;
  final String lang;
  final void Function(StudyCard card, Rating rating)? onRated;

  @override
  State<SwipeStage> createState() => _SwipeStageState();
}

class _SwipeStageState extends State<SwipeStage> {
  final _controller = SwipeCardController();
  final _peek = ValueNotifier<double>(0); // drag progress → deck-behind rises
  bool _revealed = false;

  @override
  void dispose() {
    _peek.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.vm.current!;
    final next = widget.vm.next;
    final cardStack = Stack(
      children: [
        if (next != null)
          Positioned.fill(
            child: ValueListenableBuilder<double>(
              valueListenable: _peek,
              builder: (_, p, __) => _PeekCard(card: next, progress: p),
            ),
          ),
        Positioned.fill(
          child: SwipeCard(
            controller: _controller,
            onRate: (rating) {
              widget.onRated?.call(card, rating);
              widget.vm.rate(rating);
            },
            onProgress: (p) => _peek.value = p,
            onRevealChanged: (v) => setState(() => _revealed = v),
            front: _Face(card: card, lang: widget.lang, revealed: false),
            back: _Face(card: card, lang: widget.lang, revealed: true),
          ),
        ),
      ],
    );

    // Rotation-adaptive: landscape sets the card beside a vertical grade column so
    // nothing fights for the short height; portrait keeps the card above the bar,
    // bounded so a tablet centres a real card instead of a giant one.
    if (context.isLandscape) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: BoundedBoard(maxWidth: 480, child: cardStack)),
            const SizedBox(width: 16),
            SizedBox(
              width: 164,
              child: _ActionBar(
                  revealed: _revealed,
                  controller: _controller,
                  axis: Axis.vertical),
            ),
          ],
        ),
      );
    }
    return BoundedBoard(
      child: Column(
        children: [
          Expanded(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                child: cardStack),
          ),
          _ActionBar(revealed: _revealed, controller: _controller),
        ],
      ),
    );
  }
}

/// The next card, peeking behind, rises + fades in as the top card is dragged.
class _PeekCard extends StatelessWidget {
  const _PeekCard({required this.card, required this.progress});
  final StudyCard card;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final scale = 0.93 + 0.055 * progress;
    final dy = 16 - 10 * progress;
    return Transform.translate(
      offset: Offset(0, dy),
      child: Transform.scale(
        scale: scale,
        child: Container(
          decoration: BoxDecoration(
            color: jc.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: jc.ink, width: 2.5),
          ),
          alignment: Alignment.center,
          child: Opacity(
            opacity: 0.35 + 0.4 * progress,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Text(card.front,
                    style: TextStyle(
                        fontFamily: JpFonts.variant(card.id + card.reps),
                        fontSize: 96,
                        fontWeight: FontWeight.w700,
                        color: jc.ink)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The premium bottom controls: "Show answer" before reveal, then the four
/// colour-coded grade buttons that mirror the swipe directions.
class _ActionBar extends StatelessWidget {
  const _ActionBar(
      {required this.revealed,
      required this.controller,
      this.axis = Axis.horizontal});
  final bool revealed;
  final SwipeCardController controller;
  final Axis axis;

  static const _grades = [Rating.again, Rating.hard, Rating.good, Rating.easy];

  @override
  Widget build(BuildContext context) {
    final vertical = axis == Axis.vertical;

    final revealBtn = StudyActionButton(
      label: context.trText('Show answer'),
      icon: Icons.visibility_outlined,
      color: context.jc.ink,
      foreground: context.jc.acid,
      onTap: () {
        Haptics.light();
        controller.reveal();
      },
    );

    final Widget content = revealed
        ? (vertical
            ? Column(
                key: const ValueKey('grades'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _grades.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _GradeButton(
                        rating: _grades[i],
                        onTap: () => controller.rate(_grades[i])),
                  ],
                ],
              )
            : Column(
                key: const ValueKey('grades'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.trText('How did it feel?'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.55,
                    children: [
                      for (final rating in _grades)
                        _GradeButton(
                          rating: rating,
                          onTap: () => controller.rate(rating),
                        ),
                    ],
                  ),
                ],
              ))
        : KeyedSubtree(
            key: const ValueKey('reveal'),
            child: vertical ? Center(child: revealBtn) : revealBtn,
          );

    return SafeArea(
      top: false,
      child: Padding(
        padding: vertical
            ? const EdgeInsets.symmetric(vertical: 4)
            : const EdgeInsets.fromLTRB(18, 4, 18, 14),
        child: AnimatedSwitcher(
            duration: Motion.timed(context, Motion.fast), child: content),
      ),
    );
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({required this.rating, required this.onTap});
  final Rating rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = switch (rating) {
      Rating.again => context.jc.coral,
      Rating.hard => context.jc.acid,
      Rating.good => context.jc.lime,
      Rating.easy => context.jc.brand,
    };
    final foreground =
        rating == Rating.easy ? context.jc.surface : context.jc.ink;
    final interval = switch (rating) {
      Rating.again => '2 min',
      Rating.hard => '1 d',
      Rating.good => '3 d',
      Rating.easy => '7 d',
    };
    return Pressable(
      label: 'Grade: ${rating.label}',
      haptic: false, // the light impact below is the intended feedback
      onTap: () {
        Haptics.light();
        onTap();
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.jc.ink, width: 2.5),
          boxShadow: [
            BoxShadow(
                color: context.jc.ink,
                blurRadius: 0,
                offset: const Offset(3, 3))
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Icon(ratingIcon(rating), color: foreground, size: 22),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rating.label,
                      style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                  const SizedBox(height: 1),
                  Text(interval,
                      style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5)),
                ],
              ),
            ),
            Text(
              ratingArrow(rating),
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.card, required this.lang, required this.revealed});
  final StudyCard card;
  final String lang;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      child: Column(
        children: [
          Align(alignment: Alignment.centerLeft, child: _TypeBadge(card: card)),
          const Spacer(),
          Flexible(
            flex: 8,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                card.front,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: JpFonts.variant(card.id + card.reps),
                  fontSize: 104,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: jc.ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!revealed)
            const _Hint(icon: Icons.touch_app_outlined, text: 'Tap to reveal')
          else
            _AnswerBlock(card: card, lang: lang),
          const Spacer(),
          if (revealed)
            const _Hint(
                icon: Icons.swipe_outlined,
                text: 'Swipe any way, or tap a button'),
        ],
      ),
    );
  }
}

/// The revealed answer: a hairline lead-in, the reading in vermilion, the meaning
/// below, and a play button. A clear stack instead of loose stacked lines.
class _AnswerBlock extends StatelessWidget {
  const _AnswerBlock({required this.card, required this.lang});
  final StudyCard card;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final hasReading = card.reading.isNotEmpty && card.reading != card.front;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 4,
          decoration: BoxDecoration(
              color: jc.ink, borderRadius: BorderRadius.circular(Radii.pill)),
        ),
        const SizedBox(height: 16),
        if (hasReading) ...[
          Text(card.reading,
              textAlign: TextAlign.center,
              // Readings are kana; pin a JP face so they never fall back to a
              // Latin font (which renders them as tofu).
              style: TextStyle(
                  fontFamily: 'NotoSansJP',
                  fontSize: 27,
                  color: jc.ink,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3)),
          const SizedBox(height: 8),
        ],
        Text(card.meaning(lang),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 17.5,
                color: jc.ink,
                height: 1.35,
                fontWeight: FontWeight.w700)),
        if (card.sourceSentence.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: jc.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Text(card.sourceSentence,
                textAlign: TextAlign.center,
                style: TextStyle(color: jc.body, fontSize: 13, height: 1.35)),
          ),
        ],
        if (card.sourceTitle.isNotEmpty || card.sourceUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              card.sourceTitle.isNotEmpty
                  ? context.trText('Source: ${card.sourceTitle}')
                  : context.trText('Source captured from reading'),
              textAlign: TextAlign.center,
              style: TextStyle(color: jc.muted, fontSize: 11),
            ),
          ),
        const SizedBox(height: 12),
        SpeechButton(text: _cardSpeech(card), size: 26),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: jc.muted),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                color: jc.muted, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.card});
  final StudyCard card;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final isNew = card.isNew;
    final label = isNew ? 'NEW' : card.itemType.wire.toUpperCase();
    final color = isNew ? jc.brand : jc.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.pill)),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.2)),
    );
  }
}
