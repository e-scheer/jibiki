import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../core/languages.dart';
import '../../l10n/l10n.dart';
import '../widgets/language_picker.dart';
import '../../models/enums.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final jc = context.jc;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: BoundedContent(
        maxWidth: 640,
        child: ListView(
          children: [
            _section(context, context.l10n.interfaceLanguage),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(profile.interfaceLanguage == 'fr'
                  ? context.l10n.french
                  : context.l10n.english),
              subtitle: Text(context.l10n.interfaceLanguageHelp),
              trailing: DropdownButton<String>(
                value: profile.interfaceLanguage,
                onChanged: (code) {
                  if (code != null) vm.setInterfaceLanguage(code);
                },
                items: [
                  DropdownMenuItem(
                      value: 'en', child: Text(context.l10n.english)),
                  DropdownMenuItem(
                      value: 'fr', child: Text(context.l10n.french)),
                ],
              ),
            ),
            const Divider(),
            _section(context, context.l10n.mode),
            RadioGroup<AppMode>(
              groupValue: app.mode,
              onChanged: (v) => v == null ? null : vm.setMode(v),
              child: Column(
                children: AppMode.values
                    .map((m) => RadioListTile<AppMode>(
                          value: m,
                          title: Text(_modeLabel(context, m)),
                          subtitle: Text(_modeHelp(context, m),
                              style: const TextStyle(fontSize: 12)),
                        ))
                    .toList(),
              ),
            ),
            const Divider(),
            _section(context, context.l10n.mnemonicLanguage),
            ListTile(
              leading: const Icon(Icons.translate),
              title: Text(mnemonicLanguageName(profile.mnemonicLanguage)),
              subtitle: Text(context.l10n.mnemonicLanguageHelp),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showMnemonicLanguagePicker(
                    context, profile.mnemonicLanguage);
                if (picked != null) await vm.setMnemonicLanguage(picked);
              },
            ),
            const Divider(),
            _section(context, context.l10n.spacedRepetition),
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
              onCommit: (v) =>
                  vm.setDesiredRetention(double.parse(v.toStringAsFixed(2))),
            ),
            SwitchListTile(
              title: Text(context.l10n.studyReminders),
              subtitle: Text(context.l10n.studyRemindersHelp),
              value: profile.notificationsEnabled,
              onChanged: vm.setNotifications,
            ),
            const Divider(),
            _section(context, context.l10n.community),
            ListTile(
              leading: const Icon(Icons.brush_outlined),
              title: Text(context.l10n.mySubmissions),
              subtitle: Text(context.l10n.mySubmissionsHelp),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/submissions'),
            ),
            ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined),
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
            ),
            const Divider(),
            _section(context, context.l10n.data),
            ListTile(
              leading: const Icon(Icons.download_for_offline_outlined),
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
            const Divider(),
            _section(context, context.l10n.account),
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
            const SizedBox(height: 24),
            Center(
              child: Text(context.l10n.dictionaryCredits,
                  style: TextStyle(fontSize: 11, color: jc.muted)),
            ),
            const SizedBox(height: 16),
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
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.exportCards(lines)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(tsv,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.close)),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: tsv));
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.ankiCopied)),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: Text(context.l10n.copy),
          ),
        ],
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
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.personalisedScheduling),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: (reviews / minReviews).clamp(0, 1)),
            const SizedBox(height: 12),
            Text(context.l10n.reviewProgress(reviews, minReviews)),
            const SizedBox(height: 6),
            Text(
              ready ? context.l10n.fsrsReady : context.l10n.fsrsKeepReviewing,
              style: TextStyle(color: ctx.jc.muted, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.close)),
          FilledButton(
            onPressed: ready
                ? () async {
                    Navigator.pop(ctx);
                    final res = await vm.runOptimize();
                    if (context.mounted && res != null) {
                      final improved = res['improved'] == true;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(improved
                            ? context.l10n.schedulerPersonalised
                            : context.l10n.schedulerDefaultsKept),
                      ));
                    }
                  }
                : null,
            child: Text(context.l10n.optimiseNow),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.jc.brand)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(widget.title),
          subtitle: Slider(
            value: _value.clamp(widget.min, widget.max),
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: widget.format(_value),
            onChanged: (v) => setState(() => _value = v),
            onChangeEnd: widget.onCommit,
          ),
          trailing: Text(widget.format(_value)),
        ),
        if (widget.helper != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(widget.helper!,
                style: TextStyle(
                    color: context.jc.muted, fontSize: 12, height: 1.35)),
          ),
      ],
    );
  }
}
