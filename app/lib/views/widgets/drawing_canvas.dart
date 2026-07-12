import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../theme/app_theme.dart';
import 'stroke_order_view.dart';

/// Holds the drawn strokes so a parent can undo/clear and read emptiness.
class DrawingController extends ChangeNotifier {
  final List<List<Offset>> strokes = [];

  bool get isEmpty => strokes.isEmpty;

  void begin(Offset p) {
    strokes.add([p]);
    notifyListeners();
  }

  void extend(Offset p) {
    if (strokes.isNotEmpty) {
      strokes.last.add(p);
      notifyListeners();
    }
  }

  void undo() {
    if (strokes.isNotEmpty) {
      strokes.removeLast();
      notifyListeners();
    }
  }

  void clear() {
    if (strokes.isNotEmpty) {
      strokes.clear();
      notifyListeners();
    }
  }
}

/// A square writing pad: genkō-yōshi guide lines, an optional faint KanjiVG guide
/// to trace over (Ringotan-style fading hints), and the user's ink on top.
class DrawingCanvas extends StatelessWidget {
  const DrawingCanvas({
    super.key,
    required this.controller,
    this.guidePaths = const [],
    this.guideViewBox = '0 0 109 109',
    this.showGuide = true,
    this.showStrokeNumbers = false,
    this.strokeNumberColor,
  });

  final DrawingController controller;
  final List<String> guidePaths;
  final String guideViewBox;
  final bool showGuide;
  final bool showStrokeNumbers;
  final Color? strokeNumberColor;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final parsed = <Path>[];
    if (showGuide) {
      for (final d in guidePaths) {
        try {
          parsed.add(parseSvgPathData(d));
        } catch (_) {}
      }
    }
    final metrics = [
      for (final path in parsed) path.computeMetrics().toList(),
    ];
    final canvasUnit = _unit(guideViewBox);
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: jc.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: jc.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          onPanStart: (d) => controller.begin(d.localPosition),
          onPanUpdate: (d) => controller.extend(d.localPosition),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final padSize = constraints.biggest.shortestSide;
              final numberCenters = showGuide && showStrokeNumbers
                  ? layoutStrokeNumberCenters(
                      metrics: metrics,
                      canvas: canvasUnit,
                      size: padSize,
                    )
                  : const <Offset?>[];
              return ListenableBuilder(
                listenable: controller,
                builder: (context, _) => CustomPaint(
                  painter: _PadPainter(
                    strokes: controller.strokes,
                    guide: parsed,
                    canvasUnit: canvasUnit,
                    numberCenters: numberCenters,
                    numberColor: strokeNumberColor ?? jc.brand,
                    grid: jc.hairline,
                    guideColor: jc.ink.withValues(alpha: 0.12),
                    ink: jc.ink,
                  ),
                  size: Size.infinite,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  double _unit(String vb) {
    final p = vb.split(RegExp(r'\s+'));
    return p.length == 4 ? (double.tryParse(p[2]) ?? 109) : 109;
  }
}

class _PadPainter extends CustomPainter {
  _PadPainter({
    required this.strokes,
    required this.guide,
    required this.canvasUnit,
    required this.numberCenters,
    required this.numberColor,
    required this.grid,
    required this.guideColor,
    required this.ink,
  });

  final List<List<Offset>> strokes;
  final List<Path> guide;
  final double canvasUnit;
  final List<Offset?> numberCenters;
  final Color numberColor, grid, guideColor, ink;

  @override
  void paint(Canvas c, Size size) {
    _grid(c, size);

    if (guide.isNotEmpty) {
      c.save();
      c.scale(size.width / canvasUnit);
      final gp = Paint()
        ..color = guideColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final path in guide) {
        c.drawPath(path, gp);
      }
      c.restore();
    }

    if (numberCenters.isNotEmpty) {
      paintStrokeNumberBadges(
        c,
        centers: numberCenters,
        fillColor: numberColor,
        outlineColor: ink,
      );
    }

    final pen = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.028
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        c.drawPoints(PointMode.points, stroke, pen);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      c.drawPath(path, pen);
    }
  }

  void _grid(Canvas c, Size s) {
    final line = Paint()
      ..color = grid
      ..strokeWidth = 1;
    final dashed = Paint()
      ..color = grid
      ..strokeWidth = 1;
    // Center cross (genkō-yōshi).
    c.drawLine(Offset(s.width / 2, 0), Offset(s.width / 2, s.height), line);
    c.drawLine(Offset(0, s.height / 2), Offset(s.width, s.height / 2), line);
    // Diagonals as faint guides.
    _dash(c, Offset.zero, Offset(s.width, s.height), dashed);
    _dash(c, Offset(s.width, 0), Offset(0, s.height), dashed);
  }

  void _dash(Canvas c, Offset a, Offset b, Paint p) {
    const dash = 6.0, gap = 6.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final start = a + dir * d;
      final end = a + dir * (d + dash).clamp(0, total);
      c.drawLine(start, end, p);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_PadPainter old) => true;
}
