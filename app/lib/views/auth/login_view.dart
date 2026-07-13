import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/dev_login.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../widgets/jibiki_brand.dart';
import '../widgets/neo_pop.dart';
import 'auth_chrome.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AuthViewModel(ctx.read<AppState>()),
      child: const _LoginForm(),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();
  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _continuingLocally = false;
  String? _localEntryError;

  @override
  void initState() {
    super.initState();
    // Dev builds land with a working test account already filled in.
    if (DevLogin.enabled) _fill(DevLogin.accounts.first);
  }

  void _fill(({String label, String email, String password}) a) {
    setState(() {
      _email.text = a.email;
      _password.text = a.password;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<AuthViewModel>();
    await vm.login(_email.text, _password.text);
    // On success AppState flips to authenticated and the router redirects.
  }

  Future<void> _continueWithoutAccount() async {
    final app = context.read<AppState>();
    // Settings, report sheets and other signed-in entry points push this
    // screen. In that case "continue" means cancel the optional sign-in,
    // not changing the current local/account state. This intent is explicit:
    // a Web history stack is not a reliable proxy for it.
    final linkingAccount =
        GoRouterState.of(context).uri.queryParameters['link'] == '1';
    if (linkingAccount) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
      return;
    }

    // A local learner can arrive here after a reload or a copied /login URL.
    // They are already allowed into the app, so there is nothing to persist.
    if (app.canEnter) {
      context.go('/');
      return;
    }

    setState(() {
      _continuingLocally = true;
      _localEntryError = null;
    });
    try {
      await app.continueWithoutAccount();
      if (!mounted) return;
      // When onboarding was completed in an earlier session the router keeps
      // /login available for account linking. Leave the landing login
      // explicitly so the guest CTA never looks inert on Web.
      context.go('/');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _continuingLocally = false;
        _localEntryError = context.trText(
          'Could not continue without an account. Please try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return AuthChrome(
      eyebrow: context.trText('YOUR SPACE'),
      headline: context.trText('Welcome back.'),
      description: context.trText(
        'Your dictionary, reviews and community picks are waiting for you.',
      ),
      onBack: context.canPop() && !vm.isLoading ? () => context.pop() : null,
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.trText('Sign in'),
              style: context.text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.trText('Pick up exactly where you stopped.'),
              style: TextStyle(
                  color: context.jc.body, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            AuthField(
              controller: _email,
              label: context.trText('Email'),
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              enabled: !vm.isLoading,
              validator: (v) => (v == null || !v.contains('@'))
                  ? context.trText('Enter a valid email')
                  : null,
            ),
            const SizedBox(height: 18),
            AuthField(
              controller: _password,
              label: context.trText('Password'),
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              enabled: !vm.isLoading,
              validator: (v) => (v == null || v.length < 6)
                  ? context.trText('At least 6 characters')
                  : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (vm.hasError) ...[
              const SizedBox(height: 16),
              AuthInlineError(vm.error!),
            ],
            if (DevLogin.enabled) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  NeoBadge(context.trText('DEV'), tone: NeoTone.magenta),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final account in DevLogin.accounts)
                          NeoCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            shadow: 2,
                            radius: 8,
                            onTap: vm.isLoading ? null : () => _fill(account),
                            child: Text(
                              account.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            NeoPrimaryButton(
              label: context.trText('Sign in'),
              icon: Icons.arrow_forward_rounded,
              tone: NeoTone.acid,
              busy: vm.isLoading,
              onTap: _submit,
            ),
            const SizedBox(height: 14),
            NeoCard(
              shadow: 3,
              radius: 10,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              onTap: vm.isLoading ? null : () => context.go('/register'),
              child: Center(
                child: Text(
                  context.trText('New here? Create an account'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: vm.isLoading || _continuingLocally
                  ? null
                  : _continueWithoutAccount,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _continuingLocally
                    ? NeoChaseLoader.small(
                        key: const ValueKey('local-entry-loader'),
                        semanticLabel: context.trText('Opening local mode'),
                      )
                    : Text(
                        context.trText('Continue without an account'),
                        key: const ValueKey('local-entry-label'),
                      ),
              ),
            ),
            if (_localEntryError != null) ...[
              const SizedBox(height: 8),
              AuthInlineError(_localEntryError!),
            ],
          ],
        ),
      ),
    );
  }
}
