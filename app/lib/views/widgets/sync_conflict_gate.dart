import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../sync/sync_engine.dart';

class SyncConflictGate extends StatefulWidget {
  const SyncConflictGate({super.key, required this.sync, required this.child});

  final SyncEngine? sync;
  final Widget child;

  @override
  State<SyncConflictGate> createState() => _SyncConflictGateState();
}

class _SyncConflictGateState extends State<SyncConflictGate> {
  SyncConflict? _presented;

  @override
  void initState() {
    super.initState();
    widget.sync?.addListener(_onSyncChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSyncChanged());
  }

  @override
  void didUpdateWidget(SyncConflictGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sync != widget.sync) {
      oldWidget.sync?.removeListener(_onSyncChanged);
      widget.sync?.addListener(_onSyncChanged);
      _presented = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _onSyncChanged());
    }
  }

  void _onSyncChanged() {
    if (!mounted) return;
    final conflict = widget.sync?.conflict;
    if (conflict == null) {
      _presented = null;
      return;
    }
    if (identical(conflict, _presented)) return;
    _presented = conflict;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.sync?.conflict != conflict) return;
      await showSyncConflictDialog(context, widget.sync!);
    });
  }

  @override
  void dispose() {
    widget.sync?.removeListener(_onSyncChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> showSyncConflictDialog(
  BuildContext context,
  SyncEngine sync,
) async {
  final conflict = sync.conflict;
  if (conflict == null) return;
  final anotherAccount = conflict.belongsToAnotherAccount;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        anotherAccount
            ? 'Data from another account'
            : 'Choose which progress to keep',
      ),
      content: Text(
        anotherAccount
            ? 'This device still contains progress linked to another account. '
                'It cannot be uploaded to the account you just opened. You can '
                'load this account from the cloud or stay offline for now.'
            : 'This device has ${conflict.localCards} cards and '
                '${conflict.localReviews} reviews. The cloud has '
                '${conflict.cloudCards} cards and ${conflict.cloudReviews} reviews.\n\n'
                'Keeping one version replaces the other. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(context.trText('Not now')),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.cloud_outlined),
          label: Text(context.trText('Keep cloud')),
          onPressed: () async {
            Navigator.pop(dialogContext);
            await sync.resolveConflict(SyncResolution.cloud);
          },
        ),
        if (!anotherAccount)
          FilledButton.icon(
            icon: const Icon(Icons.phone_android_outlined),
            label: Text(context.trText('Keep this device')),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await sync.resolveConflict(SyncResolution.local);
            },
          ),
      ],
    ),
  );
}
