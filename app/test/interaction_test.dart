import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/models/enums.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/views/widgets/drawing_canvas.dart';
import 'package:jibiki/views/widgets/swipe_card.dart';

void main() {
  testWidgets('SwipeCard flings and commits the rating via its controller', (tester) async {
    final controller = SwipeCardController();
    Rating? rated;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 520,
              child: SwipeCard(
                controller: controller,
                onRate: (r) => rated = r,
                front: const Text('front'),
                back: const Text('back'),
              ),
            ),
          ),
        ),
      ),
    );

    controller.reveal();
    await tester.pump();
    expect(controller.isRevealed, isTrue);

    controller.rate(Rating.good);
    await tester.pumpAndSettle();
    expect(rated, Rating.good);
  });

  test('DrawingController tracks strokes, undo and clear', () {
    final c = DrawingController();
    expect(c.isEmpty, isTrue);
    c.begin(const Offset(0, 0));
    c.extend(const Offset(10, 10));
    c.begin(const Offset(20, 20));
    expect(c.strokes.length, 2);
    c.undo();
    expect(c.strokes.length, 1);
    c.clear();
    expect(c.isEmpty, isTrue);
  });
}
