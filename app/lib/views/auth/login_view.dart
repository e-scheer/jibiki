import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/dev_login.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/auth_viewmodel.dart';

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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('字', style: TextStyle(fontSize: 56, color: context.jc.brand, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text('Welcome back', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                      validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                      validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (vm.hasError) ...[
                      const SizedBox(height: 12),
                      Text(vm.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    if (DevLogin.enabled) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('DEV',
                              style: TextStyle(
                                  color: context.jc.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final a in DevLogin.accounts)
                                  ActionChip(
                                    label: Text(a.label),
                                    onPressed: () {
                                      Haptics.tick();
                                      _fill(a);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: vm.isLoading ? null : _submit,
                      child: vm.isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: const Text("New here? Create an account"),
                    ),
                    // The paid app works fully offline; an account only adds
                    // sync + community. Signing up later uploads the whole
                    // local history, nothing is lost by starting here.
                    TextButton(
                      onPressed: () =>
                          context.read<AppState>().continueWithoutAccount(),
                      child: const Text('Continue without an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
