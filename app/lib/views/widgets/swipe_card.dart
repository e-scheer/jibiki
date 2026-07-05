import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../theme/app_theme.dart';

/// The signature review interaction, a Tinder-grade card.
/// Tap to flip, then swipe to grade. Direction → FSRS grade:
///   ← Again · ↓ Hard · ↑ Easy · → Good
/// As you drag, the card rotates, washes its colour, lifts, and a bold stamp
/// fades/scales in toward the target grade. A bottom action bar mirrors it.
class SwipeCardController {
  _SwipeCardState? _state;
  void _bind(_SwipeCardState s) => _state = s;
  void _unbind(_SwipeCardState s) {
    if (_state == s) _state = null;
  }

  bool get isRevealed => _state?._revealed ?? false;
  void reveal() => _state?._reveal();
  void rate(Rating r) => _state?._flingOut(r);
}

Rating _ratingFor(Offset o) {
  if (o.dx.abs() >= o.dy.abs()) return o.dx >= 0 ? Rating.good : Rating.again;
  return o.dy <= 0 ? Rating.easy : Rating.hard;
}

Color ratingColor(BuildContext c, Rating r) => switch (r) {
      Rating.again => c.jc.ratingAgain,
      Rating.hard => c.jc.ratingHard,
      Rating.good => c.jc.ratingGood,
      Rating.easy => c.jc.ratingEasy,
    };

String ratingArrow(Rating r) => switch (r) {
      Rating.again => '←',
      Rating.hard => '↓',
      Rating.easy => '↑',
      Rating.good => '→',
    };

IconData ratingIcon(Rating r) => switch (r) {
      Rating.again => Icons.replay_rounded,
      Rating.hard => Icons.trending_down_rounded,
      Rating.good => Icons.check_rounded,
      Rating.easy => Icons.bolt_rounded,
    };

class SwipeCard extends StatefulWidget {
  const SwipeCard({
    super.key,
    required this.front,
    required this.back,
    required this.onRate,
    required this.controller,
    this.onRevealChanged,
    this.onProgress,
  });

  final Widget front;
  final Widget back;
  final void Function(Rating) onRate;
  final SwipeCardController controller;
  final ValueChanged<bool>? onRevealChanged;

