import 'dart:convert';

import 'package:flutter/services.dart';

/// Offline KanaVG stroke-order data for the 142 single kana glyphs used by the
/// dictionary. Yōon guides are composed from those primitives at runtime, so
/// all 208 reference entries stay instant and available offline.
class KanaStrokeData {
  const KanaStrokeData({required this.paths, this.viewBox = '0 0 109 109'});

  final List<String> paths;
  final String viewBox;
}

class KanaStrokeCatalog {
  KanaStrokeCatalog._();

  static Map<String, KanaStrokeData>? _cache;

  static const Map<String, String> _smallYoonSources = {
    'ゃ': 'や',
    'ゅ': 'ゆ',
    'ょ': 'よ',
    'ャ': 'ヤ',
    'ュ': 'ユ',
    'ョ': 'ヨ',
  };

  // The base keeps its original 109-unit KanaVG geometry. The second glyph is
  // the normal-size ya/yu/yo guide reduced and aligned to the lower right, as
  // small kana is written. A wider viewBox gives both glyphs a clear gutter.
  static const double _smallYoonScale = .54;
  static const double _smallYoonX = 112;
  static const double _smallYoonY = 48;
  static const String _yoonViewBox = '0 0 176 109';

  static Future<KanaStrokeData?> load(String character) async {
    final cache = _cache ??= await _read();
    final direct = cache[character];
    if (direct != null) return direct;

    final composed = _composeYoon(cache, character);
    if (composed != null) cache[character] = composed;
    return composed;
  }

  static KanaStrokeData? _composeYoon(
    Map<String, KanaStrokeData> cache,
    String character,
  ) {
    final characters = character.runes.map(String.fromCharCode).toList();
    if (characters.length != 2) return null;

    final baseCharacter = characters.first;
    final smallCharacter = characters.last;
    final smallSourceCharacter = _smallYoonSources[smallCharacter];
    if (smallSourceCharacter == null ||
        !_usesSameScript(baseCharacter, smallCharacter)) {
      return null;
    }

    final base = cache[baseCharacter];
    final smallSource = cache[smallSourceCharacter];
    if (base == null || smallSource == null) return null;

    return KanaStrokeData(
      paths: [
        ...base.paths,
        for (final path in smallSource.paths)
          _transformKanaVgPath(
            path,
            scale: _smallYoonScale,
            translateX: _smallYoonX,
            translateY: _smallYoonY,
          ),
      ],
      viewBox: _yoonViewBox,
    );
  }

  static bool _usesSameScript(String first, String second) {
    final firstCodePoint = first.runes.single;
    final secondCodePoint = second.runes.single;
    final bothHiragana = firstCodePoint >= 0x3040 &&
        firstCodePoint <= 0x309f &&
        secondCodePoint >= 0x3040 &&
        secondCodePoint <= 0x309f;
    final bothKatakana = firstCodePoint >= 0x30a0 &&
        firstCodePoint <= 0x30ff &&
        secondCodePoint >= 0x30a0 &&
        secondCodePoint <= 0x30ff;
    return bothHiragana || bothKatakana;
  }

  /// KanaVG's local asset uses one absolute `M` followed by relative `c`
  /// commands for every stroke. Scaling every numeric coordinate and applying
  /// translation only to that initial move preserves the curves exactly.
  static String _transformKanaVgPath(
    String path, {
    required double scale,
    required double translateX,
    required double translateY,
  }) {
    final numberPattern = RegExp(
      r'-?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?',
    );
    var coordinateIndex = 0;
    return path.replaceAllMapped(numberPattern, (match) {
      var transformed = double.parse(match.group(0)!) * scale;
      if (coordinateIndex == 0) transformed += translateX;
      if (coordinateIndex == 1) transformed += translateY;
      coordinateIndex++;
      return _formatSvgNumber(transformed);
    });
  }

  static String _formatSvgNumber(double value) {
    if (value.abs() < .0005) return '0';
    return value
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static Future<Map<String, KanaStrokeData>> _read() async {
    final raw = await rootBundle.loadString('assets/data/kana_strokes.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final entry in decoded.entries)
        entry.key: KanaStrokeData(
          paths: ((entry.value as Map)['paths'] as List?)
                  ?.whereType<String>()
                  .toList(growable: false) ??
              const [],
          viewBox: (entry.value as Map)['viewBox'] as String? ?? '0 0 109 109',
        ),
    };
  }
}
