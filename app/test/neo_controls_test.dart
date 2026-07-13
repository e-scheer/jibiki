import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/views/auth/auth_chrome.dart';
import 'package:jibiki/views/widgets/neo_pop.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
    );

void main() {
  testWidgets('NeoRefreshIndicator uses the branded loader without a spinner',
      (tester) async {
    final refresh = Completer<void>();
    addTearDown(() {
      if (!refresh.isCompleted) refresh.complete();
    });
    await tester.pumpWidget(
      _host(
        SizedBox(
          height: 360,
          child: NeoRefreshIndicator(
            onRefresh: () => refresh.future,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 500)],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(find.byKey(NeoRefreshIndicator.loaderKey), findsOneWidget);
    final opacityFinder = find.ancestor(
      of: find.byKey(NeoRefreshIndicator.loaderKey),
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 0);

    await tester.drag(find.byType(ListView), const Offset(0, 160));
    await tester.pump();

    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 1);
  });

  testWidgets('NeoSegmentedControl slides its shared selection pill',
      (tester) async {
    var selected = 'first';
    late StateSetter update;

    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return NeoSegmentedControl<String>(
              selected: selected,
              segments: const [
                NeoSegment('first', 'First'),
                NeoSegment('second', 'Second'),
              ],
              onChanged: (_) {},
            );
          },
        ),
      ),
    );

    expect(tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment,
        const Alignment(-1, 0));
    update(() => selected = 'second');
    await tester.pump();
    expect(tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment,
        const Alignment(1, 0));
  });

  testWidgets('NeoSegmentedControl can represent no study status',
      (tester) async {
    await tester.pumpWidget(
      _host(
        NeoSegmentedControl<String?>(
          selected: null,
          segments: const [
            NeoSegment<String?>('learning', 'Study'),
            NeoSegment<String?>('known', 'Known'),
          ],
          onChanged: (_) {},
        ),
      ),
    );

    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0);
  });

  testWidgets('AuthField exposes a distinct error icon and message',
      (tester) async {
    final key = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: AuthField(
            controller: controller,
            label: 'Email',
            icon: Icons.mail_outline,
            validator: (_) => 'Enter a valid email',
          ),
        ),
      ),
    );

    key.currentState!.validate();
    await tester.pump();
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });
}
