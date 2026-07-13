import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/views/reference/reference_data.dart';
import 'package:jibiki/views/reference/reference_view.dart';
import 'package:jibiki/views/widgets/tappable_japanese.dart';

const _body = '\u65e5\u672c\u8a9e\u3092\u8aad\u3080';
const _example = '\u672c\u3092\u8aad\u3080\u3002 Read a book.';

const _card = ReferenceCard(
  id: 'test',
  icon: '\u6587',
  title: ReferenceText('Reading', 'Lecture'),
  summary: ReferenceText('Quick reading help.', 'Aide rapide.'),
  sections: [
    ReferenceSection(
      title: ReferenceText('\u8aad\u307f\u65b9', '\u8aad\u307f\u65b9'),
      body: ReferenceText(_body, _body),
      examples: [ReferenceText(_example, _example)],
    ),
  ],
);

void main() {
  testWidgets(
    'reference detail linkifies its Japanese icon, explanation and example',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const ReferenceDetailView(card: _card),
        ),
      );

      final linked = tester
          .widgetList<TappableJapanese>(find.byType(TappableJapanese))
          .map((widget) => widget.text)
          .toSet();
      expect(linked, contains(_card.icon));
      expect(linked, contains(_card.sections.single.title.en));
      expect(linked, contains(_body));
      expect(linked, contains(_example));

      await tester.tap(find.text(_body));
      await tester.pumpAndSettle();
      expect(find.text('Tap a character to look it up'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
