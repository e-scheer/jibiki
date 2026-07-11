import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The brush engines the studio offers. Each renders the same list of points in
/// a distinctive way, so a user can build mnemonics "in their own style":
///   • pen         crisp, constant-width ink
///   • calligraphy sumi-e style, the stroke thins as the hand moves faster and
///                 tapers at both ends, like a real brush
///   • marker      broad, translucent, chisel-tipped highlighter
///   • pencil      grainy graphite texture
///   • neon        a glowing halo around a bright core
///   • spray       a scattered airbrush of dots
enum Brush { pen, calligraphy, marker, pencil, neon, spray }

/// The guide sits between two independent drawing layers. A stroke keeps the
/// layer selected when it starts, just like it keeps its brush and colour.
enum DrawingLayer { below, above }

extension DrawingLayerMeta on DrawingLayer {
  String get label => switch (this) {
        DrawingLayer.below => 'Behind',
        DrawingLayer.above => 'Front',
      };

  IconData get icon => switch (this) {
        DrawingLayer.below => Icons.flip_to_back_outlined,
        DrawingLayer.above => Icons.flip_to_front_outlined,
      };
}

extension BrushMeta on Brush {
  String get label => switch (this) {
        Brush.pen => 'Pen',
        Brush.calligraphy => 'Brush',
        Brush.marker => 'Marker',
        Brush.pencil => 'Pencil',
        Brush.neon => 'Neon',
        Brush.spray => 'Spray',
      };

  IconData get icon => switch (this) {
        Brush.pen => Icons.edit_outlined,
        Brush.calligraphy => Icons.brush_outlined,
        Brush.marker => Icons.border_color_outlined,
        Brush.pencil => Icons.mode_edit_outline_outlined,
        Brush.neon => Icons.auto_awesome_outlined,
        Brush.spray => Icons.blur_on_outlined,
      };

  /// The intrinsic opacity of the medium, multiplied by the user's opacity
  /// slider. Neon manages its own alpha and ignores this.
  double get baseAlpha => switch (this) {
        Brush.marker => 0.42,
        Brush.spray => 0.5,
        Brush.pencil => 0.85,
        _ => 1.0,
      };
}

/// One drawn (or erased) stroke: an ordered path of points captured with the
/// tool that was active when it began. Erase strokes punch through the drawing
/// layer (BlendMode.clear); every other brush reads its own `brush`.
class Stroke {
  Stroke({
    required this.layer,
    required this.brush,
    required this.color,
    required this.width,
    required this.opacity,
    required this.erase,
  });

  final List<Offset> points = [];
  final DrawingLayer layer;
  final Brush brush;
  final Color color;
  final double width;
  final double opacity; // 0..1, the user's opacity slider
  final bool erase;
}

/// The drawing engine behind the mnemonic pad: strokes + full undo/redo history
/// and the current tool (brush, colour, width, opacity, eraser). A
/// ChangeNotifier so the canvas and toolbar rebuild reactively.
class PaintController extends ChangeNotifier {
  PaintController({Color initialColor = const Color(0xFF0F0F0F)})
      : color = initialColor;

  final List<Stroke> _strokes = [];
  final List<Stroke> _redo = [];
  Stroke? _active;

  Color color;
  double width = 6;
  double opacity = 1;
  Brush brush = Brush.pen;
  DrawingLayer layer = DrawingLayer.above;
  bool erasing = false;

  List<Stroke> get strokes => _strokes;
  bool get isEmpty => _strokes.isEmpty;
  bool get canUndo => _strokes.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void setColor(Color c) {
    color = c;
    erasing = false;
    notifyListeners();
  }

  void setWidth(double w) {
    width = w;
    notifyListeners();
  }

