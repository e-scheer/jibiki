/// The content-report sheet: signed-out learners are prompted to sign in;
/// signed-in ones pick a reason and the flag posts with the entry's identity.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/repositories/auth_repository.dart';
import 'package:jibiki/services/auth_service.dart';
import 'package:jibiki/services/feedback_service.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/viewmodels/app_state.dart';
import 'package:jibiki/views/feedback/report_item_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An AppState pinned to "signed in" without the real auth handshake.
class _AuthedAppState extends AppState {
  _AuthedAppState(super.auth);
  @override
  bool get isAuthenticated => true;
}

/// Captures the report payload instead of hitting the network.
class _FakeFeedbackService extends FeedbackService {
  _FakeFeedbackService(super.api);
  Map<String, dynamic>? sent;

  @override
  Future<void> reportContent({
    required String itemType,
    required String itemRef,
    required String reason,
    String message = '',
    Map<String, dynamic> context = const {},
  }) async {
    sent = {
      'item_type': itemType,
      'item_ref': itemRef,
      'reason': reason,
      'message': message,
    };
  }
}

Future<({ApiClient api, AuthRepository auth})> _deps() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final session = SessionStore(prefs);
  final api = ApiClient(session);
  return (api: api, auth: AuthRepository(AuthService(api), session));
}

Widget _host({required AppState appState, required FeedbackService service}) {
  return MultiProvider(
    providers: [
      Provider<FeedbackService>.value(value: service),
      ChangeNotifierProvider<AppState>.value(value: appState),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        appBar: AppBar(
          actions: const [
            ReportItemAction(
                type: ReportItemType.kanji, itemRef: '水', label: '水'),
          ],
        ),
        body: const SizedBox.expand(),
      ),
    ),
  );
}

void main() {
  testWidgets('signed-out learner is prompted to sign in, not shown the form',
      (tester) async {
    final d = await _deps();
    await tester.pumpWidget(
        _host(appState: AppState(d.auth), service: _FakeFeedbackService(d.api)));

    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sign in to report'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    // The reason picker never appears when signed out.
    expect(find.text("Something's wrong"), findsNothing);
  });

  testWidgets('signed-in learner picks a reason and the flag posts',
      (tester) async {
    final d = await _deps();
    final service = _FakeFeedbackService(d.api);
    await tester.pumpWidget(
        _host(appState: _AuthedAppState(d.auth), service: service));

    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();

    // Send is gated until a reason is chosen.
    final send = find.widgetWithText(FilledButton, 'Send report');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    await tester.tap(find.text("Something's wrong"));
    await tester.pump();
    expect(tester.widget<FilledButton>(send).onPressed, isNotNull);

    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(service.sent, isNotNull);
    expect(service.sent!['item_type'], 'kanji');
    expect(service.sent!['item_ref'], '水');
    expect(service.sent!['reason'], 'wrong');
    // Sheet closes and a confirmation lands.
    expect(find.textContaining("we'll take a look"), findsOneWidget);
  });
}
