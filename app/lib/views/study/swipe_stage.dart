import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/study.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/review_viewmodel.dart';
import '../widgets/pressable.dart';
import '../widgets/speech_button.dart';
import '../widgets/swipe_card.dart';

/// The Japanese to read aloud for a card: the glyph for kana/kanji, the kana
/// reading for words (romaji readings never go to a JA voice).
String _cardSpeech(StudyCard c) => switch (c.itemType) {
      ItemType.word => c.reading.isNotEmpty ? c.reading : c.front,
      ItemType.kana => c.front,
      ItemType.kanji => c.front,
    };

/// Swipe study over one card (fresh state per card via the parent's ValueKey).
class SwipeStage extends StatefulWidget {
  const SwipeStage({super.key, required this.vm, required this.lang});
  final ReviewViewModel vm;
  final String lang;

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
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
            child: Stack(
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
                    onRate: widget.vm.rate,
                    onProgress: (p) => _peek.value = p,
                    onRevealChanged: (v) => setState(() => _revealed = v),
                    front: _Face(card: card, lang: widget.lang, revealed: false),
                    back: _Face(card: card, lang: widget.lang, revealed: true),
                  ),
                ),
              ],
            ),
          ),
        ),
        _ActionBar(revealed: _revealed, controller: _controller),
      ],
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
            borderRadius: BorderRadius.circular(Radii.xl),
            border: Border.all(color: jc.hairline),
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
  const _ActionBar({required this.revealed, required this.controller});
  final bool revealed;
  final SwipeCardController controller;

  static const _grades = [Rating.again, Rating.hard, Rating.good, Rating.easy];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: AnimatedSwitcher(
          duration: Motion.timed(context, Motion.fast),
          child: revealed
              ? Row(
                  key: const ValueKey('grades'),
                  children: [
                    for (var i = 0; i < _grades.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: _GradeButton(rating: _grades[i], onTap: () => controller.rate(_grades[i]))),
                    ],
                  ],
                )
              : SizedBox(
                  key: const ValueKey('reveal'),
                  height: 54,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Haptics.light();
                      controller.reveal();
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    label: const Text('Show answer'),
                  ),
                ),
        ),
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
    final color = ratingColor(context, rating);
    return Pressable(
      label: 'Grade: ${rating.label}',
      haptic: false, // the light impact below is the intended feedback
      onTap: () {
        Haptics.light();
        onTap();
      },
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ratingIcon(rating), color: color, size: 22),
            const SizedBox(height: 3),
            Text(rating.label,
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12.5)),
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
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
      child: Column(
        children: [
          _TypeBadge(card: card),
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
                  fontSize: 120,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: jc.ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (!revealed)
            const _Hint(icon: Icons.touch_app_outlined, text: 'Tap to reveal')
          else ...[
            if (card.reading.isNotEmpty && card.reading != card.front)
              Text(card.reading, style: TextStyle(fontSize: 22, color: jc.brand, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(card.meaning(lang),
                textAlign: TextAlign.center, style: TextStyle(fontSize: 19, color: jc.body, height: 1.35)),
            const SizedBox(height: 4),
            SpeechButton(text: _cardSpeech(card), size: 26),
          ],
          const Spacer(),
          if (revealed) const _Hint(icon: Icons.swipe_outlined, text: 'Swipe, or use the buttons'),
        ],
      ),
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
        Text(text, style: TextStyle(color: jc.muted, fontSize: 13, fontWeight: FontWeight.w500)),
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.pill)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2)),
    );
  }
}
