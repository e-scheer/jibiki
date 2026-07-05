import 'package:flutter/material.dart';

import '../../models/word.dart';
import '../../theme/app_theme.dart';
import 'status_views.dart';

class WordTile extends StatelessWidget {
  const WordTile({super.key, required this.word, required this.lang, this.onTap});
  final WordEntry word;
  final String lang;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final showReading = word.headword != word.primaryReading && word.primaryReading.isNotEmpty;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              word.headword,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showReading) ...[
            const SizedBox(width: 8),
            Text(word.primaryReading, style: TextStyle(fontSize: 14, color: jc.muted)),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(word.summaryGloss(lang), maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (word.isCommon) TagChip('common', color: jc.success),
          if (word.jlpt != null) ...[
            const SizedBox(height: 4),
            TagChip('N${word.jlpt}'),
          ],
        ],
      ),
    );
  }
}
