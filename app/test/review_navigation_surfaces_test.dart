import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/models/deck.dart';
import 'package:jibiki/models/study.dart';
import 'package:jibiki/repositories/auth_repository.dart';
import 'package:jibiki/repositories/study_repository.dart';
import 'package:jibiki/services/auth_service.dart';
import 'package:jibiki/services/study_service.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/viewmodels/app_state.dart';
import 'package:jibiki/views/study/decks_view.dart';
import 'package:jibiki/views/study/statistics_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StudyRepository extends StudyRepository {
  _StudyRepository(StudyService service) : super(service, service);

  @override
  Future<StudyStats> stats() async => StudyStats.empty();

  @override
  Future<List<Deck>> decks() async => const [];
}

Future<_StudyRepository> _repository() async {
  final prefs = await SharedPreferences.getInstance();
  final service = StudyService(ApiClient(SessionStore(prefs)));
  return _StudyRepository(service);
}

Future<AppState> _appState() async {
  final prefs = await SharedPreferences.getInstance();
  final session = SessionStore(prefs);
  return AppState(AuthRepository(AuthService(ApiClient(session)), session));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('standalone statistics has a working back action',
      (tester) async {
    final repository = await _repository();
    final app = await _appState();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StudyRepository>.value(value: repository),
          ChangeNotifierProvider<AppState>.value(value: app),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const StatisticsView(showBack: true),
                  ),
                ),
                child: const Text('Open statistics'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open statistics'));
    await tester.pumpAndSettle();
    expect(find.text('Statistics'), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open statistics'), findsOneWidget);
  });

  testWidgets('Review header exposes Japanese reference access',
      (tester) async {
    final repository = await _repository();
    await tester.pumpWidget(
      Provider<StudyRepository>.value(
        value: repository,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DecksView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review-reference-action')), findsOneWidget);
    expect(find.bySemanticsLabel('Japanese reference'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
