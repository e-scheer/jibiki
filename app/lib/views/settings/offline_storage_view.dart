import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../infrastructure/packs/pack_manager.dart';
import '../../sync/sync_engine.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/storage_viewmodel.dart';
import '../widgets/sync_conflict_gate.dart';

/// Offline & storage: what lives on the phone (packs, sizes, updates) and the
/// study-sync status - the one place that makes the offline story visible.
class OfflineStorageView extends StatelessWidget {
  const OfflineStorageView({super.key});

  @override
  Widget build(BuildContext context) {
    final packs = context.read<PackManager?>();
    if (packs == null) {
      // Web: no local packs, nothing to manage.
      return Scaffold(
        appBar: AppBar(title: const Text('Offline & storage')),
        body: const Center(
            child: Text('Offline packs are managed in the mobile app.')),
      );
    }
    return ChangeNotifierProvider(
      create: (ctx) =>
          StorageViewModel(packs, ctx.read<SyncEngine?>())..checkUpdates(),
      child: const _Storage(),
    );
  }
}

class _Storage extends StatelessWidget {
  const _Storage();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StorageViewModel>();
    final jc = context.jc;
    final sync = vm.sync;

    return Scaffold(
      appBar: AppBar(title: const Text('Offline & storage')),
      body: BoundedContent(
        maxWidth: 640,
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.sd_storage_outlined),
              title: const Text('On this phone'),
              subtitle: Text(
                  '${StorageViewModel.humanSize(vm.installedBytesTotal)} of dictionary data'),
            ),
            const Divider(),
            _section(context, 'Dictionary packs'),
            for (final row in vm.rows) _PackTile(row: row),
            ListTile(
              leading: vm.checking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              title: const Text('Check for updates'),
              subtitle: vm.updateError != null
                  ? Text("Can't reach the server right now.",
                      style: TextStyle(color: jc.muted))
                  : null,
              onTap: vm.checking ? null : vm.checkUpdates,
            ),
            if (sync != null) ...[
              const Divider(),
              _section(context, 'Study sync'),
              ListTile(
                leading: Icon(
                  sync.conflict != null
                      ? Icons.sync_problem_outlined
                      : !sync.online
                          ? Icons.cloud_off_outlined
                          : sync.lastError != null
                              ? Icons.sync_problem_outlined
                              : sync.pendingCount > 0
                                  ? Icons.cloud_upload_outlined
                                  : Icons.cloud_done_outlined,
                  color: sync.conflict != null ||
                          sync.lastError != null ||
                          sync.pendingCount > 0
                      ? jc.brand
                      : jc.muted,
                ),
                title: Text(
                  sync.conflict != null
                      ? 'Choose which progress to keep'
                      : !sync.online
                          ? 'Sync paused while offline'
                          : sync.lastError != null
                              ? 'Last sync attempt failed'
                              : sync.pendingCount > 0
                                  ? '${sync.pendingCount} changes waiting to upload'
                                  : 'Everything synced',
                ),
                subtitle: Text('${_lastSynced(sync)}\n${_gap(sync)}'),
                isThreeLine: true,
                trailing: sync.syncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(
                        onPressed: !sync.online
                            ? null
                            : sync.conflict != null
                                ? () => showSyncConflictDialog(context, sync)
                                : () => vm.syncNow(),
                        child: Text(
                            sync.conflict != null ? 'Resolve' : 'Sync now')),
              ),
            ],
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Dictionary data © EDRDG (JMdict, KANJIDIC2, JMnedict) under the '
                'EDRDG licence · stroke order © KanjiVG (CC BY-SA 3.0) · examples '
                '© Tatoeba (CC-BY) · pitch accent © Kanjium.',
                style: TextStyle(fontSize: 11, color: jc.muted, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
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

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: context.jc.muted)),
      );
}

class _PackTile extends StatelessWidget {
  const _PackTile({required this.row});

  final PackRow row;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<StorageViewModel>();
    final jc = context.jc;
    final progress = row.progress;

    return ListTile(
      leading: Icon(
        switch (row.id) {
          basePackId => Icons.smartphone,
          'names' => Icons.badge_outlined,
          _ when row.id.startsWith('examples-') => Icons.notes_outlined,
          _ when row.id.startsWith('mnemonics-') => Icons.brush_outlined,
          _ => Icons.translate,
        },
        color: row.isInstalled ? jc.brand : jc.muted,
      ),
      title: Text(row.title),
      subtitle: progress != null
          ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                value:
                    progress.phase == 'downloading' ? progress.fraction : null,
                minHeight: 4,
              ),
            )
          : Text(row.subtitle, style: const TextStyle(fontSize: 12)),
      trailing: _trailing(context, vm),
    );
  }

  Widget? _trailing(BuildContext context, StorageViewModel vm) {
    final jc = context.jc;
    final progress = row.progress;
    if (progress != null) {
      return IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel',
        onPressed: () => vm.cancel(row.id),
      );
    }
    if (row.updateAvailable) {
      return TextButton(
        onPressed: () => vm.download(row.id),
        child: const Text('Update'),
      );
    }
    if (row.canDownload) {
      return IconButton(
        icon: Icon(Icons.download_outlined, color: jc.brand),
        tooltip: 'Download',
        onPressed: () => vm.download(row.id),
      );
    }
    if (row.canDelete) {
      return IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete',
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Delete ${row.title}?'),
              content: const Text(
                  'The built-in essentials keep working; you can download this pack again anytime.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete')),
              ],
            ),
          );
          if (confirmed == true) await vm.delete(row.id);
        },
      );
    }
    if (row.isInstalled) {
      return Icon(Icons.check_circle, color: jc.brand, size: 20);
    }
    return null;
  }
}
