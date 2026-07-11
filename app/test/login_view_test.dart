import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/repositories/auth_repository.dart';
import 'package:jibiki/services/auth_service.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/viewmodels/app_state.dart';
import 'package:jibiki/views/auth/login_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _appState() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final session = SessionStore(prefs);
  return AppState(AuthRepository(AuthService(ApiClient(session)), session));
}

void main() {
  testWidgets('canceling optional sign-in returns to settings', (tester) async {
    final app = await _appState();
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, __) => const Scaffold(body: Text('Settings')),
        ),
        GoRoute(path: '/login', builder: (_, __) => const LoginView()),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.push('/login');
    await tester.pumpAndSettle();
    expect(find.textContaining('Continue without an account'), findsOneWidget);

    await tester.tap(find.textContaining('Continue without an account'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });
}
