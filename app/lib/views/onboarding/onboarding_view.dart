import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/onboarding_viewmodel.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => OnboardingViewModel(ctx.read<AppState>()),
      child: const _Onboarding(),
    );
  }
}

class _Onboarding extends StatelessWidget {
  const _Onboarding();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnboardingViewModel>();
    final jc = context.jc;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 8),
            Text('How will you use jibiki?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Pick a starting point. You can change it anytime in Settings.',
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
            Text('Mnemonic language', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Kana mnemonics ride on sound, so they differ by language.',
                style: TextStyle(color: jc.muted, fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: OnboardingViewModel.languages.entries.map((e) {
                return ChoiceChip(
                  label: Text(e.value),
                  selected: vm.language == e.key,
                  onSelected: (_) => vm.selectLanguage(e.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: jc.brand),
              onPressed: vm.isLoading ? null : () => vm.finish(),
              child: vm.isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Start learning'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.selected, required this.onTap});
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
                  Text(mode.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(mode.blurb, style: TextStyle(color: jc.muted, fontSize: 13, height: 1.35)),
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
