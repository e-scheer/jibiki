import 'package:flutter/material.dart';

/// Adds a quiet top/bottom fade only while a vertical scrollable has content
/// outside its viewport. The cue never intercepts gestures and disappears at
/// the corresponding edge, so it communicates overflow without permanent UI.
class VerticalOverflowCue extends StatefulWidget {
  const VerticalOverflowCue({
    super.key,
    required this.child,
    this.edgeColor,
    this.fadeExtent = 28,
  });

  static const topCueKey = ValueKey('vertical-overflow-cue-top');
  static const bottomCueKey = ValueKey('vertical-overflow-cue-bottom');

  final Widget child;
  final Color? edgeColor;
  final double fadeExtent;

  @override
  State<VerticalOverflowCue> createState() => _VerticalOverflowCueState();
}

class _VerticalOverflowCueState extends State<VerticalOverflowCue> {
  bool _showTop = false;
  bool _showBottom = false;

  bool _handleScroll(ScrollNotification notification) {
    _syncWith(notification.metrics);
    return false;
  }

  bool _handleMetrics(ScrollMetricsNotification notification) {
    _syncWith(notification.metrics);
    return false;
  }

  void _syncWith(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;

    const tolerance = 0.5;
    final reversed = metrics.axisDirection == AxisDirection.up;
    final showTop = reversed
        ? metrics.extentAfter > tolerance
        : metrics.extentBefore > tolerance;
    final showBottom = reversed
        ? metrics.extentBefore > tolerance
        : metrics.extentAfter > tolerance;
    if (showTop == _showTop && showBottom == _showBottom) return;

    setState(() {
      _showTop = showTop;
      _showBottom = showBottom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final edgeColor = widget.edgeColor ?? Theme.of(context).colorScheme.surface;
    final fadeExtent = widget.fadeExtent.clamp(10.0, 56.0);

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
                child: Column(
                  children: [
                    _VerticalEdgeFade(
                      key: VerticalOverflowCue.topCueKey,
                      visible: _showTop,
                      height: fadeExtent,
                      color: edgeColor,
                      leading: true,
                    ),
                    const Spacer(),
                    _VerticalEdgeFade(
                      key: VerticalOverflowCue.bottomCueKey,
                      visible: _showBottom,
                      height: fadeExtent,
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

class _VerticalEdgeFade extends StatelessWidget {
  const _VerticalEdgeFade({
    super.key,
    required this.visible,
    required this.height,
    required this.color,
    required this.leading,
  });

  final bool visible;
  final double height;
  final Color color;
  final bool leading;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: leading ? Alignment.topCenter : Alignment.bottomCenter,
                end: leading ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      );
}
