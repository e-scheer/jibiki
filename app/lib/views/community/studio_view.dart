import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

/// The Studio tab, the home of the mnemonic-drawing ecosystem: your active pack,
/// browsing & applying community packs, your own drawings, and creating packs.
class StudioView extends StatelessWidget {
  const StudioView({super.key});

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.trText('Studio')),
        actions: [
          IconButton(
            tooltip: context.trText('Settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                gradient: jc.instaLinear,
                borderRadius: BorderRadius.circular(Radii.lg)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.trText('Mnemonic packs'),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                  context.trText(
                      'Every character shows a drawing by default. Swap the whole pack, or draw your own; it then appears everywhere you study.'),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13.5, height: 1.35),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: jc.ink),
                        onPressed: () {
                          Haptics.light();
                          context.push('/decks/community');
                        },
                        child: Text(context.trText('Browse packs')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                        ),
                        onPressed: () {
                          Haptics.light();
                          context.push('/decks/new');
                        },
                        child: Text(context.trText('Create')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(context.trText('Your work'), style: context.text.titleMedium),
          const SizedBox(height: 10),
          _Tile(
            icon: Icons.brush_outlined,
            title: 'My drawings',
            subtitle: 'Everything you\'ve drawn, with review status.',
            onTap: () => context.push('/submissions'),
          ),
          _Tile(
            icon: Icons.collections_bookmark_outlined,
            title: 'My packs',
            subtitle: 'Drafts, in review and published.',
            onTap: () => context.push('/decks/community?tab=mine'),
          ),
          _Tile(
            icon: Icons.add_box_outlined,
            title: 'Create a pack',
            subtitle: 'Bundle your drawings and share them.',
            onTap: () => context.push('/decks/new'),
          ),
          const SizedBox(height: 22),
          Text(context.trText('How it works'), style: context.text.titleMedium),
          const SizedBox(height: 8),
          const _Step(
              n: '1',
              text: 'Open any kana or kanji and tap Draw to make a mnemonic.'),
          const _Step(
              n: '2',
              text:
                  'Your drawing becomes the active one for that character, everywhere.'),
          const _Step(
              n: '3',
              text:
                  'Bundle drawings into a pack and share it, or apply someone else\'s.'),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: jc.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: jc.hairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: jc.brandSoft,
                      borderRadius: BorderRadius.circular(Radii.sm)),
                  child: Icon(icon, color: jc.brand, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 1),
                      Text(subtitle,
                          style: TextStyle(color: jc.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: jc.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final String n;
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
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration:
                BoxDecoration(color: jc.brandSoft, shape: BoxShape.circle),
            child: Text(n,
                style: TextStyle(
                    color: jc.brandPressed,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style:
                      TextStyle(color: jc.body, fontSize: 13.5, height: 1.35))),
        ],
      ),
    );
  }
}
