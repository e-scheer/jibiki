import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../models/kana.dart';
import '../../theme/app_theme.dart';
import 'content_language_notice.dart';

/// Lexical occurrences are separate from the kana's grammatical usage.
class KanaWordExamplesSection extends StatelessWidget {
  const KanaWordExamplesSection({super.key, required this.kana});

  final KanaEntry kana;

  @override
  Widget build(BuildContext context) {
    if (kana.wordExamples.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            context
                .trText('Words containing {kana}')
                .replaceAll('{kana}', kana.char),
            style: context.text.titleMedium),
        const SizedBox(height: 4),
        Text(
            context
                .trText('JMdict reading match · editorial review not recorded'),
            style: TextStyle(color: context.jc.muted, fontSize: 11.5)),
        const SizedBox(height: 8),
        for (final example in kana.wordExamples.take(8))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: context.jc.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.md),
                side: BorderSide(color: context.jc.ink, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: ValueKey('kana-word-${example.wordId}-${example.reading}'),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title:
                    Text(example.reading, style: const TextStyle(fontSize: 20)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (example.glosses.isNotEmpty) ...[
                      ContentLanguageNotice(
                          language: example.glosses.first.language),
                      Text(
                          example.glosses
                              .take(3)
                              .map((g) => g.text)
                              .join(' · '),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 3),
                    Text(context.trText('Open dictionary entry'),
                        style:
                            TextStyle(color: context.jc.brand, fontSize: 11.5)),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/word/${example.wordId}'),
              ),
            ),
          ),
      ],
    );
  }
}
