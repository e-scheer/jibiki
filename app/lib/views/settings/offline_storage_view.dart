import 'package:flutter/material.dart';
import 'package:jibiki/l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../infrastructure/packs/pack_manager.dart';
import '../../sync/sync_engine.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/storage_viewmodel.dart';
import '../widgets/neo_pop.dart';
import '../widgets/jibiki_brand.dart';
import '../widgets/sync_conflict_gate.dart';

class OfflineStorageView extends StatelessWidget {
  const OfflineStorageView({super.key});

  @override
  Widget build(BuildContext context) {
    final packs = context.read<PackManager?>();
    if (packs == null) return const _WebStorageEmpty();
    return ChangeNotifierProvider(
      create: (ctx) => StorageViewModel(
        packs,
        ctx.read<SyncEngine?>(),
      )..checkUpdates(),
      child: const _Storage(),
    );
  }
}

class _WebStorageEmpty extends StatelessWidget {
  const _WebStorageEmpty();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.jc.canvas,
        body: Column(
          children: [
            _StorageHeader(
              subtitle: context.trText('Your dictionary, ready anywhere.'),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: NeoCard(
                      tone: NeoTone.lavender,
                      shadow: 7,
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const NeoBadge(
                            'MOBILE',
                            tone: NeoTone.acid,
                            rotate: -2,
                          ),
                          const SizedBox(height: 20),
                          const Icon(Icons.phone_android_rounded, size: 58),
                          const SizedBox(height: 16),
                          Text(
                            context.trText(
                              'Offline packs are managed in the mobile app.',
                            ),
                            textAlign: TextAlign.center,
                            style: context.text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
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

class _Storage extends StatelessWidget {
  const _Storage();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StorageViewModel>();
    final sync = vm.sync;
    return Scaffold(
      backgroundColor: context.jc.canvas,
      body: Column(
        children: [
          _StorageHeader(
            subtitle:
                '${StorageViewModel.humanSize(vm.installedBytesTotal)} ${context.trText('on this phone')}',
          ),
          Expanded(
            child: BoundedContent(
              maxWidth: 820,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  context.isWide ? 28 : 18,
                  22,
                  context.isWide ? 28 : 18,
                  34,
                ),
                children: [
                  _StorageSummary(bytes: vm.installedBytesTotal),
                  const SizedBox(height: 24),
                  NeoSectionTitle(
                    context.trText('Dictionary packs'),
                    trailing: _UpdateButton(vm: vm),
                  ),
                  NeoCard(
                    shadow: 5,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var index = 0;
                            index < vm.rows.length;
                            index++) ...[
                          if (index > 0) const _HardDivider(),
                          _PackPanelRow(row: vm.rows[index]),
                        ],
                      ],
                    ),
                  ),
                  if (vm.updateError != null) ...[
                    const SizedBox(height: 12),
                    NeoCard(
                      tone: NeoTone.coral,
                      shadow: 0,
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.trText(
                                "Can't reach the server right now.",
                              ),
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
                  if (sync != null) ...[
                    const SizedBox(height: 26),
                    NeoSectionTitle(context.trText('Study sync')),
                    _SyncPanel(sync: sync, vm: vm),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.jc.surface,
                      border: Border.all(color: context.jc.ink, width: 2.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      context.trText(
                        'Dictionary data © EDRDG (JMdict, KANJIDIC2, JMnedict) under the EDRDG licence · stroke order © KanjiVG (CC BY-SA 3.0) · examples © Tatoeba (CC-BY) · pitch accent © Kanjium.',
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.jc.body,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageHeader extends StatelessWidget {
  const _StorageHeader({required this.subtitle});
  final String subtitle;

  @override
  Widget build(BuildContext context) => NeoPageHeader(
        title: context.trText('Offline & storage'),
        subtitle: subtitle,
        tone: NeoTone.blue,
        leading: NeoIconButton(
          icon: Icons.arrow_back_rounded,
          label: context.trText('Back'),
          onTap: () => Navigator.of(context).maybePop(),
        ),
        trailing: const NeoBadge(
          'OFFLINE',
          tone: NeoTone.acid,
          icon: Icons.offline_bolt_rounded,
        ),
      );
}

class _StorageSummary extends StatelessWidget {
  const _StorageSummary({required this.bytes});
  final int bytes;

  @override
  Widget build(BuildContext context) => NeoCard(
        tone: NeoTone.acid,
        shadow: 6,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.jc.surface,
                border: Border.all(color: context.jc.ink, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.sd_storage_rounded, size: 29),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    StorageViewModel.humanSize(bytes),
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.trText('of dictionary data on this phone'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const NeoBadge('LOCAL', tone: NeoTone.paper),
          ],
        ),
      );
}

class _UpdateButton extends StatelessWidget {
  const _UpdateButton({required this.vm});
  final StorageViewModel vm;

  @override
  Widget build(BuildContext context) => NeoCard(
        tone: vm.updateError == null ? NeoTone.paper : NeoTone.coral,
        shadow: vm.checking ? 0 : 3,
        radius: 9,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        onTap: vm.checking ? null : vm.checkUpdates,
        semanticLabel: context.trText('Check for updates'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (vm.checking)
              const NeoChaseLoader(
                size: 16,
                blockSize: 7,
                borderWidth: 1.3,
                radius: 2,
                shadow: 1,
              )
            else
              const Icon(Icons.refresh_rounded, size: 17),
            const SizedBox(width: 6),
            Text(
              context.trText(vm.checking ? 'Checking' : 'Check'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
}

class _PackPanelRow extends StatelessWidget {
  const _PackPanelRow({required this.row});
  final PackRow row;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<StorageViewModel>();
    final progress = row.progress;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: row.updateAvailable
                  ? context.jc.magenta
                  : row.isInstalled
                      ? context.jc.lime
                      : context.jc.lavender,
              border: Border.all(color: context.jc.ink, width: 2.5),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(_iconFor(row.id), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    if (row.updateAvailable) ...[
                      const SizedBox(width: 8),
                      const NeoBadge('NEW', tone: NeoTone.magenta),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (progress == null)
                  Text(
                    row.subtitle,
                    style: TextStyle(
                      color: context.jc.body,
                      fontSize: 11.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else ...[
                  Text(
                    context.trText('Downloading…'),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _DownloadProgress(
                    value: progress.phase == 'downloading'
                        ? progress.fraction
                        : null,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _PackAction(row: row, vm: vm),
        ],
      ),
    );
  }

  IconData _iconFor(String id) => switch (id) {
        basePackId => Icons.smartphone_rounded,
        'names' => Icons.badge_outlined,
        _ when id.startsWith('examples-') => Icons.notes_rounded,
        _ when id.startsWith('mnemonics-') => Icons.brush_outlined,
        _ => Icons.translate_rounded,
      };
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.value});
  final double? value;

  @override
  Widget build(BuildContext context) => Container(
        height: 12,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          border: Border.all(color: context.jc.ink, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: LinearProgressIndicator(
          value: value,
          color: context.jc.brand,
          backgroundColor: context.jc.surface,
        ),
      );
}

class _PackAction extends StatelessWidget {
  const _PackAction({required this.row, required this.vm});
  final PackRow row;
  final StorageViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (row.progress != null) {
      return _SmallAction(
        icon: Icons.close_rounded,
        label: context.trText('Cancel'),
        tone: NeoTone.coral,
        onTap: () => vm.cancel(row.id),
      );
    }
    if (row.updateAvailable) {
      return _SmallAction(
        icon: Icons.system_update_alt_rounded,
        label: context.trText('Update'),
        tone: NeoTone.magenta,
        onTap: () => vm.download(row.id),
      );
    }
    if (row.canDownload) {
      return _SmallAction(
        icon: Icons.download_rounded,
        label: context.trText('Download'),
        tone: NeoTone.acid,
        onTap: () => vm.download(row.id),
      );
    }
    if (row.canDelete) {
      return _SmallAction(
        icon: Icons.delete_outline_rounded,
        label: context.trText('Delete'),
        onTap: () => _confirmDelete(context),
      );
    }
    if (row.isInstalled) {
      return const Icon(Icons.check_circle_rounded, size: 24);
    }
    return const SizedBox.shrink();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: NeoCard(
            tone: NeoTone.lavender,
            shadow: 7,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NeoBadge('DELETE', tone: NeoTone.coral, rotate: -2),
                const SizedBox(height: 16),
                Text(
                  context.trText('Delete ${row.title}?'),
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.trText(
                    'The built-in essentials keep working; you can download this pack again anytime.',
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
                        tone: NeoTone.coral,
                        shadow: 4,
                        onTap: () => Navigator.pop(dialogContext, true),
                        child: Center(
                          child: Text(
                            context.trText('Delete'),
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
    if (confirmed == true) await vm.delete(row.id);
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = NeoTone.paper,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final NeoTone tone;

  @override
  Widget build(BuildContext context) => NeoCard(
        tone: tone,
        shadow: onTap == null ? 0 : 2,
        radius: 8,
        padding: const EdgeInsets.all(9),
        onTap: onTap,
        semanticLabel: label,
        child: Icon(icon, size: 18),
      );
}

class _SyncPanel extends StatelessWidget {
  const _SyncPanel({required this.sync, required this.vm});
  final SyncEngine sync;
  final StorageViewModel vm;

  @override
  Widget build(BuildContext context) {
    final problem = sync.conflict != null ||
        sync.lastError != null ||
        sync.pendingCount > 0 ||
        !sync.online;
    final title = sync.conflict != null
        ? 'Choose which progress to keep'
        : !sync.online
            ? 'Sync paused while offline'
            : sync.lastError != null
                ? 'Last sync attempt failed'
                : sync.pendingCount > 0
                    ? '${sync.pendingCount} changes waiting to upload'
                    : 'Everything synced';
    return NeoCard(
      tone: problem ? NeoTone.lavender : NeoTone.lime,
      shadow: 5,
      padding: const EdgeInsets.all(16),
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
            child: Icon(
              sync.conflict != null
                  ? Icons.sync_problem_rounded
                  : !sync.online
                      ? Icons.cloud_off_rounded
                      : sync.pendingCount > 0
                          ? Icons.cloud_upload_rounded
                          : Icons.cloud_done_rounded,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.trText(title),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_lastSynced(sync)}\n${_gap(sync)}',
                  style: TextStyle(
                    color: context.jc.body,
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (sync.syncing)
            const NeoChaseLoader.small()
          else
            _SmallAction(
              icon: sync.conflict != null
                  ? Icons.call_split_rounded
                  : Icons.sync_rounded,
              label: context.trText(
                sync.conflict != null ? 'Resolve' : 'Sync now',
              ),
              tone: NeoTone.acid,
              onTap: !sync.online
                  ? null
                  : () {
                      if (sync.conflict != null) {
                        showSyncConflictDialog(context, sync);
                      } else {
                        vm.syncNow();
                      }
                    },
            ),
        ],
      ),
    );
  }

  String _lastSynced(SyncEngine sync) {
    final at = sync.lastSyncedAt;
    if (at == null) return 'Not synced yet';
    final delta = DateTime.now().toUtc().difference(at.toUtc());
    if (delta.inMinutes < 1) return 'Last synced just now';
    if (delta.inHours < 1) return 'Last synced ${delta.inMinutes} min ago';
    if (delta.inDays < 1) return 'Last synced ${delta.inHours} h ago';
    return 'Last synced ${delta.inDays} d ago';
  }

  String _gap(SyncEngine sync) {
    if (sync.pendingCount == 0) return 'Sync gap: 0 local changes';
    final oldest = sync.oldestPendingAt;
    if (oldest == null) return 'Sync gap: ${sync.pendingCount} local changes';
    final age = DateTime.now().toUtc().difference(oldest.toUtc());
    final value = age.inDays > 0
        ? '${age.inDays} d'
        : age.inHours > 0
            ? '${age.inHours} h'
            : '${age.inMinutes} min';
    return 'Sync gap: ${sync.pendingCount} local changes, oldest $value';
  }
}

class _HardDivider extends StatelessWidget {
  const _HardDivider();

  @override
  Widget build(BuildContext context) => Container(
        height: 2.5,
        color: context.jc.ink,
      );
}
