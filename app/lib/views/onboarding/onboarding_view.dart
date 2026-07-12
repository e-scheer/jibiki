import 'package:flutter/material.dart';
import 'package:jibiki/l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../core/languages.dart';
import '../../infrastructure/packs/pack_manager.dart';
import '../../models/enums.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/onboarding_viewmodel.dart';
import '../../viewmodels/storage_viewmodel.dart' show StorageViewModel;
import '../widgets/jibiki_brand.dart';
import '../widgets/language_picker.dart';
import '../widgets/neo_pop.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (ctx) => OnboardingViewModel(
          ctx.read<AppState>(),
          ctx.read<PackManager?>(),
          ctx.read<StudyRepository>(),
        ),
        child: const _Onboarding(),
      );
}

class _Onboarding extends StatelessWidget {
  const _Onboarding();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnboardingViewModel>();
    return Scaffold(
      backgroundColor: context.jc.canvas,
      body: Column(
        children: [
          _ProgressMasthead(step: vm.step, hasDataStep: vm.hasDataStep),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.timed(context, Motion.base),
              switchInCurve: Motion.out,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: switch (vm.step) {
                0 => const _ProfileStep(),
                1 => const _PlacementStep(),
                _ => const _DataStep(),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressMasthead extends StatelessWidget {
  const _ProgressMasthead({required this.step, required this.hasDataStep});

  final int step;
  final bool hasDataStep;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final total = hasDataStep ? 3 : 2;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: jc.brand,
        border: Border(bottom: BorderSide(color: jc.ink, width: 3)),
      ),
      child: SafeArea(
        bottom: false,
        child: BoundedContent(
          maxWidth: 960,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Row(
              children: [
                const JibikiWordmark(
                  fontSize: 23,
                  variant: JibikiBrandVariant.negative,
                  dotOutline: JibikiBrandColors.ink,
                ),
                const Spacer(),
                for (var index = 0; index < total; index++) ...[
                  AnimatedContainer(
                    duration: Motion.timed(context, Motion.fast),
                    width: index == step ? 34 : 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: index <= step ? jc.acid : jc.surface,
                      border: Border.all(color: jc.ink, width: 2.5),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: index == step
                          ? [
                              BoxShadow(
                                color: jc.ink,
                                blurRadius: 0,
                                offset: const Offset(2, 2),
                              ),
                            ]
                          : null,
                    ),
                  ),
                  if (index < total - 1) const SizedBox(width: 7),
                ],
                const SizedBox(width: 12),
                Text(
                  '${step + 1}/$total',
                  style: TextStyle(
                    color: jc.surface,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnboardingViewModel>();
    return _StepScroll(
      key: const ValueKey('step-profile'),
      children: [
        _StepIntro(
          sticker: context.trText('LET’S START'),
          title: context.trText('How will you use jibiki?'),
          subtitle: context.trText(
            'Pick a starting point. You can change it anytime in Settings.',
          ),
        ),
        const SizedBox(height: 22),
        _ResponsiveWrap(
          itemCount: AppMode.values.length,
          itemBuilder: (index) {
            final mode = AppMode.values[index];
            return _ModeCard(
              mode: mode,
              selected: vm.mode == mode,
              onTap: () => vm.selectMode(mode),
            );
          },
        ),
        const SizedBox(height: 28),
        NeoCard(
          tone: NeoTone.lavender,
          shadow: 5,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeoSectionTitle(context.trText('Mnemonic language')),
              Text(
                context.trText(
                  'Kana mnemonics ride on sound, so they differ by language. Pick yours even if it has no content yet. English backs you up, and the community can draw the rest.',
                ),
                style: TextStyle(
                  color: context.jc.body,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 9,
                runSpacing: 10,
                children: [
                  for (final language in quickMnemonicLanguages(vm.language))
                    _SelectionTag(
                      label: language.nativeName,
                      selected: vm.language == language.code,
                      onTap: () => vm.selectLanguage(language.code),
                    ),
                  _SelectionTag(
                    label: context.trText('More…'),
                    icon: Icons.language_rounded,
                    onTap: () async {
                      final picked = await showMnemonicLanguagePicker(
                        context,
                        vm.language,
                      );
                      if (picked != null) vm.selectLanguage(picked);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: NeoPrimaryButton(
              label: context.trText('Continue'),
              icon: Icons.arrow_forward_rounded,
              busy: vm.isLoading,
              onTap: vm.goToPlacementStep,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlacementStep extends StatelessWidget {
  const _PlacementStep();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnboardingViewModel>();
    const options = [
      ('fresh', 'Start fresh', 'Everything begins in the new queue.'),
      ('kana', 'I know hiragana', 'Mark the basic hiragana as known.'),
      (
        'custom',
        'I know specific characters',
        'Paste kana or kanji you already read.',
      ),
    ];
    return _StepScroll(
      key: const ValueKey('step-placement'),
      children: [
        _StepIntro(
          sticker: context.trText('YOUR LEVEL'),
          title: context.trText('Where should we place you?'),
          subtitle: context.trText(
            'Start fresh, skip what you already know, or type a few characters. You can change this later.',
          ),
          onBack: vm.backToProfileStep,
        ),
        const SizedBox(height: 22),
        _ResponsiveWrap(
          itemCount: options.length,
          itemBuilder: (index) {
            final option = options[index];
            return _PlacementCard(
              title: context.trText(option.$2),
              subtitle: context.trText(option.$3),
              index: index + 1,
              selected: vm.placement == option.$1,
              onTap: () => vm.selectPlacement(option.$1),
            );
          },
        ),
        AnimatedSize(
          duration: Motion.timed(context, Motion.base),
          curve: Motion.out,
          child: vm.placement == 'custom'
              ? Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: NeoCard(
                    tone: NeoTone.lavender,
                    shadow: 4,
                    child: TextField(
                      onChanged: vm.setKnownCharacters,
                      style: const TextStyle(
                        fontFamily: 'ZenKakuGothicNew',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        labelText: context.trText('Known characters'),
                        hintText: context.trText('Example: 日本語かな'),
                        prefixIcon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            if (context.isWide) ...[
              Expanded(
                child: NeoCard(
                  shadow: 3,
                  onTap: vm.backToProfileStep,
                  child: Center(
                    child: Text(
                      context.trText('Back'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              flex: 2,
              child: NeoPrimaryButton(
                label: context.trText(
                  vm.hasDataStep ? 'Continue' : 'Start learning',
                ),
                icon: Icons.arrow_forward_rounded,
                busy: vm.isLoading,
                onTap: () async {
                  if (vm.hasDataStep) {
                    await vm.goToDataStep();
                  } else {
                    await vm.finish();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DataStep extends StatelessWidget {
  const _DataStep();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnboardingViewModel>();
    return _StepScroll(
      key: const ValueKey('step-data'),
      children: [
        _StepIntro(
          sticker: context.trText('OFFLINE FIRST'),
          title: context.trText('Take it offline?'),
          subtitle: context.trText(
            'The essentials are already on your phone. Kana, JLPT kanji and everyday words work with no connection. Add more now or later in Settings.',
          ),
          onBack: vm.backToPlacementStep,
        ),
        const SizedBox(height: 22),
        if (!vm.offersLoaded)
          const _OfferSkeletons()
        else if (vm.offers.isEmpty)
          NeoCard(
            tone: NeoTone.lime,
            shadow: 4,
            child: Row(
              children: [
                const Icon(Icons.offline_pin_rounded, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.trText(
                        'Everything essential is already ready offline.'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          )
        else
          _ResponsiveWrap(
            itemCount: vm.offers.length,
            itemBuilder: (index) => _OfferCard(offer: vm.offers[index]),
          ),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NeoPrimaryButton(
                  label: context.trText(
                    vm.offers.any((offer) => offer.selected)
                        ? 'Download & start'
                        : 'Start learning',
                  ),
                  icon: vm.offers.any((offer) => offer.selected)
                      ? Icons.download_rounded
                      : Icons.arrow_forward_rounded,
                  busy: vm.isLoading,
                  tone: NeoTone.acid,
                  onTap: () => vm.finish(download: true),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: vm.isLoading ? null : () => vm.finish(),
                  child: Text(
                    context.trText('Skip - download later in Settings'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepScroll extends StatelessWidget {
  const _StepScroll({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => BoundedContent(
        maxWidth: 960,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            context.isWide ? 32 : 18,
            context.isWide ? 34 : 24,
            context.isWide ? 32 : 18,
            36,
          ),
          children: children,
        ),
      );
}

class _StepIntro extends StatelessWidget {
  const _StepIntro({
    required this.sticker,
    required this.title,
    required this.subtitle,
    this.onBack,
  });

  final String sticker;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null) ...[
            NeoIconButton(
              icon: Icons.arrow_back_rounded,
              label: context.trText('Back'),
              onTap: onBack!,
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NeoBadge(sticker, tone: NeoTone.magenta, rotate: -1.5),
                const SizedBox(height: 15),
                Text(
                  title,
                  style: context.text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    height: 1.02,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.jc.body,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _ResponsiveWrap extends StatelessWidget {
  const _ResponsiveWrap({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final Widget Function(int index) itemBuilder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 760 ? 3 : 1;
          final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (var index = 0; index < itemCount; index++)
                SizedBox(width: width, child: itemBuilder(index)),
            ],
          );
        },
      );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final AppMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: context.isWide ? 178 : 0,
        ),
        child: NeoCard(
          tone: selected ? NeoTone.acid : NeoTone.paper,
          shadow: selected ? 6 : 4,
          padding: const EdgeInsets.all(17),
          onTap: onTap,
          semanticLabel: mode.label,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          selected ? context.jc.surface : context.jc.lavender,
                      border: Border.all(color: context.jc.ink, width: 2.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      switch (mode) {
                        AppMode.dictionary => Icons.menu_book_outlined,
                        AppMode.middle => Icons.balance_outlined,
                        AppMode.learning => Icons.school_outlined,
                      },
                    ),
                  ),
                  const Spacer(),
                  if (selected)
                    const Icon(Icons.check_circle_rounded, size: 24),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                mode.label,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
              const SizedBox(height: 5),
              Text(
                mode.blurb,
                style: TextStyle(
                  color: context.jc.body,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}

class _PlacementCard extends StatelessWidget {
  const _PlacementCard({
    required this.title,
    required this.subtitle,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: context.isWide ? 156 : 0,
        ),
        child: NeoCard(
          tone: selected ? NeoTone.acid : NeoTone.paper,
          shadow: selected ? 6 : 4,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  NeoBadge('0$index',
                      tone: selected ? NeoTone.ink : NeoTone.lavender),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.jc.body,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}

class _SelectionTag extends StatelessWidget {
  const _SelectionTag({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => NeoCard(
        tone: selected ? NeoTone.acid : NeoTone.paper,
        shadow: selected ? 3 : 0,
        radius: 8,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17),
              const SizedBox(width: 6),
            ],
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});
  final PackOffer offer;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<OnboardingViewModel>();
    final size = offer.info == null
        ? null
        : StorageViewModel.humanSize(offer.info!.bytes);
    return NeoCard(
      tone: offer.selected ? NeoTone.lavender : NeoTone.paper,
      shadow: offer.selected ? 6 : 4,
      onTap: () => vm.toggleOffer(offer, !offer.selected),
      semanticLabel: offer.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: offer.selected ? context.jc.acid : context.jc.canvas,
                  border: Border.all(color: context.jc.ink, width: 2.5),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.download_for_offline_outlined),
              ),
              const Spacer(),
              Icon(
                offer.selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 27,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            offer.title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          if (size != null) ...[
            const SizedBox(height: 5),
            NeoBadge(size, tone: NeoTone.lime),
          ],
          const SizedBox(height: 8),
          Text(
            offer.blurb,
            style: TextStyle(
              color: context.jc.body,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferSkeletons extends StatelessWidget {
  const _OfferSkeletons();

  @override
  Widget build(BuildContext context) => _ResponsiveWrap(
        itemCount: 3,
        itemBuilder: (index) => NeoCard(
          shadow: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: context.jc.lavender,
                      border: Border.all(color: context.jc.ink, width: 2.5),
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  const Spacer(),
                  const NeoChaseLoader(
                    size: 22,
                    blockSize: 9,
                    borderWidth: 1.5,
                    radius: 2,
                    shadow: 1.5,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Container(height: 14, width: 132, color: context.jc.ink),
              const SizedBox(height: 10),
              Container(height: 10, color: context.jc.hairline),
              const SizedBox(height: 6),
              FractionallySizedBox(
                widthFactor: 0.7,
                child: Container(height: 10, color: context.jc.hairline),
              ),
            ],
          ),
        ),
      );
}
