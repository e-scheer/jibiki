import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.focusRadius = 12,
  }) : builder = null;

  const Pressable.builder({
    super.key,
    required this.builder,
    required this.onTap,
    this.label,
    this.selected = false,
    this.pressedScale = 1,
    this.haptic = true,
    this.focusRadius = 12,
  }) : child = null;

  final Widget? child;

  /// Use this form when the painted child owns a hard shadow. The builder gets
  /// the pressed state, so it can animate that shadow to zero while this widget
  /// performs the contract's fixed 4 px translation.
  final Widget Function(BuildContext context, bool pressed)? builder;
  final VoidCallback? onTap;

  /// Spoken label for screen readers. Omit when the [child] already exposes clear
  /// text; provide it when the child is an icon/glyph whose meaning isn't textual.
  final String? label;
  final bool selected;
  final double pressedScale;
  final bool haptic;
  final double focusRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _focused = false;

  bool get _active => widget.onTap != null;

  void _set(bool v) {
    if (!_active) return;
    if (_down != v) setState(() => _down = v);
  }

  void _activate() {
    if (!_active) return;
    if (widget.haptic) Haptics.tick();
    widget.onTap!();
  }

  void _activateFromKeyboard() {
    if (!_active) return;
    _set(true);
    _activate();
    Future<void>.delayed(Motion.fast, () {
      if (mounted) _set(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final paintedChild = widget.builder?.call(context, _down) ?? widget.child!;
    return FocusableActionDetector(
      enabled: _active,
      mouseCursor:
          _active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowFocusHighlight: (value) {
        if (_focused != value) setState(() => _focused = value);
      },
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activateFromKeyboard();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        enabled: _active,
        selected: widget.selected,
        label: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _set(true),
          onTapCancel: () => _set(false),
          onTapUp: (_) => _set(false),
          onTap: _active ? _activate : null,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: _down ? 1 : 0),
            duration: Motion.timed(context, const Duration(milliseconds: 70)),
            curve: Curves.easeOut,
            child: paintedChild,
            builder: (context, value, child) => Transform.translate(
              offset: Offset(4 * value, 4 * value),
              child: Transform.scale(
                scale: 1 - (1 - widget.pressedScale) * value,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    child!,
                    if (_focused)
                      Positioned(
                        top: -5,
                        left: -5,
                        right: -5,
                        bottom: -5,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(widget.focusRadius + 5),
                              border: Border.all(
                                color: context.jc.brand,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
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
