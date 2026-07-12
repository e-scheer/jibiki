import 'package:flutter/material.dart';
import 'package:jibiki/l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../models/mnemonic.dart';
import '../../repositories/mnemonic_deck_repository.dart';
import '../../repositories/mnemonic_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/mnemonic_deck_viewmodel.dart';
import '../auth/auth_required_sheet.dart';
import '../widgets/neo_pop.dart';
import '../widgets/net_image.dart';
import '../widgets/pressable.dart';
import '../widgets/status_views.dart';

/// Bundle drawings into a private draft or a shareable community pack.
class DeckBuilderView extends StatelessWidget {
  const DeckBuilderView({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.read<AppState>().mnemonicLanguage;
    return ChangeNotifierProvider(
      create: (ctx) => DeckBuilderViewModel(
        ctx.read<MnemonicDeckRepository>(),
        ctx.read<MnemonicRepository>(),
        language: lang,
      )..load(),
      child: const _Builder(),
    );
  }
}

class _Builder extends StatefulWidget {
  const _Builder();

  @override
  State<_Builder> createState() => _BuilderState();
}

class _BuilderState extends State<_Builder> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _publish = true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create(DeckBuilderViewModel vm) async {
    if (_title.text.trim().isEmpty || vm.selectedCount == 0) return;
    setState(() => _saving = true);
    final deck = await vm.create(
      title: _title.text.trim(),
      description: _description.text.trim(),
      publish: _publish,
    );
    if (!mounted) return;
    if (deck == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error ?? 'Could not create the pack')),
      );
      return;
    }
    final msg = !_publish
        ? 'Saved as a draft'
        : deck.status == 'visible'
            ? 'Published, thank you!'
            : 'Submitted for review, thank you!';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AppState>().isAuthenticated) {
      return Scaffold(
        body: Column(
          children: [
            NeoPageHeader(
              title: context.trText('New pack'),
              subtitle: context.trText('Build a community mnemonic pack.'),
              tone: NeoTone.magenta,
              leading: NeoIconButton(
                icon: Icons.arrow_back_rounded,
                label: context.trText('Back'),
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: AuthRequiredPanel(
                title: context.trText('Sign in to publish'),
                description: context.trText(
                  'Your drawings are ready to become a pack. Sign in to keep ownership and publish it safely.',
                ),
                icon: Icons.rocket_launch_outlined,
              ),
            ),
          ],
        ),
      );
    }
    final vm = context.watch<DeckBuilderViewModel>();
    final jc = context.jc;

    return Scaffold(
      body: Column(
        children: [
          NeoPageHeader(
            title: context.trText('New pack'),
            subtitle: context.trText(
              'Give your visual memory system a name, then choose its characters.',
            ),
            tone: NeoTone.magenta,
            leading: NeoIconButton(
              icon: Icons.arrow_back,
              label: context.trText('Back'),
              onTap: () => Navigator.of(context).pop(),
            ),
            trailing: NeoBadge(
              '${vm.selectedCount} selected',
              tone: NeoTone.acid,
              rotate: 2,
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                NeoContent(
                  maxWidth: 760,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const NeoBadge(
                        'PACK IDENTITY',
                        tone: NeoTone.lavender,
                        rotate: -2,
                      ),
                      const SizedBox(height: 14),
                      _NeoTextField(
                        controller: _title,
                        label: context.trText('Pack title'),
                        hint: context.trText('e.g. My hiragana mascots'),
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !_saving,
                      ),
                      const SizedBox(height: 14),
                      _NeoTextField(
                        controller: _description,
                        label: context.trText('Description (optional)'),
                        maxLines: 3,
                        enabled: !_saving,
                      ),
                      const SizedBox(height: 18),
                      NeoSegmentedControl<String>(
                        height: 56,
                        selected: vm.kind,
                        onChanged: vm.setKind,
                        enabled: !_saving,
                        segments: const [
                          NeoSegment('kana', 'Kana', icon: Icons.grid_view),
                          NeoSegment(
                            'kanji',
                            'Kanji',
                            icon: Icons.auto_stories_outlined,
                          ),
                        ],
                      ),
                      if (vm.kind == 'kana') ...[
                        const SizedBox(height: 10),
                        NeoSegmentedControl<String>(
                          height: 46,
                          selected: vm.kanaScriptFilter,
                          onChanged: vm.setKanaScriptFilter,
                          enabled: !_saving,
                          segments: const [
                            NeoSegment('both', 'Both'),
                            NeoSegment('hiragana', 'Hiragana'),
                            NeoSegment('katakana', 'Katakana'),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      _PublishToggle(
                        value: _publish,
                        enabled: !_saving,
                        onChanged: (value) => setState(() => _publish = value),
                      ),
                      const SizedBox(height: 24),
                      NeoSectionTitle(
                        context.trText(
                          'Your ${vm.kind == 'kanji' ? 'kanji' : 'kana'} drawings',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            NeoBadge(
                              '${vm.selectedCount}/${vm.available.length}',
                              tone: NeoTone.lime,
                            ),
                            const SizedBox(width: 8),
                            NeoCard(
                              tone: vm.allVisibleSelected
                                  ? NeoTone.lavender
                                  : NeoTone.paper,
                              shadow: 2,
                              radius: 8,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 7,
                              ),
                              onTap: !_saving && vm.available.isNotEmpty
                                  ? vm.toggleAllVisible
                                  : null,
                              semanticLabel: vm.allVisibleSelected
                                  ? context.trText('Clear selection')
                                  : context.trText('Select all'),
                              child: Text(
                                vm.allVisibleSelected
                                    ? context.trText('Clear')
                                    : context.trText('All'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (vm.isLoading && vm.available.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(28),
                          child: LoadingView(),
                        )
                      else if (vm.available.isEmpty)
                        const EmptyHint(
                          icon: Icons.brush_outlined,
                          title: 'No drawings yet',
                          subtitle:
                              'Draw some mascots from a kana or kanji, then bundle them here.',
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 150,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1,
                          ),
                          itemCount: vm.available.length,
                          itemBuilder: (context, index) {
                            final mnemonic = vm.available[index];
                            return _PickTile(
                              mnemonic: mnemonic,
                              selected: vm.isSelected(mnemonic.id),
                              enabled: !_saving,
                              onTap: () => vm.toggle(mnemonic.id),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: jc.surface,
              border: Border(top: BorderSide(color: jc.ink, width: 3)),
            ),
            child: SafeArea(
              top: false,
              child: Align(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: ListenableBuilder(
                      listenable: _title,
                      builder: (context, _) {
                        final canCreate = _title.text.trim().isNotEmpty &&
                            vm.selectedCount > 0 &&
                            !_saving;
                        return NeoPrimaryButton(
                          label: _publish
                              ? 'Publish pack (${vm.selectedCount})'
                              : 'Save draft (${vm.selectedCount})',
                          icon: _publish
                              ? Icons.rocket_launch_outlined
                              : Icons.save_outlined,
                          tone: _publish ? NeoTone.acid : NeoTone.lavender,
                          busy: _saving,
                          onTap: canCreate ? () => _create(vm) : null,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeoTextField extends StatelessWidget {
  const _NeoTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
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
            enabled: enabled,
            maxLines: maxLines,
            textCapitalization: textCapitalization,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _PublishToggle extends StatelessWidget {
  const _PublishToggle({
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return NeoCard(
      tone: value ? NeoTone.lime : NeoTone.paper,
      shadow: 4,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: enabled ? () => onChanged(!value) : null,
      semanticLabel: context.trText('Publish to the community'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.trText('Publish to the community'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  value
                      ? 'Others can discover and study it'
                      : 'Keep it private for now',
                  style: TextStyle(
                    color: jc.body,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _NeoSwitch(value: value),
        ],
      ),
    );
  }
}

class _NeoSwitch extends StatelessWidget {
  const _NeoSwitch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return AnimatedContainer(
      duration: Motion.timed(context, Motion.fast),
      width: 68,
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: value ? jc.lime : jc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: jc.ink, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: jc.ink,
            blurRadius: 0,
            offset: const Offset(3, 3),
          ),
        ],
      ),
      child: AnimatedAlign(
        duration: Motion.timed(context, Motion.fast),
        curve: Motion.out,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: jc.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: jc.ink, width: 2.5),
          ),
          alignment: Alignment.center,
          child: value
              ? const Icon(Icons.check, size: 17)
              : const Icon(Icons.close, size: 15),
        ),
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.mnemonic,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final Mnemonic mnemonic;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Opacity(
      opacity: enabled ? 1 : .52,
      child: Pressable(
        label: '${mnemonic.character} mnemonic',
        selected: selected,
        pressedScale: 1,
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: Motion.timed(context, Motion.fast),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: selected ? jc.acid : jc.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: jc.ink, width: 2.5),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: jc.ink,
                      blurRadius: 0,
                      offset: const Offset(3, 3),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              mnemonic.hasImage
                  ? NetImage(
                      url: mnemonic.imageUrl,
                      cacheWidth: 300,
                      errorBuilder: (_) => _glyph(jc),
                    )
                  : _glyph(jc),
              Positioned(
                left: 5,
                bottom: 5,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: selected ? jc.acid : jc.surface,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: jc.ink, width: 2),
                  ),
                  child: Text(
                    mnemonic.character,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: jc.lime,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: jc.ink, width: 2),
                    ),
                    child: const Icon(Icons.check, size: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glyph(JibikiColors jc) => Center(
        child: Text(
          mnemonic.character,
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: jc.ink,
          ),
        ),
      );
}
