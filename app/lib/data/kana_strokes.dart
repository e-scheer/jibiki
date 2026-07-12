import 'dart:convert';

import 'package:flutter/services.dart';

/// Offline KanjiVG stroke-order data for the 142 kana glyphs used by the
/// dictionary. Keeping this local makes the trace preview instant and usable
/// when the dictionary API is unavailable.
class KanaStrokeData {
  const KanaStrokeData({required this.paths, this.viewBox = '0 0 109 109'});

  final List<String> paths;
  final String viewBox;
}

class KanaStrokeCatalog {
  KanaStrokeCatalog._();

  static Map<String, KanaStrokeData>? _cache;

  static Future<KanaStrokeData?> load(String character) async {
    final cache = _cache ??= await _read();
    return cache[character];
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
