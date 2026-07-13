import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../core/breakpoints.dart';
import '../../theme/app_theme.dart';
import 'jibiki_brand.dart';
import 'pressable.dart';
import 'vertical_overflow_cue.dart';

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
      duration: Motion.timed(context, const Duration(milliseconds: 70)),
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
  final VoidCallback? onTap;
  final NeoTone tone;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? .45 : 1,
        child: SizedBox.square(
          dimension: 44,
          child: NeoCard(
            tone: tone,
            padding: EdgeInsets.zero,
            radius: 10,
            onTap: onTap,
            semanticLabel: label,
            child: Icon(icon, size: 21),
          ),
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

/// A branded pull-to-refresh surface that behaves like part of the page.
///
/// The content follows the resisted drag and uncovers a full-width status band
/// above it. Nothing floats over the page and no platform spinner is used.
class NeoRefreshIndicator extends StatefulWidget {
  const NeoRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.edgeOffset = 0,
    this.triggerMode = RefreshIndicatorTriggerMode.onEdge,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.semanticLabel = 'Refresh',
    this.showOverflowCue = true,
    this.edgeColor,
  });

  static const loaderKey = ValueKey('neo-refresh-loader');
  static const headerKey = ValueKey('neo-refresh-header');
  static const contentKey = ValueKey('neo-refresh-content');
  static const double triggerExtent = 72;

  final RefreshCallback onRefresh;
  final Widget child;
  final double edgeOffset;
  final RefreshIndicatorTriggerMode triggerMode;
  final ScrollNotificationPredicate notificationPredicate;
  final String semanticLabel;
  final bool showOverflowCue;
  final Color? edgeColor;

  @override
  State<NeoRefreshIndicator> createState() => _NeoRefreshIndicatorState();
}

