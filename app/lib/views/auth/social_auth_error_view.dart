import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../viewmodels/app_state.dart';
import '../widgets/neo_pop.dart';
import 'auth_chrome.dart';

class SocialAuthErrorView extends StatelessWidget {
  const SocialAuthErrorView({
    super.key,
    required this.errorCode,
    required this.errorProcess,
  });

  final String? errorCode;
  final String? errorProcess;

  @override
  Widget build(BuildContext context) {
    final copy = _copyFor(context, errorCode);
    final app = context.watch<AppState>();
    final reconnecting = errorProcess == 'connect';
    final loginLocation = reconnecting ? '/login?link=1' : '/login';
    return AuthChrome(
      eyebrow: context.l10n.socialAuthEyebrow,
      headline: context.l10n.socialAuthHeadline,
      description: context.l10n.socialAuthDescription,
      onBack: () => context.go(app.canEnter ? '/' : '/login'),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthStatusPanel(
            icon: copy.icon,
            title: copy.title,
            description: copy.description,
            tone: copy.tone,
          ),
          const SizedBox(height: 24),
          NeoPrimaryButton(
            key: const ValueKey('social-auth-retry-button'),
            label: context.l10n.trySignInAgain,
            icon: Icons.refresh_rounded,
            onTap: () => context.go(loginLocation),
          ),
          if (app.canEnter) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/'),
              child: Text(context.l10n.returnToJibiki),
            ),
          ],
        ],
      ),
    );
  }

  _SocialAuthCopy _copyFor(BuildContext context, String? code) =>
      switch (code) {
        'cancelled' => _SocialAuthCopy(
            Icons.cancel_outlined,
            context.l10n.socialAuthCancelledTitle,
            context.l10n.socialAuthCancelledBody,
            NeoTone.lavender,
          ),
        'denied' || 'permission_denied' => _SocialAuthCopy(
            Icons.shield_outlined,
            context.l10n.socialAuthDeniedTitle,
            context.l10n.socialAuthDeniedBody,
            NeoTone.coral,
          ),
        'reauthentication_required' => _SocialAuthCopy(
            Icons.lock_clock_outlined,
            context.l10n.socialAuthReauthenticationTitle,
            context.l10n.socialAuthReauthenticationBody,
            NeoTone.lavender,
          ),
        'signup_closed' => _SocialAuthCopy(
            Icons.person_off_outlined,
            context.l10n.socialAuthSignupClosedTitle,
            context.l10n.socialAuthSignupClosedBody,
            NeoTone.coral,
          ),
        _ => _SocialAuthCopy(
            Icons.sync_problem_outlined,
            context.l10n.socialAuthUnknownTitle,
            context.l10n.socialAuthUnknownBody,
            NeoTone.coral,
          ),
      };
}

class _SocialAuthCopy {
  const _SocialAuthCopy(this.icon, this.title, this.description, this.tone);

  final IconData icon;
  final String title;
  final String description;
  final NeoTone tone;
}
