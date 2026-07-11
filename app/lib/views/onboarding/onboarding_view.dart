import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/languages.dart';
import '../../infrastructure/packs/pack_manager.dart';
import '../../models/enums.dart';
import '../widgets/language_picker.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/onboarding_viewmodel.dart';
import '../../viewmodels/storage_viewmodel.dart' show StorageViewModel;

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          OnboardingViewModel(ctx.read<AppState>(), ctx.read<PackManager?>()),
      child: const _Onboarding(),
    );
  }
}

class _Onboarding extends StatelessWidget {
  const _Onboarding();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnboardingViewModel>();
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: vm.step == 0 ? const _ProfileStep() : const _DataStep(),
        ),
      ),
    );
  }
}

/// Step 1 - how will you use jibiki (mode + mnemonic language).
class _ProfileStep extends StatelessWidget {
  const _ProfileStep();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnboardingViewModel>();
    final jc = context.jc;
    return ListView(
      key: const ValueKey('step-profile'),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 8),
        Text(context.trText('How will you use jibiki?'),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
            context.trText(
                'Pick a starting point. You can change it anytime in Settings.'),
            style: TextStyle(color: jc.muted)),
        const SizedBox(height: 20),
        for (final m in AppMode.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ModeCard(
              mode: m,
              selected: vm.mode == m,
              onTap: () => vm.selectMode(m),
            ),
          ),
        const SizedBox(height: 12),
        Text(context.trText('Mnemonic language'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
            context.trText(
                'Kana mnemonics ride on sound, so they differ by language. Pick '
                'yours even if it has no content yet - English backs you up, and '
                'the community can draw the rest.'),
            style: TextStyle(color: jc.muted, fontSize: 13, height: 1.35)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final lang in quickMnemonicLanguages(vm.language))
              ChoiceChip(
                label: Text(lang.nativeName),
                selected: vm.language == lang.code,
                onSelected: (_) => vm.selectLanguage(lang.code),
              ),
            ActionChip(
              avatar: const Icon(Icons.language, size: 18),
              label: Text(context.trText('More…')),
              onPressed: () async {
                final picked =
                    await showMnemonicLanguagePicker(context, vm.language);
                if (picked != null) vm.selectLanguage(picked);
              },
            ),
          ],
        ),
        const SizedBox(height: 28),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: jc.brand),
          onPressed: vm.isLoading
              ? null
              : () async {
                  if (vm.hasDataStep) {
                    await vm.goToDataStep();
                  } else {
                    await vm.finish();
                  }
                },
          child: vm.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(vm.hasDataStep ? 'Continue' : 'Start learning'),
        ),
      ],
    );
  }
}

/// Step 2 - offline dictionary data: what to download now (all optional; the
/// built-in essentials already cover kana, JLPT kanji and common words).
class _DataStep extends StatelessWidget {
  const _DataStep();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnboardingViewModel>();
    final jc = context.jc;
    return ListView(
      key: const ValueKey('step-data'),
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: vm.backToProfileStep,
            ),
          ],
        ),
        Text(context.trText('Take it offline?'),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
            context.trText(
                'The essentials are already on your phone - kana, JLPT kanji and '
                'everyday words work with no connection. Add more now or later in '
                'Settings.'),
            style: TextStyle(color: jc.muted, height: 1.4)),
        const SizedBox(height: 20),
        if (!vm.offersLoaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          for (final offer in vm.offers)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OfferCard(offer: offer),
            ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: jc.brand),
          onPressed: vm.isLoading ? null : () => vm.finish(download: true),
          child: vm.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(vm.offers.any((o) => o.selected)
                  ? 'Download & start'
                  : 'Start learning'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: vm.isLoading ? null : () => vm.finish(),
          child: Text(context.trText('Skip - download later in Settings')),
        ),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});

  final PackOffer offer;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<OnboardingViewModel>();
    final jc = context.jc;
    final size = offer.info == null
        ? null
        : StorageViewModel.humanSize(offer.info!.bytes);
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.md),
      onTap: () => vm.toggleOffer(offer, !offer.selected),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: BoxDecoration(
          color: jc.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: offer.selected ? jc.brand : jc.hairline,
            width: offer.selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(size == null ? offer.title : '${offer.title} · $size',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(offer.blurb,
                      style: TextStyle(
                          color: jc.muted, fontSize: 13, height: 1.35)),
                ],
              ),
            ),
            Checkbox(
              value: offer.selected,
              onChanged: (v) => vm.toggleOffer(offer, v ?? false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard(
      {required this.mode, required this.selected, required this.onTap});
  final AppMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.md),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: jc.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: selected ? jc.brand : jc.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              switch (mode) {
                AppMode.dictionary => Icons.menu_book_outlined,
                AppMode.middle => Icons.balance_outlined,
                AppMode.learning => Icons.school_outlined,
              },
              color: selected ? jc.brand : jc.muted,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mode.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(mode.blurb,
                      style: TextStyle(
                          color: jc.muted, fontSize: 13, height: 1.35)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: jc.brand, size: 20),
          ],
        ),
      ),
    );
  }
}
