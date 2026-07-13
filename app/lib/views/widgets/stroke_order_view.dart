import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:jibiki/l10n/l10n.dart';
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
    this.numberColor,
    this.onCompleted,
  });

  final List<String> paths; // SVG `d` strings, in stroke order
  final String viewBox; // "0 0 109 109"
  final double size;
  final bool showControls;
  final Color? numberColor;
  final VoidCallback? onCompleted;

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
  late List<Offset?> _numberCenters;
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
    )..addStatusListener(_handleStatus);
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onCompleted?.call();
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
    _numberCenters = layoutStrokeNumberCenters(
      metrics: _metrics,
      canvas: _canvas,
      size: widget.size,
    );
  }

  @override
  void didUpdateWidget(StrokeOrderView old) {
    super.didUpdateWidget(old);
    final geometryChanged = old.paths != widget.paths ||
        old.viewBox != widget.viewBox ||
        old.size != widget.size;
    if (geometryChanged) {
      _parse();
      if (old.paths != widget.paths) {
        _controller.duration =
            Duration(milliseconds: 380 * widget.paths.length.clamp(1, 40));
      }
      if (old.paths != widget.paths || old.viewBox != widget.viewBox) _play();
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
                      numberColor: widget.numberColor ?? jc.brand,
                      numberCenters: _numberCenters,
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
    required this.numberCenters,
    required this.showNumbers,
  });

  final List<Path> strokes;
  final List<List<PathMetric>> metrics;
  final double canvas;
  final double progress; // 0..1 across all strokes
  final Color ink;
  final Color guide;
  final Color numberColor;
  final List<Offset?> numberCenters;
  final bool showNumbers;

  @override
  void paint(Canvas c, Size size) {
    if (strokes.isEmpty) return;
    final scale = size.width / canvas;
    c.save();
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
    c.restore();
    if (showNumbers) {
      paintStrokeNumberBadges(
        c,
        centers: numberCenters,
        fillColor: numberColor,
        outlineColor: ink,
      );
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
      old.numberCenters != numberCenters ||
      old.showNumbers != showNumbers;
}

/// Fixed logical-pixel footprint of a stroke number. Keeping the badge in
/// screen coordinates makes it equally readable in compact and large guides.
@visibleForTesting
const double strokeNumberBadgeRadiusPx = 8.5;

@visibleForTesting
const double strokeNumberBadgeBorderPx = 1.25;

/// Paints the shared NeoPop stroke-order markers in logical screen pixels.
/// Both the animated reference and the writing canvas use this function so
/// their numbers keep the exact same size, contrast and outline.
void paintStrokeNumberBadges(
  Canvas canvas, {
  required List<Offset?> centers,
  required Color fillColor,
  required Color outlineColor,
}) {
  final numberInk = _contrastingMonochrome(fillColor);
  final fill = Paint()
    ..color = fillColor
    ..style = PaintingStyle.fill;
  final outline = Paint()
    ..color = outlineColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeNumberBadgeBorderPx;
  for (var i = 0; i < centers.length; i++) {
    final center = centers[i];
    if (center == null) continue;
    canvas.drawCircle(center, strokeNumberBadgeRadiusPx, fill);
    canvas.drawCircle(center, strokeNumberBadgeRadiusPx, outline);
    final label = '${i + 1}';
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: numberInk,
          fontSize: label.length > 1 ? 7.5 : 9,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }
}

/// Places each stroke number close to its stroke origin without covering any
/// stroke or an already placed badge. Work happens once when geometry changes,
/// never on an animation tick.
List<Offset?> layoutStrokeNumberCenters({
  required List<List<PathMetric>> metrics,
  required double canvas,
  required double size,
}) {
  if (metrics.isEmpty || canvas <= 0 || size <= 0) return const [];
  final scale = size / canvas;
  const sampleStepPx = 1.5;
  final sampleStep = sampleStepPx / scale;
  final segments = <_StrokeSegment>[];
  final origins = <({Offset position, Offset direction})?>[];

  for (final strokeMetrics in metrics) {
    ({Offset position, Offset direction})? origin;
    for (final metric in strokeMetrics) {
      if (metric.length <= 0) continue;
      final start = metric.getTangentForOffset(0);
      if (origin == null && start != null) {
        origin = (
          position: start.position * scale,
          direction: _unit(start.vector),
        );
      }
      final first = start?.position;
      if (first == null) continue;
      var previous = first * scale;
      for (var offset = sampleStep;
          offset < metric.length;
          offset += sampleStep) {
        final point = metric.getTangentForOffset(offset)?.position;
        if (point == null) continue;
        final current = point * scale;
        segments.add(_StrokeSegment(previous, current));
        previous = current;
      }
      final end = metric.getTangentForOffset(metric.length)?.position;
      if (end != null) {
        final current = end * scale;
        segments.add(_StrokeSegment(previous, current));
      }
    }
    origins.add(origin);
  }

  final strokeRadiusPx = 4.5 * scale / 2;
  const freeGapPx = 2.5;
  final outerBadgeRadius =
      strokeNumberBadgeRadiusPx + strokeNumberBadgeBorderPx / 2;
  final strokeClearance =
      outerBadgeRadius + strokeRadiusPx + freeGapPx + sampleStepPx / 2;
  final labelClearance = outerBadgeRadius * 2 + 2.5;
  final margin = outerBadgeRadius + 1.5;
  final maxDistance = math.min(size * .7, 96.0);

  final candidateSets = <List<Offset>>[];
  for (final origin in origins) {
    if (origin == null) {
      candidateSets.add(const []);
      continue;
    }
    final tangent =
        origin.direction == Offset.zero ? const Offset(1, 0) : origin.direction;
    final normal = Offset(-tangent.dy, tangent.dx);
    final directions = <Offset>[
      -tangent,
      normal,
      -normal,
      _unit(-tangent + normal),
      _unit(-tangent - normal),
      tangent,
      for (var step = 0; step < 32; step++)
        Offset(
          math.cos(step * math.pi / 16),
          math.sin(step * math.pi / 16),
        ),
    ];
    final candidates = <Offset>[];
    for (var distance = strokeClearance;
        distance <= maxDistance && candidates.length < 96;
        distance += 4) {
      for (final direction in directions) {
        if (direction == Offset.zero) continue;
        final candidate = origin.position + direction * distance;
        if (candidate.dx < margin ||
            candidate.dy < margin ||
            candidate.dx > size - margin ||
            candidate.dy > size - margin) {
          continue;
        }
        var touchesStroke = false;
        for (final segment in segments) {
          if (segment.distanceSquaredTo(candidate) <
              strokeClearance * strokeClearance) {
            touchesStroke = true;
            break;
          }
        }
        if (!touchesStroke) candidates.add(candidate);
      }
    }
    candidateSets.add(candidates);
  }

  final result = List<Offset?>.filled(metrics.length, null);
  final placed = <Offset>[];
  final order = List<int>.generate(metrics.length, (index) => index)
    ..sort((a, b) {
      final byFreedom =
          candidateSets[a].length.compareTo(candidateSets[b].length);
      return byFreedom != 0 ? byFreedom : a.compareTo(b);
    });
  for (final index in order) {
    for (final candidate in candidateSets[index]) {
      if (placed.every(
        (other) => (candidate - other).distance >= labelClearance,
      )) {
        result[index] = candidate;
        placed.add(candidate);
        break;
      }
    }
  }
  return result;
}

Offset _unit(Offset vector) {
  final length = vector.distance;
  return length <= 0.0001 ? Offset.zero : vector / length;
}

Color _contrastingMonochrome(Color background) {
  final luminance = background.computeLuminance();
  final whiteContrast = 1.05 / (luminance + 0.05);
  final blackContrast = (luminance + 0.05) / 0.05;
  return whiteContrast > blackContrast ? Colors.white : Colors.black;
}

class _StrokeSegment {
  const _StrokeSegment(this.start, this.end);

  final Offset start;
  final Offset end;

  double distanceSquaredTo(Offset point) {
    final vector = end - start;
    final lengthSquared = vector.distanceSquared;
    if (lengthSquared <= 0.0001) return (point - start).distanceSquared;
    final projection =
        ((point - start).dx * vector.dx + (point - start).dy * vector.dy) /
            lengthSquared;
    final nearest = start + vector * projection.clamp(0.0, 1.0).toDouble();
    return (point - nearest).distanceSquared;
  }
}
