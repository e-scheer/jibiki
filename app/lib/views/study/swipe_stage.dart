import 'dart:math' as math;

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
    this.onOpenDetails,
    this.onRated,
  });
  final ReviewViewModel vm;
  final String lang;
  final VoidCallback? onOpenDetails;
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
    final landscape = studyUsesLandscapeContract(context);
    final cardStack = Stack(
      clipBehavior: Clip.none,
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
            front: _Face(
              card: card,
              lang: widget.lang,
              revealed: false,
              landscape: landscape,
            ),
            back: _Face(
              card: card,
              lang: widget.lang,
              revealed: true,
              landscape: landscape,
            ),
          ),
        ),
        if (landscape && _revealed)
          Positioned(
            top: -64,
            right: -26,
            child: IgnorePointer(
              child: _CardCelebration(
                label: _copy(context, 'REMEMBERED', 'RETENU'),
              ),
            ),
          ),
      ],
    );

    if (landscape) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 55,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 20, 30, 26),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = math.min(548.0, constraints.maxWidth);
                  final height = math.min(540.0, constraints.maxHeight);
                  return Center(
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: cardStack,
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            flex: 45,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 20, 30, 26),
              child: _ActionBar(
                revealed: _revealed,
                controller: _controller,
                axis: Axis.vertical,
                card: card,
                lang: widget.lang,
                onOpenDetails: widget.onOpenDetails,
              ),
            ),
          ),
        ],
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
          _ActionBar(
            revealed: _revealed,
            controller: _controller,
            card: card,
            lang: widget.lang,
          ),
        ],
      ),
    );
  }
}

class _CardCelebration extends StatelessWidget {
  const _CardCelebration({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        height: 126,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(
              child: StudyConfetti(size: Size(210, 108)),
            ),
            Positioned(
              top: 48,
              right: 20,
              child: StudySticker(label, large: true),
            ),
          ],
        ),
      );
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
  const _ActionBar({
    required this.revealed,
    required this.controller,
    required this.card,
    required this.lang,
    this.axis = Axis.horizontal,
    this.onOpenDetails,
  });
  final bool revealed;
  final SwipeCardController controller;
  final StudyCard card;
  final String lang;
  final Axis axis;
  final VoidCallback? onOpenDetails;

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
                key: const ValueKey('grades-landscape'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _copy(context, 'Did you know it?', 'Tu l\'avais ?'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _grades.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _GradeButton(
                      rating: _grades[i],
                      vertical: true,
                      onTap: () => controller.rate(_grades[i]),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _LandscapeContextPanel(
                    card: card,
                    lang: lang,
                    onTap: onOpenDetails,
                  ),
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

    final switched = AnimatedSwitcher(
      duration: Motion.timed(context, Motion.fast),
      child: content,
    );
    return SafeArea(
      top: false,
      child: vertical
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 4, bottom: 8),
                child: switched,
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
              child: switched,
            ),
    );
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({
    required this.rating,
    required this.onTap,
    this.vertical = false,
  });
  final Rating rating;
  final VoidCallback onTap;
  final bool vertical;

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
    final interval = _ratingInterval(context, rating);
    return Pressable.builder(
      label: 'Grade: ${rating.label}',
      haptic: false, // the light impact below is the intended feedback
      focusRadius: 12,
      onTap: () {
        Haptics.light();
        onTap();
      },
      builder: (context, pressed) => AnimatedContainer(
        duration: Motion.timed(context, const Duration(milliseconds: 120)),
        curve: Curves.easeOut,
        height: vertical ? 70 : 60,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(vertical ? 12 : 10),
          border: Border.all(
            color: context.jc.ink,
            width: vertical ? 3 : 2.5,
          ),
          boxShadow: pressed
              ? null
              : [
                  BoxShadow(
                    color: context.jc.ink,
                    blurRadius: 0,
                    offset: Offset(vertical ? 4 : 3, vertical ? 4 : 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            SizedBox(width: vertical ? 16 : 10),
            Icon(ratingIcon(rating), color: foreground, size: 22),
            SizedBox(width: vertical ? 14 : 9),
            Expanded(
              child: Text(
                context.trText(rating.label),
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: vertical ? 18 : 15,
                ),
              ),
            ),
            if (vertical)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: context.jc.surface,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: context.jc.ink, width: 2),
                ),
                child: Text(
                  interval,
                  style: TextStyle(
                    color: context.jc.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else ...[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    interval,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
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
                ],
              ),
            ],
            SizedBox(width: vertical ? 16 : 8),
          ],
        ),
      ),
    );
  }
}

