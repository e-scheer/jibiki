import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/study.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/review_viewmodel.dart';
import '../widgets/pressable.dart';
import '../widgets/speech_button.dart';

/// The Japanese to read aloud once an answer is locked (reinforcement, never a
/// giveaway): the reading for words, the glyph itself for kana/kanji.
String _quizSpeech(StudyCard c) => switch (c.itemType) {
      ItemType.word => c.reading.isNotEmpty ? c.reading : c.front,
      _ => c.front,
    };

String _question(ItemType t) => switch (t) {
      ItemType.kana => 'How do you read this?',
      ItemType.kanji => 'What does this mean?',
      ItemType.word => 'What does this mean?',
    };

/// Multiple-choice study over one card. Options are built client-side from the
/// rest of the session; a correct pick grades Good, a wrong pick grades Again.
class QuizStage extends StatefulWidget {
  const QuizStage({super.key, required this.vm, required this.lang});
  final ReviewViewModel vm;
  final String lang;

  @override
  State<QuizStage> createState() => _QuizStageState();
}

class _QuizStageState extends State<QuizStage> with SingleTickerProviderStateMixin {
  late final String _correct;
  late final List<String> _options;
  String? _picked;
  bool _locked = false;

  // Options rise + fade in on a short stagger so a fresh question feels dealt,
  // not swapped. Collapses to instant under reduce-motion (handled in build).
  late final AnimationController _intro = AnimationController(vsync: this, duration: Motion.slow)..forward();

  @override
  void initState() {
    super.initState();
    final card = widget.vm.current!;
    _correct = _answer(card);
    final pool = widget.vm.sessionCards
        .where((c) => c.id != card.id)
        .map(_answer)
        .where((a) => a.isNotEmpty && a != _correct)
        .toSet()
        .toList()
      ..shuffle();
    _options = [_correct, ...pool.take(3)]..shuffle();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  String _answer(StudyCard c) {
    switch (c.itemType) {
      case ItemType.kana:
        return c.kana?.romaji ?? '';
      case ItemType.kanji:
        final m = c.kanji?.meaningsFor(widget.lang) ?? const [];
        return m.isNotEmpty ? m.first : '';
      case ItemType.word:
        final g = c.word?.summaryGloss(widget.lang) ?? '';
        return g.split(';').first.trim();
    }
  }

  Future<void> _pick(String option) async {
    if (_locked) return;
    setState(() {
      _picked = option;
      _locked = true;
    });
    final correct = option == _correct;
    correct ? Haptics.success() : Haptics.medium();
    // Linger longer on a miss so the revealed reading has time to land.
    await Future.delayed(Duration(milliseconds: correct ? 850 : 1500));
    if (!mounted) return;
    widget.vm.rate(correct ? Rating.good : Rating.again);
  }

  /// Eased 0..1 entrance value for the option at [i], offset so later rows trail
  /// the earlier ones.
  double _introT(int i) {
    final start = (i * 0.12).clamp(0.0, 0.6);
    final raw = ((_intro.value - start) / 0.5).clamp(0.0, 1.0);
    return Motion.outStrong.transform(raw);
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.vm.current!;
    if (!Motion.enabled(context)) _intro.value = 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          Expanded(flex: 5, child: _Prompt(card: card, answered: _locked)),
          const SizedBox(height: 16),
          Expanded(
            flex: 6,
            child: Column(
              children: [
                for (var i = 0; i < _options.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: i == _options.length - 1 ? 0 : 10),
                      child: AnimatedBuilder(
                        animation: _intro,
                        builder: (_, child) {
                          final t = _introT(i);
                          return Opacity(
                            opacity: t,
                            child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
                          );
                        },
                        child: _OptionTile(
                          letter: String.fromCharCode(65 + i),
                          label: _options[i],
                          state: _tileState(_options[i]),
                          onTap: _locked ? null : () => _pick(_options[i]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _OptState _tileState(String opt) {
    if (!_locked) return _OptState.idle;
    if (opt == _correct) return _OptState.correct;
    if (opt == _picked) return _OptState.wrong;
    return _OptState.dimmed;
  }
}

/// The card being tested: the question line, the glyph, and, once answered, a
/// play button so the learner hears it right after committing.
class _Prompt extends StatelessWidget {
  const _Prompt({required this.card, required this.answered});
  final StudyCard card;
  final bool answered;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: jc.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: jc.hairline),
        boxShadow: Shadows.soft(context),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_question(card.itemType),
              style: TextStyle(color: jc.muted, fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(card.front,
                  style: TextStyle(
                      fontFamily: JpFonts.variant(card.id + card.reps),
                      fontSize: 88,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: jc.ink)),
            ),
          ),
          const SizedBox(height: 8),
          // Reserved slots so revealing the reading + audio never shifts the glyph.
          // The reading (kana, hence the JP face) surfaces on answer, turning a miss
          // into a teaching moment: you see how the character is actually read.
          SizedBox(
            height: 28,
            child: AnimatedSwitcher(
              duration: Motion.timed(context, Motion.fast),
              child: (answered && card.reading.isNotEmpty && card.reading != card.front)
                  ? Text(card.reading,
                      key: const ValueKey('reading'),
                      style: TextStyle(
                          fontFamily: 'NotoSansJP',
                          fontSize: 18,
                          color: jc.brand,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3))
                  : const SizedBox.shrink(),
            ),
          ),
          SizedBox(
            height: 34,
            child: AnimatedSwitcher(
              duration: Motion.timed(context, Motion.fast),
              child: answered
                  ? SpeechButton(key: const ValueKey('play'), text: _quizSpeech(card), size: 24)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

enum _OptState { idle, correct, wrong, dimmed }

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.letter, required this.label, required this.state, required this.onTap});
  final String letter;
  final String label;
  final _OptState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    // (tile bg, label colour, border, chip bg, chip fg)
    final (bg, fg, border, chipBg, chipFg) = switch (state) {
      _OptState.idle => (jc.surface, jc.ink, jc.hairline, jc.surfaceAlt, jc.body),
      _OptState.correct => (jc.ratingGood.withValues(alpha: 0.14), jc.ink, jc.ratingGood, jc.ratingGood, Colors.white),
      _OptState.wrong => (jc.ratingAgain.withValues(alpha: 0.14), jc.ink, jc.ratingAgain, jc.ratingAgain, Colors.white),
      _OptState.dimmed => (jc.surface, jc.muted, jc.hairline, jc.surfaceAlt, jc.muted),
    };
    final icon = switch (state) {
      _OptState.correct => Icons.check_rounded,
      _OptState.wrong => Icons.close_rounded,
      _ => null,
    };
    return Pressable(
      label: label,
      haptic: false, // the result haptic in _pick is the intended feedback
      pressedScale: 0.98,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.timed(context, Motion.base),
        curve: Motion.out,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(
          children: [
            _OptionChip(bg: chipBg, fg: chipFg, letter: letter, icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w600, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// The leading square: a letter while choosing, a check/cross once answered.
class _OptionChip extends StatelessWidget {
  const _OptionChip({required this.bg, required this.fg, required this.letter, required this.icon});
  final Color bg;
  final Color fg;
  final String letter;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // The chip snaps to its verdict colour instantly (not animated) so the white
    // check/cross always lands on a solid backing; the tile fill behind it is what
    // eases in.
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.sm)),
      child: icon != null
          ? Icon(icon, color: fg, size: 19)
          : Text(letter, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 14)),
    );
  }
}
