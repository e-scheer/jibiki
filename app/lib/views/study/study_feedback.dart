import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'study_chrome.dart';

/// A compact sticker celebration shared by quiz, match and listening rounds.
/// It uses the same outlined paper pieces as the review card in the HTML.
class SuccessBurst extends StatelessWidget {
  const SuccessBurst({super.key, this.size = 76});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size * 2.35,
        height: size * 1.5,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: StudyConfetti(size: Size(size * 2.35, size * 1.5)),
            ),
            StudySticker(
              'RETENU',
              color: context.jc.acid,
              angle: -5,
              large: true,
            ),
          ],
        ),
      );
}

class WinOverlay extends StatelessWidget {
  const WinOverlay({
    super.key,
    required this.show,
    required this.child,
    this.size = 76,
  });

  final bool show;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          child,
          if (show)
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: const Alignment(0.58, -0.72),
                  child: SuccessBurst(size: size),
                ),
              ),
            ),
        ],
      );
}

class MissBurst extends StatelessWidget {
  const MissBurst({super.key, this.size = 76});

  final double size;

  @override
  Widget build(BuildContext context) {
    final badge = StudySticker(
      'ENCORE',
      color: context.jc.coral,
      angle: 4,
      large: true,
    );
    if (!Motion.enabled(context)) return badge;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -1, end: 0),
      duration: Motion.timed(context, const Duration(milliseconds: 420)),
      curve: Motion.outStrong,
      builder: (_, offset, child) => Transform.translate(
        offset: Offset(offset * 10, 0),
        child: child,
      ),
      child: badge,
    );
  }
}

class MissOverlay extends StatelessWidget {
  const MissOverlay({
    super.key,
    required this.show,
    required this.child,
    this.size = 76,
  });

  final bool show;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          child,
          if (show)
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: const Alignment(0.58, -0.72),
                  child: MissBurst(size: size),
                ),
              ),
            ),
        ],
      );
}
