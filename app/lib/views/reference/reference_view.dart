import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../core/breakpoints.dart';
import '../../theme/app_theme.dart';
import 'reference_data.dart';

class ReferenceView extends StatefulWidget {
  const ReferenceView({super.key});

  @override
  State<ReferenceView> createState() => _ReferenceViewState();
}

class _ReferenceViewState extends State<ReferenceView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final cards = japaneseReferenceCards
        .where((card) => '${card.title.en} ${card.title.fr} ${card.summary.en}'
            .toLowerCase()
            .contains(_query.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.trText('Japanese reference'))),
      body: BoundedContent(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(context.trText('Reference cards'),
                style: context.text.headlineSmall),
            const SizedBox(height: 6),
            Text(
              context.trText(
                  'Short, practical notes for grammar and reading. Open a card when you need a reminder, then return to your study.'),
              style: TextStyle(color: context.jc.muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: context.trText('Find a reference'),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 16),
            for (final card in cards)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReferenceTile(
                  card: card,
                  language: language,
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ReferenceDetailView(card: card)),
                  ),
                ),
              ),
            if (cards.isEmpty)
              Center(child: Text(context.trText('No reference found.'))),
          ],
        ),
      ),
    );
  }
}

class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile(
      {required this.card, required this.language, required this.onTap});
  final ReferenceCard card;
  final String language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: jc.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: jc.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: jc.brandSoft,
                  borderRadius: BorderRadius.circular(Radii.md)),
              child: Text(card.icon,
                  style: TextStyle(
                      color: jc.brand,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.title.resolve(language),
                      style: context.text.titleMedium),
                  const SizedBox(height: 3),
                  Text(card.summary.resolve(language),
                      style: TextStyle(color: jc.muted, height: 1.3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: jc.muted),
          ],
        ),
      ),
    );
  }
}

class ReferenceDetailView extends StatelessWidget {
  const ReferenceDetailView({super.key, required this.card});
  final ReferenceCard card;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(card.title.resolve(language))),
      body: BoundedContent(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(card.summary.resolve(language),
                style: TextStyle(color: context.jc.muted, height: 1.4)),
            const SizedBox(height: 20),
            for (final section in card.sections)
              Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child:
                    _ReferenceSectionView(section: section, language: language),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceSectionView extends StatelessWidget {
  const _ReferenceSectionView({required this.section, required this.language});
  final ReferenceSection section;
  final String language;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.title.resolve(language), style: context.text.titleMedium),
        const SizedBox(height: 7),
        Text(section.body.resolve(language),
            style: const TextStyle(height: 1.45)),
        for (final example in section.examples)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 9),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: jc.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Text(example.resolve(language),
                style: TextStyle(
                    color: jc.body, fontFamily: 'NotoSansJP', height: 1.4)),
          ),
      ],
    );
  }
}
