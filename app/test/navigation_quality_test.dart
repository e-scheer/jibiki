import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jibiki/core/api_exception.dart';
import 'package:jibiki/l10n/l10n.dart';
import 'package:jibiki/models/deck.dart';
import 'package:jibiki/models/enums.dart';
import 'package:jibiki/models/study.dart';
import 'package:jibiki/repositories/auth_repository.dart';
import 'package:jibiki/repositories/study_repository.dart';
import 'package:jibiki/routing/app_router.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/services/study_service.dart';
import 'package:jibiki/viewmodels/app_state.dart';
import 'package:jibiki/views/reference/reference_view.dart';
import 'package:jibiki/views/shell/home_shell.dart';
import 'package:jibiki/views/study/session_view.dart';
import 'package:jibiki/views/study/decks_view.dart';
import 'package:jibiki/views/widgets/pressable.dart';
import 'package:provider/provider.dart';

class _Auth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _App extends AppState {
  _App() : super(_Auth());
  AuthStatus currentStatus = AuthStatus.authenticated;
  @override
  AuthStatus get status => currentStatus;
  @override
  bool get canEnter => currentStatus == AuthStatus.authenticated;
  @override
  bool get onboarded => true;
  @override
  AppMode get mode => AppMode.learning;
  void ready() {
    currentStatus = AuthStatus.authenticated;
    notifyListeners();
  }
}

class _Study implements StudyRepository {
  int loads = 0;
  List<Deck> deckList = [];
  @override
  Future<List<StudyCard>> cards({ItemType? type}) async => [];
  Completer<StudyQueue>? queueResponse;
  @override
  Future<StudyStats> stats() async => StudyStats.empty();
  @override
  Future<List<Deck>> decks() async {
    loads++;
    return deckList;
  }

  @override
  Future<StudyQueue> queue({int? newLimit}) =>
      queueResponse?.future ?? Future.error(ApiException('Offline'));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, _App app, _Study study,
    {GoRouter? router,
    Size size = const Size(390, 844),
    Locale locale = const Locale('en')}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AppState>.value(value: app),
      Provider<StudyRepository>.value(value: study),
    ],
    child: router != null
        ? MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          )
        : MaterialApp(
            theme: AppTheme.light(),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const HomeShell(),
          ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1440, 900)
  ]) {
    testWidgets('navigation labels and review state survive resize at $size',
        (tester) async {
      final app = _App();
      final study = _Study();
      await _pump(tester, app, study, size: size, locale: const Locale('fr'));
      expect(find.byTooltip('Dictionnaire'), findsOneWidget);
      expect(find.byTooltip('Communauté'), findsOneWidget);
      expect(find.byTooltip('Profil'), findsOneWidget);
      final loads = study.loads;
      tester.view.physicalSize =
          size.width < 600 ? const Size(1024, 768) : const Size(390, 844);
      await tester.pumpAndSettle();
      expect(study.loads, loads,
          reason: 'Resizing must not recreate the review tab.');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'cold reference link survives bootstrap and has a way out at $size',
        (tester) async {
      final app = _App()..currentStatus = AuthStatus.unknown;
      final router =
          buildRouter(app, initialLocation: '/reference?source=guide');
      addTearDown(router.dispose);
      await _pump(tester, app, _Study(), router: router, size: size);
      expect(router.routeInformationProvider.value.uri.path, '/splash');
      app.ready();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(),
          '/reference?source=guide');
      expect(find.byType(ReferenceView), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Back').first);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(tester.takeException(), isNull);
    });

    testWidgets('session failure retains a close action at $size',
        (tester) async {
      final router = GoRouter(initialLocation: '/session', routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('Home destination'))),
        GoRoute(path: '/session', builder: (_, __) => const SessionView()),
      ]);
      addTearDown(router.dispose);
      await _pump(tester, _App(), _Study(), router: router, size: size);
      expect(find.text('Offline'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Home destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a partly studied pack stays available when no reviews are due',
      (tester) async {
    final study = _Study()
      ..deckList = [
        Deck(
          id: 'test',
          title: 'Test pack',
          subtitle: 'More to learn',
          icon: '水',
          kind: 'content',
          total: 100,
          enrolled: 10,
          studied: 10,
          due: 0,
        )
      ];
    await tester.pumpWidget(Provider<StudyRepository>.value(
      value: study,
      child: MaterialApp(theme: AppTheme.light(), home: const DecksView()),
    ));
    await tester.pumpAndSettle();
    final action = tester.widget<Pressable>(find
        .ancestor(
          of: find.text('Test pack'),
          matching: find.byType(Pressable),
        )
        .first);
    expect(action.onTap, isNotNull);
    expect(find.text('Up to date. Next batch tomorrow.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('malformed and unknown links show a localized recovery action',
      (tester) async {
    final app = _App();
    final router = buildRouter(app, initialLocation: '/word/not-a-number');
    addTearDown(router.dispose);
    await _pump(tester, app, _Study(), router: router);
    expect(find.text('This page is unavailable.'), findsOneWidget);
    router.go('/decks/community/invalid');
    await tester.pumpAndSettle();
    expect(find.text('Return to Jibiki'), findsOneWidget);
    router.go('/missing-page');
    await tester.pumpAndSettle();
    expect(find.text('This page is unavailable.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a loading session can be closed without waiting for the network',
      (tester) async {
    final study = _Study()..queueResponse = Completer<StudyQueue>();
    final router = GoRouter(initialLocation: '/session', routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Home destination'))),
      GoRoute(path: '/session', builder: (_, __) => const SessionView()),
    ]);
    addTearDown(router.dispose);
    await _pump(tester, _App(), study, router: router);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Home destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