class _NeoRefreshIndicatorState extends State<NeoRefreshIndicator>
    with SingleTickerProviderStateMixin {
  static const _maxExtent = 112.0;
  static const _refreshExtent = 64.0;

  late final AnimationController _extent = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );
  _NeoRefreshPhase _phase = _NeoRefreshPhase.idle;
  bool _trackingDrag = false;
  bool _thresholdHapticSent = false;

  bool get _refreshing => _phase == _NeoRefreshPhase.refreshing;

  @override
  void dispose() {
    _extent.dispose();
    super.dispose();
  }

  void _setPhase(_NeoRefreshPhase phase) {
    if (_phase == phase || !mounted) return;
    setState(() => _phase = phase);
  }

  bool _atLeadingEdge(ScrollMetrics metrics) =>
      metrics.extentBefore <= .5 || metrics.pixels <= metrics.minScrollExtent;

  bool _handleScroll(ScrollNotification notification) {
    if (!widget.notificationPredicate(notification) ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollStartNotification &&
        notification.dragDetails != null &&
        !_refreshing) {
      _trackingDrag = widget.triggerMode == RefreshIndicatorTriggerMode.anywhere
          ? true
          : _atLeadingEdge(notification.metrics);
      _thresholdHapticSent = false;
    } else if (notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.overscroll < 0 &&
        _trackingDrag &&
        !_refreshing) {
      _addPull(-notification.overscroll);
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        _trackingDrag &&
        !_refreshing) {
      final fingerDelta = notification.dragDetails!.delta.dy;
      if (notification.metrics.pixels <
          notification.metrics.minScrollExtent - .5) {
        // Bouncing physics consumes the overscroll instead of dispatching an
        // OverscrollNotification. Mirror that distance for the integrated band.
        final overscroll =
            notification.metrics.minScrollExtent - notification.metrics.pixels;
        _setPull((overscroll * .58).clamp(0, _maxExtent));
      } else if (fingerDelta < 0 && _extent.value > 0) {
        // Let a learner reverse the gesture before releasing it.
        _setPull((_extent.value + fingerDelta).clamp(0, _maxExtent));
      }
    }

    if ((notification is ScrollEndNotification ||
            notification is UserScrollNotification &&
                notification.direction == ScrollDirection.idle) &&
        _trackingDrag) {
      _finishDrag();
    }
    return false;
  }

  void _addPull(double rawDelta) {
    final progress = (_extent.value / _maxExtent).clamp(0.0, 1.0);
    final resistance = .58 - progress * .24;
    _setPull(
      (_extent.value + rawDelta * resistance).clamp(0, _maxExtent),
    );
  }

  void _setPull(double value) {
    _extent.value = value;
    final armed = value >= NeoRefreshIndicator.triggerExtent;
    if (armed && !_thresholdHapticSent) {
      _thresholdHapticSent = true;
      Haptics.medium();
    }
    _setPhase(
      value <= .5
          ? _NeoRefreshPhase.idle
          : armed
              ? _NeoRefreshPhase.armed
              : _NeoRefreshPhase.pulling,
    );
  }

  void _finishDrag() {
    _trackingDrag = false;
    if (_phase == _NeoRefreshPhase.armed) {
      unawaited(_beginRefresh());
    } else if (!_refreshing) {
      unawaited(_settle());
    }
  }

  Future<void> _animateExtent(double value) => _extent.animateTo(
        value,
        duration: Motion.timed(context, Motion.fast),
        curve: Motion.outStrong,
      );

  Future<void> _settle() async {
    _setPhase(_NeoRefreshPhase.settling);
    await _animateExtent(0);
    if (mounted && !_trackingDrag && !_refreshing) {
      _setPhase(_NeoRefreshPhase.idle);
    }
  }

  Future<void> _beginRefresh() async {
    if (_refreshing) return;
    _setPhase(_NeoRefreshPhase.refreshing);
    // Start I/O at release; the short visual snap must never delay the request.
    final refresh = _invokeRefresh();
    await _animateExtent(_refreshExtent);
    await refresh;
    if (!mounted) return;
    await _animateExtent(0);
    if (mounted) _setPhase(_NeoRefreshPhase.idle);
  }

  Future<void> _invokeRefresh() async {
    try {
      await widget.onRefresh();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'jibiki widgets',
          context: ErrorDescription('while refreshing a NeoPop surface'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final content = widget.showOverflowCue
        ? VerticalOverflowCue(
            edgeColor: widget.edgeColor ?? jc.canvas,
            child: widget.child,
          )
        : widget.child;
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _extent,
          child: content,
          builder: (context, child) {
            final extent = _extent.value.clamp(0.0, _maxExtent);
            return Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: widget.edgeOffset,
                  height: extent,
                  child: _NeoRefreshBand(
                    key: NeoRefreshIndicator.headerKey,
                    extent: extent,
                    phase: _phase,
                    semanticLabel: widget.semanticLabel,
                  ),
                ),
                Transform.translate(
                  key: NeoRefreshIndicator.contentKey,
                  offset: Offset(0, extent),
                  transformHitTests: true,
                  child: child,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _NeoRefreshPhase { idle, pulling, armed, refreshing, settling }

class _NeoRefreshBand extends StatelessWidget {
  const _NeoRefreshBand({
    super.key,
    required this.extent,
    required this.phase,
    required this.semanticLabel,
  });

  final double extent;
  final _NeoRefreshPhase phase;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final french = Localizations.localeOf(context).languageCode == 'fr';
    final armed = phase == _NeoRefreshPhase.armed;
    final refreshing = phase == _NeoRefreshPhase.refreshing;
    final label = refreshing
        ? french
            ? 'Actualisation…'
            : 'Refreshing…'
        : armed
            ? french
                ? 'Relâcher pour actualiser'
                : 'Release to refresh'
            : french
                ? 'Tirer pour actualiser'
                : 'Pull to refresh';
    final reveal = (extent / 32).clamp(0.0, 1.0);
    final visual = ExcludeSemantics(
      child: ColoredBox(
        color: armed ? jc.acid : jc.lavender,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: jc.ink.withValues(alpha: reveal),
                width: 2.5,
              ),
            ),
          ),
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.bottomCenter,
              minHeight: _NeoRefreshIndicatorState._refreshExtent,
              maxHeight: _NeoRefreshIndicatorState._refreshExtent,
              child: SizedBox(
                height: _NeoRefreshIndicatorState._refreshExtent,
                child: Opacity(
                  opacity: reveal,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      child: AnimatedSize(
                        duration: Motion.timed(context, Motion.fast),
                        curve: Motion.outStrong,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (refreshing)
                              TickerMode(
                                enabled: Motion.enabled(context),
                                child: NeoChaseLoader.small(
                                  key: NeoRefreshIndicator.loaderKey,
                                  semanticLabel: semanticLabel,
                                ),
                              )
                            else
                              Icon(
                                armed
                                    ? Icons.keyboard_double_arrow_down_rounded
                                    : Icons.south_rounded,
                                size: 20,
                              ),
                            const SizedBox(width: 9),
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (phase == _NeoRefreshPhase.idle || extent <= .5) {
      return ExcludeSemantics(child: visual);
    }
    return Semantics(
      liveRegion: armed || refreshing,
      label: '$semanticLabel, $label',
      child: visual,
    );
  }
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
/// frame, compact cells and one acid selection with a tiny offset shadow. The
/// selection travels between cells instead of popping in place, so toggles
/// read as one continuous control on touch and keyboard navigation.
class NeoSegmentedControl<T> extends StatelessWidget {
  const NeoSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.height = 56,
    this.selectionColor,
  });

  final List<NeoSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final double height;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Semantics(
      container: true,
      child: Opacity(
        opacity: enabled ? 1 : .5,
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
          child: LayoutBuilder(
            builder: (context, _) {
              final selectedIndex = segments.indexWhere(
                (segment) => segment.value == selected,
              );
              final count = segments.length.clamp(1, 12);
              final hasSelection = selectedIndex >= 0;
              final alignment = count == 1
                  ? 0.0
                  : -1.0 +
                      (selectedIndex.clamp(0, count - 1) * 2 / (count - 1));
              return Stack(
                children: [
                  AnimatedOpacity(
                    duration: Motion.timed(context, Motion.fast),
                    opacity: hasSelection ? 1 : 0,
                    child: AnimatedAlign(
                      duration: Motion.timed(
                        context,
                        const Duration(milliseconds: 230),
                      ),
                      curve: Motion.outStrong,
                      alignment: Alignment(alignment, 0),
                      child: FractionallySizedBox(
                        widthFactor: 1 / count,
                        heightFactor: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: _SlidingSelectionPill(
                            color: selectionColor ?? jc.acid,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final segment in segments)
                        Expanded(
                          child: _NeoSegmentButton<T>(
                            segment: segment,
                            selected: segment.value == selected,
                            enabled: enabled,
                            showSelection: false,
                            onTap: () => onChanged(segment.value),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SlidingSelectionPill extends StatelessWidget {
  const _SlidingSelectionPill({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(2, 2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.jc.ink,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: context.jc.ink, width: 2.5),
              ),
            ),
          ),
        ],
      );
}

class _NeoSegmentButton<T> extends StatelessWidget {
  const _NeoSegmentButton({
    required this.segment,
    required this.selected,
    this.enabled = true,
    this.showSelection = true,
    required this.onTap,
  });

  final NeoSegment<T> segment;
  final bool selected;
  final bool enabled;
  final bool showSelection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Pressable(
      label: segment.label,
      selected: selected,
      pressedScale: 1,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: Motion.timed(context, Motion.fast),
        curve: Motion.out,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: selected && showSelection ? jc.acid : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: selected && showSelection
              ? Border.all(color: jc.ink, width: 2.5)
              : null,
          boxShadow: selected && showSelection
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
