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
import 'neo_pop.dart';
import 'net_image.dart';
import 'status_views.dart';

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
            SizedBox(
              height: 44,
              child: NeoCard(
                tone: NeoTone.acid,
                radius: 9,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                semanticLabel: context.trText('Add'),
                onTap: vm.isLoading ? null : () => _contribute(context, vm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 18),
                    const SizedBox(width: 5),
                    Text(
                      context.trText('Add'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (vm.englishFallback)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NeoCard(
              tone: NeoTone.lavender,
              shadow: 0,
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 390;
                  final copy = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                    ],
                  );
                  final draw = SizedBox(
                    height: 42,
                    child: NeoCard(
                      tone: NeoTone.acid,
                      shadow: 3,
                      radius: 8,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      semanticLabel: context.trText('Draw it'),
                      onTap: vm.isLoading ? null : () => _draw(context, vm),
                      child: Text(
                        context.trText('Draw it'),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  );
                  return narrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            copy,
                            const SizedBox(height: 9),
                            Align(
                              alignment: Alignment.centerRight,
                              child: draw,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: copy),
                            const SizedBox(width: 8),
                            draw,
                          ],
                        );
                },
              ),
            ),
          ),
        if (vm.isLoading && vm.items.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: LoadingView())
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
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: context.jc.ink.withValues(alpha: 0.52),
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

            Future<void> submit() async {
              final text = controller.text.trim();
              if (text.isEmpty || submitting) return;
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
            }

            return AnimatedPadding(
              duration: Motion.timed(sheetCtx, Motion.base),
              curve: Motion.out,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetCtx).height * 0.9,
                  ),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: jc.canvas,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(color: jc.ink, width: 3),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: jc.ink,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.trText(
                                  'Add a mnemonic for ${vm.character}',
                                ),
                                style: sheetCtx.text.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            NeoBadge(
                              vm.character,
                              tone: NeoTone.magenta,
                              rotate: 3,
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          context.trText(
                            'Concrete and vivid works best. It posts once approved.',
                          ),
                          style: TextStyle(
                            color: jc.body,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        NeoPrimaryButton(
                          label: context.trText('Draw a mascot'),
                          icon: Icons.brush_outlined,
                          tone: NeoTone.lime,
                          onTap: submitting
                              ? null
                              : () {
                                  Navigator.pop(sheetCtx);
                                  _draw(context, vm);
                                },
                        ),
                        const SizedBox(height: 18),
                        Text(
                          context.trText('OR WRITE A HINT'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: jc.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: jc.ink, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: jc.ink,
                                blurRadius: 0,
                                offset: const Offset(4, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: controller,
                            enabled: !submitting,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: context.trText(
                                'e.g. く is a bird\'s beak going "ku"...',
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: const EdgeInsets.all(14),
                            ),
                          ),
                        ),
                        if (imageBytes != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            height: 130,
                            width: double.infinity,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: jc.ink, width: 2.5),
                            ),
                            child: Image.memory(
                              imageBytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 44,
                          child: NeoCard(
                            tone: NeoTone.paper,
                            radius: 9,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            semanticLabel: imageBytes == null
                                ? 'Add a picture'
                                : 'Change picture',
                            onTap: submitting ? null : pick,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.image_outlined, size: 18),
                                const SizedBox(width: 7),
                                Text(
                                  imageBytes == null
                                      ? 'Add a picture (optional)'
                                      : 'Change picture',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        NeoPrimaryButton(
                          label: context.trText('Share'),
                          icon: Icons.send_outlined,
                          tone: NeoTone.acid,
                          busy: submitting,
                          onTap: submitting ? null : submit,
                        ),
                      ],
                    ),
                  ),
                ),
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
    return SizedBox(
      width: double.infinity,
      child: NeoCard(
        tone: NeoTone.lavender,
        shadow: 4,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: jc.acid,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: jc.ink, width: 2.5),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.brush_outlined, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
                context.trText(
                    'No mnemonics here yet in ${mnemonicLanguageName(language)}'),
                textAlign: TextAlign.center,
                style: TextStyle(color: jc.ink, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(context.trText('Be the first, draw a mascot for $character.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: jc.body,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 14),
            NeoPrimaryButton(
              label: context.trText('Draw one'),
              icon: Icons.brush_outlined,
              tone: NeoTone.acid,
              onTap: onDraw,
            ),
          ],
        ),
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
        border: Border.all(color: jc.ink, width: 2.5),
        boxShadow: [
          BoxShadow(color: jc.ink, blurRadius: 0, offset: const Offset(4, 4))
        ],
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
                        onTap: vm.isBusy(m.id)
                            ? null
                            : () {
                                Haptics.light();
                                vm.vote(m, 1);
                              },
                      ),
                      const Spacer(),
                      _IconAction(
                        icon: m.saved ? Icons.bookmark : Icons.bookmark_border,
                        color: jc.ink,
                        tooltip: context.trText('Save'),
                        onTap: vm.isBusy(m.id)
                            ? null
                            : () {
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
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: context.jc.ink.withValues(alpha: 0.52),
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
          decoration: BoxDecoration(
            color: ctx.jc.canvas,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: ctx.jc.ink, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ctx.jc.ink,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.trText('Report mnemonic'),
                style: ctx.text.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              for (final reason in reasons.entries) ...[
                NeoCard(
                  tone: NeoTone.paper,
                  shadow: 0,
                  radius: 10,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  semanticLabel: reason.value,
                  onTap: () => Navigator.pop(ctx, reason.key),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          reason.value,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
              ],
            ],
          ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: BoxDecoration(
        color: m.isSeed ? jc.acid : jc.lavender,
        border: Border(bottom: BorderSide(color: jc.ink, width: 2.5)),
      ),
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
                        fontWeight: FontWeight.w900, fontSize: 13.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                    context.trText(
                        '${m.character} · ${mnemonicLanguageName(m.language)}'),
                    style: TextStyle(
                      color: jc.body,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    )),
                if (m.status != 'visible')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: jc.acid,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: jc.ink, width: 1.8),
                      ),
                      child: Text(
                        context.trText('In review'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          NeoIconButton(
            icon: Icons.more_horiz,
            label: context.trText('Report'),
            tone: NeoTone.paper,
            onTap: onReport,
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
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: seed ? jc.brand : jc.magenta,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: jc.ink, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: jc.ink,
            blurRadius: 0,
            offset: const Offset(3, 3),
          ),
        ],
      ),
      child: Text(seed ? '字' : initial,
          style: TextStyle(
              color: seed ? jc.surface : jc.ink,
              fontWeight: FontWeight.w900,
              fontSize: 15)),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? .45 : 1,
      child: SizedBox.square(
        dimension: 44,
        child: NeoCard(
          tone: NeoTone.paper,
          radius: 9,
          shadow: 3,
          padding: EdgeInsets.zero,
          semanticLabel: tooltip,
          onTap: onTap,
          child: Icon(icon, color: color, size: 24),
        ),
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
      color: jc.lavender,
      alignment: Alignment.center,
      child: Text(char,
          style: TextStyle(
              fontSize: 96, fontWeight: FontWeight.w900, color: jc.ink)),
    );
  }
}
