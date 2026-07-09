import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../core/languages.dart';
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
      create: (ctx) => SettingsViewModel(ctx.read<AppState>(), ctx.read<StudyRepository>()),
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
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final jc = context.jc;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BoundedContent(
        maxWidth: 640,
        child: ListView(
          children: [
          _section(context, 'Mode'),
          RadioGroup<AppMode>(
            groupValue: app.mode,
            onChanged: (v) => v == null ? null : vm.setMode(v),
            child: Column(
              children: AppMode.values
                  .map((m) => RadioListTile<AppMode>(
                        value: m,
                        title: Text(m.label),
                        subtitle: Text(m.blurb, style: const TextStyle(fontSize: 12)),
                      ))
                  .toList(),
            ),
          ),
          const Divider(),
          _section(context, 'Mnemonic language'),
          ListTile(
            leading: const Icon(Icons.translate),
            title: Text(mnemonicLanguageName(profile.mnemonicLanguage)),
            subtitle: const Text(
                'Any language works - where content is missing, English backs '
                'you up and the community (you?) can draw the first set.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked = await showMnemonicLanguagePicker(
                  context, profile.mnemonicLanguage);
              if (picked != null) await vm.setMnemonicLanguage(picked);
            },
          ),
          const Divider(),
          _section(context, 'Spaced repetition'),
          _CommitSlider(
            title: 'New cards per session',
            helper: 'How many new cards to start a session with. Not a daily cap, '
                'tap “Study more” at the end to keep going.',
            value: profile.newCardsPerDay.toDouble(),
            min: 0,
            max: 50,
            divisions: 50,
            format: (v) => '${v.round()}',
            onCommit: (v) => vm.setNewCardsPerDay(v.round()),
          ),
          _CommitSlider(
            title: 'Desired retention',
            value: profile.desiredRetention.clamp(0.80, 0.95),
            min: 0.80,
            max: 0.95,
            divisions: 15,
            format: (v) => '${(v * 100).round()}%',
            onCommit: (v) => vm.setDesiredRetention(double.parse(v.toStringAsFixed(2))),
          ),
          SwitchListTile(
            title: const Text('Study reminders'),
            subtitle: const Text('A gentle nudge when enough cards are due.'),
            value: profile.notificationsEnabled,
            onChanged: vm.setNotifications,
          ),
          const Divider(),
          _section(context, 'Community'),
          ListTile(
            leading: const Icon(Icons.brush_outlined),
            title: const Text('My submissions'),
            subtitle: const Text('Your drawn mnemonics and their review status.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/submissions'),
          ),
          ListTile(
            leading: const Icon(Icons.collections_bookmark_outlined),
            title: const Text('My packs'),
            subtitle: const Text('Packs you created, drafts, in review, published.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/decks/community?tab=mine'),
          ),
          ListTile(
            leading: const Icon(Icons.forum_outlined),
            title: const Text('Make jibiki better'),
            subtitle: const Text('Ideas, bugs, love letters - we read every single one.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/feedback'),
          ),
          const Divider(),
          _section(context, 'Data'),
          ListTile(
            leading: const Icon(Icons.download_for_offline_outlined),
            title: const Text('Offline & storage'),
            subtitle: const Text('Dictionary packs on this phone, updates, sync status.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/storage'),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('Export to Anki'),
            subtitle: const Text('Your deck as an Anki-importable TSV.'),
            onTap: () => _export(context, vm),
          ),
          ListTile(
            leading: const Icon(Icons.auto_graph),
            title: const Text('Personalised scheduling'),
            subtitle: const Text('Train FSRS on your own history once you have enough reviews.'),
            onTap: () => _optimize(context, vm),
          ),
          const Divider(),
          _section(context, 'Account'),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(app.user?.email ?? ''),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: jc.ratingAgain),
            title: Text('Sign out', style: TextStyle(color: jc.ratingAgain)),
            onTap: () => vm.logout(),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('jibiki · dictionary data © EDRDG (JMdict/KANJIDIC)',
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(vm.error ?? 'Export failed')));
      return;
    }
    final lines = tsv.split('\n').where((l) => l.isNotEmpty && !l.startsWith('#')).length;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Export · $lines cards'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(tsv, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: tsv));
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied, paste into a .txt and import in Anki')),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
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
        title: const Text('Personalised scheduling'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: (reviews / minReviews).clamp(0, 1)),
            const SizedBox(height: 12),
            Text('$reviews / $minReviews reviews'),
            const SizedBox(height: 6),
            Text(
              ready
                  ? 'Ready. FSRS can now be tuned to your own memory.'
                  : 'Keep reviewing. FSRS uses solid defaults until then.',
              style: TextStyle(color: ctx.jc.muted, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton(
            onPressed: ready
                ? () async {
                    Navigator.pop(ctx);
                    final res = await vm.runOptimize();
                    if (context.mounted && res != null) {
                      final improved = res['improved'] == true;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(improved
                            ? 'Scheduler personalised to your history 🎯'
                            : 'Kept the defaults, they already fit you well.'),
                      ));
                    }
                  }
                : null,
            child: const Text('Optimise now'),
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
            child: Text(widget.helper!, style: TextStyle(color: context.jc.muted, fontSize: 12, height: 1.35)),
          ),
      ],
    );
  }
}
