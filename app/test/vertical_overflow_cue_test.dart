import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/views/widgets/vertical_overflow_cue.dart';

Widget _host({required Widget child}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 180, height: 180, child: child),
        ),
      ),
    );

AnimatedOpacity _cue(WidgetTester tester, Key key) =>
    tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(AnimatedOpacity),
      ),
    );

void main() {
  testWidgets('shows only the vertical edge with overflowing content',
      (tester) async {
    await tester.pumpWidget(
      _host(
        child: VerticalOverflowCue(
          edgeColor: Colors.white,
          child: ListView(children: const [SizedBox(height: 500)]),
        ),
      ),
    );
    await tester.pump();

    expect(_cue(tester, VerticalOverflowCue.topCueKey).opacity, 0);
    expect(_cue(tester, VerticalOverflowCue.bottomCueKey).opacity, 1);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();

    expect(_cue(tester, VerticalOverflowCue.topCueKey).opacity, 1);
    expect(_cue(tester, VerticalOverflowCue.bottomCueKey).opacity, 0);
  });

  testWidgets('keeps both vertical fades hidden when content fits',
      (tester) async {
    await tester.pumpWidget(
      _host(
        child: VerticalOverflowCue(
          edgeColor: Colors.white,
          child: ListView(children: const [SizedBox(height: 80)]),
        ),
      ),
    );
    await tester.pump();

    expect(_cue(tester, VerticalOverflowCue.topCueKey).opacity, 0);
    expect(_cue(tester, VerticalOverflowCue.bottomCueKey).opacity, 0);
  });

  testWidgets('maps reversed vertical metrics to physical edges',
      (tester) async {
    await tester.pumpWidget(
      _host(
        child: VerticalOverflowCue(
          edgeColor: Colors.white,
          child: ListView(
            reverse: true,
            children: const [SizedBox(height: 500)],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_cue(tester, VerticalOverflowCue.topCueKey).opacity, 1);
    expect(_cue(tester, VerticalOverflowCue.bottomCueKey).opacity, 0);
  });
}