class _LandscapeContextPanel extends StatelessWidget {
  const _LandscapeContextPanel({
    required this.card,
    required this.lang,
    this.onTap,
  });

  final StudyCard card;
  final String lang;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sentence = card.sourceSentence.trim();
    final tokens = sentence.isEmpty
        ? <String>[
            card.front,
            if (card.reading.isNotEmpty && card.reading != card.front)
              card.reading,
          ]
        : sentence
            .split(RegExp(r'\s+'))
            .where((token) => token.isNotEmpty)
            .toList(growable: false);
    var hit = tokens.indexWhere((token) => token.contains(card.front));
    if (hit < 0) hit = tokens.length - 1;

    Widget panel(bool pressed) => StudyPanel(
          borderWidth: 3,
          shadow: pressed ? 0 : 4,
          radius: 12,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _copy(context, 'In context', 'En contexte'),
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < tokens.length; i++)
                    _ContextChip(label: tokens[i], highlighted: i == hit),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                card.meaning(lang).isEmpty
                    ? _copy(
                        context,
                        'No translation captured yet.',
                        'Aucune traduction capturée pour le moment.',
                      )
                    : '« ${card.meaning(lang)} »',
                style: TextStyle(
                  color: context.jc.body,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      context.trText('Open full details'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
              ],
            ],
          ),
        );

    if (onTap == null) return panel(false);
    return Pressable.builder(
      label: context.trText('Open full details'),
      focusRadius: 12,
      onTap: onTap,
      builder: (context, pressed) => panel(pressed),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.label, required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 40, maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: highlighted ? context.jc.acid : context.jc.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: context.jc.ink, width: 2.5),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'ZenKakuGothicNew',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _Face extends StatelessWidget {
  const _Face({
    required this.card,
    required this.lang,
    required this.revealed,
    required this.landscape,
  });
  final StudyCard card;
  final String lang;
  final bool revealed;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Padding(
      padding: landscape
          ? const EdgeInsets.fromLTRB(24, 62, 24, 44)
          : const EdgeInsets.fromLTRB(22, 24, 22, 22),
      child: Column(
        children: [
          if (!landscape)
            Align(
              alignment: Alignment.centerLeft,
              child: _TypeBadge(card: card),
            ),
          const Spacer(),
          Flexible(
            flex: 8,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                card.front,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: landscape
                      ? 'ZenKakuGothicNew'
                      : JpFonts.variant(card.id + card.reps),
                  fontSize: landscape ? 148 : 104,
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
            _AnswerBlock(card: card, lang: lang, landscape: landscape),
          const Spacer(),
          if (revealed && !landscape)
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
  const _AnswerBlock({
    required this.card,
    required this.lang,
    required this.landscape,
  });
  final StudyCard card;
  final String lang;
  final bool landscape;

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
                  fontFamily: 'ZenKakuGothicNew',
                  fontSize: landscape ? 30 : 27,
                  color: jc.ink,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3)),
          const SizedBox(height: 8),
        ],
        Text(card.meaning(lang),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: landscape ? 18.5 : 17.5,
                color: jc.ink,
                height: 1.35,
                fontWeight: FontWeight.w600)),
        if (!landscape && card.sourceSentence.isNotEmpty) ...[
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
        if (!landscape &&
            (card.sourceTitle.isNotEmpty || card.sourceUrl.isNotEmpty))
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
        if (!landscape) ...[
          const SizedBox(height: 12),
          SpeechButton(text: _cardSpeech(card), size: 26),
        ],
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

String _ratingInterval(BuildContext context, Rating rating) {
  final french = Localizations.localeOf(context).languageCode == 'fr';
  return switch (rating) {
    Rating.again => '2 min',
    Rating.hard => french ? '1 j' : '1 d',
    Rating.good => french ? '3 j' : '3 d',
    Rating.easy => french ? '7 j' : '7 d',
  };
}

String _copy(BuildContext context, String english, String french) =>
    Localizations.localeOf(context).languageCode == 'fr' ? french : english;
