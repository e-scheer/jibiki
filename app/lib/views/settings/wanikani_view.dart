import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/integration.dart';
import '../../services/integration_service.dart';
import '../../theme/app_theme.dart';

class WaniKaniView extends StatefulWidget {
  const WaniKaniView({super.key});

  @override
  State<WaniKaniView> createState() => _WaniKaniViewState();
}

class _WaniKaniViewState extends State<WaniKaniView> {
  final _token = TextEditingController();
  WaniKaniStatus? _status;
  String _threshold = 'guru';
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final status = await context.read<WaniKaniService>().status();
      if (!mounted) return;
      setState(() {
        _status = status;
        _threshold = status.threshold;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _busy = false;
      });
    }
  }

  Future<void> _connect() async {
    if (_token.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await context
          .read<WaniKaniService>()
          .connect(_token.text.trim(), _threshold);
      if (!mounted) return;
      setState(() {
        _status = status;
        _busy = false;
      });
      _token.clear();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _busy = false;
      });
    }
  }

  Future<void> _sync() async {
    await _run(() async {
      final status = await context.read<WaniKaniService>().sync();
      if (mounted) setState(() => _status = status);
    });
  }

  Future<void> _import() async {
    final status = _status;
    if (status == null || !status.pending) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.trText('Review WaniKani import')),
        content: Text(
            context.trText('${status.count('new_cards')} cards will be added. '
                '${status.count('known_cards')} are marked known and '
                '${status.count('learning_cards')} start learning.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.trText('Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.trText('Import'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final result = await context.read<WaniKaniService>().importPreview();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.trText(
              'Imported ${result['created'] ?? 0} cards from WaniKani.'))));
      final status = await context.read<WaniKaniService>().status();
      if (mounted) setState(() => _status = status);
    });
  }

  Future<void> _cancel() async {
    final service = context.read<WaniKaniService>();
    await _run(() async {
      await service.cancel();
      final status = await service.status();
      if (mounted) setState(() => _status = status);
    });
  }

  Future<void> _disconnect() async {
    await _run(() async {
      await context.read<WaniKaniService>().disconnect();
      if (mounted) {
        setState(() => _status = const WaniKaniStatus(connected: false));
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(title: Text(context.trText('WaniKani integration'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(context.trText('Read-only import with a preview'),
              style: context.text.titleLarge),
          const SizedBox(height: 8),
          Text(
              context.trText(
                  'Jibiki never changes your WaniKani account and never imports '
                  'without your confirmation. Different SRS calendars stay separate.'),
              style: TextStyle(color: context.jc.muted, height: 1.4)),
          const SizedBox(height: 20),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: context.jc.ratingAgain.withValues(alpha: 0.12),
              child: Text(_error!,
                  style: TextStyle(color: context.jc.ratingAgain)),
            ),
          if (_busy && status == null)
            const Center(child: CircularProgressIndicator())
          else if (status?.connected != true)
            _connectForm(context)
          else ...[
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(status!.username.isEmpty
                  ? context.trText('Connected')
                  : status.username),
              subtitle: Text(context.trText('WaniKani token stored securely')),
            ),
            const Divider(),
            _thresholdPicker(context),
            const SizedBox(height: 12),
            if (status.pending) _preview(context, status),
            if (status.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _import,
                      icon: const Icon(Icons.download_done),
                      label: Text(context.trText('Apply import')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                      onPressed: _busy ? null : _cancel,
                      tooltip: context.trText('Cancel import'),
                      icon: const Icon(Icons.close)),
                ],
              ),
            ],
            OutlinedButton.icon(
              onPressed: _busy ? null : _sync,
              icon: const Icon(Icons.sync),
              label: Text(context.trText('Refresh preview')),
            ),
            TextButton(
                onPressed: _busy ? null : _disconnect,
                child: Text(context.trText('Disconnect WaniKani'))),
          ],
        ],
      ),
    );
  }

  Widget _connectForm(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _token,
            obscureText: true,
            decoration: InputDecoration(
              labelText: context.trText('WaniKani API token'),
              hintText: context.trText('Paste your read-only token'),
            ),
          ),
          const SizedBox(height: 12),
          _thresholdPicker(context),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _connect,
            icon: const Icon(Icons.preview),
            label: Text(context.trText('Preview import')),
          ),
        ],
      );

  Widget _thresholdPicker(BuildContext context) =>
      DropdownButtonFormField<String>(
        initialValue: _threshold,
        decoration: InputDecoration(labelText: context.trText('Known from')),
        items: [
          for (final entry in const {
            'guru': 'Guru',
            'master': 'Master',
            'burned': 'Burned',
          }.entries)
            DropdownMenuItem(
                value: entry.key, child: Text(context.trText(entry.value))),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _threshold = value);
        },
      );

  Widget _preview(BuildContext context, WaniKaniStatus status) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.trText('Import preview'),
                  style: context.text.titleMedium),
              const SizedBox(height: 10),
              Text(context.trText('${status.count('recognized')} recognized, '
                  '${status.count('ambiguous')} ambiguous, '
                  '${status.count('ignored')} ignored.')),
              const SizedBox(height: 6),
              Text(context.trText('${status.count('new_cards')} new cards; '
                  '${status.count('estimated_new_reviews')} estimated first reviews.')),
            ],
          ),
        ),
      );
}
