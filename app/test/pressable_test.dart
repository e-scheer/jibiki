import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/views/widgets/pressable.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('activates from the keyboard', (tester) async {
    var activations = 0;
    await tester.pumpWidget(
      _host(
        Pressable(
          label: 'Open',
          onTap: () => activations++,
          child: const SizedBox(width: 120, height: 48),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 140));

    expect(activations, 1);
  });

  testWidgets('exposes its pressed state to hard-shadow builders',
      (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      _host(
        Pressable.builder(
          label: 'Press',
          onTap: () {},
          builder: (context, value) {
            pressed = value;
            return const SizedBox(width: 120, height: 48);
          },
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Pressable)),
    );
    await tester.pump();
    expect(pressed, isTrue);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(pressed, isFalse);
  });
}
