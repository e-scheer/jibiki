import 'package:jibiki/l10n/l10n.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/languages.dart';
import '../../models/mnemonic.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/mnemonic_viewmodel.dart';
import '../learn/draw_mascot_view.dart';
import 'net_image.dart';

/// The community mnemonics section (DEEP_SEARCH feature 5/6), rendered as an
/// Instagram-style feed: each mnemonic is a post, author header, full-bleed
/// image, then a ❤ like / 🔖 save action row and a caption. Reads an ambient
/// [MnemonicViewModel] so it serves both kana and kanji.
class MnemonicPanel extends StatelessWidget {
  const MnemonicPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MnemonicViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                  context.trText(
                      'Mnemonics · ${mnemonicLanguageName(vm.language)}'),
                  style: context.text.titleMedium),
            ),
            TextButton.icon(
              onPressed: () => _contribute(context, vm),
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.trText('Add')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (vm.englishFallback)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              decoration: BoxDecoration(
                color: context.jc.surfaceAlt,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.translate, size: 18, color: context.jc.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.trText(
                          'Nothing in ${mnemonicLanguageName(vm.language)} for '
                          '${vm.character} yet - yours could be the first! '
                          'English shown meanwhile.'),
                      style: TextStyle(
                          fontSize: 12.5,
                          color: context.jc.muted,
                          height: 1.35),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _draw(context, vm),
                    child: Text(context.trText('Draw it')),
                  ),
                ],
              ),
            ),
          ),
        if (vm.isLoading && vm.items.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()))
        else if (vm.items.isEmpty)
          _EmptyFeed(
              character: vm.character,
              language: vm.language,
              onDraw: () => _draw(context, vm))
        else
          ...vm.items.map((m) => _MnemonicPost(mnemonic: m, vm: vm)),
      ],
    );
  }

  /// Push the drawing pad for this character; reload the feed if something saved.
  Future<void> _draw(BuildContext context, MnemonicViewModel vm) async {
    Haptics.light();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DrawMascotView(
            character: vm.character, language: vm.language, kind: vm.kind),
      ),
    );
    if (saved == true) vm.load();
  }

  Future<void> _contribute(BuildContext context, MnemonicViewModel vm) async {
    final controller = TextEditingController();
    Uint8List? imageBytes;
    String? imageName;
    bool submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final jc = sheetCtx.jc;
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            Future<void> pick() async {
              final picked = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1600,
                  imageQuality: 88);
              if (picked != null) {
                final bytes = await picked.readAsBytes();
                setSheet(() {
                  imageBytes = bytes;
                  imageName = picked.name;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.trText('Add a mnemonic for ${vm.character}'),
                      style: sheetCtx.text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                      context.trText(
                          'Concrete and vivid works best. It posts once approved.'),
                      style: TextStyle(color: jc.muted, fontSize: 13)),
                  const SizedBox(height: 14),
                  // Draw is the signature path, surface it first.
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      _draw(context, vm);
                    },
                    icon: const Icon(Icons.brush_outlined, size: 18),
                    label: Text(context.trText('Draw a mascot')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      foregroundColor: jc.brand,
                      side: BorderSide(color: jc.brand),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(context.trText('… or write a hint'),
                      style: TextStyle(
                          color: jc.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: InputDecoration(
                        hintText: context.trText(
                            'e.g. く is a bird\'s beak going "ku"…')),
                  ),
                  const SizedBox(height: 12),
                  if (imageBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      child: Image.memory(imageBytes!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: pick,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text(imageBytes == null
                          ? 'Add a picture (optional)'
                          : 'Change picture'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;
                            setSheet(() => submitting = true);
                            final created = await vm.contribute(
                              text,
                              imageBytes: imageBytes,
                              imageFilename: imageName,
                            );
                            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                            if (context.mounted) {
                              final msg = created == null
                                  ? (vm.error ?? 'Could not submit')
                                  : created.status == 'visible'
                                      ? 'Published, thank you!'
                                      : 'Submitted for review, thank you!';
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(msg)));
                            }
                          },
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    child: submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(context.trText('Share')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed(
      {required this.character, required this.language, required this.onDraw});
  final String character;
  final String language;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: jc.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        children: [
          Icon(Icons.brush_outlined, color: jc.muted, size: 30),
          const SizedBox(height: 10),
          Text(
              context.trText(
                  'No mnemonics here yet in ${mnemonicLanguageName(language)}'),
              textAlign: TextAlign.center,
              style: TextStyle(color: jc.body, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(context.trText('Be the first, draw a mascot for $character.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: jc.muted, fontSize: 13)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onDraw,
            icon: const Icon(Icons.brush_outlined, size: 18),
            label: Text(context.trText('Draw one')),
          ),
        ],
      ),
    );
  }
}

/// One mnemonic rendered as an Instagram post.
class _MnemonicPost extends StatelessWidget {
  const _MnemonicPost({required this.mnemonic, required this.vm});
  final Mnemonic mnemonic;
  final MnemonicViewModel vm;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final m = mnemonic;
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: jc.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: jc.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(mnemonic: m, onReport: () => _report(context)),
          if (m.hasImage)
            AspectRatio(
              aspectRatio: 1,
              child: NetImage(
                url: m.imageUrl,
                bytes: m.imageBytes,
                cacheWidth: 900,
                semanticLabel: 'Mnemonic drawing for ${m.character}',
                errorBuilder: (_) => _GlyphFallback(char: m.character),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Like/save only exist for published mnemonics - the server
                // rejects votes/saves on an "in review" one, so showing the
                // controls there just made them flip back on tap.
                if (m.isVisible) ...[
                  Row(
                    children: [
                      _IconAction(
                        icon: m.liked ? Icons.favorite : Icons.favorite_border,
                        color: m.liked ? jc.ratingAgain : jc.ink,
                        tooltip: context.trText('Like'),
                        onTap: () {
                          Haptics.light();
                          vm.vote(m, 1);
                        },
                      ),
                      const Spacer(),
                      _IconAction(
                        icon: m.saved ? Icons.bookmark : Icons.bookmark_border,
                        color: jc.ink,
                        tooltip: context.trText('Save'),
                        onTap: () {
                          Haptics.tick();
                          vm.toggleSave(m);
                        },
                      ),
                    ],
                  ),
                  if (m.score > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 2),
                      child: Text(
                          '${m.score} ${m.score == 1 ? 'like' : 'likes'}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13.5)),
                    ),
                ] else
                  const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                          color: jc.body,
                          fontSize: 14.5,
                          height: 1.4,
                          fontFamily: AppTheme.fontFamily),
                      children: [
                        TextSpan(
                            text: '${m.authorName}  ',
                            style: TextStyle(
                                color: jc.ink, fontWeight: FontWeight.w700)),
                        TextSpan(text: m.story),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _report(BuildContext context) async {
    const reasons = {
      'offensive': 'Offensive or explicit',
      'inaccurate': 'Inaccurate or misleading',
      'spam': 'Spam or advertising',
      'off_topic': 'Off-topic',
      'other': 'Something else',
    };
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.entries
              .map((e) => ListTile(
                  title: Text(e.value), onTap: () => Navigator.pop(ctx, e.key)))
              .toList(),
        ),
      ),
    );
    if (choice != null) {
      await vm.report(mnemonic, choice);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.trText('Reported, thank you'))));
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.mnemonic, required this.onReport});
  final Mnemonic mnemonic;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final m = mnemonic;
    final initial = m.authorName.isNotEmpty
        ? m.authorName.substring(0, 1).toUpperCase()
        : '?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
      child: Row(
        children: [
          _Avatar(initial: initial, seed: m.isSeed),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.authorName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                    context.trText(
                        '${m.character} · ${mnemonicLanguageName(m.language)}'),
                    style: TextStyle(color: jc.muted, fontSize: 11.5)),
              ],
            ),
          ),
          if (m.status != 'visible')
            Container(
              margin: const EdgeInsets.only(right: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: jc.warn.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Text(context.trText('In review'),
                  style: TextStyle(
                      color: jc.warn,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: jc.ink),
            onSelected: (_) => onReport(),
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'report', child: Text(context.trText('Report'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.seed});
  final String initial;
  final bool seed;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final inner = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: seed ? jc.brandSoft : jc.surface,
        shape: BoxShape.circle,
      ),
      child: Text(seed ? '字' : initial,
          style: TextStyle(
              color: seed ? jc.brand : jc.ink,
              fontWeight: FontWeight.w800,
              fontSize: 14)),
    );
    // Community authors get the Instagram story-style gradient ring; the seed
    // "jibiki" account gets a plain hairline ring.
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: seed ? null : jc.instaLinear,
        border: seed ? Border.all(color: jc.hairline) : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: jc.surface, shape: BoxShape.circle),
        child: inner,
      ),
    );
  }
}

class _IconAction extends StatefulWidget {
  const _IconAction(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<_IconAction> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: () {
        // Pop the icon so the tap feels alive; the colour/fill has already flipped
        // optimistically in the view model.
        if (Motion.enabled(context)) {
          setState(() => _down = true);
          Future.delayed(Motion.fast, () {
            if (mounted) setState(() => _down = false);
          });
        }
        widget.onTap();
      },
      icon: AnimatedScale(
        scale: _down ? 0.78 : 1.0,
        duration: Motion.timed(context, Motion.fast),
        curve: Motion.outStrong,
        child: Icon(widget.icon, color: widget.color, size: 26),
      ),
    );
  }
}

class _GlyphFallback extends StatelessWidget {
  const _GlyphFallback({required this.char});
  final String char;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Container(
      color: jc.brandSoft,
      alignment: Alignment.center,
      child: Text(char,
          style: TextStyle(
              fontSize: 96, fontWeight: FontWeight.w700, color: jc.brand)),
    );
  }
}
