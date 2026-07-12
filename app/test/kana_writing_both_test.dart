import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/data/kana_strokes.dart';
import 'package:jibiki/models/kana.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/views/kana/kana_detail_view.dart';
import 'package:jibiki/views/widgets/drawing_canvas.dart';
import 'package:jibiki/views/widgets/stroke_order_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  KanaEntry kana({
    required String char,
    required String script,
  }) =>
      KanaEntry(
        char: char,
        romaji: 'a',
        script: script,
        kind: 'gojuon',
        row: 'a',
        order: script == 'hiragana' ? 1 : 2,
      );

  Future<List<KanaWritingTarget>> targets() async {
    final hiraganaStroke = await KanaStrokeCatalog.load('あ');
    final katakanaStroke = await KanaStrokeCatalog.load('ア');
    expect(hiraganaStroke, isNotNull);
    expect(katakanaStroke, isNotNull);
    expect(hiraganaStroke!.paths, isNot(equals(katakanaStroke!.paths)));
    return [
      KanaWritingTarget(
        kana: kana(char: 'あ', script: 'hiragana'),
        stroke: hiraganaStroke,
      ),
      KanaWritingTarget(
        kana: kana(char: 'ア', script: 'katakana'),
        stroke: katakanaStroke,
      ),
    ];
  }

  testWidgets('Both practice keeps each script and canvas independent',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final pair = await targets();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: KanaWritingPracticePage(
          targets: pair,
          mode: KanaWritingMode.free,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    var canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
    final hiraganaController = canvas.controller;
    expect(canvas.guidePaths, pair.first.stroke!.paths);
    expect(canvas.showGuide, isFalse);
    expect(find.text('Next: Katakana ア'), findsOneWidget);

    await tester.drag(find.byType(DrawingCanvas), const Offset(32, 0));
    await tester.pump();
    expect(hiraganaController.isEmpty, isFalse);

    await tester.tap(find.text('2 · Katakana ア'));
    await tester.pump(const Duration(milliseconds: 250));
    canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
    final katakanaController = canvas.controller;
    expect(canvas.guidePaths, pair.last.stroke!.paths);
    expect(katakanaController, isNot(same(hiraganaController)));
    expect(katakanaController.isEmpty, isTrue);
    expect(find.text('Katakana'), findsWidgets);

    await tester.tap(find.text('Stroke order'));
    await tester.pump();
    canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
    expect(canvas.showGuide, isTrue);
    expect(canvas.showStrokeNumbers, isTrue);

    await tester.tap(find.text('1 · Hiragana あ'));
    await tester.pump(const Duration(milliseconds: 250));
    canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
    expect(canvas.controller, same(hiraganaController));
    expect(canvas.controller.isEmpty, isFalse);
    expect(canvas.showGuide, isFalse);

    await tester.tap(find.text('Next: Katakana ア'));
    await tester.pump(const Duration(milliseconds: 250));
    canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
    expect(canvas.controller, same(katakanaController));
    expect(canvas.showGuide, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Both reference renders the two real stroke diagrams',
      (tester) async {
    final pair = await targets();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 820,
            child: SingleChildScrollView(
              child: KanaWritingReference(targets: pair),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final diagrams = tester
        .widgetList<StrokeOrderView>(find.byType(StrokeOrderView))
        .toList(growable: false);
    expect(diagrams, hasLength(2));
    expect(diagrams[0].paths, pair[0].stroke!.paths);
    expect(diagrams[1].paths, pair[1].stroke!.paths);
    expect(find.text('Hiragana gesture · あ'), findsOneWidget);
    expect(find.text('Katakana gesture · ア'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Both practice has no overflow on tablet', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: KanaWritingPracticePage(
          targets: await targets(),
          mode: KanaWritingMode.guided,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Trace both forms'), findsOneWidget);
    expect(find.byType(DrawingCanvas), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short phone keeps a usable Both guided canvas', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: KanaWritingPracticePage(
          targets: await targets(),
          mode: KanaWritingMode.guided,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final canvasSize = tester.getSize(find.byType(DrawingCanvas));
    expect(canvasSize.shortestSide, greaterThanOrEqualTo(180));
    expect(tester.takeException(), isNull);
  });
}