  /// Drag magnitude 0..1 toward the current threshold, drives the deck peek.
  final ValueChanged<double>? onProgress;

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> with TickerProviderStateMixin {
  Offset _drag = Offset.zero;
  bool _revealed = false;
  bool _gone = false;

  late final AnimationController _return = AnimationController(vsync: this, duration: Motion.base);
  // Snappy flip, the answer should appear quickly.
  late final AnimationController _flip =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  Animation<Offset>? _returnAnim;
  Rating? _lastCrossed;

  @override
  void initState() {
    super.initState();
    widget.controller._bind(this);
    _return.addListener(() {
      if (_returnAnim != null) {
        setState(() => _drag = _returnAnim!.value);
        widget.onProgress?.call(_progress(_drag).clamp(0.0, 1.0));
      }
    });
  }

  @override
  void dispose() {
    widget.controller._unbind(this);
    _return.dispose();
    _flip.dispose();
    super.dispose();
  }

  void _reveal() {
    if (_revealed) return;
    setState(() => _revealed = true);
    _flip.forward();
    Haptics.light();
    widget.onRevealChanged?.call(true);
  }

  /// Tap handler: first tap reveals; tapping an already-revealed card flips it
  /// between the answer and the question (a quick peek), animated.
  void _onTap() {
    if (!_revealed) {
      _reveal();
      return;
    }
    Haptics.tick();
    if (_flip.value >= 0.5) {
      _flip.reverse();
    } else {
      _flip.forward();
    }
  }

  Size get _size => (context.findRenderObject() as RenderBox?)?.size ?? const Size(360, 520);

  double _progress(Offset o) {
    final s = _size;
    return math.max(o.dx.abs() / (s.width * 0.42), o.dy.abs() / (s.height * 0.34));
  }

  void _onPanUpdate(DragUpdateDetails d) {
    // A swipe reveals the card too, no need to tap first, then it grades.
    if (!_revealed) _reveal();
    _return.stop();
    setState(() => _drag += d.delta);
    widget.onProgress?.call(_progress(_drag).clamp(0.0, 1.0));
    final crossed = _progress(_drag) >= 1 ? _ratingFor(_drag) : null;
    if (crossed != _lastCrossed) {
      if (crossed != null) Haptics.tick();
      _lastCrossed = crossed;
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_revealed) return;
    if (_progress(_drag) >= 1) {
      _flingOut(_ratingFor(_drag));
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    _lastCrossed = null;
    _returnAnim = Tween(begin: _drag, end: Offset.zero)
        .animate(CurvedAnimation(parent: _return, curve: Motion.outStrong));
    _return.forward(from: 0);
  }

  void _flingOut(Rating r) {
    if (_gone) return;
    if (!_revealed) {
      _reveal();
      return;
    }
    _gone = true;
    Haptics.medium();
    final s = _size;
    final target = switch (r) {
      Rating.good => Offset(s.width * 1.5, _drag.dy - s.height * 0.15),
      Rating.again => Offset(-s.width * 1.5, _drag.dy - s.height * 0.15),
      Rating.easy => Offset(_drag.dx, -s.height * 1.4),
      Rating.hard => Offset(_drag.dx, s.height * 1.4),
    };
    _returnAnim =
        Tween(begin: _drag, end: target).animate(CurvedAnimation(parent: _return, curve: Motion.out));
    _return.forward(from: 0).whenComplete(() => widget.onRate(r));
  }

  @override
  Widget build(BuildContext context) {
    // Reduce-motion alternative: collapse the flip + fling/snap to instant so the
    // 3D rotation and the off-screen throw don't play. Direct-drag feedback
    // (rotation, colour wash) stays, it tracks the finger, it isn't animation.
    _flip.duration = Motion.timed(context, const Duration(milliseconds: 300));
    _return.duration = Motion.timed(context, Motion.base);

    final s = MediaQuery.sizeOf(context);
    final angle = (_drag.dx / s.width) * 0.18;
    final prog = _progress(_drag).clamp(0.0, 1.0);
    final dir = prog > 0.06 && _revealed ? _ratingFor(_drag) : null;

    return GestureDetector(
      onTap: _onTap,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: RepaintBoundary(
        child: Transform.translate(
          offset: _drag,
          child: Transform.rotate(
            angle: angle,
            child: AnimatedBuilder(
              animation: _flip,
              builder: (context, _) {
                final t = _flip.value;
                final showBack = t >= 0.5;
                final face = showBack ? widget.back : widget.front;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(t * math.pi),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: showBack ? (Matrix4.identity()..rotateY(math.pi)) : Matrix4.identity(),
                    child: _CardShell(dir: dir, progress: prog, child: face),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.dir, this.progress = 0});
  final Widget child;
  final Rating? dir;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final wash = dir == null ? null : ratingColor(context, dir!);
    return Container(
      decoration: BoxDecoration(
        color: jc.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(
          color: wash != null ? wash.withValues(alpha: (0.3 + progress).clamp(0.0, 1.0)) : jc.hairline,
          width: wash != null ? 2.5 : 1,
        ),
        boxShadow: Shadows.lifted(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(child: child),
          if (wash != null)
            IgnorePointer(child: Container(color: wash.withValues(alpha: progress * 0.14))),
          if (wash != null) _Stamp(rating: dir!, color: wash, progress: progress),
        ],
      ),
    );
  }
}

/// The Tinder-style grade stamp: a bold badge that fades + scales in toward the
/// drag direction.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.rating, required this.color, required this.progress});
  final Rating rating;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final align = switch (rating) {
      Rating.easy => const Alignment(0, -0.62),
      Rating.hard => const Alignment(0, 0.62),
      Rating.again => const Alignment(-0.75, -0.35),
      Rating.good => const Alignment(0.75, -0.35),
    };
    final tilt = switch (rating) {
      Rating.again => -0.24,
      Rating.good => 0.24,
      _ => 0.0,
    };
    final t = ((progress - 0.06) / 0.5).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Align(
        alignment: align,
        child: Opacity(
          opacity: t,
          child: Transform.rotate(
            angle: tilt,
            child: Transform.scale(
              scale: 0.7 + 0.5 * t,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: color, width: 3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(ratingIcon(rating), color: color, size: 26),
                    const SizedBox(width: 8),
                    Text(
                      rating.label.toUpperCase(),
                      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
