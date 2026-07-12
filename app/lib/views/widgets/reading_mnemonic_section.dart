import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/languages.dart';
import '../../models/mnemonic.dart';
import '../../repositories/mnemonic_repository.dart';
import '../../theme/app_theme.dart';

/// Read-only section showing the seed READING mnemonics for a kanji: each one
/// anchors an on-yomi's sound to a keyword in the learner's language. Loads once
/// and hides itself entirely when there is nothing to show, so it never adds
/// empty chrome to the kanji page. Distinct from the community MnemonicPanel
/// (which is the meaning feed with likes / contributions).
class ReadingMnemonicSection extends StatefulWidget {
  const ReadingMnemonicSection({
    super.key,
    required this.character,
    required this.language,
  });

  final String character;
  final String language;

  @override
  State<ReadingMnemonicSection> createState() => _ReadingMnemonicSectionState();
}

class _ReadingMnemonicSectionState extends State<ReadingMnemonicSection> {
  List<Mnemonic> _items = const [];
  bool _englishFallback = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<MnemonicRepository>();
    final items = await _listOrEmpty(repo, widget.language);
    var result = items;
    var fallback = false;
    if (items.isEmpty && widget.language != fallbackLanguage) {
      final en = await _listOrEmpty(repo, fallbackLanguage);
      if (en.isNotEmpty) {
        result = en;
        fallback = true;
      }
    }
    if (!mounted) return;
    setState(() {
      _items = result;
      _englishFallback = fallback;
    });
  }

  Future<List<Mnemonic>> _listOrEmpty(
      MnemonicRepository repo, String language) async {
    try {
      return await repo.list(
        character: widget.character,
        language: language,
        kind: 'kanji_reading',
      );
    } catch (_) {
      return const []; // offline with no pack, or transient error: just hide
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                  context.trText(
                      'Reading mnemonic · ${mnemonicLanguageName(_items.first.language)}'),
                  style: context.text.titleMedium),
            ),
            if (_englishFallback)
              Text(mnemonicLanguageName(fallbackLanguage),
                  style: TextStyle(color: context.jc.muted, fontSize: 11.5)),
          ],
        ),
        const SizedBox(height: 8),
        for (final m in _items) _ReadingCard(mnemonic: m),
      ],
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.mnemonic});
  final Mnemonic mnemonic;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final m = mnemonic;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: jc.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: jc.ink, width: 2.5),
        boxShadow: [
          BoxShadow(color: jc.ink, blurRadius: 0, offset: const Offset(4, 4))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.reading.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: jc.brandSoft,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Text(
                m.reading,
                style: TextStyle(
                  color: jc.brand,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              m.story,
              style: TextStyle(
                color: jc.body,
                fontSize: 14.5,
                height: 1.4,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
