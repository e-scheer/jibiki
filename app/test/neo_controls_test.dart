import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/views/auth/auth_chrome.dart';
import 'package:jibiki/views/widgets/neo_pop.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
    );

void main() {
  double contentOffset(WidgetTester tester) => tester
      .widget<Transform>(find.byKey(NeoRefreshIndicator.contentKey))
      .transform
      .getTranslation()
      .y;

  testWidgets('NeoRefreshIndicator follows pull, arms, and refreshes in-page',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final refresh = Completer<void>();
    var refreshCalls = 0;
    final platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(() {
      if (!refresh.isCompleted) refresh.complete();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await tester.pumpWidget(
      _host(
        SizedBox(
          height: 360,
          child: NeoRefreshIndicator(
            onRefresh: () {
              refreshCalls++;
              return refresh.future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              // Pull-to-refresh must also work when the page itself is shorter
              // than the viewport (empty/error/community states).
              children: const [SizedBox(height: 40)],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(find.byKey(NeoRefreshIndicator.loaderKey), findsNothing);
    expect(contentOffset(tester), 0);
    expect(
      find.bySemanticsLabel('Refresh, Pull to refresh'),
      findsNothing,
    );
    expect(
      tester.getSize(find.byKey(NeoRefreshIndicator.headerKey)).height,
      0,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );
    await gesture.moveBy(const Offset(0, 52));
    await tester.pumpAndSettle();

    final pullingOffset = contentOffset(tester);
    expect(pullingOffset, greaterThan(0));
    expect(pullingOffset, lessThan(NeoRefreshIndicator.triggerExtent));
    expect(find.text('Pull to refresh'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Refresh, Pull to refresh'),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(NeoRefreshIndicator.headerKey)).width,
      360,
    );
    expect(refreshCalls, 0);

    await gesture.moveBy(const Offset(0, 180));
    await tester.pumpAndSettle();

    expect(
      contentOffset(tester),
      greaterThanOrEqualTo(NeoRefreshIndicator.triggerExtent),
    );
    expect(find.text('Release to refresh'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Refresh, Release to refresh'),
      findsOneWidget,
    );
    expect(
      platformCalls.where(
        (call) =>
            call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.mediumImpact',
      ),
      hasLength(1),
    );

    await gesture.up();
    await tester.pump();
    expect(refreshCalls, 1);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(find.byKey(NeoRefreshIndicator.loaderKey), findsOneWidget);
    expect(find.text('Refreshing…'), findsOneWidget);
    final pinnedOffset = contentOffset(tester);
    expect(pinnedOffset, greaterThan(0));
    await tester.pump(const Duration(seconds: 1));
    expect(refreshCalls, 1);
    expect(contentOffset(tester), pinnedOffset);
    expect(tester.takeException(), isNull);

    refresh.complete();
    await tester.pumpAndSettle();

    expect(contentOffset(tester), 0);
    expect(find.byKey(NeoRefreshIndicator.loaderKey), findsNothing);
    expect(
      tester.getSize(find.byKey(NeoRefreshIndicator.headerKey)).height,
      0,
    );
    semantics.dispose();
  });

  testWidgets(
      'NeoRefreshIndicator retracts a pull released before its threshold',
      (tester) async {
    var refreshCalls = 0;
    await tester.pumpWidget(
      _host(
        SizedBox(
          height: 360,
          child: NeoRefreshIndicator(
            onRefresh: () async => refreshCalls++,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 500)],
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );
    await gesture.moveBy(const Offset(0, 52));
    await tester.pump();
    expect(contentOffset(tester), greaterThan(0));
    expect(
      contentOffset(tester),
      lessThan(NeoRefreshIndicator.triggerExtent),
    );
    expect(tester.takeException(), isNull);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(refreshCalls, 0);
    expect(contentOffset(tester), 0);
    expect(find.byKey(NeoRefreshIndicator.loaderKey), findsNothing);
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
