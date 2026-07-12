import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'jibiki_brand.dart';
import 'neo_pop.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: NeoChaseLoader(),
        ),
      );
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: NeoCard(
            tone: NeoTone.coral,
            shadow: 6,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: context.jc.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.jc.ink, width: 2.5),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.cloud_off_outlined, size: 30),
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 18),
                  NeoPrimaryButton(
                    label: context.trText('Retry'),
                    icon: Icons.refresh,
                    onTap: onRetry,
                  ),
                ],
              ],
            ),
          ),
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
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: NeoCard(
            tone: NeoTone.lavender,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: jc.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: jc.ink, width: 2.5),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 30, color: jc.ink),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: jc.body,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
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
        color: Theme.of(context).brightness == Brightness.dark
            ? context.jc.surfaceAlt
            : const Color(0xFFD7D3E3),
        borderRadius: circle ? null : BorderRadius.circular(radius),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        border: Border.all(color: context.jc.ink, width: 2.5),
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
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Motion.enabled(context)) {
      return widget.child;
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
        separatorBuilder: (_, __) => const SizedBox(height: 9),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: context.jc.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.jc.ink, width: 2.5),
            ),
            child: const Row(
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
        itemBuilder: (context, __) => LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxHeight < 150 &&
                constraints.maxWidth > constraints.maxHeight * 1.8;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.jc.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.jc.ink, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: context.jc.ink,
                    blurRadius: 0,
                    offset: const Offset(4, 4),
                  ),
                ],
              ),
              child: horizontal
                  ? const Row(
                      children: [
                        Skeleton(width: 58, height: 58, radius: 9),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Skeleton(width: 150, height: 13),
                              SizedBox(height: 8),
                              FractionallySizedBox(
                                widthFactor: 0.72,
                                child: Skeleton(
                                  width: double.infinity,
                                  height: 10,
                                ),
                              ),
                              SizedBox(height: 8),
                              Skeleton(width: 76, height: 10),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Skeleton(width: double.infinity, radius: 10),
                        ),
                        SizedBox(height: 12),
                        Skeleton(width: 88, height: 12),
                        SizedBox(height: 9),
                        FractionallySizedBox(
                          widthFactor: 0.75,
                          child: Skeleton(
                            width: double.infinity,
                            height: 10,
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Skeleton(width: 38, height: 30, radius: 8),
                            SizedBox(width: 7),
                            Skeleton(width: 50, height: 30, radius: 8),
                            SizedBox(width: 7),
                            Skeleton(width: 34, height: 30, radius: 8),
                          ],
                        ),
                      ],
                    ),
            );
          },
        ),
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
    final fg = jc.ink;
    final bg = color ?? jc.surface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: jc.ink, width: 2.5),
      ),
      child: Text(label,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}
