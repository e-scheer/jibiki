import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/breakpoints.dart';
import '../../core/speech.dart';
import '../../models/enums.dart';
import '../../models/study.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/review_viewmodel.dart';
import '../widgets/pressable.dart';
import '../widgets/speech_button.dart';
import 'study_feedback.dart';
import 'study_prompts.dart';

const _fallbackKana = [
  'あ', 'い', 'う', 'え', 'お', 'か', 'き', 'く', 'こ', 'さ', 'し', 'す', //
  'た', 'ち', 'つ', 'と', 'な', 'に', 'は', 'ひ', 'ふ', 'ま', 'み', 'め', 'ら', 'り', 'る',
];

/// Listen-and-build: hear the reading, then reconstruct it kana-by-kana from a
/// shuffled tile bank into the empty cells. A correct build grades Good, a wrong
/// one grades Again and shows the answer.
class ListenStage extends StatefulWidget {
  const ListenStage({super.key, required this.vm, required this.lang});
  final ReviewViewModel vm;
  final String lang;

  @override
  State<ListenStage> createState() => _ListenStageState();
}

class _ListenStageState extends State<ListenStage> {
  late final String _target;
  late final bool _showGlyph;
  late final List<String> _answer; // target split into cells
  late final List<String> _bank;
  late final List<bool> _used;
  final List<int> _placed = []; // bank indices, in cell order
  bool _checked = false;
  bool _correct = false;

  @override
  void initState() {
    super.initState();
    final card = widget.vm.current!;
    _target = listenTarget(card);
    _showGlyph =
        card.front != _target; // hide the glyph when it *is* the answer (kana)
    _answer = _target.split('');

    final pool = <String>{};
    for (final c in widget.vm.sessionCards) {
      if (c.id == card.id) continue;
      pool.addAll(listenTarget(c).split(''));
    }
    pool.removeAll(_answer);
    var distract = pool.toList()..shuffle();
    if (distract.length < 3) {
      distract = [
        ...distract,
        ..._fallbackKana
            .where((k) => !_answer.contains(k) && !distract.contains(k)),
      ];
    }
    final want = math.max(2, math.min(4, 6 - _answer.length));
    _bank = [..._answer, ...distract.take(want)]..shuffle();
    _used = List<bool>.filled(_bank.length, false);

    // Play it once on arrival; the button below replays.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => Speech.instance.say(_target));
  }

  void _place(int i) {
    if (_checked || _used[i] || _placed.length >= _answer.length) return;
    Haptics.tick();
    setState(() {
      _placed.add(i);
      _used[i] = true;
    });
  }

  void _removeCell(int cell) {
    if (_checked || cell >= _placed.length) return;
    Haptics.tick();
    setState(() {
      final idx = _placed.removeAt(cell);
      _used[idx] = false;
    });
  }

  Future<void> _check() async {
    final assembled = _placed.map((i) => _bank[i]).join();
    _correct = assembled == _target;
    setState(() => _checked = true);
    _correct ? Haptics.success() : Haptics.medium();
    await Future.delayed(Duration(milliseconds: _correct ? 700 : 1600));
    if (!mounted) return;
    widget.vm.rate(_correct ? Rating.good : Rating.again);
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.vm.current!;
    final full = _placed.length == _answer.length;
    // Rotation-adaptive: landscape puts the prompt (what you hear) beside the
    // answer builder; portrait stacks them, bounded on a tablet.
    final Widget content = context.isLandscape
        ? Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _promptPanel(context, card)),
                const SizedBox(width: 20),
                Expanded(child: _answerPanel(context, full)),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: BoundedBoard(
              child: Column(
                children: [
                  Expanded(flex: 4, child: _promptPanel(context, card)),
                  const SizedBox(height: 18),
                  Expanded(flex: 5, child: _answerPanel(context, full)),
                ],
              ),
            ),
          );
    // A win pops a green check; a miss pops a red cross that fades to leave the
    // corrected reading readable. Mutually exclusive, so both wrap the content.
    return WinOverlay(
      show: _checked && _correct,
      child: MissOverlay(show: _checked && !_correct, child: content),
    );
  }

  Widget _promptPanel(BuildContext context, StudyCard card) {
    final jc = context.jc;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: jc.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: jc.hairline),
        boxShadow: Shadows.soft(context),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Type what you hear',
              style: TextStyle(
                  color: jc.muted,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          if (_showGlyph) ...[
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(card.front,
                    style: TextStyle(
                        fontFamily: JpFonts.variant(card.id + card.reps),
                        fontSize: 76,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        color: jc.ink)),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _ReplayButton(text: _target, big: !_showGlyph),
        ],
      ),
    );
  }

  Widget _answerPanel(BuildContext context, bool full) {
    return Column(
      children: [
        _Cells(
          answer: _answer,
          placed: [for (final i in _placed) _bank[i]],
          checked: _checked,
          correct: _correct,
          onTapCell: _removeCell,
        ),
        if (_checked) ...[
          const SizedBox(height: 10),
          _ResultBlock(
              card: widget.vm.current!,
              target: _target,
              correct: _correct,
              lang: widget.lang),
        ],
        const SizedBox(height: 18),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < _bank.length; i++)
                    _BankTile(
                        char: _bank[i], used: _used[i], onTap: () => _place(i)),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: 54,
          width: double.infinity,
          child: FilledButton(
            onPressed: (full && !_checked) ? _check : null,
            child: const Text('Check'),
          ),
        ),
      ],
    );
  }
}

