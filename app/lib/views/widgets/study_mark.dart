import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// How far along a dictionary item is in the user's study deck.
enum StudyMark { none, seen, known }

/// Map a card state (0 new, 1 learning, 2 review, 3 relearning) - or null for "no
/// card" - to a display mark. State >= 2 has graduated to review, so it reads as
/// "known"; 0-1 is in progress ("seen").
StudyMark studyMarkFor(int? state) => state == null
    ? StudyMark.none
    : (state >= 2 ? StudyMark.known : StudyMark.seen);

/// A small, quiet corner indicator for an item's study status: a filled vermilion
/// dot when known, a hollow vermilion ring when seen/in-progress, nothing
/// otherwise. Shape differs by state (fill vs ring), so it never relies on colour
/// alone - and it stays a small dot, not a loud checkbox.
class StudyDot extends StatelessWidget {
  const StudyDot({super.key, required this.mark, this.size = 9});
  final StudyMark mark;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (mark == StudyMark.none) return const SizedBox.shrink();
    final jc = context.jc;
    final known = mark == StudyMark.known;
    return Semantics(
      label: known ? 'Known' : 'In progress',
      child: Container(
        width: size < 16 ? 17 : size,
        height: size < 16 ? 17 : size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: known ? jc.lime : jc.acid,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: jc.ink, width: 2),
        ),
        child: Text(known ? '✓' : '•',
            style: TextStyle(
                color: jc.ink,
                fontSize: known ? 10 : 9,
                fontWeight: FontWeight.w900,
                height: 1)),
      ),
    );
  }
}
