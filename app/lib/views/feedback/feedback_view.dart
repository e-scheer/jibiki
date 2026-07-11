import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../infrastructure/packs/pack_manager.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/feedback_viewmodel.dart';

/// The feedback space: ideas, bugs, love letters. Deliberately warm and
/// zero-friction - one tap on a kind, one field, and the diagnostics ride
/// along automatically (and visibly, which is why people trust it).
class FeedbackView extends StatelessWidget {
  const FeedbackView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => FeedbackViewModel(
        ctx.read<FeedbackService>(),
        ctx.read<AppState>(),
        ctx.read<PackManager?>(),
      ),
      child: const _Feedback(),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FeedbackViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Make jibiki better')),
      body: BoundedContent(
        maxWidth: 640,
        child: vm.sent ? const _ThankYou() : const _Form(),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FeedbackViewModel>();
    final jc = context.jc;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Ideas, bugs, love letters - a human reads every single one.',
            style: TextStyle(color: jc.muted, height: 1.4)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in FeedbackKind.values)
              ChoiceChip(
                label: Text('${kind.emoji}  ${kind.label}'),
                selected: vm.kind == kind,
                onSelected: (_) => vm.selectKind(kind),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          autofocus: true,
          minLines: 5,
          maxLines: 12,
          maxLength: 4000,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: vm.kind.prompt,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md)),
            counterText: '',
          ),
          onChanged: vm.setMessage,
        ),
        if (vm.wantsEmailField) ...[
          const SizedBox(height: 12),
          TextField(
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Email - only if you’d like a reply (optional)',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md)),
            ),
            onChanged: vm.setEmail,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, size: 16, color: jc.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sent along for context: ${_contextLine(vm)} - nothing else.',
                style: TextStyle(fontSize: 12, color: jc.muted, height: 1.4),
              ),
            ),
          ],
        ),
        if (vm.error != null) ...[
          const SizedBox(height: 12),
          Text(
            "Couldn't send - you might be offline. Your message is safe here; "
            'try again once connected.',
            style: TextStyle(color: jc.ratingAgain, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: jc.brand),
          onPressed: vm.canSubmit ? vm.submit : null,
          child: vm.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Send'),
        ),
      ],
    );
  }

  String _contextLine(FeedbackViewModel vm) {
    final ctx = vm.context;
    final packs = (ctx['packs'] as List).length;
    return '${ctx['platform']}, $packs pack${packs == 1 ? '' : 's'} installed, app state';
  }
}

class _ThankYou extends StatelessWidget {
  const _ThankYou();

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, color: jc.brand, size: 56),
            const SizedBox(height: 16),
            Text('Thank you!',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('We read everything. It genuinely shapes what gets built next.',
                textAlign: TextAlign.center, style: TextStyle(color: jc.muted)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
