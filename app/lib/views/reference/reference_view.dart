import 'package:flutter/material.dart';
import 'package:jibiki/l10n/l10n.dart';

import '../../core/breakpoints.dart';
import '../../theme/app_theme.dart';
import '../widgets/neo_pop.dart';
import '../widgets/tappable_japanese.dart';
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
    final normalized = _query.trim().toLowerCase();
    final cards = japaneseReferenceCards.where((card) {
      final searchable = [
        card.title.en,
        card.title.fr,
        card.summary.en,
        card.summary.fr,
        for (final section in card.sections) ...[
          section.title.en,
          section.title.fr,
          section.body.en,
          section.body.fr,
        ],
      ].join(' ').toLowerCase();
      return searchable.contains(normalized);
    }).toList();
    return Scaffold(
      backgroundColor: context.jc.canvas,
      body: Column(
        children: [
          NeoPageHeader(
            title: context.trText('Japanese reference'),
            subtitle: context.trText(
              'Practical answers, built to get you back to reading quickly.',
            ),
            tone: NeoTone.blue,
            leading: NeoIconButton(
              icon: Icons.arrow_back_rounded,
              label: context.trText('Back'),
              onTap: () => Navigator.of(context).maybePop(),
            ),
            trailing: const NeoBadge('文法', tone: NeoTone.acid, rotate: 2),
            child: _ReferenceSearch(
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: BoundedContent(
              maxWidth: 980,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  context.isWide ? 28 : 18,
                  22,
                  context.isWide ? 28 : 18,
                  36,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: NeoSectionTitle(
                            context.trText('Reference cards'),
                          ),
                        ),
                        NeoBadge(
                          '${cards.length} ${context.trText('cards')}',
                          tone: NeoTone.lime,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (cards.isEmpty)
                      _EmptyReference(query: _query)
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 760 ? 2 : 1;
                          final width =
                              (constraints.maxWidth - (columns - 1) * 14) /
                                  columns;
                          return Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              for (var index = 0; index < cards.length; index++)
                                SizedBox(
                                  width: width,
                                  child: _ReferenceTile(
                                    card: cards[index],
                                    language: language,
                                    tone: _tones[index % _tones.length],
                                    onTap: () => Navigator.push<void>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ReferenceDetailView(
                                          card: cards[index],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _tones = [
    NeoTone.acid,
    NeoTone.lavender,
    NeoTone.lime,
    NeoTone.magenta,
  ];
}

class _ReferenceSearch extends StatelessWidget {
  const _ReferenceSearch({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 54,
        decoration: BoxDecoration(
          color: context.jc.surface,
          border: Border.all(color: context.jc.ink, width: 3),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: context.jc.ink,
              blurRadius: 0,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: TextField(
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: context.trText('Find a reference'),
            prefixIcon: const Icon(Icons.search_rounded),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
      );
}

class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({
    required this.card,
    required this.language,
    required this.tone,
    required this.onTap,
  });

  final ReferenceCard card;
  final String language;
  final NeoTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NeoCard(
        tone: tone,
        shadow: 5,
        padding: const EdgeInsets.all(16),
        onTap: onTap,
        semanticLabel: card.title.resolve(language),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.jc.surface,
                border: Border.all(color: context.jc.ink, width: 2.5),
                borderRadius: BorderRadius.circular(11),
              ),
              child: TappableJapanese(
                card.icon,
                affordance: false,
                style: const TextStyle(
                  fontFamily: 'ZenKakuGothicNew',
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title.resolve(language),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.summary.resolve(language),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.jc.body,
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: context.jc.surface,
                border: Border.all(color: context.jc.ink, width: 2.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_forward_rounded, size: 18),
            ),
          ],
        ),
      );
}

class _EmptyReference extends StatelessWidget {
  const _EmptyReference({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) => NeoCard(
        tone: NeoTone.lavender,
        shadow: 5,
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const Icon(Icons.search_off_rounded, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.trText('No reference found.'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '“$query”',
                    style: TextStyle(
                      color: context.jc.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class ReferenceDetailView extends StatelessWidget {
  const ReferenceDetailView({super.key, required this.card});
  final ReferenceCard card;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return Scaffold(
      backgroundColor: context.jc.canvas,
      body: Column(
        children: [
          NeoPageHeader(
            title: card.title.resolve(language),
            subtitle: card.summary.resolve(language),
            tone: NeoTone.lavender,
            leading: NeoIconButton(
              icon: Icons.arrow_back_rounded,
              label: context.trText('Back'),
              onTap: () => Navigator.of(context).pop(),
            ),
            trailing: NeoCard(
              tone: NeoTone.acid,
              shadow: 4,
              radius: 11,
              padding: const EdgeInsets.all(10),
              child: TappableJapanese(
                card.icon,
                affordance: false,
                style: const TextStyle(
                  fontFamily: 'ZenKakuGothicNew',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Expanded(
            child: BoundedContent(
              maxWidth: 860,
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  context.isWide ? 28 : 18,
                  24,
                  context.isWide ? 28 : 18,
                  38,
                ),
                itemCount: card.sections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 18),
                itemBuilder: (_, index) => _ReferenceSectionView(
                  section: card.sections[index],
                  language: language,
                  index: index + 1,
                  tone: index.isEven ? NeoTone.paper : NeoTone.lavender,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceSectionView extends StatelessWidget {
  const _ReferenceSectionView({
    required this.section,
    required this.language,
    required this.index,
    required this.tone,
  });

  final ReferenceSection section;
  final String language;
  final int index;
  final NeoTone tone;

  @override
  Widget build(BuildContext context) => NeoCard(
        tone: tone,
        shadow: 5,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NeoBadge(
                  index.toString().padLeft(2, '0'),
                  tone: index.isEven ? NeoTone.magenta : NeoTone.acid,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TappableJapanese(
                    section.title.resolve(language),
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TappableJapanese(
              section.body.resolve(language),
              style: TextStyle(
                color: context.jc.body,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (section.examples.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                context.trText('EXAMPLES'),
                style: const TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
            ],
            for (var index = 0; index < section.examples.length; index++)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(top: index == 0 ? 0 : 8),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: context.jc.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.jc.ink, width: 2.5),
                ),
                child: TappableJapanese(
                  section.examples[index].resolve(language),
                  style: TextStyle(
                    color: context.jc.ink,
                    fontFamily: 'ZenKakuGothicNew',
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      );
}
