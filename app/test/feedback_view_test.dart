/// The feedback space: kind chips adapt the prompt, submit gates on content,
/// and the auto-attached context is disclosed on screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/data/packs/pack_manager.dart';
import 'package:jibiki/repositories/auth_repository.dart';
import 'package:jibiki/services/auth_service.dart';
import 'package:jibiki/services/feedback_service.dart';
import 'package:jibiki/viewmodels/app_state.dart';
import 'package:jibiki/views/feedback/feedback_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final session = SessionStore(prefs);
  final api = ApiClient(session);
  final appState = AppState(AuthRepository(AuthService(api), session));
  return MultiProvider(
    providers: [
      Provider<PackManager?>.value(value: null),
      Provider(create: (_) => FeedbackService(api)),
      ChangeNotifierProvider.value(value: appState),
    ],
    child: const MaterialApp(home: FeedbackView()),
  );
}

void main() {
  testWidgets('kinds swap the prompt and gate the send button', (tester) async {
    await tester.pumpWidget(await _app());

    expect(find.text('💡  Idea'), findsOneWidget);
    expect(find.text('🐛  Bug'), findsOneWidget);
    expect(find.textContaining('a human reads every single one'), findsOneWidget);
    // Transparency line about the attached context.
    expect(find.textContaining('Sent along for context'), findsOneWidget);

    // Send is disabled on an empty message.
    final send = find.widgetWithText(FilledButton, 'Send');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    // Switching kind swaps the placeholder prompt.
    await tester.tap(find.text('🐛  Bug'));
    await tester.pump();
    expect(find.textContaining('What happened'), findsOneWidget);

    // Typing unlocks the button.
    await tester.enterText(
        find.byType(TextField).first, 'Stroke order stalls on 水.');
    await tester.pump();
    expect(tester.widget<FilledButton>(send).onPressed, isNotNull);

    // Signed-out: the optional reply-to email is offered.
    expect(find.textContaining('only if you’d like a reply'), findsOneWidget);
  });
}
