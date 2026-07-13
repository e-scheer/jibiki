import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../core/languages.dart';
import '../../l10n/l10n.dart';
import '../widgets/language_picker.dart';
import '../widgets/jibiki_brand.dart';
import '../widgets/neo_pop.dart';
import '../../models/enums.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/settings_viewmodel.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          SettingsViewModel(ctx.read<AppState>(), ctx.read<StudyRepository>()),
      child: const _Settings(),
    );
  }
}

class _Settings extends StatelessWidget {
  const _Settings();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final vm = context.read<SettingsViewModel>();
    final profile = app.profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: NeoChaseLoader()));
    }
    final jc = context.jc;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            BoundedContent(
              maxWidth: 640,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      NeoIconButton(
                        icon: Icons.arrow_back_rounded,
                        label: context.trText('Back to profile'),
                        onTap: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            context.go('/');
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      Text(
                        context.l10n.settings,
                        style: context.text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: BoundedContent(
                maxWidth: 640,
                child: ListView(
                  children: [
                    _section(context, context.trText('Appearance')),
                    _SettingsCard(
                      children: [
                        _SettingsControlRow(
                          title: context.trText('Theme'),
                          control: SizedBox(
                            width: 230,
                            child: NeoSegmentedControl<ThemeModeSetting>(
                              height: 50,
                              segments: [
                                NeoSegment(
                                  ThemeModeSetting.light,
                                  context.trText('Light'),
                                ),
                                NeoSegment(
                                  ThemeModeSetting.dark,
                                  context.trText('Dark'),
                                ),
                                NeoSegment(
                                  ThemeModeSetting.system,
                                  context.trText('Auto'),
                                ),
                              ],
                              selected: context.watch<ThemeController>().mode,
                              onChanged:
                                  context.read<ThemeController>().setMode,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: _PalettePicker(
                            value: context.watch<ThemeController>().palette,
                            onChanged:
                                context.read<ThemeController>().setPalette,
                          ),
                        ),
                      ],
                    ),
                    _section(context, context.l10n.interfaceLanguage),
                    _SettingsCard(children: [
                      _SettingsControlRow(
                        title: context.l10n.interfaceLanguage,
                        helper: context.l10n.interfaceLanguageHelp,
                        control: SizedBox(
                          width: 178,
                          child: NeoSegmentedControl<String>(
                            height: 48,
                            segments: [
                              NeoSegment('fr', context.l10n.french),
                              NeoSegment('en', context.l10n.english),
                            ],
                            selected: profile.interfaceLanguage,
                            onChanged: vm.setInterfaceLanguage,
                          ),
                        ),
                      ),
                    ]),
                    _section(context, context.l10n.mode),
                    _SettingsCard(children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            NeoSegmentedControl<AppMode>(
                              height: 54,
                              segments: [
                                for (final mode in AppMode.values)
                                  NeoSegment(mode, _modeLabel(context, mode)),
                              ],
                              selected: app.mode,
                              onChanged: vm.setMode,
                            ),
                            const SizedBox(height: 10),
                            AnimatedSwitcher(
                              duration: Motion.timed(context, Motion.fast),
                              child: Text(
                                _modeHelp(context, app.mode),
                                key: ValueKey(app.mode),
                                style: TextStyle(
                                  color: jc.body,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                    _section(context, context.l10n.mnemonicLanguage),
                    _SettingsCard(children: [
                      ListTile(
                        leading: const Icon(Icons.translate),
                        title: Text(
                            mnemonicLanguageName(profile.mnemonicLanguage)),
                        subtitle: Text(context.l10n.mnemonicLanguageHelp),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final picked = await showMnemonicLanguagePicker(
                              context, profile.mnemonicLanguage);
                          if (picked != null) {
                            await vm.setMnemonicLanguage(picked);
                          }
                        },
                      )
                    ]),
                    _section(context, context.l10n.spacedRepetition),
                    _SettingsCard(children: [
                      _CommitSlider(
                        title: context.l10n.newCardsPerSession,
                        helper: context.l10n.newCardsHelp,
                        value: profile.newCardsPerDay.toDouble(),
                        min: 0,
                        max: 50,
                        divisions: 50,
                        format: (v) => '${v.round()}',
                        onCommit: (v) => vm.setNewCardsPerDay(v.round()),
                      ),
                      _CommitSlider(
                        title: context.l10n.desiredRetention,
                        value: profile.desiredRetention.clamp(0.80, 0.95),
                        min: 0.80,
                        max: 0.95,
                        divisions: 15,
                        format: (v) => '${(v * 100).round()}%',
                        onCommit: (v) => vm.setDesiredRetention(
                            double.parse(v.toStringAsFixed(2))),
                      ),
                      _SettingsSwitchRow(
                        title: context.l10n.studyReminders,
                        helper: context.l10n.studyRemindersHelp,
                        value: profile.notificationsEnabled,
                        onChanged: vm.setNotifications,
                      ),
                    ]),
                    _section(context, context.l10n.community),
                    _SettingsCard(children: [
                      ListTile(
                        leading: const Icon(Icons.brush_outlined),
                        title: Text(context.l10n.mySubmissions),
                        subtitle: Text(context.l10n.mySubmissionsHelp),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/submissions'),
                      ),
                      ListTile(
                        leading:
                            const Icon(Icons.collections_bookmark_outlined),
                        title: Text(context.l10n.myPacks),
                        subtitle: Text(context.l10n.myPacksHelp),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/decks/community?tab=mine'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.forum_outlined),
                        title: Text(context.l10n.makeJibikiBetter),
                        subtitle: Text(context.l10n.makeJibikiBetterHelp),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/feedback'),
                      )
                    ]),
                    _section(context, context.l10n.data),
                    _SettingsCard(children: [
                      ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: Text(context.trText('Japanese reference')),
                        subtitle: Text(context.trText(
                            'Particles, conjugation, readings and other quick references.')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/reference'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.insights_outlined),
                        title: Text(context.trText('Statistics')),
                        subtitle: Text(context.trText(
                            'See retention, accumulated knowledge and review trends.')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/stats'),
                      ),
                      ListTile(
                        leading:
                            const Icon(Icons.download_for_offline_outlined),
                        title: Text(context.l10n.offlineStorage),
                        subtitle: Text(context.l10n.offlineStorageHelp),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/settings/storage'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.ios_share),
                        title: Text(context.l10n.exportToAnki),
                        subtitle: Text(context.l10n.exportToAnkiHelp),
                        onTap: () => _export(context, vm),
                      ),
                      ListTile(
                        leading: const Icon(Icons.auto_graph),
                        title: Text(context.l10n.personalisedScheduling),
                        subtitle: Text(context.l10n.personalisedSchedulingHelp),
                        onTap: () => _optimize(context, vm),
                      ),
                      if (app.isAuthenticated)
                        ListTile(
                          leading: const Icon(
                              Icons.integration_instructions_outlined),
                          title: Text(context.trText('WaniKani integration')),
                          subtitle: Text(context.trText(
                              'Import known kanji and vocabulary with a reviewable preview.')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.push('/settings/integrations/wanikani'),
                        ),
                    ]),
                    _section(context, context.l10n.account),
                    _SettingsCard(children: [
                      if (app.isAuthenticated) ...[
                        ListTile(
                          leading: const Icon(Icons.mail_outline),
                          title: Text(app.user!.email),
                        ),
                        ListTile(
                          leading: Icon(Icons.logout, color: jc.ratingAgain),
                          title: Text(context.l10n.signOut,
                              style: TextStyle(color: jc.ratingAgain)),
                          onTap: () => vm.logout(),
                        ),
                      ] else ...[
                        ListTile(
                          leading: const Icon(Icons.cloud_upload_outlined),
                          title: Text(context.l10n.syncWithAccount),
                          subtitle: Text(context.l10n.syncWithAccountHelp),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/login'),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(context.l10n.dictionaryCredits,
                          style: TextStyle(fontSize: 11, color: jc.muted)),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, SettingsViewModel vm) async {
    final tsv = await vm.exportDeck();
    if (!context.mounted) return;
    if (tsv == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.error ?? context.l10n.exportFailed)));
      return;
    }
    final lines =
        tsv.split('\n').where((l) => l.isNotEmpty && !l.startsWith('#')).length;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SizedBox(
            height: (MediaQuery.sizeOf(ctx).height * 0.72).clamp(360, 620),
            child: NeoCard(
              shadow: 6,
              radius: 14,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SettingsModalHeader(
                    title: context.l10n.exportCards(lines),
                    onClose: () => Navigator.pop(ctx),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ctx.jc.canvas,
                        border: Border.all(color: ctx.jc.ink, width: 2.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          tsv,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _SettingsModalButton(
                          label: context.l10n.close,
                          onTap: () => Navigator.pop(ctx),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SettingsModalButton(
                          label: context.l10n.copy,
                          icon: Icons.copy_rounded,
                          tone: NeoTone.acid,
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: tsv));
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.l10n.ankiCopied),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _optimize(BuildContext context, SettingsViewModel vm) async {
    final status = await vm.optimizeStatus();
    if (!context.mounted || status == null) return;
    final reviews = status['reviews'] as int? ?? 0;
    final minReviews = status['min_reviews'] as int? ?? 1000;
    final ready = status['ready'] as bool? ?? false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: NeoCard(
            shadow: 6,
            radius: 14,
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SettingsModalHeader(
                  title: context.l10n.personalisedScheduling,
                  onClose: () => Navigator.pop(ctx),
                ),
                const SizedBox(height: 18),
                NeoProgress(
                  value: (reviews / minReviews).clamp(0, 1),
                  tone: ready ? NeoTone.lime : NeoTone.blue,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.reviewProgress(reviews, minReviews),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  ready
                      ? context.l10n.fsrsReady
                      : context.l10n.fsrsKeepReviewing,
                  style: TextStyle(
                    color: ctx.jc.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _SettingsModalButton(
                        label: context.l10n.close,
                        onTap: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SettingsModalButton(
                        label: context.l10n.optimiseNow,
                        tone: NeoTone.acid,
                        enabled: ready,
                        onTap: () async {
                          Navigator.pop(ctx);
                          final res = await vm.runOptimize();
                          if (context.mounted && res != null) {
                            final improved = res['improved'] == true;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  improved
                                      ? context.l10n.schedulerPersonalised
                                      : context.l10n.schedulerDefaultsKept,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Text(title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            )),
      );

  String _modeLabel(BuildContext context, AppMode mode) => switch (mode) {
        AppMode.dictionary => context.l10n.dictionaryMode,
        AppMode.middle => context.l10n.middleMode,
        AppMode.learning => context.l10n.learningMode,
      };

  String _modeHelp(BuildContext context, AppMode mode) => switch (mode) {
        AppMode.dictionary => context.l10n.dictionaryModeHelp,
        AppMode.middle => context.l10n.middleModeHelp,
        AppMode.learning => context.l10n.learningModeHelp,
      };
}

class _SettingsModalHeader extends StatelessWidget {
  const _SettingsModalHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 21,
                height: 1.1,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.45,
              ),
            ),
          ),
          const SizedBox(width: 12),
          NeoIconButton(
            icon: Icons.close_rounded,
            label: context.trText('Close'),
            onTap: onClose,
          ),
        ],
      );
}

class _SettingsModalButton extends StatelessWidget {
  const _SettingsModalButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.tone = NeoTone.paper,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final NeoTone tone;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : 0.42,
        child: SizedBox(
          height: 50,
          child: NeoCard(
            tone: tone,
            shadow: enabled ? 3 : 0,
            radius: 10,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            semanticLabel: label,
            onTap: enabled ? onTap : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 7),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: jc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: jc.ink, width: 3),
        boxShadow: [
          BoxShadow(
            color: jc.ink,
            blurRadius: 0,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 2.5, thickness: 2.5, color: jc.ink),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _PalettePicker extends StatelessWidget {
  const _PalettePicker({required this.value, required this.onChanged});

  final ThemePalette value;
  final ValueChanged<ThemePalette> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 368
            ? 178.0
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final palette in ThemePalette.values)
              _PaletteSwatch(
                width: width,
                palette: palette,
                selected: value == palette,
                onTap: () => onChanged(palette),
              ),
          ],
        );
      },
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({
    required this.width,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final ThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = palette == ThemePalette.neopop
        ? const [
            Color(0xFFF2E51C),
            Color(0xFF2B36E3),
            Color(0xFFFF57A8),
            Color(0xFF8FE838)
          ]
        : const [
            Color(0xFFF28AB4),
            Color(0xFF3441D4),
            Color(0xFF7452C9),
            Color(0xFFA9B6F2)
          ];
    return SizedBox(
      width: width,
      child: NeoCard(
        onTap: onTap,
        semanticLabel: context.trText('${palette.label} palette'),
        tone: selected ? NeoTone.acid : NeoTone.paper,
        shadow: selected ? 4 : 0,
        radius: 10,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Row(children: [
                for (final color in colors)
                  Expanded(
                    child: ColoredBox(
                      color: color,
                      child: const SizedBox(height: 28),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(
                child: Text(
                  palette.label,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: Motion.timed(context, Motion.fast),
                child: const Icon(Icons.check_rounded, size: 20),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _SettingsControlRow extends StatelessWidget {
  const _SettingsControlRow({
    required this.title,
    required this.control,
    this.helper,
  });

  final String title;
  final String? helper;
  final Widget control;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 480;
            final label = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (helper != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    helper!,
                    style: TextStyle(
                      color: context.jc.body,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [label, const SizedBox(height: 10), control],
              );
            }
            return Row(
              children: [
                Expanded(child: label),
                const SizedBox(width: 14),
                control,
              ],
            );
          },
        ),
      );
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.helper,
  });

  final String title;
  final String? helper;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _SettingsControlRow(
        title: title,
        helper: helper,
        control: _NeoSwitch(value: value, onChanged: onChanged),
      );
}

class _NeoSwitch extends StatelessWidget {
  const _NeoSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Semantics(
      button: true,
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.tick();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: Motion.timed(context, Motion.fast),
          curve: Motion.out,
          width: 68,
          height: 44,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? jc.lime : jc.surfaceAlt,
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
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: jc.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: jc.ink, width: 2.5),
              ),
              child: AnimatedOpacity(
                opacity: value ? 1 : 0,
                duration: Motion.timed(context, Motion.fast),
                child: const Icon(Icons.check_rounded, size: 17),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A slider that tracks the finger locally and only writes the profile once the
/// drag ends (so a settings save isn't fired on every intermediate value).
class _CommitSlider extends StatefulWidget {
  const _CommitSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onCommit,
    this.helper,
  });

  final String title;
  final String? helper;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onCommit;

  @override
  State<_CommitSlider> createState() => _CommitSliderState();
}

class _CommitSliderState extends State<_CommitSlider> {
  late double _value = widget.value;

  @override
  void didUpdateWidget(_CommitSlider old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: context.jc.acid,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: context.jc.ink, width: 2),
                ),
                child: Text(
                  widget.format(_value),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _value.clamp(widget.min, widget.max),
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: widget.format(_value),
            onChanged: (v) => setState(() => _value = v),
            onChangeEnd: widget.onCommit,
          ),
          if (widget.helper != null)
            Text(
              widget.helper!,
              style: TextStyle(
                color: context.jc.body,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }
}
