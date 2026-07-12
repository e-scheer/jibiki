import 'package:jibiki/l10n/l10n.dart';
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../theme/app_theme.dart';

/// Animates a kanji's KanjiVG strokes in order: completed strokes stay inked, the
/// current stroke traces in, upcoming strokes show as a faint guide. Tap to replay.
class StrokeOrderView extends StatefulWidget {
  const StrokeOrderView({
    super.key,
    required this.paths,
    required this.viewBox,
    this.size = 200,
    this.showControls = true,
  });

  final List<String> paths; // SVG `d` strings, in stroke order
  final String viewBox; // "0 0 109 109"
  final double size;
  final bool showControls;

  @override
  State<StrokeOrderView> createState() => _StrokeOrderViewState();
}

class _StrokeOrderViewState extends State<StrokeOrderView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<Path> _parsed;
  // PathMetrics precomputed once per stroke, extracting them every frame in the
  // painter (during the trace animation) is needless work.
  late List<List<PathMetric>> _metrics;
  double _canvas = 109;

  bool _started = false;
  bool _showNumbers = true;

  @override
  void initState() {
    super.initState();
    _parse();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 380 * widget.paths.length.clamp(1, 40)),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // First frame: trace the strokes, or jump straight to the finished character
    // when reduce-motion is on (the stroke order is still fully visible, static).
    if (!_started) {
      _started = true;
      _play();
    }
  }

  void _play() {
    if (Motion.enabled(context)) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
    }
  }

  void _parse() {
    // viewBox = "minX minY width height"; KanjiVG is square (109).
    final parts = widget.viewBox.split(RegExp(r'\s+'));
    _canvas = parts.length == 4 ? (double.tryParse(parts[2]) ?? 109) : 109;
    _parsed = [];
    _metrics = [];
    for (final d in widget.paths) {
      try {
        final path = parseSvgPathData(d);
        _parsed.add(path);
        _metrics.add(path.computeMetrics().toList());
      } catch (_) {
        // Skip an unparseable stroke rather than fail the whole diagram.
      }
    }
  }

  @override
  void didUpdateWidget(StrokeOrderView old) {
    super.didUpdateWidget(old);
    if (old.paths != widget.paths) {
      _parse();
      _controller.duration =
          Duration(milliseconds: 380 * widget.paths.length.clamp(1, 40));
      _play();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _replay() {
    Haptics.tick();
    _play();
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Replay stroke order',
          child: GestureDetector(
            onTap: _replay,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) => CustomPaint(
                    painter: _StrokePainter(
                      strokes: _parsed,
                      metrics: _metrics,
                      canvas: _canvas,
                      progress: _controller.value,
                      ink: jc.ink,
                      guide: jc.ink.withValues(alpha: 0.12),
                      numberColor: jc.magenta,
                      showNumbers: _showNumbers,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.showControls)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: _replay,
                icon: const Icon(Icons.replay, size: 18),
                label: Text(context.trText('Replay strokes')),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _showNumbers = !_showNumbers),
                icon: Icon(
                  _showNumbers ? Icons.looks_one_outlined : Icons.visibility,
                  size: 17,
                ),
                label: Text(
                  _showNumbers
                      ? context.trText('Hide numbers')
                      : context.trText('Show numbers'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _StrokePainter extends CustomPainter {
  _StrokePainter({
    required this.strokes,
    required this.metrics,
    required this.canvas,
    required this.progress,
    required this.ink,
    required this.guide,
    required this.numberColor,
    required this.showNumbers,
  });

  final List<Path> strokes;
  final List<List<PathMetric>> metrics;
  final double canvas;
  final double progress; // 0..1 across all strokes
  final Color ink;
  final Color guide;
  final Color numberColor;
  final bool showNumbers;

  @override
  void paint(Canvas c, Size size) {
    if (strokes.isEmpty) return;
    final scale = size.width / canvas;
    c.scale(scale);

    final n = strokes.length;
    final scaled = progress * n; // how many strokes are "reached"

    Paint pen(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i < n; i++) {
      final stroke = strokes[i];
      if (i + 1 <= scaled) {
        c.drawPath(stroke, pen(ink)); // fully drawn
      } else if (i < scaled) {
        final frac = (scaled - i).clamp(0.0, 1.0); // currently tracing
        c.drawPath(_partial(i, frac), pen(ink));
        c.drawPath(stroke, pen(guide)); // faint full guide under the trace
      } else {
        c.drawPath(stroke, pen(guide)); // upcoming: faint guide
      }
    }
    if (showNumbers) {
      final numberStyle = TextStyle(
        color: numberColor,
        fontSize: 10 / scale,
        fontWeight: FontWeight.w900,
      );
      for (var i = 0; i < metrics.length; i++) {
        final first =
            metrics[i].isEmpty ? null : metrics[i].first.getTangentForOffset(0);
        if (first == null) continue;
        final painter = TextPainter(
          text: TextSpan(text: '${i + 1}', style: numberStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          c,
          first.position - Offset(painter.width / 2, painter.height / 2),
        );
      }
    }
  }

  Path _partial(int index, double frac) {
    final out = Path();
    for (final metric in metrics[index]) {
      out.addPath(metric.extractPath(0, metric.length * frac), Offset.zero);
    }
    return out;
  }

  @override
  bool shouldRepaint(_StrokePainter old) =>
      old.progress != progress ||
      old.strokes != strokes ||
      old.ink != ink ||
      old.numberColor != numberColor ||
      old.showNumbers != showNumbers;
}
