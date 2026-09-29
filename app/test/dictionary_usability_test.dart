import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/l10n/l10n.dart';
import 'package:jibiki/models/enums.dart';
import 'package:jibiki/models/word.dart';
import 'package:jibiki/repositories/auth_repository.dart';
import 'package:jibiki/repositories/dictionary_repository.dart';
import 'package:jibiki/repositories/study_repository.dart';
import 'package:jibiki/services/dictionary_data_source.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/viewmodels/app_state.dart';
import 'package:jibiki/viewmodels/dashboard_viewmodel.dart';
import 'package:jibiki/views/dictionary/search_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _App extends AppState {
  _App(this.mode, this.canStudy) : super(_Auth());
  @override
  final AppMode mode;
  @override
  final bool canStudy;
}

class _Study implements StudyRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Dictionary implements DictionaryDataSource {
  @override
  Future<List<WordEntry>> words(
          {bool common = false,
          int? jlpt,
          int limit = 60,
          int offset = 0}) async =>
      [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1440, 900)
  ]) {
    for (final guest in [false, true]) {
      testWidgets(
          'dictionary landing respects mode and guest capability at $size guest=$guest',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>(
                create: (_) =>
                    _App(guest ? AppMode.middle : AppMode.dictionary, !guest)),
            Provider(create: (_) => DictionaryRepository(_Dictionary())),
            ChangeNotifierProvider(create: (_) => DashboardViewModel(_Study())),
          ],
          child: MaterialApp(
              theme: AppTheme.light(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                  data:
                      MediaQuery.of(context).copyWith(disableAnimations: true),
                  child: child!),
              home: const SearchView()),
        ));
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('nothing due'), findsNothing);
        expect(find.text('Start learning'), findsNothing);
        expect(find.textContaining('Streak:'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
