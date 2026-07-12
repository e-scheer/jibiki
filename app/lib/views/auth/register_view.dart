import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'auth_chrome.dart';
import '../widgets/neo_pop.dart';

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AuthViewModel(ctx.read<AppState>()),
      child: const _RegisterForm(),
    );
  }
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm();
  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AuthViewModel>().register(_email.text, _password.text);
    // Success → AppState authenticated → router sends to onboarding.
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return AuthChrome(
      eyebrow: context.trText('ONE ACCOUNT'),
      headline: context.trText('Make it yours.'),
      description: context.trText(
        'Keep your progress, your study decks and your finds on every device.',
      ),
      onBack: () => context.go('/login'),
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.trText('Create your account'),
                    style: context.text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const NeoBadge('FREE', tone: NeoTone.lime, rotate: 2),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.trText('Your study progress syncs across devices.'),
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
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) => (v == null || v.length < 8)
                  ? context.trText('Use at least 8 characters')
                  : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (vm.hasError) ...[
              const SizedBox(height: 16),
              AuthInlineError(vm.error!),
            ],
            const SizedBox(height: 24),
            NeoPrimaryButton(
              label: context.trText('Create account'),
              icon: Icons.arrow_forward_rounded,
              tone: NeoTone.acid,
              busy: vm.isLoading,
              onTap: _submit,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 17, color: context.jc.body),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.trText(
                      'Your local data stays available even when you are offline.',
                    ),
                    style: TextStyle(
                      color: context.jc.body,
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
