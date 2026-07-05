import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/study.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/review_viewmodel.dart';

/// Multiple-choice study over one card. Options are built client-side from the
/// rest of the session; a correct pick grades Good, a wrong pick grades Again.
class QuizStage extends StatefulWidget {
  const QuizStage({super.key, required this.vm, required this.lang});
  final ReviewViewModel vm;
  final String lang;

  @override
  State<QuizStage> createState() => _QuizStageState();
}

class _QuizStageState extends State<QuizStage> {
  late final String _correct;
  late final List<String> _options;
  String? _picked;
  bool _locked = false;

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
    await Future.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    widget.vm.rate(correct ? Rating.good : Rating.again);
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final card = widget.vm.current!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: jc.surface,
                borderRadius: BorderRadius.circular(Radii.xl),
                border: Border.all(color: jc.hairline),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('What does this mean?', style: TextStyle(color: jc.muted, fontSize: 13.5)),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(card.front,
                        style: TextStyle(
                            fontFamily: JpFonts.variant(card.id + card.reps),
                            fontSize: 92,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            color: jc.ink)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 6,
            child: Column(
              children: [
                for (final opt in _options)
                  Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 10), child: _OptionTile(
                    label: opt,
                    state: _tileState(opt),
                    onTap: () => _pick(opt),
                  ))),
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

enum _OptState { idle, correct, wrong, dimmed }

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.label, required this.state, required this.onTap});
  final String label;
  final _OptState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final (bg, fg, border) = switch (state) {
      _OptState.idle => (jc.surface, jc.ink, jc.hairline),
      _OptState.correct => (jc.ratingGood.withValues(alpha: 0.16), jc.ratingGood, jc.ratingGood),
      _OptState.wrong => (jc.ratingAgain.withValues(alpha: 0.16), jc.ratingAgain, jc.ratingAgain),
      _OptState.dimmed => (jc.surface, jc.muted, jc.hairline),
    };
    final icon = switch (state) {
      _OptState.correct => Icons.check_circle,
      _OptState.wrong => Icons.cancel,
      _ => null,
    };
    return AnimatedContainer(
      duration: Motion.timed(context, Motion.fast),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: border, width: state == _OptState.idle ? 1 : 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w600),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                if (icon != null) Icon(icon, color: fg, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
