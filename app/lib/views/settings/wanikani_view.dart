import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../l10n/l10n.dart';
import '../../models/integration.dart';
import '../../services/integration_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/neo_pop.dart';

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
      final status = await context.read<WaniKaniService>().connect(
            _token.text.trim(),
            _threshold,
          );
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
      builder: (dialogContext) => Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: NeoCard(
            tone: NeoTone.lavender,
            shadow: 7,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NeoBadge('IMPORT', tone: NeoTone.magenta, rotate: -2),
                const SizedBox(height: 16),
                Text(
                  context.trText('Review WaniKani import'),
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.trText(
                    '${status.count('new_cards')} cards will be added. ${status.count('known_cards')} are marked known and ${status.count('learning_cards')} start learning.',
                  ),
                  style: TextStyle(
                    color: context.jc.body,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: NeoCard(
                        shadow: 3,
                        onTap: () => Navigator.pop(dialogContext, false),
                        child: Center(
                          child: Text(
                            context.trText('Cancel'),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NeoCard(
                        tone: NeoTone.acid,
                        shadow: 4,
                        onTap: () => Navigator.pop(dialogContext, true),
                        child: Center(
                          child: Text(
                            context.trText('Import'),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
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
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final result = await context.read<WaniKaniService>().importPreview();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.trText(
              'Imported ${result['created'] ?? 0} cards from WaniKani.',
            ),
          ),
        ),
      );
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
      backgroundColor: context.jc.canvas,
      body: Column(
        children: [
          NeoPageHeader(
            title: context.trText('WaniKani integration'),
            subtitle: context.trText('Read-only import with a preview'),
            tone: NeoTone.magenta,
            leading: NeoIconButton(
              icon: Icons.arrow_back_rounded,
              label: context.trText('Back'),
              onTap: () => Navigator.of(context).maybePop(),
            ),
            trailing: const NeoBadge('蟹', tone: NeoTone.acid, rotate: 2),
          ),
          Expanded(
            child: BoundedContent(
              maxWidth: 800,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  context.isWide ? 28 : 18,
                  22,
                  context.isWide ? 28 : 18,
                  36,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NeoCard(
                      tone: NeoTone.lavender,
                      shadow: 5,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.visibility_outlined, size: 27),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.trText(
                                'Jibiki never changes your WaniKani account and never imports without your confirmation. Different SRS calendars stay separate.',
                              ),
                              style: TextStyle(
                                color: context.jc.body,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      NeoCard(
                        tone: NeoTone.coral,
                        shadow: 3,
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    if (_busy && status == null)
                      const _WaniSkeleton()
                    else if (status?.connected != true)
                      _connectForm(context)
                    else
                      _connectedContent(context, status!),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectForm(BuildContext context) => NeoCard(
        shadow: 6,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const NeoBadge('01', tone: NeoTone.acid),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.trText('Connect your account'),
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: context.jc.ink,
                    blurRadius: 0,
                    offset: const Offset(4, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _token,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.trText('WaniKani API token'),
                  hintText: context.trText('Paste your read-only token'),
                  prefixIcon: const Icon(Icons.key_rounded),
                ),
              ),
            ),
            const SizedBox(height: 22),
            _thresholdPicker(context),
            const SizedBox(height: 22),
            NeoPrimaryButton(
              label: context.trText('Preview import'),
              icon: Icons.preview_rounded,
              busy: _busy,
              onTap: _connect,
            ),
          ],
        ),
      );

  Widget _connectedContent(BuildContext context, WaniKaniStatus status) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NeoCard(
            tone: NeoTone.lime,
            shadow: 5,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.jc.surface,
                    border: Border.all(color: context.jc.ink, width: 2.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.link_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.username.isEmpty
                            ? context.trText('Connected')
                            : status.username,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.trText('WaniKani token stored securely'),
                        style: TextStyle(
                          color: context.jc.body,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const NeoBadge('LIVE', tone: NeoTone.paper),
              ],
            ),
          ),
          const SizedBox(height: 22),
          NeoCard(
            shadow: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NeoSectionTitle(context.trText('Known from')),
                _thresholdPicker(context),
              ],
            ),
          ),
          if (status.pending) ...[
            const SizedBox(height: 18),
            _preview(context, status),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: NeoPrimaryButton(
                    label: context.trText('Apply import'),
                    icon: Icons.download_done_rounded,
                    busy: _busy,
                    onTap: _import,
                  ),
                ),
                const SizedBox(width: 12),
                NeoIconButton(
                  icon: Icons.close_rounded,
                  label: context.trText('Cancel import'),
                  onTap: _busy ? () {} : _cancel,
                  tone: NeoTone.coral,
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          NeoCard(
            shadow: 4,
            onTap: _busy ? null : _sync,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_busy)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  const Icon(Icons.sync_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  context.trText('Refresh preview'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _busy ? null : _disconnect,
            child: Text(context.trText('Disconnect WaniKani')),
          ),
        ],
      );

  Widget _thresholdPicker(BuildContext context) => NeoSegmentedControl<String>(
        segments: const [
          NeoSegment('guru', 'Guru'),
          NeoSegment('master', 'Master'),
          NeoSegment('burned', 'Burned'),
        ],
        selected: _threshold,
        onChanged: (value) => setState(() => _threshold = value),
      );

  Widget _preview(BuildContext context, WaniKaniStatus status) => NeoCard(
        tone: NeoTone.lavender,
        shadow: 6,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.trText('Import preview'),
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const NeoBadge('READY', tone: NeoTone.acid, rotate: 2),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 500;
                final stats = [
                  (
                    status.count('recognized'),
                    context.trText('recognized'),
                    NeoTone.lime,
                  ),
                  (
                    status.count('ambiguous'),
                    context.trText('ambiguous'),
                    NeoTone.acid,
                  ),
                  (
                    status.count('ignored'),
                    context.trText('ignored'),
                    NeoTone.magenta,
                  ),
                ];
                if (compact) {
                  return Column(
                    children: [
                      for (var index = 0; index < stats.length; index++) ...[
                        if (index > 0) const SizedBox(height: 9),
                        SizedBox(
                          width: double.infinity,
                          child: _PreviewStat(
                            value: stats[index].$1,
                            label: stats[index].$2,
                            tone: stats[index].$3,
                          ),
                        ),
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var index = 0; index < stats.length; index++) ...[
                      if (index > 0) const SizedBox(width: 9),
                      Expanded(
                        child: _PreviewStat(
                          value: stats[index].$1,
                          label: stats[index].$2,
                          tone: stats[index].$3,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Text(
              context.trText(
                '${status.count('new_cards')} new cards; ${status.count('estimated_new_reviews')} estimated first reviews.',
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}

class _PreviewStat extends StatelessWidget {
  const _PreviewStat({
    required this.value,
    required this.label,
    required this.tone,
  });

  final int value;
  final String label;
  final NeoTone tone;

  @override
  Widget build(BuildContext context) => NeoCard(
        tone: tone,
        shadow: 0,
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 26,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style:
                  const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}

class _WaniSkeleton extends StatelessWidget {
  const _WaniSkeleton();

  @override
  Widget build(BuildContext context) => NeoCard(
        shadow: 5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: context.jc.lavender,
                    border: Border.all(color: context.jc.ink, width: 2.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Container(height: 16, color: context.jc.ink)),
                const SizedBox(width: 14),
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(height: 12, color: context.jc.hairline),
            const SizedBox(height: 8),
            FractionallySizedBox(
              widthFactor: 0.65,
              child: Container(height: 12, color: context.jc.hairline),
            ),
          ],
        ),
      );
}
