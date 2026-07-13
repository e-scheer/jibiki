import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../repositories/auth_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_recovery_viewmodel.dart';
import '../widgets/jibiki_brand.dart';
import '../widgets/neo_pop.dart';
import 'auth_chrome.dart';

class VerifyEmailView extends StatelessWidget {
  const VerifyEmailView({super.key, required this.verificationKey});

  final String verificationKey;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (context) =>
            AuthRecoveryViewModel(context.read<AuthRepository>()),
        child: _VerifyEmailContent(verificationKey: verificationKey),
      );
}

class _VerifyEmailContent extends StatefulWidget {
  const _VerifyEmailContent({required this.verificationKey});

  final String verificationKey;

  @override
  State<_VerifyEmailContent> createState() => _VerifyEmailContentState();
}

class _VerifyEmailContentState extends State<_VerifyEmailContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context
            .read<AuthRecoveryViewModel>()
            .inspectEmailLink(widget.verificationKey);
      }
    });
  }

  void _backToSignIn() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthRecoveryViewModel>();
    return AuthChrome(
      eyebrow: context.l10n.verifyEmailEyebrow,
      headline: context.l10n.verifyEmailHeadline,
      description: context.l10n.verifyEmailDescription,
      onBack: vm.isLoading ? null : _backToSignIn,
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.verifyEmailTitle,
            style: context.text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 20),
          switch (vm.linkState) {
            AuthRecoveryLinkState.unchecked ||
            AuthRecoveryLinkState.checking =>
              _checking(context),
            AuthRecoveryLinkState.ready => _ready(context, vm),
            AuthRecoveryLinkState.unavailable => _unavailable(context, vm),
            AuthRecoveryLinkState.complete => _complete(context),
          },
        ],
      ),
    );
  }

  Widget _checking(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthStatusPanel(
            icon: Icons.mark_email_unread_outlined,
            title: context.l10n.verifyEmailCheckingTitle,
            description: context.l10n.verifyEmailCheckingBody,
          ),
          const SizedBox(height: 24),
          Center(
            child: NeoChaseLoader.small(
              semanticLabel: context.l10n.verifyEmailCheckingTitle,
            ),
          ),
        ],
      );

  Widget _ready(BuildContext context, AuthRecoveryViewModel vm) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthStatusPanel(
            icon: Icons.verified_outlined,
            title: context.l10n.verifyEmailReadyTitle,
            description: context.l10n.verifyEmailReadyBody,
            tone: NeoTone.lime,
          ),
          if (vm.hasError) ...[
            const SizedBox(height: 16),
            AuthInlineError(vm.error!),
          ],
          const SizedBox(height: 24),
          NeoPrimaryButton(
            key: const ValueKey('verify-email-button'),
            label: context.l10n.verifyEmailAction,
            icon: Icons.mark_email_read_outlined,
            busy: vm.isLoading,
            onTap: () => vm.verifyEmail(widget.verificationKey),
          ),
        ],
      );

  Widget _unavailable(
    BuildContext context,
    AuthRecoveryViewModel vm,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthStatusPanel(
            icon: Icons.link_off_rounded,
            title: context.l10n.authLinkUnavailableTitle,
            description: context.l10n.authLinkUnavailableBody,
            tone: NeoTone.coral,
          ),
          const SizedBox(height: 24),
          NeoPrimaryButton(
            key: const ValueKey('verify-email-retry-button'),
            label: context.l10n.authCheckAgain,
            icon: Icons.refresh_rounded,
            busy: vm.isLoading,
            onTap: () => vm.inspectEmailLink(widget.verificationKey),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _backToSignIn,
            child: Text(context.l10n.authBackToSignIn),
          ),
        ],
      );

  Widget _complete(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthStatusPanel(
            icon: Icons.check_circle_outline_rounded,
            title: context.l10n.verifyEmailSuccessTitle,
            description: context.l10n.verifyEmailSuccessBody,
            tone: NeoTone.lime,
          ),
          const SizedBox(height: 24),
          NeoPrimaryButton(
            key: const ValueKey('verify-email-continue-button'),
            label: context.l10n.authContinueToSignIn,
            icon: Icons.arrow_forward_rounded,
            onTap: _backToSignIn,
          ),
        ],
      );
}
