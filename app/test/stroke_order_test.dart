import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/views/widgets/stroke_order_view.dart';

void main() {
  testWidgets('StrokeOrderView parses KanjiVG paths and renders without error', (tester) async {
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
    // Mid-animation frame — must not throw while tracing partial strokes.
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Replay strokes'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Let the animation finish so the controller isn't disposed mid-flight.
    await tester.pumpAndSettle();
  });

  testWidgets('StrokeOrderView tolerates an unparseable stroke', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StrokeOrderView(paths: ['not-a-path', 'M0,0 L10,10'], viewBox: '0 0 109 109')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
  });
}
