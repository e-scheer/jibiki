import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

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
  bool _motion = true; // mirrors reduce-motion, refreshed each build

  // Drives both the settle (spring) and the throw (eased tween) by interpolating
  // _drag between these anchors; _animCurve is null for the raw spring value.
  late final AnimationController _return = AnimationController(vsync: this, duration: Motion.base);
  // Snappy flip, the answer should appear quickly.
  late final AnimationController _flip =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  Offset _animFrom = Offset.zero;
  Offset _animTo = Offset.zero;
  Curve? _animCurve;
  bool _animating = false;
  Rating? _lastCrossed;

  // A critically damped spring: it continues the finger's motion and settles home
  // with no overshoot (a natural spring, not a dated bounce).
  static final SpringDescription _snapSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 260, ratio: 1.0);

  @override
  void initState() {
    super.initState();
    widget.controller._bind(this);
    _return.addListener(() {
      if (!_animating) return;
      final raw = _return.value;
      final t = _animCurve == null ? raw : _animCurve!.transform(raw.clamp(0.0, 1.0));
      setState(() => _drag = Offset.lerp(_animFrom, _animTo, t)!);
      widget.onProgress?.call(_progress(_drag).clamp(0.0, 1.0));
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
    _animating = false;
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
    final v = d.velocity.pixelsPerSecond;
    // Commit on distance OR on a decisive flick: a quick throw grades even before
    // the card crosses the distance threshold, the way a swipe deck should feel.
    if (_progress(_drag) >= 1 || (v.distance > 1000 && _progress(_drag) > 0.35)) {
      _flingOut(_ratingFor(_drag), v);
    } else {
      _snapBack(v);
    }
  }

  void _snapBack(Offset velocity) {
    _lastCrossed = null;
    if (!_motion) {
      _animating = false;
      setState(() => _drag = Offset.zero);
      widget.onProgress?.call(0);
      return;
    }
    final dist = _drag.distance;
    _animFrom = _drag;
    _animTo = Offset.zero;
    _animCurve = null; // raw spring position
    _animating = true;
    // Release velocity projected onto the drag→centre axis, in [0,1]/s, so the
    // settle carries the finger's momentum instead of restarting from rest.
    final vNorm = dist == 0 ? 0.0 : (velocity.dx * -_drag.dx + velocity.dy * -_drag.dy) / (dist * dist);
    _return.animateWith(SpringSimulation(_snapSpring, 0.0, 1.0, vNorm));
  }

  void _flingOut(Rating r, [Offset velocity = Offset.zero]) {
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
    if (!_motion) {
      _animating = false;
      setState(() => _drag = target);
      widget.onRate(r);
      return;
    }
    _animFrom = _drag;
    _animTo = target;
    _animCurve = Motion.out;
    _animating = true;
    // A harder flick leaves faster; a button tap (no velocity) uses the full time.
    final ms = (260 - velocity.distance / 24).clamp(150, 260).toInt();
    _return.duration = Duration(milliseconds: ms);
    _return.forward(from: 0).whenComplete(() => widget.onRate(r));
  }

  @override
  Widget build(BuildContext context) {
    // Reduce-motion alternative: collapse the flip + fling/snap to instant so the
    // 3D rotation and the off-screen throw don't play. Direct-drag feedback
    // (rotation, colour wash) stays, it tracks the finger, it isn't animation.
    _motion = Motion.enabled(context);
    _flip.duration = Motion.timed(context, const Duration(milliseconds: 300));

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
          color: wash != null ? wash.withValues(alpha: (0.35 + progress * 0.65).clamp(0.0, 1.0)) : jc.hairline,
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
            IgnorePointer(child: _DirectionalWash(dir: dir!, color: wash, progress: progress)),
          if (wash != null) _Stamp(rating: dir!, color: wash, progress: progress),
        ],
      ),
    );
  }
}

/// A colour glow that grows from the edge you're dragging toward, so the card
/// leans into the grade instead of tinting uniformly. Stronger, more directional
/// than a flat overlay: it reads like the card is being pulled that way.
class _DirectionalWash extends StatelessWidget {
  const _DirectionalWash({required this.dir, required this.color, required this.progress});
  final Rating dir;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final (begin, end) = switch (dir) {
      Rating.again => (Alignment.centerLeft, Alignment.centerRight),
      Rating.good => (Alignment.centerRight, Alignment.centerLeft),
      Rating.easy => (Alignment.topCenter, Alignment.bottomCenter),
      Rating.hard => (Alignment.bottomCenter, Alignment.topCenter),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [color.withValues(alpha: (progress * 0.3).clamp(0.0, 0.3)), Colors.transparent],
          stops: const [0.0, 0.72],
        ),
      ),
    );
  }
}

/// The Tinder-style grade stamp: a bold badge that fades + scales in toward the
/// drag direction, set on an opaque plate with a coloured halo so the label stays
/// crisp over the glyph beneath it.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.rating, required this.color, required this.progress});
  final Rating rating;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final align = switch (rating) {
      Rating.easy => const Alignment(0, -0.66),
      Rating.hard => const Alignment(0, 0.66),
      Rating.again => const Alignment(-0.72, -0.4),
      Rating.good => const Alignment(0.72, -0.4),
    };
    final tilt = switch (rating) {
      Rating.again => -0.22,
      Rating.good => 0.22,
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
              scale: 0.72 + 0.42 * t,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: context.jc.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: color, width: 3.5),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 6)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(ratingIcon(rating), color: color, size: 26),
                    const SizedBox(width: 9),
                    Text(
                      rating.label.toUpperCase(),
                      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 23, letterSpacing: 1.5),
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