/// The answer cells: filled ones show a kana and pop back to the bank on tap.
class _Cells extends StatelessWidget {
  const _Cells({
    required this.answer,
    required this.placed,
    required this.checked,
    required this.correct,
    required this.onTapCell,
  });
  final List<String> answer;
  final List<String> placed;
  final bool checked;
  final bool correct;
  final ValueChanged<int> onTapCell;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (var j = 0; j < answer.length; j++)
          () {
            final filled = j < placed.length;
            final Color border;
            if (checked) {
              border = correct ? jc.ratingGood : jc.ratingAgain;
            } else {
              border = filled ? jc.brand : jc.hairline;
            }
            return Pressable(
              onTap: (!checked && filled) ? () => onTapCell(j) : null,
              haptic: false,
              pressedScale: 0.94,
              child: Container(
                width: 52,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: filled ? jc.surface : jc.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                      color: border, width: filled || checked ? 2 : 1),
                ),
                child: Text(filled ? placed[j] : '',
                    style: TextStyle(
                        fontFamily: 'NotoSansJP',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: jc.ink)),
              ),
            );
          }(),
      ],
    );
  }
}

/// Shown once checked: the word's meaning (so the listen game teaches sense, not
/// just spelling), plus the correct reading when the build was wrong.
class _ResultBlock extends StatelessWidget {
  const _ResultBlock(
      {required this.card,
      required this.target,
      required this.correct,
      required this.lang});
  final StudyCard card;
  final String target;
  final bool correct;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final meaning = card.meaning(lang);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // On a miss the cells show the wrong build, so spell out the reading here.
        if (!correct)
          Text(target,
              style: TextStyle(
                  fontFamily: 'NotoSansJP',
                  color: jc.ratingGood,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
        if (meaning.isNotEmpty) ...[
          if (!correct) const SizedBox(height: 3),
          Text(meaning,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: jc.body,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ],
    );
  }
}

class _BankTile extends StatelessWidget {
  const _BankTile(
      {required this.char, required this.used, required this.onTap});
  final String char;
  final bool used;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Pressable(
      label: char,
      haptic: false,
      pressedScale: 0.94,
      onTap: used ? null : onTap,
      child: AnimatedOpacity(
        duration: Motion.timed(context, Motion.fast),
        opacity: used ? 0.28 : 1,
        child: Container(
          width: 52,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: jc.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: jc.hairline),
          ),
          child: Text(char,
              style: TextStyle(
                  fontFamily: 'NotoSansJP',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: jc.ink)),
        ),
      ),
    );
  }
}

/// A speaker control: a large pill when audio is the whole prompt (kana), a plain
/// icon button when a glyph is already shown.
class _ReplayButton extends StatelessWidget {
  const _ReplayButton({required this.text, required this.big});
  final String text;
  final bool big;

  @override
  Widget build(BuildContext context) {
    if (!big) return SpeechButton(text: text, size: 28);
    final jc = context.jc;
    return Pressable(
      label: 'Play audio',
      onTap: () => Speech.instance.say(text),
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(color: jc.brandSoft, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(Icons.volume_up_rounded, size: 40, color: jc.brand),
      ),
    );
  }
}
