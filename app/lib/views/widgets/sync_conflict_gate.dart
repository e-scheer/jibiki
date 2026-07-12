import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../sync/sync_engine.dart';
import '../../theme/app_theme.dart';
import 'neo_pop.dart';

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
    barrierColor: context.jc.ink.withValues(alpha: 0.62),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: NeoCard(
          tone: anotherAccount ? NeoTone.coral : NeoTone.lavender,
          shadow: 6,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: dialogContext.jc.surface,
                      borderRadius: BorderRadius.circular(11),
                      border:
                          Border.all(color: dialogContext.jc.ink, width: 2.5),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      anotherAccount
                          ? Icons.person_off_outlined
                          : Icons.sync_problem_outlined,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      anotherAccount
                          ? 'Data from another account'
                          : 'Choose which progress to keep',
                      style: dialogContext.text.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900, height: 1.05),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: dialogContext.jc.surface,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: dialogContext.jc.ink, width: 2.5),
                ),
                child: Text(
                  anotherAccount
                      ? 'This device still contains progress linked to another account. '
                          'It cannot be uploaded to the account you just opened. You can '
                          'load this account from the cloud or stay offline for now.'
                      : 'This device has ${conflict.localCards} cards and '
                          '${conflict.localReviews} reviews. The cloud has '
                          '${conflict.cloudCards} cards and ${conflict.cloudReviews} reviews.\n\n'
                          'Keeping one version replaces the other. This cannot be undone.',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              NeoPrimaryButton(
                label: context.trText('Keep cloud'),
                icon: Icons.cloud_outlined,
                tone: NeoTone.blue,
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await sync.resolveConflict(SyncResolution.cloud);
                },
              ),
              if (!anotherAccount) ...[
                const SizedBox(height: 10),
                NeoPrimaryButton(
                  label: context.trText('Keep this device'),
                  icon: Icons.phone_android_outlined,
                  tone: NeoTone.acid,
                  onTap: () async {
                    Navigator.pop(dialogContext);
                    await sync.resolveConflict(SyncResolution.local);
                  },
                ),
              ],
              const SizedBox(height: 10),
              NeoPrimaryButton(
                label: context.trText('Not now'),
                tone: NeoTone.paper,
                onTap: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