  void setOpacity(double o) {
    opacity = o.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setBrush(Brush b) {
    brush = b;
    erasing = false;
    notifyListeners();
  }

  void setLayer(DrawingLayer value) {
    layer = value;
    notifyListeners();
  }

  void setErasing(bool v) {
    erasing = v;
    notifyListeners();
  }

  void start(Offset p) {
    _redo.clear();
    _active = Stroke(
      layer: layer,
      brush: brush,
      color: color,
      width: erasing ? width * 1.8 : width,
      opacity: opacity,
      erase: erasing,
    )..points.add(p);
    _strokes.add(_active!);
    notifyListeners();
  }

  void extend(Offset p) {
    _active?.points.add(p);
    notifyListeners();
  }

  void end() {
    _active = null;
    notifyListeners();
  }

  void undo() {
    if (_strokes.isEmpty) return;
    _redo.add(_strokes.removeLast());
    _active = null;
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _strokes.add(_redo.removeLast());
    notifyListeners();
  }

  void clear() {
    if (_strokes.isEmpty) return;
    _strokes.clear();
    _redo.clear();
    _active = null;
    notifyListeners();
  }
}

/// The canvas: a faint reference glyph between two transparent drawing layers.
class DrawingPad extends StatelessWidget {
  const DrawingPad({
    super.key,
    required this.controller,
    required this.character,
    this.showGuide = true,
  });

