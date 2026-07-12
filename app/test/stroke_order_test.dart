import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/data/kana_strokes.dart';
import 'package:jibiki/views/widgets/stroke_order_view.dart';
import 'package:path_drawing/path_drawing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('StrokeOrderView parses KanjiVG paths and renders without error',
      (tester) async {
    // Two real-shaped KanjiVG-style stroke paths on the 109×109 canvas.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StrokeOrderView(
            paths: [
              'M52.73,9.5c1.01,1.01,1.75,2.25,1.75,3.76c0,3.53-0.09,5.73-0.1,8.95',
              'M21.88,24c0,3.37-4.06,14.25-5.62,16.5',
            ],
            viewBox: '0 0 109 109',
          ),
        ),
      ),
    );
    // Mid-animation frame - must not throw while tracing partial strokes.
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Replay strokes'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Let the animation finish so the controller isn't disposed mid-flight.
    await tester.pumpAndSettle();
  });

  testWidgets('StrokeOrderView tolerates an unparseable stroke',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
            body: StrokeOrderView(
                paths: ['not-a-path', 'M0,0 L10,10'], viewBox: '0 0 109 109')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
  });

  test('number bubbles avoid real kana strokes and one another', () async {
    final data = await KanaStrokeCatalog.load('あ');
    expect(data, isNotNull);
    final paths = [for (final d in data!.paths) parseSvgPathData(d)];
    final metrics = [
      for (final path in paths) path.computeMetrics().toList(),
    ];
    const size = 158.0;
    const canvas = 109.0;
    const scale = size / canvas;
    final centers = layoutStrokeNumberCenters(
      metrics: metrics,
      canvas: canvas,
      size: size,
    );

    expect(centers, hasLength(paths.length));
    expect(centers, everyElement(isNotNull));
    const outerRadius =
        strokeNumberBadgeRadiusPx + strokeNumberBadgeBorderPx / 2;
    const minimumStrokeDistance = outerRadius + 4.5 * scale / 2 + 2.5;
    const minimumBadgeDistance = outerRadius * 2 + 2.5;

    for (final center in centers.whereType<Offset>()) {
      expect(center.dx, inInclusiveRange(outerRadius, size - outerRadius));
      expect(center.dy, inInclusiveRange(outerRadius, size - outerRadius));
      for (final stroke in metrics) {
        for (final metric in stroke) {
          final step = .5 / scale;
          for (var distance = 0.0;
              distance <= metric.length;
              distance += step) {
            final point = metric.getTangentForOffset(distance)?.position;
            if (point == null) continue;
            expect(
              (center - point * scale).distance,
              greaterThanOrEqualTo(minimumStrokeDistance - .55),
            );
          }
        }
      }
    }

    final placed = centers.whereType<Offset>().toList();
    for (var i = 0; i < placed.length; i++) {
      for (var j = i + 1; j < placed.length; j++) {
        expect(
          (placed[i] - placed[j]).distance,
          greaterThanOrEqualTo(minimumBadgeDistance),
        );
      }
    }
  });
}
