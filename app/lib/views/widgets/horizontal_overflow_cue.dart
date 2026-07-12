import 'package:flutter/material.dart';

/// Adds subtle, non-interactive edge fades when a horizontal scrollable has
/// more content outside the viewport.
///
/// The cues follow the scroll metrics rather than staying permanently visible:
/// the left fade appears only after moving away from the start and the right
/// fade disappears at the end. This also handles scrollables using [reverse].
class HorizontalOverflowCue extends StatefulWidget {
  const HorizontalOverflowCue({
    super.key,
    required this.child,
    this.edgeColor,
    this.fadeExtent = 24,
  });

  static const leftCueKey = ValueKey('horizontal-overflow-cue-left');
  static const rightCueKey = ValueKey('horizontal-overflow-cue-right');

  final Widget child;
  final Color? edgeColor;
  final double fadeExtent;

  @override
  State<HorizontalOverflowCue> createState() => _HorizontalOverflowCueState();
}

class _HorizontalOverflowCueState extends State<HorizontalOverflowCue> {
  bool _showLeft = false;
  bool _showRight = false;

  bool _handleScroll(ScrollNotification notification) {
    _syncWith(notification.metrics);
    return false;
  }

  bool _handleMetrics(ScrollMetricsNotification notification) {
    _syncWith(notification.metrics);
    return false;
  }

  void _syncWith(ScrollMetrics metrics) {
    if (metrics.axis != Axis.horizontal) return;

    const tolerance = 0.5;
    final reversed = metrics.axisDirection == AxisDirection.left;
    final showLeft = reversed
        ? metrics.extentAfter > tolerance
        : metrics.extentBefore > tolerance;
    final showRight = reversed
        ? metrics.extentBefore > tolerance
        : metrics.extentAfter > tolerance;
    if (showLeft == _showLeft && showRight == _showRight) return;

    setState(() {
      _showLeft = showLeft;
      _showRight = showRight;
    });
  }

  @override
  Widget build(BuildContext context) {
    final edgeColor = widget.edgeColor ?? Theme.of(context).colorScheme.surface;
    final fadeExtent = widget.fadeExtent.clamp(8.0, 48.0);

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _handleMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: Row(
                  children: [
                    _EdgeFade(
                      key: HorizontalOverflowCue.leftCueKey,
                      visible: _showLeft,
                      width: fadeExtent,
                      color: edgeColor,
                      leading: true,
                    ),
                    const Spacer(),
                    _EdgeFade(
                      key: HorizontalOverflowCue.rightCueKey,
                      visible: _showRight,
                      width: fadeExtent,
                      color: edgeColor,
                      leading: false,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EdgeFade extends StatelessWidget {
  const _EdgeFade({
    super.key,
    required this.visible,
    required this.width,
    required this.color,
    required this.leading,
  });

  final bool visible;
  final double width;
  final Color color;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: leading ? Alignment.centerLeft : Alignment.centerRight,
              end: leading ? Alignment.centerRight : Alignment.centerLeft,
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}
