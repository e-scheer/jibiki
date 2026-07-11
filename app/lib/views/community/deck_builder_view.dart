import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/mnemonic.dart';
import '../../repositories/mnemonic_deck_repository.dart';
import '../../repositories/mnemonic_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/mnemonic_deck_viewmodel.dart';
import '../widgets/net_image.dart';
import '../widgets/pressable.dart';
import '../widgets/status_views.dart';

/// Bundle your own drawings into a shareable pack, then save it as a draft or
/// publish it to the community.
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
          SnackBar(content: Text(vm.error ?? 'Could not create the pack')));
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
    final vm = context.watch<DeckBuilderViewModel>();
    final jc = context.jc;

    return Scaffold(
      appBar: AppBar(title: Text(context.trText('New pack'))),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
            color: jc.canvas,
            border: Border(top: BorderSide(color: jc.hairline))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SizedBox(
              height: 48,
              width: double.infinity,
              // Listen to the title field here so typing enables the button
              // without a setState that rebuilds the whole drawing grid.
              child: ListenableBuilder(
                listenable: _title,
                builder: (context, _) {
                  final canCreate = _title.text.trim().isNotEmpty &&
                      vm.selectedCount > 0 &&
                      !_saving;
                  return FilledButton(
                    onPressed: canCreate ? () => _create(vm) : null,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(_publish
                            ? 'Publish pack (${vm.selectedCount})'
                            : 'Save draft (${vm.selectedCount})'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
                labelText: context.trText('Pack title'),
                hintText: context.trText('e.g. My hiragana mascots')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 2,
            decoration: InputDecoration(
                labelText: context.trText('Description (optional)')),
          ),
          const SizedBox(height: 16),
          _KindToggle(kind: vm.kind, onChanged: vm.setKind),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _publish,
            onChanged: (v) => setState(() => _publish = v),
            contentPadding: EdgeInsets.zero,
            title: Text(context.trText('Publish to the community')),
            subtitle: Text(
                _publish
                    ? 'Others can discover and study it'
                    : 'Keep it private for now',
                style: TextStyle(color: jc.muted, fontSize: 12.5)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                  context.trText(
                      'Your ${vm.kind == 'kanji' ? 'kanji' : 'kana'} drawings'),
                  style: context.text.titleMedium),
              const Spacer(),
              Text(context.trText('${vm.selectedCount} selected'),
                  style: TextStyle(color: jc.muted, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 12),
          if (vm.isLoading && vm.available.isEmpty)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()))
          else if (vm.available.isEmpty)
            const EmptyHint(
              icon: Icons.brush_outlined,
              title: 'No drawings yet',
              subtitle:
                  'Draw some mascots first (from a kana or kanji), then bundle them here.',
            )
          else
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (final m in vm.available)
                  _PickTile(
                      mnemonic: m,
                      selected: vm.isSelected(m.id),
                      onTap: () => vm.toggle(m.id)),
              ],
            ),
        ],
      ),
    );
  }
}

class _KindToggle extends StatelessWidget {
  const _KindToggle({required this.kind, required this.onChanged});
  final String kind;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    Widget seg(String value, String label) {
      final on = kind == value;
      return Expanded(
        child: Pressable(
          label: label,
          selected: on,
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: Motion.timed(context, Motion.fast),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: on ? jc.brand : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Text(label,
                style: TextStyle(
                    color: on ? Colors.white : jc.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: jc.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(children: [seg('kana', 'Kana'), seg('kanji', 'Kanji')]),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile(
      {required this.mnemonic, required this.selected, required this.onTap});
  final Mnemonic mnemonic;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Pressable(
      label: '${mnemonic.character} mnemonic',
      selected: selected,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: jc.surfaceAlt,
              child: mnemonic.hasImage
                  ? NetImage(
                      url: mnemonic.imageUrl,
                      cacheWidth: 300,
                      errorBuilder: (_) => _glyph(jc))
                  : _glyph(jc),
            ),
            if (selected)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: jc.brand, width: 3),
                  borderRadius: BorderRadius.circular(Radii.sm),
                  color: jc.brand.withValues(alpha: 0.12),
                ),
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.check_circle, color: jc.brand, size: 22),
                ),
              ),
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: jc.ink.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(mnemonic.character,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glyph(JibikiColors jc) => Center(
        child: Text(mnemonic.character,
            style: TextStyle(
                fontSize: 30, fontWeight: FontWeight.w700, color: jc.brand)),
      );
}
