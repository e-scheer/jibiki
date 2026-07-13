import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/telemetry.dart';
import 'package:jibiki/data/kana_strokes.dart';
import 'package:jibiki/l10n/app_localizations.dart';
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
    await tester.pumpAndSettle();
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

  testWidgets('Stroke order animates over free practice before settling',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final target = (await targets()).first;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: KanaWritingPracticePage(
          targets: [target],
          mode: KanaWritingMode.free,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(StrokeOrderView), findsNothing);
    await tester.tap(find.text('Stroke order'));
    await tester.pump();

    expect(find.byType(StrokeOrderView), findsOneWidget);
    var canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
    expect(canvas.showGuide, isFalse);
    expect(canvas.showStrokeNumbers, isFalse);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(StrokeOrderView), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(StrokeOrderView), findsNothing);
    canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
    expect(canvas.showGuide, isTrue);
    expect(canvas.showStrokeNumbers, isTrue);

    await tester.tap(find.text('Stroke order'));
    await tester.pump();
    expect(find.byType(StrokeOrderView), findsOneWidget);
    canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
    expect(canvas.showGuide, isFalse);
    expect(canvas.showStrokeNumbers, isFalse);

    await tester.pumpAndSettle();
    expect(find.byType(StrokeOrderView), findsNothing);
    canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
    expect(canvas.showGuide, isTrue);
    expect(canvas.showStrokeNumbers, isTrue);
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

  for (final width in <double>[550, 390, 360]) {
    testWidgets(
        'Both reference uses aligned script columns at ${width.toInt()}',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final pair = (await targets()).reversed.toList(growable: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: KanaWritingReference(targets: pair),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final hiragana = tester.getRect(
        find.byKey(const ValueKey('kana-writing-column-hiragana')),
      );
      final katakana = tester.getRect(
        find.byKey(const ValueKey('kana-writing-column-katakana')),
      );
      expect(hiragana.top, closeTo(katakana.top, .1));
      expect(hiragana.width, closeTo(katakana.width, .1));
      expect(hiragana.right, lessThan(katakana.left));

      final hiraganaDiagram = tester.getRect(
        find.byKey(const ValueKey('kana-writing-diagram-hiragana')),
      );
      final katakanaDiagram = tester.getRect(
        find.byKey(const ValueKey('kana-writing-diagram-katakana')),
      );
      expect(hiraganaDiagram.top, closeTo(katakanaDiagram.top, .1));
      expect(hiraganaDiagram.width, closeTo(hiraganaDiagram.height, .1));
      expect(hiraganaDiagram.size, equals(katakanaDiagram.size));
      expect(hiraganaDiagram.width, greaterThanOrEqualTo(140));

      final hiraganaGuided = tester.getRect(
        find.byKey(const ValueKey('kana-writing-guided-hiragana')),
      );
      final katakanaGuided = tester.getRect(
        find.byKey(const ValueKey('kana-writing-guided-katakana')),
      );
      final hiraganaFree = tester.getRect(
        find.byKey(const ValueKey('kana-writing-free-hiragana')),
      );
      final katakanaFree = tester.getRect(
        find.byKey(const ValueKey('kana-writing-free-katakana')),
      );
      expect(hiraganaGuided.top, closeTo(katakanaGuided.top, .1));
      expect(hiraganaFree.top, closeTo(katakanaFree.top, .1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Both columns stay overflow-free in French with larger text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: KanaWritingReference(targets: await targets()),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Tracé guidé'), findsNWidgets(2));
    expect(find.text('Pratique libre'), findsNWidgets(2));
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

  testWidgets('practice records start and completion without kana content',
      (tester) async {
    final recorder = _RecordingTelemetry();
    final target = (await targets()).first;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: KanaWritingPracticePage(
          targets: [target],
          mode: KanaWritingMode.free,
          telemetry: recorder,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(
      recorder.events.map((event) => event.name),
      [
        TelemetryEvent.writingPracticeStarted,
        TelemetryEvent.writingPracticeCompleted,
      ],
    );
    for (final event in recorder.events) {
      expect(event.parameters, isNot(contains('character')));
      expect(event.parameters, isNot(contains('ref')));
      expect(event.parameters, isNot(contains('text')));
    }
  });
}

class _RecordingTelemetry implements TelemetrySink {
  final events = <({String name, Map<String, Object?> parameters})>[];

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async {
    events.add((name: name, parameters: Map.of(parameters)));
  }
}
