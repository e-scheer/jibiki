import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/models/kana.dart';
import 'package:jibiki/models/mnemonic.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/views/widgets/mnemonic_quality_note.dart';
import 'package:jibiki/views/widgets/origin_section.dart';

Widget host(Widget child) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('en'), Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('kana English fallback is labelled per localized field',
      (tester) async {
    final kana = KanaEntry.fromJson({
      'char': 'は',
      'origin': '波',
      'origin_note': 'Origin note.',
      'origin_language': 'en',
      'usage': 'Description en français.',
      'usage_language': 'fr',
      'usage_examples': [
        {
          'before': '私',
          'particle': 'は',
          'after': '学生です。',
          'translation': 'I am a student.',
          'language': 'en'
        },
      ],
    });
    await tester.pumpWidget(host(Column(children: [
      KanaOriginSection(kana: kana),
      KanaGrammarSection(kana: kana),
    ])));
    expect(find.text('Contenu en anglais · traduction française indisponible'),
        findsNWidgets(2));
    expect(find.text('Description en français.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy published seed does not imply editorial verification',
      (tester) async {
    final mnemonic =
        Mnemonic.fromJson({'id': 1, 'is_seed': true, 'status': 'visible'});
    await tester.pumpWidget(host(MnemonicQualityNote(mnemonic: mnemonic)));
    expect(find.text('Relecture non documentée · origine non documentée'),
        findsOneWidget);
    expect(mnemonic.hasEditorialReview, isFalse);
  });

  testWidgets('voting retains provenance and its documented review label',
      (tester) async {
    final original = Mnemonic.fromJson({
      'id': 1,
      'is_seed': true,
      'provenance': {
        'review_status': 'verified',
        'generation_method': 'human',
        'review': {'reviewer': 'Editor', 'story_sha256': 'fixture'},
      }
    });
    final voted = original.copyWith(score: 1, myVote: 1);
    await tester.pumpWidget(host(MnemonicQualityNote(mnemonic: voted)));
    expect(voted.provenance, original.provenance);
    expect(find.text('Relecture éditoriale documentée'), findsOneWidget);
  });
}
