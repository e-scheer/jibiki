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
    // Settings, report sheets and other signed-in entry points push this
    // screen. In that case "continue" means cancel the optional sign-in,
    // not changing the current local/account state.
    if (context.canPop()) {
      context.pop();
      return;
    }
    await context.read<AppState>().continueWithoutAccount();
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
      onBack: context.canPop() ? () => context.pop() : null,
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    context.trText('Sign in'),
                    style: context.text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const JibikiBrandMark(size: 52),
              ],
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
                            onTap: () => _fill(account),
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
              onTap: () => context.go('/register'),
              child: Center(
                child: Text(
                  context.trText('New here? Create an account'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: vm.isLoading ? null : _continueWithoutAccount,
              child: Text(context.trText('Continue without an account')),
            ),
          ],
        ),
      ),
    );
  }
}
