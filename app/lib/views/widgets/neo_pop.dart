import 'package:flutter/material.dart';

import '../../core/breakpoints.dart';
import '../../theme/app_theme.dart';
import 'jibiki_brand.dart';
import 'pressable.dart';

enum NeoTone { paper, acid, blue, magenta, lime, lavender, coral, ink }

extension NeoToneX on NeoTone {
  Color color(BuildContext context) {
    final jc = context.jc;
    return switch (this) {
      NeoTone.paper => jc.surface,
      NeoTone.acid => jc.acid,
      NeoTone.blue => jc.brand,
      NeoTone.magenta => jc.magenta,
      NeoTone.lime => jc.lime,
      NeoTone.lavender => jc.lavender,
      NeoTone.coral => jc.coral,
      NeoTone.ink => jc.ink,
    };
  }

  Color foreground(BuildContext context) =>
      this == NeoTone.blue || this == NeoTone.ink
          ? context.jc.surface
          : context.jc.ink;
}

class NeoCard extends StatefulWidget {
  const NeoCard({
    super.key,
    required this.child,
    this.tone = NeoTone.paper,
    this.padding = const EdgeInsets.all(16),
    this.radius = Radii.md,
    this.shadow = 4,
    this.rotate = 0,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final NeoTone tone;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double shadow;
  final double rotate;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<NeoCard> createState() => _NeoCardState();
}

class _NeoCardState extends State<NeoCard> {
  bool _down = false;

  void _setDown(bool value) {
    if (widget.onTap == null || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: Motion.timed(context, Motion.fast),
      curve: Motion.out,
      transform: Matrix4.translationValues(
        _down ? widget.shadow : 0,
        _down ? widget.shadow : 0,
        0,
      ),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.tone.color(context),
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: context.jc.ink, width: 2.5),
        boxShadow: widget.shadow == 0 || _down
            ? null
            : [
                BoxShadow(
                  color: context.jc.ink,
                  blurRadius: 0,
                  offset: Offset(widget.shadow, widget.shadow),
                ),
              ],
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: widget.tone.foreground(context)),
        child: IconTheme.merge(
          data: IconThemeData(color: widget.tone.foreground(context)),
          child: widget.child,
        ),
      ),
    );
    final transformed = widget.rotate == 0
        ? card
        : Transform.rotate(angle: widget.rotate * 0.0174533, child: card);
    if (widget.onTap == null) return transformed;
    return Semantics(
      button: true,
      enabled: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapCancel: () => _setDown(false),
        onTapUp: (_) => _setDown(false),
        onTap: () {
          Haptics.tick();
          widget.onTap!();
        },
        child: transformed,
      ),
    );
  }
}

class NeoBadge extends StatelessWidget {
  const NeoBadge(
    this.label, {
    super.key,
    this.tone = NeoTone.paper,
    this.rotate = 0,
    this.icon,
  });

  final String label;
  final NeoTone tone;
  final double rotate;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => NeoCard(
        tone: tone,
        rotate: rotate,
        shadow: 3,
        radius: 8,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, height: 1)),
          ],
        ),
      );
}

class NeoSectionTitle extends StatelessWidget {
  const NeoSectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: context.jc.ink,
                  )),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class NeoIconButton extends StatelessWidget {
  const NeoIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = NeoTone.paper,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final NeoTone tone;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 44,
        child: NeoCard(
          tone: tone,
          padding: EdgeInsets.zero,
          radius: 10,
          onTap: onTap,
          semanticLabel: label,
          child: Icon(icon, size: 21),
        ),
      );
}

class NeoPrimaryButton extends StatelessWidget {
  const NeoPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.tone = NeoTone.acid,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final NeoTone tone;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        width: double.infinity,
        child: NeoCard(
          tone: tone,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          radius: 12,
          onTap: busy ? null : onTap,
          semanticLabel: label,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                NeoChaseLoader.small(
                  alternateFirst: tone == NeoTone.blue || tone == NeoTone.ink,
                  semanticLabel: '$label, loading',
                )
              else if (icon != null)
                Icon(icon, size: 20),
              if (busy || icon != null) const SizedBox(width: 9),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      );
}

class NeoPageHeader extends StatelessWidget {
  const NeoPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.tone = NeoTone.blue,
    this.child,
  });
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final NeoTone tone;
  final Widget? child;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: tone.color(context),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: context.jc.ink, width: 2.5),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: BoundedContent(
              maxWidth: context.isExpanded ? 920 : Breakpoints.maxContent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(title,
                              style: context.text.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: tone.foreground(context),
                              )),
                        ),
                        if (trailing != null) trailing!,
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(subtitle!,
                          style: TextStyle(
                            color: tone.foreground(context),
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          )),
                    ],
                    if (child != null) ...[
                      const SizedBox(height: 14),
                      child!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class NeoContent extends StatelessWidget {
  const NeoContent({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 28),
    this.maxWidth = Breakpoints.maxContent,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => BoundedContent(
        maxWidth: context.isExpanded ? maxWidth + 160 : maxWidth,
        child: Padding(padding: padding, child: child),
      );
}

class NeoListRow extends StatelessWidget {
  const NeoListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.tone = NeoTone.paper,
  });
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final NeoTone tone;

  @override
  Widget build(BuildContext context) => NeoCard(
        tone: tone,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(
                    style: const TextStyle(fontWeight: FontWeight.w800),
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    DefaultTextStyle.merge(
                      style: TextStyle(
                          color: context.jc.body, fontSize: 13, height: 1.3),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
          ],
        ),
      );
}

class NeoProgress extends StatelessWidget {
  const NeoProgress({super.key, required this.value, this.tone = NeoTone.blue});
  final double value;
  final NeoTone tone;

  @override
  Widget build(BuildContext context) => Container(
        height: 18,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.jc.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: context.jc.ink, width: 2.5),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0, 1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tone.color(context),
              border:
                  Border(right: BorderSide(color: context.jc.ink, width: 2.5)),
            ),
          ),
        ),
      );
}

class NeoSegment<T> {
  const NeoSegment(this.value, this.label, {this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// The exact segmented control used by the NeoPop exploration: a hard outer
/// frame, three compact cells and one acid selection with a tiny offset shadow.
/// It deliberately has no Material indicator animation or sliding pill.
class NeoSegmentedControl<T> extends StatelessWidget {
  const NeoSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.height = 56,
  });

  final List<NeoSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Semantics(
      container: true,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: jc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: jc.ink, width: 3),
          boxShadow: [
            BoxShadow(
              color: jc.ink,
              blurRadius: 0,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final segment in segments)
              Expanded(
                child: _NeoSegmentButton<T>(
                  segment: segment,
                  selected: segment.value == selected,
                  onTap: () => onChanged(segment.value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NeoSegmentButton<T> extends StatelessWidget {
  const _NeoSegmentButton({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final NeoSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Pressable(
      label: segment.label,
      selected: selected,
      pressedScale: 1,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.timed(context, Motion.fast),
        curve: Motion.out,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: selected ? jc.acid : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: selected ? Border.all(color: jc.ink, width: 2.5) : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: jc.ink,
                    blurRadius: 0,
                    offset: const Offset(2, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (segment.icon != null) ...[
              Icon(segment.icon, size: 15),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                segment.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
