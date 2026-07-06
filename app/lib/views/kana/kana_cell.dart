import 'package:flutter/material.dart';

import '../../models/kana.dart';
import '../../theme/app_theme.dart';
import '../widgets/pressable.dart';
import '../widgets/study_mark.dart';

/// One cell in the kana matrix: the glyph(s) over their romaji, carrying study +
/// selection state. Purely presentational — the matrix decides `selected`,
/// `mark`, and what a tap does. In "Both" mode it shows hiragana then katakana
/// (muted) side by side. Soft filled tiles (no per-cell borders) keep the grid
/// calm; the selected tile lifts with the vermilion wash + ring, and a press
/// gives a real button response via [Pressable].
class KanaCell extends StatelessWidget {
  const KanaCell({
    super.key,
    required this.entries,
    required this.selected,
    required this.mark,
    required this.onTap,
  });

  final List<KanaEntry> entries; // 1 (single script) or 2 (Both: hiragana, katakana)
  final bool selected;
  final StudyMark mark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final both = entries.length > 1;
    final romaji = entries.first.romaji;

    return Pressable(
      label: '${entries.map((e) => e.char).join(' ')} $romaji',
      selected: selected,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.timed(context, Motion.fast),
        curve: Motion.out,
        height: 56,
        decoration: BoxDecoration(
          color: selected ? jc.brandSoft : jc.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: selected ? jc.brand : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (both)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(entries[0].char,
                            style: TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w600, height: 1, color: jc.ink)),
                        const SizedBox(width: 6),
                        Text(entries[1].char,
                            style: TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w600, height: 1, color: jc.muted)),
                      ],
                    )
                  else
                    Text(entries.first.char,
                        style: TextStyle(
                            fontSize: 25, fontWeight: FontWeight.w600, height: 1, color: jc.ink)),
                  const SizedBox(height: 4),
                  Text(romaji,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          height: 1,
                          color: jc.muted)),
                ],
              ),
            ),
            if (mark != StudyMark.none) Positioned(top: 5, right: 5, child: StudyDot(mark: mark)),
          ],
        ),
      ),
    );
  }
}
