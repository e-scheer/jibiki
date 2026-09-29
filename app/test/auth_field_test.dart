import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/views/auth/auth_chrome.dart';

void main() {
  for (final width in [320.0, 900.0]) {
    testWidgets('error stays outside the field shadow at width $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
      addTearDown(tester.view.reset);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final formKey = GlobalKey<FormState>();
      const error =
          'Use at least six characters so that your password is long enough.';
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: AuthField(
                controller: controller,
                label: 'Password',
                icon: Icons.lock_outline,
                obscureText: true,
                validator: (value) => (value?.length ?? 0) < 6 ? error : null,
              ),
            ),
          ),
        ),
      ));

      final shadow = find.descendant(
        of: find.byType(AuthField),
        matching: find.byType(AnimatedContainer),
      );
      final normalHeight = tester.getSize(shadow).height;
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();

      expect(find.text(error), findsOneWidget);
      expect(tester.getSize(shadow).height, normalHeight);
      expect(tester.getRect(find.text(error)).top,
          greaterThan(tester.getRect(shadow).bottom + 3));
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextFormField), 'secret123');
      await tester.pumpAndSettle();
      expect(find.text(error), findsNothing);
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
      expect(formKey.currentState!.validate(), isTrue);
      expect(tester.getSize(shadow).height, normalHeight);

      await tester.enterText(find.byType(TextFormField), 'short');
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      formKey.currentState!.reset();
      await tester.pumpAndSettle();
      expect(find.text(error), findsNothing);
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
      expect(controller.text, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
