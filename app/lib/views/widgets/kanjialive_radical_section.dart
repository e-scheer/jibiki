import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/kanji.dart';
import '../../theme/app_theme.dart';
import 'content_language_notice.dart';

/// Kanji alive's named radical is a separate source from KRAD decomposition.
class KanjiAliveRadicalSection extends StatelessWidget {
  const KanjiAliveRadicalSection({super.key, required this.kanji});
  final KanjiEntry kanji;

  @override
  Widget build(BuildContext context) {
    final source = kanji.metadata['kanjialive'];
    if (source is! Map || source['radical'] is! Map) {
      return const SizedBox.shrink();
    }
    final radical = source['radical'] as Map;
    final literal = radical['literal'] as String? ?? '';
    final reading = radical['reading'] as String? ?? '';
    final meaning = radical['meaning'] as String? ?? '';
    final position = radical['position'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.trText('Radical in Kanji alive'),
              style: context.text.titleMedium),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.jc.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: context.jc.ink, width: 2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (radical['glyph_available'] == true &&
                    literal.isNotEmpty) ...[
                  Text(literal, style: const TextStyle(fontSize: 40)),
                  const SizedBox(width: 14),
                ],
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reading,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (position.isNotEmpty)
                      Text(context
                          .trText('Position: {position}')
                          .replaceAll('{position}', position)),
                    const SizedBox(height: 4),
                    ContentLanguageNotice(
                        language: radical['meaning_language'] as String? ?? ''),
                    Text(meaning),
                    if (radical['glyph_available'] != true) ...[
                      const SizedBox(height: 6),
                      Text(
                          context.trText(
                              'This source uses a special glyph font; its name is shown here.'),
                          style: TextStyle(
                              color: context.jc.muted, fontSize: 11.5)),
                    ],
                    const SizedBox(height: 8),
                    Text(context.trText('Kanji alive · CC BY 4.0'),
                        style: const TextStyle(fontSize: 11.5)),
                  ],
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
