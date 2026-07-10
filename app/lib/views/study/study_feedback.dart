import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A brief "you got it" flourish shown over a study stage when a round is won: a
/// check pops in over a soft ring that expands once and fades. It makes the win
/// unmistakable and fills the short beat before the next card slides in, so the
/// pause reads as a small celebration rather than a freeze. Non-blocking, and it
/// collapses to a static badge under reduce-motion.
class SuccessBurst extends StatefulWidget {
  const SuccessBurst({super.key, this.size = 76});

  /// Diameter of the solid check disc; the ring pulses out past it.
  final double size;

  @override
  State<SuccessBurst> createState() => _SuccessBurstState();
}

class _SuccessBurstState extends State<SuccessBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final disc = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: jc.ratingGood,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: jc.ratingGood.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 8)),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(Icons.check_rounded,
          color: Colors.white, size: widget.size * 0.56),
    );

    // Reduce-motion: no pop, no pulse, just the badge.
    if (!Motion.enabled(context)) return disc;

    return AnimatedBuilder(
      animation: _c,
      child: disc,
      builder: (context, child) {
        final t = _c.value;
        // Disc: an overshoot-free ease-out pop that lands full by ~45%.
        final pop = Motion.outStrong.transform((t / 0.45).clamp(0.0, 1.0));
        final discOpacity = (t / 0.18).clamp(0.0, 1.0);
        // Ring: a single clean pulse expanding past the disc as it fades.
        final ringT = Motion.out.transform(t);
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: (1 - t) * 0.4,
              child: Transform.scale(
                scale: 0.7 + 1.1 * ringT,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: jc.ratingGood, width: 3),
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: discOpacity,
              child: Transform.scale(scale: 0.5 + 0.5 * pop, child: child),
            ),
          ],
        );
      },
    );
  }
}

/// Lays a [SuccessBurst] over the centre of [child] while [show] is true, without
/// intercepting taps. One place for every game to signal a won round the same way.
class WinOverlay extends StatelessWidget {
  const WinOverlay(
      {super.key, required this.show, required this.child, this.size = 76});
  final bool show;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (show)
          Positioned.fill(
            child:
                IgnorePointer(child: Center(child: SuccessBurst(size: size))),
          ),
      ],
    );
  }
}

/// The negative counterpart to [SuccessBurst]: a cross pops onto a red disc,
/// gives a short side-to-side shake, then fades itself out so the answer revealed
/// underneath stays readable through the miss linger. It makes a miss as clearly
/// acknowledged as a win, rather than leaving only a quiet colour change. Collapses
/// to a static badge under reduce-motion.
class MissBurst extends StatefulWidget {
  const MissBurst({super.key, this.size = 76});

  /// Diameter of the solid cross disc.
  final double size;

  @override
  State<MissBurst> createState() => _MissBurstState();
}

class _MissBurstState extends State<MissBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final disc = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: jc.ratingAgain,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: jc.ratingAgain.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 8)),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(Icons.close_rounded,
          color: Colors.white, size: widget.size * 0.56),
    );

    // Reduce-motion: no pop, no shake, no fade, just the badge.
    if (!Motion.enabled(context)) return disc;

    return AnimatedBuilder(
      animation: _c,
      child: disc,
      builder: (context, child) {
        final t = _c.value;
        // Disc: the same overshoot-free pop as the win, landing full by ~45%.
        final pop = Motion.outStrong.transform((t / 0.45).clamp(0.0, 1.0));
        // Shake: a quick two-beat wobble that decays as the disc settles.
        final shakeT = ((t - 0.15) / 0.35).clamp(0.0, 1.0);
        final dx = shakeT > 0 && shakeT < 1
            ? math.sin(shakeT * math.pi * 3) * 6 * (1 - shakeT)
            : 0.0;
        // Fade out over the tail so the corrected answer beneath reads clearly.
        final opacity =
            ((t / 0.18).clamp(0.0, 1.0)) * (1 - ((t - 0.7) / 0.3).clamp(0.0, 1.0));
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(scale: 0.5 + 0.5 * pop, child: child),
          ),
        );
      },
    );
  }
}

/// Lays a [MissBurst] over the centre of [child] while [show] is true, without
/// intercepting taps. The negative counterpart to [WinOverlay].
class MissOverlay extends StatelessWidget {
  const MissOverlay(
      {super.key, required this.show, required this.child, this.size = 76});
  final bool show;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (show)
          Positioned.fill(
            child: IgnorePointer(child: Center(child: MissBurst(size: size))),
          ),
      ],
    );
  }
}
