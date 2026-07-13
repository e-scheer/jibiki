import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth_callback_query.dart';
import '../core/telemetry_route_observer.dart';
import '../models/enums.dart';
import '../viewmodels/app_state.dart';
import '../views/auth/login_view.dart';
import '../views/auth/register_view.dart';
import '../views/auth/reset_password_view.dart';
import '../views/auth/social_auth_error_view.dart';
import '../views/auth/verify_email_view.dart';
import '../views/community/community_decks_view.dart';
import '../views/community/deck_builder_view.dart';
import '../views/community/deck_detail_view.dart';
import '../views/community/my_submissions_view.dart';
import '../views/dictionary/kanji_detail_view.dart';
import '../views/dictionary/word_detail_view.dart';
import '../views/kana/kana_detail_view.dart';
import '../views/feedback/feedback_view.dart';
import '../views/onboarding/onboarding_view.dart';
import '../views/settings/offline_storage_view.dart';
import '../views/settings/settings_view.dart';
import '../views/settings/wanikani_view.dart';
import '../views/shell/home_shell.dart';
import '../views/shell/splash_view.dart';
import '../views/study/session_view.dart';
import '../views/study/statistics_view.dart';
import '../views/reference/reference_view.dart';

/// Declarative routing with a single redirect guard that reads AppState:
///   unknown → splash · unauthenticated → login · authenticated but
///   not onboarded → onboarding · otherwise the home shell.
GoRouter buildRouter(AppState app, {String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: app,
    observers: [TelemetryRouteObserver()],
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final atAuth = loc == '/login' || loc == '/register';
      final atRecovery = loc.startsWith('/verify-email/') ||
          loc == '/reset-password' ||
          loc.startsWith('/reset-password/') ||
          loc == '/social-error';

      if (app.status == AuthStatus.unknown) {
        if (atRecovery) return null;
        return loc == '/splash' ? null : '/splash';
      }
      // Email and provider callbacks must survive cold-start bootstrap and stay
      // reachable regardless of the current account or onboarding state.
      if (atRecovery) return null;
      // Local-only (no account) counts as signed in: the paid app is fully
      // usable offline; login stays reachable to link an account later.
      if (!app.canEnter) {
        // The landing route still asks for an account, but deep links remain on
        // their intended surface so an account-only panel can explain the gate
        // without throwing the learner into a dead-end login page.
        if (atAuth || loc == '/' || loc == '/splash') {
          return atAuth ? null : '/login';
        }
        return null;
      }
      if (!app.onboarded) return loc == '/onboarding' ? null : '/onboarding';
      if (app.localOnly && atAuth) {
        return null;
      }
      if (atAuth || loc == '/onboarding' || loc == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(
          name: 'splash',
          path: '/splash',
          builder: (_, __) => const SplashView()),
      GoRoute(
          name: 'login', path: '/login', builder: (_, __) => const LoginView()),
      GoRoute(
          name: 'register',
          path: '/register',
          builder: (_, __) => const RegisterView()),
      GoRoute(
        name: 'verify_email',
        path: '/verify-email/:key',
        pageBuilder: (_, state) => _authFlowPage(
          state,
          VerifyEmailView(
            verificationKey: state.pathParameters['key'] ?? '',
          ),
        ),
      ),
      GoRoute(
        name: 'request_password_reset',
        path: '/reset-password',
        pageBuilder: (_, state) =>
            _authFlowPage(state, const ResetPasswordView()),
      ),
      GoRoute(
        name: 'reset_password',
        path: '/reset-password/:key',
        pageBuilder: (_, state) => _authFlowPage(
          state,
          ResetPasswordView(resetKey: state.pathParameters['key']),
        ),
      ),
      GoRoute(
        name: 'social_auth_error',
        path: '/social-error',
        pageBuilder: (_, state) {
          final outerQuery = readOuterAuthCallbackQuery();
          return _authFlowPage(
            state,
            SocialAuthErrorView(
              errorCode:
                  state.uri.queryParameters['error'] ?? outerQuery['error'],
              errorProcess: state.uri.queryParameters['error_process'] ??
                  outerQuery['error_process'],
            ),
          );
        },
      ),
      GoRoute(
          name: 'onboarding',
          path: '/onboarding',
          builder: (_, __) => const OnboardingView()),
      GoRoute(name: 'home', path: '/', builder: (_, __) => const HomeShell()),
      GoRoute(
        name: 'study_session',
        path: '/session',
        builder: (_, s) => SessionView(
          deckId: s.uri.queryParameters['deck'],
          initialMode: StudyMode.fromString(s.uri.queryParameters['mode']),
          title: s.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        name: 'word_detail',
        path: '/word/:id',
        builder: (_, s) =>
            WordDetailView(wordId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        name: 'kanji_detail',
        path: '/kanji/:literal',
        builder: (_, s) =>
            KanjiDetailView(literal: s.pathParameters['literal']!),
      ),
      GoRoute(
        name: 'kana_detail',
        path: '/kana/:char',
        builder: (_, s) => KanaDetailView(
          char: s.pathParameters['char']!,
          showBoth: s.uri.queryParameters['mode'] == 'both',
        ),
      ),
      GoRoute(
          name: 'settings',
          path: '/settings',
          builder: (_, __) => const SettingsView()),
      GoRoute(
          name: 'reference',
          path: '/reference',
          builder: (_, __) => const ReferenceView()),
      GoRoute(
        name: 'statistics',
        path: '/stats',
        builder: (_, __) => const StatisticsView(showBack: true),
      ),
      GoRoute(
          name: 'offline_storage',
          path: '/settings/storage',
          builder: (_, __) => const OfflineStorageView()),
      GoRoute(
          name: 'wanikani',
          path: '/settings/integrations/wanikani',
          builder: (_, __) => const WaniKaniView()),
      GoRoute(
          name: 'feedback',
          path: '/feedback',
          builder: (_, __) => const FeedbackView()),
      GoRoute(
          name: 'submissions',
          path: '/submissions',
          builder: (_, __) => const MySubmissionsView()),
      GoRoute(
          name: 'deck_builder',
          path: '/decks/new',
          builder: (_, __) => const DeckBuilderView()),
      GoRoute(
        name: 'community_decks',
        path: '/decks/community',
        builder: (_, s) => CommunityDecksView(
          initialTab: s.uri.queryParameters['tab'] == 'mine' ? 1 : 0,
          showBack: true,
        ),
      ),
      GoRoute(
        name: 'community_deck_detail',
        path: '/decks/community/:id',
        builder: (_, s) => DeckDetailView(
          deckId: int.parse(s.pathParameters['id']!),
          owned: s.uri.queryParameters['owned'] == '1',
        ),
      ),
    ],
  );
}

CustomTransitionPage<void> _authFlowPage(
  GoRouterState state,
  Widget child,
) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(.08, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
