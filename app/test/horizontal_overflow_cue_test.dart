import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/views/widgets/horizontal_overflow_cue.dart';

Widget _host({required Widget child}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 160, height: 48, child: child),
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
  testWidgets('shows only the edge that has overflowing content',
      (tester) async {
    await tester.pumpWidget(
      _host(
        child: HorizontalOverflowCue(
          edgeColor: Colors.white,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [SizedBox(width: 500)],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_cue(tester, HorizontalOverflowCue.leftCueKey).opacity, 0);
    expect(_cue(tester, HorizontalOverflowCue.rightCueKey).opacity, 1);

    await tester.drag(find.byType(ListView), const Offset(-500, 0));
    await tester.pump();

    expect(_cue(tester, HorizontalOverflowCue.leftCueKey).opacity, 1);
    expect(_cue(tester, HorizontalOverflowCue.rightCueKey).opacity, 0);
  });

  testWidgets('maps reversed scroll metrics to physical edges', (tester) async {
    await tester.pumpWidget(
      _host(
        child: HorizontalOverflowCue(
          edgeColor: Colors.white,
          child: ListView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            children: const [SizedBox(width: 500)],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_cue(tester, HorizontalOverflowCue.leftCueKey).opacity, 1);
    expect(_cue(tester, HorizontalOverflowCue.rightCueKey).opacity, 0);
  });

  testWidgets('keeps both fades hidden when the row fits', (tester) async {
    await tester.pumpWidget(
      _host(
        child: HorizontalOverflowCue(
          edgeColor: Colors.white,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [SizedBox(width: 80)],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_cue(tester, HorizontalOverflowCue.leftCueKey).opacity, 0);
    expect(_cue(tester, HorizontalOverflowCue.rightCueKey).opacity, 0);
  });
}