  final PaintController controller;
  final String character;
  final bool showGuide;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Container(
      decoration: BoxDecoration(
        color: jc.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: jc.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: ListenableBuilder(
              listenable: controller,
              builder: (_, __) => CustomPaint(
                key: const ValueKey('drawing-layer-below'),
                painter: _PadPainter(controller.strokes, DrawingLayer.below),
                size: Size.infinite,
              ),
            ),
          ),
          if (showGuide)
            Center(
              key: const ValueKey('drawing-guide'),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    character,
                    style: TextStyle(
                      fontSize: 220,
                      fontWeight: FontWeight.w700,
                      color: jc.ink.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => controller.start(d.localPosition),
            onPanUpdate: (d) => controller.extend(d.localPosition),
            onPanEnd: (_) => controller.end(),
            child: RepaintBoundary(
              child: ListenableBuilder(
                listenable: controller,
                builder: (_, __) => CustomPaint(
                  key: const ValueKey('drawing-layer-above'),
                  painter: _PadPainter(controller.strokes, DrawingLayer.above),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PadPainter extends CustomPainter {
  _PadPainter(this.strokes, this.layer);
  final List<Stroke> strokes;
  final DrawingLayer layer;

  @override
  void paint(Canvas canvas, Size size) {
    // Isolate the drawing in a layer so eraser strokes (BlendMode.clear) punch
    // through to reveal the glyph/surface below instead of painting a colour.
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final s in strokes) {
      if (s.layer != layer) continue;
      if (s.points.isEmpty) continue;
      if (s.erase) {
        _paintErase(canvas, s);
        continue;
      }
      switch (s.brush) {
        case Brush.pen:
          _paintPen(canvas, s);
        case Brush.calligraphy:
          _paintCalligraphy(canvas, s);
        case Brush.marker:
          _paintMarker(canvas, s);
        case Brush.pencil:
          _paintPencil(canvas, s);
        case Brush.neon:
          _paintNeon(canvas, s);
        case Brush.spray:
          _paintSpray(canvas, s);
      }
    }
    canvas.restore();
  }

  /// The stroke colour at its effective alpha (opacity slider × medium alpha).
  Color _c(Stroke s, {double mul = 1}) => s.color
      .withValues(alpha: (s.opacity * s.brush.baseAlpha * mul).clamp(0.0, 1.0));

  // ── Pen ─────────────────────────────────────────────────────────────────
  void _paintPen(Canvas c, Stroke s) {
    final ink = _c(s);
    if (s.points.length == 1) {
      c.drawCircle(
          s.points.first,
          s.width / 2,
          Paint()
            ..color = ink
            ..isAntiAlias = true);
      return;
    }
    c.drawPath(
      _smooth(s.points),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  // ── Marker (broad, translucent, chisel cap) ───────────────────────────────
  void _paintMarker(Canvas c, Stroke s) {
    final ink = _c(s);
    final w = s.width * 2.4;
    if (s.points.length == 1) {
      c.drawCircle(
          s.points.first,
          w / 2,
          Paint()
            ..color = ink
            ..isAntiAlias = true);
      return;
    }
    // A single path (not per-segment) so the stroke keeps a uniform alpha
    // instead of darkening at every overlap within itself.
    c.drawPath(
      _smooth(s.points),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  // ── Neon (blurred halo + bright core) ─────────────────────────────────────
  void _paintNeon(Canvas c, Stroke s) {
    final glow = Paint()
      ..color = s.color.withValues(alpha: (0.55 * s.opacity).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.width)
      ..isAntiAlias = true;
    final core = Paint()
      ..color = Color.lerp(s.color, Colors.white, 0.65)!
          .withValues(alpha: s.opacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    if (s.points.length == 1) {
      c.drawCircle(s.points.first, s.width * 1.2, glow);
      c.drawCircle(s.points.first, s.width * 0.3, core);
      return;
    }
    final path = _smooth(s.points);
    c.drawPath(path, glow);
    c.drawPath(path, core);
  }

  // ── Pencil (grainy graphite) ──────────────────────────────────────────────
  void _paintPencil(Canvas c, Stroke s) {
    final grain = Paint()
      ..color = _c(s)
      ..isAntiAlias = true;
    if (s.points.length == 1) {
      c.drawCircle(s.points.first, s.width * 0.5, grain);
      return;
    }
    // A faint continuous core keeps slow, dense strokes reading as a line…
    c.drawPath(
      _smooth(s.points),
      Paint()
        ..color = _c(s, mul: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * 0.85
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
    // …with deterministic, jittered dabs over it for the graphite texture.
    final pts = _resample(s.points, math.max(1.0, s.width * 0.45));
    for (var i = 0; i < pts.length; i++) {
      final jitter = Offset(
              _rand(pts[i], i * 2 + 1) - 0.5, _rand(pts[i], i * 2 + 2) - 0.5) *
          s.width *
          0.7;
      final radius = s.width * (0.10 + 0.16 * _rand(pts[i], i + 17));
      c.drawCircle(pts[i] + jitter, radius, grain);
    }
  }

  // ── Spray / airbrush (scattered dots) ─────────────────────────────────────
  void _paintSpray(Canvas c, Stroke s) {
    final dab = Paint()
      ..color = _c(s)
      ..isAntiAlias = true;
    final radius = s.width * 1.6;
    final pts = _resample(s.points, math.max(1.0, s.width * 0.8));
    for (var i = 0; i < pts.length; i++) {
      for (var k = 0; k < 8; k++) {
        final angle = _rand(pts[i], i * 31 + k) * 2 * math.pi;
        final rr = radius * math.sqrt(_rand(pts[i], i * 71 + k + 3));
        final p = pts[i] + Offset(math.cos(angle), math.sin(angle)) * rr;
        c.drawCircle(p, s.width * 0.12, dab);
      }
    }
  }

  // ── Calligraphy (speed-variable width, tapered ends) ──────────────────────
  void _paintCalligraphy(Canvas c, Stroke s) {
    final fill = Paint()
      ..color = _c(s)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Drop near-duplicate points so tangents/normals stay well-defined.
    final pts = <Offset>[];
    for (final p in s.points) {
      if (pts.isEmpty || (p - pts.last).distance > 0.6) pts.add(p);
    }
    if (pts.length < 2) {
      c.drawCircle(s.points.first, s.width * 0.85, fill);
      return;
    }

    final n = pts.length;
    // Local speed (spacing between raw samples), smoothed to avoid the width
    // jittering point-to-point.
    final speed = List<double>.filled(n, 0);
    for (var i = 1; i < n; i++) {
      speed[i] = (pts[i] - pts[i - 1]).distance;
    }
    speed[0] = speed[1];
    final sm = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      var sum = 0.0;
      var cnt = 0;
      for (var k = i - 2; k <= i + 2; k++) {
        if (k >= 0 && k < n) {
          sum += speed[k];
          cnt++;
        }
      }
      sm[i] = sum / cnt;
    }

    const refSpeed = 15.0; // px/sample mapped to the thinnest width
    final maxHw = s.width * 0.95;
    final minHw = s.width * 0.18;
    final taper = math.min(6, (n / 3).floor()).clamp(1, 6).toDouble();

    double halfWidth(int i) {
      final t = (sm[i] / refSpeed).clamp(0.0, 1.0);
      final w = maxHw +
          (minHw - maxHw) *
              Curves.easeOut.transform(t); // slow→thick, fast→thin
      final head = (i / taper).clamp(0.0, 1.0);
      final tail = ((n - 1 - i) / taper).clamp(0.0, 1.0);
      return w * head * tail;
    }

    Offset normal(int i) {
      final a = pts[math.max(0, i - 1)];
      final b = pts[math.min(n - 1, i + 1)];
      final d = b - a;
      final len = d.distance;
      if (len < 1e-3) return Offset.zero;
      final u = d / len;
      return Offset(-u.dy, u.dx);
    }

    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i < n; i++) {
      final nrm = normal(i);
      final hw = halfWidth(i);
      left.add(pts[i] + nrm * hw);
      right.add(pts[i] - nrm * hw);
    }

    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (var i = 1; i < n; i++) {
      path.lineTo(left[i].dx, left[i].dy);
    }
    for (var i = n - 1; i >= 0; i--) {
      path.lineTo(right[i].dx, right[i].dy);
    }
    path.close();
    c.drawPath(path, fill);
  }

  // ── Eraser ────────────────────────────────────────────────────────────────
  void _paintErase(Canvas c, Stroke s) {
    if (s.points.length == 1) {
      c.drawCircle(
          s.points.first, s.width / 2, Paint()..blendMode = BlendMode.clear);
      return;
    }
    c.drawPath(
      _smooth(s.points),
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Quadratic-bezier smoothing through the midpoints → clean, premium strokes.
  Path _smooth(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length - 1; i++) {
      final mid = Offset(
          (pts[i].dx + pts[i + 1].dx) / 2, (pts[i].dy + pts[i + 1].dy) / 2);
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  /// Even-spacing resample of a poly-line, used by the textured brushes so the
  /// dabs are laid at a constant density regardless of drawing speed.
  List<Offset> _resample(List<Offset> src, double step) {
    step = math.max(step, 0.75);
    if (src.length < 2) return List.of(src);
    final out = <Offset>[src.first];
    var prev = src.first;
    var dist = 0.0;
    var i = 1;
    while (i < src.length) {
      final curr = src[i];
      final d = (curr - prev).distance;
      if (d == 0) {
        i++;
        continue;
      }
      if (dist + d >= step) {
        final t = (step - dist) / d;
        final q = Offset(prev.dx + (curr.dx - prev.dx) * t,
            prev.dy + (curr.dy - prev.dy) * t);
        out.add(q);
        prev = q;
        dist = 0;
      } else {
        dist += d;
        prev = curr;
        i++;
      }
    }
    return out;
  }

  /// Deterministic pseudo-random in [0,1) seeded by a point + salt. Stable
  /// across repaints so the pencil/spray texture doesn't shimmer while the
  /// canvas rebuilds on every added point.
  double _rand(Offset p, int salt) {
    var h = salt * 374761393 +
        (p.dx * 1000).round() * 668265263 +
        (p.dy * 1000).round() * 2246822519;
    h = (h ^ (h >> 13)) * 1274126177;
    h ^= h >> 16;
    return (h & 0x7fffffff) / 0x7fffffff;
  }

  @override
  bool shouldRepaint(_PadPainter old) => true;
}
