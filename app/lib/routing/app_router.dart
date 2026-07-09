import 'package:go_router/go_router.dart';

import '../models/enums.dart';
import '../viewmodels/app_state.dart';
import '../views/auth/login_view.dart';
import '../views/auth/register_view.dart';
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
import '../views/shell/home_shell.dart';
import '../views/shell/splash_view.dart';
import '../views/study/session_view.dart';

/// Declarative routing with a single redirect guard that reads AppState:
///   unknown → splash · unauthenticated → login · authenticated but
///   not onboarded → onboarding · otherwise the home shell.
GoRouter buildRouter(AppState app) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: app,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final atAuth = loc == '/login' || loc == '/register';

      if (app.status == AuthStatus.unknown) return loc == '/splash' ? null : '/splash';
      // Local-only (no account) counts as signed in: the paid app is fully
      // usable offline; login stays reachable to link an account later.
      if (!app.canEnter) return atAuth ? null : '/login';
      if (!app.onboarded) return loc == '/onboarding' ? null : '/onboarding';
      if (atAuth || loc == '/onboarding' || loc == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashView()),
      GoRoute(path: '/login', builder: (_, __) => const LoginView()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterView()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingView()),
      GoRoute(path: '/', builder: (_, __) => const HomeShell()),
      GoRoute(
        path: '/session',
        builder: (_, s) => SessionView(
          deckId: s.uri.queryParameters['deck'],
          initialMode: StudyMode.fromString(s.uri.queryParameters['mode']),
          title: s.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: '/word/:id',
        builder: (_, s) => WordDetailView(wordId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/kanji/:literal',
        builder: (_, s) => KanjiDetailView(literal: s.pathParameters['literal']!),
      ),
      GoRoute(
        path: '/kana/:char',
        builder: (_, s) => KanaDetailView(char: s.pathParameters['char']!),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsView()),
      GoRoute(path: '/settings/storage', builder: (_, __) => const OfflineStorageView()),
      GoRoute(path: '/feedback', builder: (_, __) => const FeedbackView()),
      GoRoute(path: '/submissions', builder: (_, __) => const MySubmissionsView()),
      GoRoute(path: '/decks/new', builder: (_, __) => const DeckBuilderView()),
      GoRoute(
        path: '/decks/community',
        builder: (_, s) => CommunityDecksView(
          initialTab: s.uri.queryParameters['tab'] == 'mine' ? 1 : 0,
        ),
      ),
      GoRoute(
        path: '/decks/community/:id',
        builder: (_, s) => DeckDetailView(
          deckId: int.parse(s.pathParameters['id']!),
          owned: s.uri.queryParameters['owned'] == '1',
        ),
      ),
    ],
  );
}
