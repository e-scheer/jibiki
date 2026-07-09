import 'package:flutter/material.dart';

import '../../core/languages.dart';
import '../../theme/app_theme.dart';

/// Bottom-sheet picker for the mnemonic language. Open by design - every real
/// ISO 639-1 language is selectable, so the community can start a language
/// before we curate it (English stays the display backup) - but ONLY real
/// languages: the list is the ISO catalog, never free text.
Future<String?> showMnemonicLanguagePicker(BuildContext context, String current) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _LanguageSheet(current: current),
  );
}

class _LanguageSheet extends StatefulWidget {
  const _LanguageSheet({required this.current});

  final String current;

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final query = _query.trim().toLowerCase();
    final all = allMnemonicLanguages;
    final featured = featuredMnemonicLanguages;
    final filtered = query.isEmpty
        ? null
        : [
            for (final l in all)
              if (l.nativeName.toLowerCase().contains(query) ||
                  l.code.contains(query))
                l,
          ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (ctx, controller) => ListView(
        controller: controller,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mnemonic language', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Mnemonics ride on sound, so they belong to a language. '
                  'No content in yours yet? Draw the first - or ask for a '
                  'curated set via Settings → Make jibiki better.',
                  style: TextStyle(color: jc.muted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search languages…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Radii.md)),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ],
            ),
          ),
          if (filtered == null) ...[
            _header(ctx, 'Featured'),
            for (final l in featured) _tile(ctx, l),
            _header(ctx, 'All languages'),
            for (final l in all)
              if (!featured.any((f) => f.code == l.code)) _tile(ctx, l),
          ] else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No language matches "$_query".',
                  style: TextStyle(color: jc.muted)),
            )
          else
            for (final l in filtered) _tile(ctx, l),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: context.jc.muted)),
      );

  Widget _tile(BuildContext context, MnemonicLanguage lang) {
    final jc = context.jc;
    return ListTile(
      dense: true,
      title: Text(lang.nativeName),
      subtitle: lang.seeded
          ? null
          : Text('No content yet - be the first!',
              style: TextStyle(fontSize: 11, color: jc.muted)),
      trailing: lang.code == widget.current
          ? Icon(Icons.check, color: jc.brand)
          : Text(lang.code, style: TextStyle(color: jc.muted, fontSize: 12)),
      onTap: () => Navigator.pop(context, lang.code),
    );
  }
}
