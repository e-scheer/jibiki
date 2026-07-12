import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../widgets/pressable.dart';

/// Shared NeoPop primitives for the study flow. These intentionally keep most
/// surfaces flat. Hard shadows are reserved for the main card, stickers and the
/// primary action, matching the hierarchy in the reference HTML.
class StudyPanel extends StatelessWidget {
  const StudyPanel({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.radius = 14,
    this.borderWidth = 2.5,
    this.shadow = 0,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double borderWidth;
  final double shadow;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? context.jc.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: context.jc.ink, width: borderWidth),
          boxShadow: shadow <= 0
              ? null
              : [
                  BoxShadow(
                    color: context.jc.ink,
                    blurRadius: 0,
                    offset: Offset(shadow, shadow),
                  ),
                ],
        ),
        child: child,
      );
}

class StudyProgressRail extends StatelessWidget {
  const StudyProgressRail({
    super.key,
    required this.value,
    this.color,
    this.height = 20,
    this.animate = true,
  });

  final double value;
  final Color? color;
  final double height;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    Widget rail(double progress) => Container(
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.jc.surface,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: context.jc.ink, width: 2.5),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color ?? context.jc.brand,
                  border: progress >= 0.995
                      ? null
                      : Border(
                          right: BorderSide(color: context.jc.ink, width: 2.5),
                        ),
                ),
              ),
            ),
          ),
        );
    if (!animate || !Motion.enabled(context)) return rail(target);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: Motion.timed(context, Motion.base),
      curve: Motion.out,
      builder: (_, progress, __) => rail(progress),
    );
  }
}

class StudyActionButton extends StatelessWidget {
  const StudyActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
    this.foreground,
    this.height = 54,
    this.shadow = 4,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final Color? foreground;
  final double height;
  final double shadow;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? context.jc.ink;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Pressable(
        label: label,
        onTap: busy ? null : onTap,
        haptic: false,
        pressedScale: 1,
        child: StudyPanel(
          color: color ?? context.jc.acid,
          shadow: shadow,
          radius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
                )
              else if (icon != null)
                Icon(icon, size: 20, color: fg),
              if (busy || icon != null) const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudySticker extends StatelessWidget {
  const StudySticker(
    this.label, {
    super.key,
    this.color,
    this.angle = -5,
    this.large = false,
  });

  final String label;
  final Color? color;
  final double angle;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final sticker = Transform.rotate(
      angle: angle * math.pi / 180,
      child: StudyPanel(
        color: color ?? context.jc.acid,
        shadow: large ? 5 : 3,
        radius: 9,
        padding: EdgeInsets.symmetric(
          horizontal: large ? 16 : 10,
          vertical: large ? 9 : 6,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: context.jc.ink,
            fontSize: large ? 18 : 12,
            fontWeight: FontWeight.w900,
            letterSpacing: large ? 0.7 : 0.2,
            height: 1,
          ),
        ),
      ),
    );
    if (!Motion.enabled(context)) return sticker;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 1),
      duration: Motion.timed(context, const Duration(milliseconds: 360)),
      curve: Motion.outStrong,
      builder: (_, scale, child) => Transform.scale(
        scale: scale,
        child: Opacity(opacity: scale.clamp(0, 1), child: child),
      ),
      child: sticker,
    );
  }
}

/// Five outlined pieces around a result sticker. The animation only uses
/// translation, scale and opacity, so it remains cheap on modest devices.
class StudyConfetti extends StatelessWidget {
  const StudyConfetti({super.key, this.size = const Size(190, 100)});

  final Size size;

  @override
  Widget build(BuildContext context) {
    final colors = [
      context.jc.magenta,
      context.jc.brand,
      context.jc.lime,
      context.jc.coral,
      context.jc.magenta,
    ];
    const placements = [
      Alignment(-0.75, -0.45),
      Alignment(-0.18, -0.92),
      Alignment(0.82, -0.18),
      Alignment(0.72, 0.72),
      Alignment(0.3, -0.76),
    ];
    Widget pieces(double t) => SizedBox.fromSize(
          size: size,
          child: Stack(
            children: [
              for (var i = 0; i < colors.length; i++)
                Align(
                  alignment: placements[i],
                  child: Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, -8 * (1 - t)),
                      child: Transform.rotate(
                        angle: (i.isEven ? 0.34 : -0.22),
                        child: Transform.scale(
                          scale: t,
                          child: Container(
                            width: i.isEven ? 17 : 11,
                            height: i.isEven ? 10 : 18,
                            decoration: BoxDecoration(
                              color: colors[i],
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: context.jc.ink,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
    if (!Motion.enabled(context)) return pieces(1);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.timed(context, const Duration(milliseconds: 480)),
      curve: Motion.out,
      builder: (_, t, __) => pieces(t),
    );
  }
}
