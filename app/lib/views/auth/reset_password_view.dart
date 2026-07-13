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

class ResetPasswordView extends StatelessWidget {
  const ResetPasswordView({super.key, this.resetKey});

  final String? resetKey;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (context) =>
            AuthRecoveryViewModel(context.read<AuthRepository>()),
        child: _ResetPasswordContent(resetKey: resetKey),
      );
}

class _ResetPasswordContent extends StatefulWidget {
  const _ResetPasswordContent({this.resetKey});

  final String? resetKey;

  @override
  State<_ResetPasswordContent> createState() => _ResetPasswordContentState();
}

class _ResetPasswordContentState extends State<_ResetPasswordContent> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _requestFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  bool get _hasResetKey => widget.resetKey?.isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    if (_hasResetKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context
              .read<AuthRecoveryViewModel>()
              .inspectPasswordLink(widget.resetKey!);
        }
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _backToSignIn() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  Future<void> _requestReset() async {
    if (!_requestFormKey.currentState!.validate()) return;
    await context
        .read<AuthRecoveryViewModel>()
        .requestPasswordReset(_email.text);
  }

  Future<void> _resetPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    await context
        .read<AuthRecoveryViewModel>()
        .resetPassword(widget.resetKey!, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthRecoveryViewModel>();
    return AuthChrome(
      eyebrow: context.l10n.passwordResetEyebrow,
      headline: context.l10n.passwordResetHeadline,
      description: context.l10n.passwordResetDescription,
      onBack: vm.isLoading ? null : _backToSignIn,
      form: _hasResetKey ? _keyFlow(context, vm) : _requestFlow(context, vm),
    );
  }

  Widget _requestFlow(BuildContext context, AuthRecoveryViewModel vm) {
    if (vm.requestSent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthStatusPanel(
            icon: Icons.outgoing_mail,
            title: context.l10n.passwordResetRequestSuccessTitle,
            description: context.l10n.passwordResetRequestSuccessBody,
            tone: NeoTone.lime,
          ),
          const SizedBox(height: 24),
          NeoPrimaryButton(
            key: const ValueKey('reset-request-continue-button'),
            label: context.l10n.authBackToSignIn,
            icon: Icons.arrow_back_rounded,
            onTap: _backToSignIn,
          ),
        ],
      );
    }
    return Form(
      key: _requestFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.passwordResetRequestTitle,
            style: context.text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.passwordResetRequestBody,
            style: TextStyle(
              color: context.jc.body,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          AuthField(
            controller: _email,
            label: context.l10n.emailFieldLabel,
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            enabled: !vm.isLoading,
            validator: (value) => value == null || !value.contains('@')
                ? context.l10n.enterValidEmail
                : null,
            onFieldSubmitted: (_) => _requestReset(),
          ),
          if (vm.hasError) ...[
            const SizedBox(height: 16),
            AuthInlineError(vm.error!),
          ],
          const SizedBox(height: 24),
          NeoPrimaryButton(
            key: const ValueKey('request-reset-button'),
            label: context.l10n.sendResetLink,
            icon: Icons.arrow_forward_rounded,
            busy: vm.isLoading,
            onTap: _requestReset,
          ),
        ],
      ),
    );
  }

  Widget _keyFlow(BuildContext context, AuthRecoveryViewModel vm) =>
      switch (vm.linkState) {
        AuthRecoveryLinkState.unchecked ||
        AuthRecoveryLinkState.checking =>
          _checking(context),
        AuthRecoveryLinkState.ready => _passwordForm(context, vm),
        AuthRecoveryLinkState.unavailable => _unavailable(context, vm),
        AuthRecoveryLinkState.complete => _complete(context),
      };

  Widget _checking(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthStatusPanel(
            icon: Icons.lock_clock_outlined,
            title: context.l10n.passwordResetCheckingTitle,
            description: context.l10n.passwordResetCheckingBody,
          ),
          const SizedBox(height: 24),
          Center(
            child: NeoChaseLoader.small(
              semanticLabel: context.l10n.passwordResetCheckingTitle,
            ),
          ),
        ],
      );

  Widget _passwordForm(BuildContext context, AuthRecoveryViewModel vm) => Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.chooseNewPasswordTitle,
              style: context.text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.chooseNewPasswordBody,
              style: TextStyle(
                color: context.jc.body,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            AuthField(
              controller: _password,
              label: context.l10n.newPasswordFieldLabel,
              icon: Icons.password_rounded,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              enabled: !vm.isLoading,
              validator: (value) => value == null || value.length < 8
                  ? context.l10n.passwordAtLeastEight
                  : null,
            ),
            const SizedBox(height: 18),
            AuthField(
              controller: _confirmation,
              label: context.l10n.confirmPasswordFieldLabel,
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              enabled: !vm.isLoading,
              validator: (value) => value != _password.text
                  ? context.l10n.passwordsDoNotMatch
                  : null,
              onFieldSubmitted: (_) => _resetPassword(),
            ),
            if (vm.hasError) ...[
              const SizedBox(height: 16),
              AuthInlineError(vm.error!),
            ],
            const SizedBox(height: 24),
            NeoPrimaryButton(
              key: const ValueKey('reset-password-button'),
              label: context.l10n.setNewPassword,
              icon: Icons.check_rounded,
              busy: vm.isLoading,
              onTap: _resetPassword,
            ),
          ],
        ),
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
            key: const ValueKey('request-another-reset-button'),
            label: context.l10n.requestAnotherResetLink,
            icon: Icons.mail_outline_rounded,
            busy: vm.isLoading,
            onTap: () => context.go('/reset-password'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => vm.inspectPasswordLink(widget.resetKey!),
            child: Text(context.l10n.authCheckAgain),
          ),
        ],
      );

  Widget _complete(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthStatusPanel(
            icon: Icons.lock_reset_rounded,
            title: context.l10n.passwordResetSuccessTitle,
            description: context.l10n.passwordResetSuccessBody,
            tone: NeoTone.lime,
          ),
          const SizedBox(height: 24),
          NeoPrimaryButton(
            key: const ValueKey('reset-password-continue-button'),
            label: context.l10n.authContinueToSignIn,
            icon: Icons.arrow_forward_rounded,
            onTap: _backToSignIn,
          ),
        ],
      );
}
