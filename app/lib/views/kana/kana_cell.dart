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
    this.focused = false,
  });

  final List<KanaEntry>
      entries; // 1 (single script) or 2 (Both: hiragana, katakana)
  final bool selected;
  final StudyMark mark;
  final VoidCallback onTap;
  final bool due;
  final bool focused;

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

    return Pressable.builder(
      label: '${entries.map((e) => e.char).join(' ')} $romaji',
      selected: selected || focused,
      onTap: onTap,
      focusRadius: 10,
      builder: (context, pressed) => AnimatedContainer(
        duration: Motion.timed(context, Motion.fast),
        curve: Motion.out,
        height: 56,
        transform: Matrix4.translationValues(
          focused ? -2 : 0,
          focused ? -2 : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: jc.ink,
            width: focused ? 3 : (selected ? 3.5 : 2.5),
          ),
          boxShadow: focused && !pressed
              ? [
                  BoxShadow(
                    color: jc.ink,
                    blurRadius: 0,
                    offset: const Offset(4, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
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
                                fontFamily: 'ZenKakuGothicNew',
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                color: jc.ink)),
                        const SizedBox(width: 5),
                        Text(entries[1].char,
                            style: TextStyle(
                                fontFamily: 'ZenKakuGothicNew',
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                color: jc.ink)),
                      ],
                    )
                  else
                    Text(entries.first.char,
                        style: TextStyle(
                            fontFamily: 'ZenKakuGothicNew',
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
            if (selected && !focused)
              Positioned(
                left: 4,
                bottom: 3,
                child: Icon(Icons.check_box_rounded, size: 13, color: jc.ink),
              ),
            if (focused)
              Positioned(
                left: -7,
                bottom: -7,
                child: Transform.rotate(
                  angle: .24,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: jc.brand,
                      border: Border.all(color: jc.ink, width: 2.5),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
