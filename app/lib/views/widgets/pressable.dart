import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A tap target that behaves like a real button:
///
///  * it is announced to assistive tech as a button (via [Semantics]), with an
///    optional [label] and [selected] state,
///  * it gives a crisp pressed response, a subtle scale, no Material ripple, to
///    match the flat theme, that collapses to instant when reduce-motion is on,
///  * it fires a selection haptic on tap.
///
/// Reach for this instead of a bare [GestureDetector] anywhere the user taps
/// something as a button (grade buttons, chart cells, carousel controls). Bare
/// gesture surfaces (drawing canvases) are not buttons and should stay as-is.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.label,
    this.selected = false,
    this.pressedScale = 1,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Spoken label for screen readers. Omit when the [child] already exposes clear
  /// text; provide it when the child is an icon/glyph whose meaning isn't textual.
  final String? label;
  final bool selected;
  final double pressedScale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  bool get _active => widget.onTap != null;

  void _set(bool v) {
    if (!_active) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _active,
      selected: widget.selected,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: _active
            ? () {
                if (widget.haptic) Haptics.tick();
                widget.onTap!();
              }
            : null,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: _down ? 1 : 0),
          duration: Motion.timed(context, Motion.fast),
          curve: Motion.out,
          child: widget.child,
          builder: (context, value, child) => Transform.translate(
            offset: Offset(4 * value, 4 * value),
            child: Transform.scale(
              scale: 1 - (1 - widget.pressedScale) * value,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
