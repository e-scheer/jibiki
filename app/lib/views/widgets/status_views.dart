import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(
          padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 40, color: context.jc.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: onRetry, child: Text(context.trText('Retry'))),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint(
      {super.key, required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: jc.muted),
            const SizedBox(height: 14),
            Text(title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: jc.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single static placeholder block (a skeleton bone). Group several inside a
/// [_Pulse] to make them breathe; on its own it's just a rounded neutral shape.
class Skeleton extends StatelessWidget {
  const Skeleton(
      {super.key,
      this.width,
      this.height = 12,
      this.radius = 6,
      this.circle = false});
  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: circle ? (width ?? height) : height,
      decoration: BoxDecoration(
        color: context.jc.surfaceAlt,
        borderRadius: circle ? null : BorderRadius.circular(radius),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }
}

/// Breathes its child's opacity so a cluster of [Skeleton]s reads as "loading".
/// One controller drives the whole group; the pulse holds still under
/// reduce-motion (the placeholder simply sits at a steady tone).
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Motion.enabled(context)) {
      return Opacity(opacity: 0.7, child: widget.child);
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) =>
          Opacity(opacity: 0.5 + 0.4 * _c.value, child: widget.child),
    );
  }
}

/// Loading placeholder for a list of entries (search results, dictionary browse):
/// stacked tile shapes instead of a spinner floating in empty content.
class SkeletonTileList extends StatelessWidget {
  const SkeletonTileList({super.key, this.count = 8});
  final int count;

  @override
  Widget build(BuildContext context) {
    return _Pulse(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: count,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 150, height: 18),
                    SizedBox(height: 9),
                    Skeleton(width: 230, height: 12),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Skeleton(width: 44, height: 20, radius: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder for a grid of cards (deck grids, kanji grids). Give it
/// [maxCrossAxisExtent] to match a responsive content grid, or a fixed
/// [crossAxisCount]. Set [shrinkWrap] when it lives inside another scroll view.
class SkeletonCardGrid extends StatelessWidget {
  const SkeletonCardGrid({
    super.key,
    this.count = 6,
    this.crossAxisCount = 2,
    this.maxCrossAxisExtent,
    this.childAspectRatio = 1.0,
    this.padding = const EdgeInsets.all(16),
    this.shrinkWrap = false,
  });
  final int count;
  final int crossAxisCount;
  final double? maxCrossAxisExtent;
  final double childAspectRatio;
  final EdgeInsets padding;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final delegate = maxCrossAxisExtent != null
        ? SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxCrossAxisExtent!,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          )
        : SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          );
    return _Pulse(
      child: GridView.builder(
        gridDelegate: delegate,
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        itemCount: count,
        itemBuilder: (_, __) => const Skeleton(
            width: double.infinity, height: double.infinity, radius: Radii.lg),
      ),
    );
  }
}

/// A small pill used for JLPT / "common" / part-of-speech tags.
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final fg = color ?? jc.body;
    final bg = color?.withValues(alpha: 0.12) ?? jc.surfaceAlt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(label,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
