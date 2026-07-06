import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/models/kana.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/views/kana/kana_cell.dart';
import 'package:jibiki/views/widgets/study_mark.dart';

KanaEntry _k(String char, String romaji, {String script = 'hiragana'}) =>
    KanaEntry.fromJson({'char': char, 'romaji': romaji, 'script': script, 'kind': 'gojuon'});

Widget _host(Widget child) =>
    MaterialApp(theme: AppTheme.light(), home: Scaffold(body: Center(child: SizedBox(width: 66, child: child))));

void main() {
  testWidgets('shows the glyph and its romaji, and taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(KanaCell(
      entries: [_k('あ', 'a')],
      selected: false,
      mark: StudyMark.none,
      onTap: () => tapped = true,
    )));
    expect(find.text('あ'), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
    await tester.tap(find.text('あ'));
    expect(tapped, isTrue);
  });

  testWidgets('Both mode shows hiragana and katakana side by side', (tester) async {
    await tester.pumpWidget(_host(KanaCell(
      entries: [_k('あ', 'a'), _k('ア', 'a', script: 'katakana')],
      selected: true,
      mark: StudyMark.known,
      onTap: () {},
    )));
    expect(find.text('あ'), findsOneWidget);
    expect(find.text('ア'), findsOneWidget);
  });
}
