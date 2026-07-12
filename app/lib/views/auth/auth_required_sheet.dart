import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../widgets/jibiki_brand.dart';
import '../widgets/neo_pop.dart';

/// Keeps the learner on the current surface when an account-only action is
/// tapped. The route is never replaced by a dead-end login screen.
Future<void> showAuthRequiredSheet(
  BuildContext context, {
  String? title,
  String? description,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: NeoCard(
          tone: NeoTone.lavender,
          shadow: 7,
          radius: 16,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const JibikiBrandMark(size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title ?? context.trText('Make this yours'),
                      style: context.text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  NeoIconButton(
                    icon: Icons.close_rounded,
                    label: context.trText('Close'),
                    onTap: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description ??
                    context.trText(
                      'Sign in to save progress, sync this action and keep it with you everywhere.',
                    ),
                style: TextStyle(
                  color: context.jc.body,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              NeoPrimaryButton(
                label: context.trText('Sign in'),
                icon: Icons.arrow_forward_rounded,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/login');
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(context.trText('Not now')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AuthRequiredPanel extends StatelessWidget {
  const AuthRequiredPanel({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.lock_outline_rounded,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: NeoCard(
              tone: NeoTone.lavender,
              shadow: 6,
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.jc.acid,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: context.jc.ink, width: 2.5),
                    ),
                    child: Icon(icon, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.jc.body,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  NeoPrimaryButton(
                    label: context.trText('Sign in'),
                    icon: Icons.arrow_forward_rounded,
                    onTap: () => showAuthRequiredSheet(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
