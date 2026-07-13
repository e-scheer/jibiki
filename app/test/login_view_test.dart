import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/l10n/app_localizations.dart';
import 'package:jibiki/repositories/auth_repository.dart';
import 'package:jibiki/services/auth_service.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/viewmodels/app_state.dart';
import 'package:jibiki/views/auth/login_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _appState({
  Map<String, Object> initialValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  final session = SessionStore(prefs);
  return AppState(AuthRepository(AuthService(ApiClient(session)), session));
}

class _FailingLocalAuth extends AuthRepository {
  _FailingLocalAuth(super.auth, super.session);

  @override
  Future<void> setLocalOnly(bool v) async {
    throw StateError('storage unavailable');
  }
}

Future<AppState> _failingAppState() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final session = SessionStore(prefs);
  return AppState(
    _FailingLocalAuth(AuthService(ApiClient(session)), session),
  );
}

Widget _routerApp(AppState app, GoRouter router) =>
    ChangeNotifierProvider.value(
      value: app,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );

void main() {
  testWidgets('canceling optional sign-in returns to settings', (tester) async {
    final app = await _appState(initialValues: {'local_only': true});
    await app.bootstrap();
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
    await tester.pumpWidget(_routerApp(app, router));
    await tester.pumpAndSettle();

    router.push('/login?link=1');
    await tester.pumpAndSettle();
    expect(find.textContaining('Continue without an account'), findsOneWidget);

    await tester.tap(find.textContaining('Continue without an account'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets(
      'guest CTA leaves landing login when onboarding is already complete',
      (tester) async {
    final app = await _appState(initialValues: {'onboarded': true});
    await app.bootstrap();
    final router = GoRouter(
      initialLocation: '/login',
      refreshListenable: app,
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginView()),
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    await tester.pumpWidget(_routerApp(app, router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue without an account'));
    await tester.pumpAndSettle();

    expect(app.localOnly, isTrue);
    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(LoginView), findsNothing);
  });

  testWidgets('a poppable unauthenticated login still enters guest mode',
      (tester) async {
    final app = await _appState(initialValues: {'onboarded': true});
    await app.bootstrap();
    final router = GoRouter(
      initialLocation: '/holding',
      routes: [
        GoRoute(
          path: '/holding',
          builder: (_, __) => const Scaffold(body: Text('Holding')),
        ),
        GoRoute(path: '/login', builder: (_, __) => const LoginView()),
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    await tester.pumpWidget(_routerApp(app, router));
    await tester.pumpAndSettle();

    router.push('/login');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue without an account'));
    await tester.pumpAndSettle();

    expect(app.localOnly, isTrue);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Holding'), findsNothing);
  });

  testWidgets('a direct login URL exits an existing local session',
      (tester) async {
    final app = await _appState(
      initialValues: {'local_only': true, 'onboarded': true},
    );
    await app.bootstrap();
    final router = GoRouter(
      initialLocation: '/holding',
      routes: [
        GoRoute(
          path: '/holding',
          builder: (_, __) => const Scaffold(body: Text('Holding')),
        ),
        GoRoute(path: '/login', builder: (_, __) => const LoginView()),
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    await tester.pumpWidget(_routerApp(app, router));
    await tester.pumpAndSettle();

    router.push('/login');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue without an account'));
    await tester.pumpAndSettle();

    expect(app.localOnly, isTrue);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Holding'), findsNothing);
  });

  testWidgets('guest storage failure is visible and retry stays available',
      (tester) async {
    final app = await _failingAppState();
    await app.bootstrap();
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginView()),
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    await tester.pumpWidget(_routerApp(app, router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue without an account'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not continue without an account. Please try again.'),
      findsOneWidget,
    );
    final retry = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Continue without an account'),
        matching: find.byType(TextButton),
      ),
    );
    expect(retry.onPressed, isNotNull);
    expect(app.localOnly, isFalse);
  });
}
