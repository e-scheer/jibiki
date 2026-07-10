import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/models/mnemonic.dart';
import 'package:jibiki/repositories/mnemonic_repository.dart';
import 'package:jibiki/services/mnemonic_service.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/views/widgets/reading_mnemonic_section.dart';

/// Overrides only [list]; the service/api are constructed but never hit.
class _FakeRepo extends MnemonicRepository {
  _FakeRepo(this._byLang, MnemonicService svc) : super(svc);
  final Map<String, List<Mnemonic>> _byLang;

  @override
  Future<List<Mnemonic>> list({
    required String character,
    required String language,
    String kind = 'kana',
  }) async =>
      _byLang[language] ?? const [];
}

Mnemonic _reading({required String lang, String reading = 'サン', String story = ''}) => Mnemonic(
      id: 1,
      character: '山',
      kind: 'kanji_reading',
      language: lang,
      reading: reading,
      story: story,
      imageSrc: '',
      imageWidth: 0,
      imageHeight: 0,
      authorName: 'jibiki',
      isSeed: true,
      status: 'visible',
      score: 0,
      myVote: 0,
      saved: false,
    );

Future<MnemonicService> _service() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return MnemonicService(ApiClient(SessionStore(prefs)));
}

Future<void> _pump(WidgetTester tester, MnemonicRepository repo, {String lang = 'en'}) async {
  await tester.pumpWidget(
    Provider<MnemonicRepository>.value(
      value: repo,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReadingMnemonicSection(character: '山', language: lang),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ReadingMnemonicSection', () {
    testWidgets('renders the reading badge and the story', (tester) async {
      final svc = await _service();
      final repo = _FakeRepo({
        'en': [_reading(lang: 'en', story: 'The sun (サン) behind the mountain.')],
      }, svc);
      await _pump(tester, repo, lang: 'en');

      expect(find.textContaining('Reading mnemonic'), findsOneWidget);
      expect(find.text('サン'), findsOneWidget); // the katakana badge
      expect(find.textContaining('behind the mountain'), findsOneWidget);
    });

    testWidgets('collapses to nothing when there is no reading mnemonic', (tester) async {
      final svc = await _service();
      await _pump(tester, _FakeRepo({}, svc), lang: 'en');
      expect(find.textContaining('Reading mnemonic'), findsNothing);
    });

    testWidgets('falls back to English when the user language is empty', (tester) async {
      final svc = await _service();
      final repo = _FakeRepo({
        'en': [_reading(lang: 'en', story: 'The sun (サン) behind the mountain.')],
      }, svc);
      await _pump(tester, repo, lang: 'fr');
      expect(find.textContaining('behind the mountain'), findsOneWidget);
    });
  });
}
