import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/views/learn/drawing_pad.dart';

Widget _host(PaintController c) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: DrawingPad(controller: c, character: 'り'),
          ),
        ),
      ),
    );

/// Drag through a few points inside the pad. `startGesture` takes GLOBAL
/// coordinates, so anchor on the centred pad rather than assuming (0,0).
Future<void> _drawStroke(WidgetTester tester) async {
  final base = tester.getCenter(find.byType(DrawingPad));
  final g = await tester.startGesture(base - const Offset(30, 30));
  await tester.pump();
  await g.moveBy(const Offset(20, 10));
  await tester.pump();
  await g
      .moveBy(const Offset(25, 30)); // a fast segment (calligraphy thins here)
  await tester.pump();
  await g.moveBy(const Offset(5, 5)); // a slow segment
  await tester.pump();
  await g.up();
  await tester.pump();
}

void main() {
  testWidgets('every brush paints a dragged stroke without throwing',
      (tester) async {
    final c = PaintController();
    await tester.pumpWidget(_host(c));

    for (final brush in Brush.values) {
      c.setBrush(brush);
      await tester.pump();
      expect(c.brush, brush);
      expect(c.erasing, isFalse);
      await _drawStroke(tester);
    }

    expect(c.strokes.length, Brush.values.length);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a single tap paints a dot for every brush + eraser',
      (tester) async {
    final c = PaintController();
    await tester.pumpWidget(_host(c));

    for (final brush in Brush.values) {
      c.setBrush(brush);
      c.start(const Offset(150, 150)); // one point only
      c.end();
      await tester.pump();
    }
    c.setErasing(true);
    c.start(const Offset(150, 150));
    c.end();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('eraser punches through and undo/redo/clear track history',
      (tester) async {
    final c = PaintController();
    await tester.pumpWidget(_host(c));

    c.setBrush(Brush.pen);
    await _drawStroke(tester);
    c.setErasing(true);
    expect(c.erasing, isTrue);
    await _drawStroke(tester);
    expect(c.strokes.length, 2);

    c.undo();
    expect(c.strokes.length, 1);
    expect(c.canRedo, isTrue);
    c.redo();
    expect(c.strokes.length, 2);
    c.clear();
    expect(c.isEmpty, isTrue);

    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('width + opacity are captured per stroke at creation time',
      (tester) async {
    final c = PaintController();
    await tester.pumpWidget(_host(c));

    c.setWidth(20);
    c.setOpacity(0.3);
    c.setBrush(Brush.marker);
    await _drawStroke(tester);

    final s = c.strokes.single;
    expect(s.width, 20);
    expect(s.opacity, 0.3);
    expect(s.brush, Brush.marker);
    expect(s.layer, DrawingLayer.above);

    // Opacity is clamped to [0,1].
    c.setOpacity(5);
    expect(c.opacity, 1.0);
    c.setOpacity(-1);
    expect(c.opacity, 0.0);
  });

  testWidgets(
      'strokes keep their selected layer and history stays chronological',
      (tester) async {
    final c = PaintController();
    await tester.pumpWidget(_host(c));

    c.setLayer(DrawingLayer.below);
    await _drawStroke(tester);
    c.setLayer(DrawingLayer.above);
    await _drawStroke(tester);

    expect(c.strokes.map((stroke) => stroke.layer),
        [DrawingLayer.below, DrawingLayer.above]);
    c.undo();
    expect(c.strokes.single.layer, DrawingLayer.below);
    c.redo();
    expect(c.strokes.last.layer, DrawingLayer.above);
  });

  testWidgets('the guide is rendered between the two drawing layers',
      (tester) async {
    final c = PaintController();
    await tester.pumpWidget(_host(c));

    final below =
        tester.getTopLeft(find.byKey(const ValueKey('drawing-layer-below')));
    final guide =
        tester.getTopLeft(find.byKey(const ValueKey('drawing-guide')));
    final above =
        tester.getTopLeft(find.byKey(const ValueKey('drawing-layer-above')));
    expect(below, guide);
    expect(guide, above);

    final stack = tester.widget<Stack>(
      find.descendant(
          of: find.byType(DrawingPad), matching: find.byType(Stack)),
    );
    expect(stack.children.length, 3);
  });

  testWidgets('calligraphy tolerates duplicate / near-coincident points',
      (tester) async {
    final c = PaintController()..setBrush(Brush.calligraphy);
    await tester.pumpWidget(_host(c));

    c.start(const Offset(150, 150));
    c.extend(const Offset(150, 150)); // exact duplicate
    c.extend(const Offset(150.1, 150.1)); // below the 0.6px dedup threshold
    c.extend(const Offset(160, 158));
    c.end();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
