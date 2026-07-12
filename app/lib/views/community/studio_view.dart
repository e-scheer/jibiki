import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../widgets/neo_pop.dart';

/// The Studio tab, the home of the mnemonic-drawing ecosystem: your active pack,
/// browsing & applying community packs, your own drawings, and creating packs.
class StudioView extends StatelessWidget {
  const StudioView({super.key});

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Scaffold(
      body: Column(
        children: [
          NeoPageHeader(
            title: context.trText('Studio'),
            subtitle: context.trText(
              'Draw characters, build packs and shape the community library.',
            ),
            tone: NeoTone.magenta,
            trailing: NeoIconButton(
              icon: Icons.settings_outlined,
              label: context.trText('Settings'),
              tone: NeoTone.paper,
              onTap: () => context.push('/settings'),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: NeoContent(
                maxWidth: 760,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NeoCard(
                      tone: NeoTone.blue,
                      shadow: 6,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: jc.acid,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: jc.ink, width: 2.5),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.auto_awesome, size: 25),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  context.trText('Mnemonic packs'),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.trText(
                              'Swap the whole visual memory system, or draw your own. The active art follows you everywhere you study.',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: NeoPrimaryButton(
                                  label: context.trText('Browse packs'),
                                  icon: Icons.explore_outlined,
                                  tone: NeoTone.acid,
                                  onTap: () => context.push('/decks/community'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: NeoPrimaryButton(
                                  label: context.trText('Create'),
                                  icon: Icons.add,
                                  tone: NeoTone.paper,
                                  onTap: () => context.push('/decks/new'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    NeoSectionTitle(context.trText('Your work')),
                    _Tile(
                      icon: Icons.brush_outlined,
                      tone: NeoTone.lime,
                      title: 'My drawings',
                      subtitle: 'Everything you\'ve drawn, with review status.',
                      onTap: () => context.push('/submissions'),
                    ),
                    _Tile(
                      icon: Icons.collections_bookmark_outlined,
                      tone: NeoTone.lavender,
                      title: 'My packs',
                      subtitle: 'Drafts, in review and published.',
                      onTap: () => context.push('/decks/community?tab=mine'),
                    ),
                    _Tile(
                      icon: Icons.add_box_outlined,
                      tone: NeoTone.acid,
                      title: 'Create a pack',
                      subtitle: 'Bundle your drawings and share them.',
                      onTap: () => context.push('/decks/new'),
                    ),
                    const SizedBox(height: 18),
                    NeoSectionTitle(context.trText('How it works')),
                    const NeoCard(
                      tone: NeoTone.paper,
                      shadow: 4,
                      padding: EdgeInsets.fromLTRB(14, 16, 14, 6),
                      child: Column(
                        children: [
                          _Step(
                            n: '1',
                            tone: NeoTone.magenta,
                            text:
                                'Open any kana or kanji and tap Draw to make a mnemonic.',
                          ),
                          _Step(
                            n: '2',
                            tone: NeoTone.lime,
                            text:
                                'Your drawing becomes active for that character everywhere.',
                          ),
                          _Step(
                            n: '3',
                            tone: NeoTone.acid,
                            text:
                                'Bundle drawings into a pack and share it, or apply someone else\'s.',
                          ),
                        ],
                      ),
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
}

class _Tile extends StatelessWidget {
  const _Tile(
      {required this.icon,
      required this.tone,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final NeoTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeoListRow(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tone.color(context),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: jc.ink, width: 2.5),
          ),
          child: Icon(icon, color: jc.ink, size: 22),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: jc.ink),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.tone, required this.text});
  final String n;
  final NeoTone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.color(context),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: jc.ink, width: 2.5),
            ),
            child: Text(n,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                    color: jc.body,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ))),
        ],
      ),
    );
  }
}
