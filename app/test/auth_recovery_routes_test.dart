import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/l10n/app_localizations.dart';
import 'package:jibiki/repositories/auth_repository.dart';
import 'package:jibiki/routing/app_router.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/viewmodels/app_state.dart';
import 'package:provider/provider.dart';

class _FakeAuthRepository implements AuthRepository {
  final List<String> inspectedEmailKeys = [];
  final List<String> verifiedEmailKeys = [];
  final List<String> resetRequests = [];
  final List<String> inspectedResetKeys = [];
  final List<({String key, String password})> passwordResets = [];

  @override
  Future<void> inspectEmailVerificationKey(String key) async {
    inspectedEmailKeys.add(key);
  }

  @override
  Future<void> verifyEmail(String key) async {
    verifiedEmailKeys.add(key);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    resetRequests.add(email);
  }

  @override
  Future<void> inspectPasswordResetKey(String key) async {
    inspectedResetKeys.add(key);
  }

  @override
  Future<void> resetPassword(String key, String password) async {
    passwordResets.add((key: key, password: password));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpRoute(
  WidgetTester tester, {
  required Size size,
  required String location,
  required _FakeAuthRepository repository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  final app = AppState(repository);
  final router = buildRouter(app, initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: repository),
        ChangeNotifierProvider<AppState>.value(value: app),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets(
      'email verification remains reachable on cold start at ${size.width}',
      (tester) async {
        final repository = _FakeAuthRepository();
        await _pumpRoute(
          tester,
          size: size,
          location: '/verify-email/email-key',
          repository: repository,
        );

        expect(repository.inspectedEmailKeys, ['email-key']);
        expect(find.text('Your email is ready to verify'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const ValueKey('verify-email-button')));
        await tester.pumpAndSettle();

        expect(repository.verifiedEmailKeys, ['email-key']);
        expect(find.text('Email verified'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'password reset request is usable at ${size.width}',
      (tester) async {
        final repository = _FakeAuthRepository();
        await _pumpRoute(
          tester,
          size: size,
          location: '/reset-password',
          repository: repository,
        );

        await tester.enterText(
          find.byType(TextFormField).first,
          'learner@example.com',
        );
        await tester.tap(find.byKey(const ValueKey('request-reset-button')));
        await tester.pumpAndSettle();

        expect(repository.resetRequests, ['learner@example.com']);
        expect(find.text('Check your inbox'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'social auth error is localized and overflow-free at ${size.width}',
      (tester) async {
        final repository = _FakeAuthRepository();
        await _pumpRoute(
          tester,
          size: size,
          location: '/social-error?error=permission_denied&error_process=login',
          repository: repository,
        );

        expect(find.text('Sign-in was not approved'), findsOneWidget);
        expect(find.text('permission_denied'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('password reset link validates and updates the password',
      (tester) async {
    final repository = _FakeAuthRepository();
    await _pumpRoute(
      tester,
      size: const Size(390, 844),
      location: '/reset-password/reset-key',
      repository: repository,
    );

    expect(repository.inspectedResetKeys, ['reset-key']);
    expect(find.text('Choose a new password'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'long-password');
    await tester.enterText(find.byType(TextFormField).at(1), 'long-password');
    await tester.tap(find.byKey(const ValueKey('reset-password-button')));
    await tester.pumpAndSettle();

    expect(
      repository.passwordResets,
      [(key: 'reset-key', password: 'long-password')],
    );
    expect(find.text('Password updated'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
