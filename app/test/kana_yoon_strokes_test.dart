import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/data/kana_strokes.dart';
import 'package:path_drawing/path_drawing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('composes hiragana yoon from base then reduced small-kana strokes',
      () async {
    final composed = await KanaStrokeCatalog.load('きゃ');
    final base = await KanaStrokeCatalog.load('き');
    final smallSource = await KanaStrokeCatalog.load('や');

    expect(composed, isNotNull);
    expect(base, isNotNull);
    expect(smallSource, isNotNull);
    expect(
      composed!.paths,
      hasLength(base!.paths.length + smallSource!.paths.length),
    );
    expect(composed.paths.take(base.paths.length), orderedEquals(base.paths));

    final baseBounds = _bounds(composed.paths.take(base.paths.length));
    final smallBounds = _bounds(composed.paths.skip(base.paths.length));
    expect(smallBounds.left, greaterThan(baseBounds.right));
    expect(smallBounds.height, lessThan(baseBounds.height));
    expect(smallBounds.bottom, closeTo(baseBounds.bottom, 12));
  });

  test('composes katakana independently and keeps script-specific paths',
      () async {
    final hiragana = await KanaStrokeCatalog.load('きゃ');
    final katakana = await KanaStrokeCatalog.load('キャ');
    final katakanaBase = await KanaStrokeCatalog.load('キ');

    expect(katakana, isNotNull);
    expect(katakanaBase, isNotNull);
    expect(
      katakana!.paths.take(katakanaBase!.paths.length),
      orderedEquals(katakanaBase.paths),
    );
    expect(katakana.paths, isNot(orderedEquals(hiragana!.paths)));
  });

  test('composed yoon exposes a valid wider viewBox containing every path',
      () async {
    final composed = await KanaStrokeCatalog.load('きゃ');
    final values = composed!.viewBox
        .split(RegExp(r'\s+'))
        .map(double.parse)
        .toList(growable: false);

    expect(values, hasLength(4));
    expect(values[0], 0);
    expect(values[1], 0);
    expect(values[2], greaterThan(109));
    expect(values[3], 109);

    final bounds = _bounds(composed.paths);
    expect(bounds.left, greaterThanOrEqualTo(values[0]));
    expect(bounds.top, greaterThanOrEqualTo(values[1]));
    expect(bounds.right, lessThanOrEqualTo(values[0] + values[2]));
    expect(bounds.bottom, lessThanOrEqualTo(values[1] + values[3]));
  });

  test('single-character stroke data remains unchanged', () async {
    final before = await KanaStrokeCatalog.load('き');
    await KanaStrokeCatalog.load('きゃ');
    final after = await KanaStrokeCatalog.load('き');

    expect(identical(after, before), isTrue);
    expect(after!.viewBox, '0 0 109 109');
    expect(after.paths, isNotEmpty);
  });
}

Rect _bounds(Iterable<String> paths) {
  final iterator = paths.iterator;
  expect(iterator.moveNext(), isTrue);
  var bounds = parseSvgPathData(iterator.current).getBounds();
  while (iterator.moveNext()) {
    bounds =
        bounds.expandToInclude(parseSvgPathData(iterator.current).getBounds());
  }
  return bounds;
}
