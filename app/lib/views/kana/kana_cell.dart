import 'package:flutter/material.dart';

import '../../models/kana.dart';
import '../../theme/app_theme.dart';
import '../widgets/pressable.dart';
import '../widgets/study_mark.dart';

/// One compact cell in the kana matrix. Its full background communicates study
/// state, while selection only strengthens the outline. Cells never cast a
/// shadow because density comes from their shared 3 px grid rhythm.
class KanaCell extends StatelessWidget {
  const KanaCell({
    super.key,
    required this.entries,
    required this.selected,
    required this.mark,
    required this.onTap,
    this.due = false,
  });

  final List<KanaEntry>
      entries; // 1 (single script) or 2 (Both: hiragana, katakana)
  final bool selected;
  final StudyMark mark;
  final VoidCallback onTap;
  final bool due;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final both = entries.length > 1;
    final romaji = entries.first.romaji;
    final background = due
        ? jc.magenta
        : mark == StudyMark.known
            ? jc.lime
            : mark == StudyMark.seen
                ? jc.acid
                : jc.surface;
    final status = due
        ? 'dû'
        : mark == StudyMark.known
            ? '✓'
            : mark == StudyMark.seen
                ? '●'
                : '';

    return Pressable(
      label: '${entries.map((e) => e.char).join(' ')} $romaji',
      selected: selected,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.timed(context, Motion.fast),
        curve: Motion.out,
        height: 56,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: jc.ink,
            width: selected ? 3.5 : 2.5,
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
                                fontFamily: 'NotoSansJP',
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                color: jc.ink)),
                        const SizedBox(width: 5),
                        Text(entries[1].char,
                            style: TextStyle(
                                fontFamily: 'NotoSansJP',
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                color: jc.ink)),
                      ],
                    )
                  else
                    Text(entries.first.char,
                        style: TextStyle(
                            fontFamily: 'NotoSansJP',
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            color: jc.ink)),
                  const SizedBox(height: 2),
                  Text(romaji,
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: jc.ink)),
                ],
              ),
            ),
            if (status.isNotEmpty)
              Positioned(
                top: due ? 4 : 3,
                right: 5,
                child: Text(
                  status,
                  style: TextStyle(
                    color: jc.ink,
                    fontSize: due
                        ? 8.5
                        : mark == StudyMark.seen
                            ? 8
                            : 10,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            if (selected)
              Positioned(
                left: 4,
                bottom: 3,
                child: Icon(Icons.check_box_rounded, size: 13, color: jc.ink),
              ),
          ],
        ),
      ),
    );
  }
}
