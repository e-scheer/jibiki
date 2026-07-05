import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/views/widgets/speech_button.dart';

Widget _host(Widget child) => MaterialApp(theme: AppTheme.light(), home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('renders a play icon and taps without throwing', (tester) async {
    await tester.pumpWidget(_host(const SpeechButton(text: 'みず')));
    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);

    await tester.tap(find.byType(SpeechButton));
    await tester.pump();
    // TTS is a no-op in the test harness (no platform engine); it must not throw.
    expect(tester.takeException(), isNull);
  });

  testWidgets('is disabled when there is nothing to say', (tester) async {
    await tester.pumpWidget(_host(const SpeechButton(text: '   ')));
    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
  });
}
