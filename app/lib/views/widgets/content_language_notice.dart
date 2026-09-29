import 'package:flutter/material.dart';

import '../../core/languages.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Labels fallback prose without implying that it has been translated.
class ContentLanguageNotice extends StatelessWidget {
  const ContentLanguageNotice({super.key, required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    final selected = Localizations.localeOf(context).languageCode;
    if (language.isEmpty || language == selected) {
      return const SizedBox.shrink();
    }
    final name = switch (language) {
      'en' => context.trText('English'),
      'fr' => context.trText('French'),
      _ => mnemonicLanguageName(language),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        context
            .trText('Content in {language} · English translation unavailable')
            .replaceAll('{language}', name),
        style: TextStyle(color: context.jc.muted, fontSize: 11.5),
      ),
    );
  }
}
