import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jibiki/l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../infrastructure/packs/pack_manager.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/feedback_viewmodel.dart';
import '../widgets/neo_pop.dart';

class FeedbackView extends StatelessWidget {
  const FeedbackView({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (ctx) => FeedbackViewModel(
          ctx.read<FeedbackService>(),
          ctx.read<AppState>(),
          ctx.read<PackManager?>(),
        ),
        child: const _Feedback(),
      );
}

class _Feedback extends StatelessWidget {
  const _Feedback();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FeedbackViewModel>();
    return Scaffold(
      backgroundColor: context.jc.canvas,
      body: Column(
        children: [
          NeoPageHeader(
            title: context.trText('Make jibiki better'),
            subtitle: context.trText(
              'Ideas, bugs and love letters land with a real human.',
            ),
            tone: NeoTone.magenta,
            leading: NeoIconButton(
              icon: Icons.arrow_back_rounded,
              label: context.trText('Back'),
              onTap: () => Navigator.of(context).maybePop(),
            ),
            trailing: const NeoBadge(
              'FEEDBACK',
              tone: NeoTone.acid,
              rotate: 2,
            ),
          ),
          Expanded(
            child: BoundedContent(
              maxWidth: 760,
              child: vm.sent ? const _ThankYou() : const _Form(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FeedbackViewModel>();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(context.isWide ? 28 : 18,
          context.isWide ? 28 : 20, context.isWide ? 28 : 18, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NeoCard(
            tone: NeoTone.lavender,
            shadow: 5,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NeoBadge('1', tone: NeoTone.ink),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.trText('What are we looking at?'),
                        style: context.text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        context.trText(
                          'Ideas, bugs, love letters - a human reads every single one.',
                        ),
                        style: TextStyle(
                          color: context.jc.body,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 9,
            runSpacing: 10,
            children: [
              for (final kind in FeedbackKind.values)
                _KindChip(
                  label: context.trText('${kind.emoji}  ${kind.label}'),
                  selected: vm.kind == kind,
                  onSelected: () => vm.selectKind(kind),
                ),
            ],
          ),
          const SizedBox(height: 22),
          NeoSectionTitle(context.trText('Tell us everything')),
          NeoCard(
            padding: const EdgeInsets.all(4),
            shadow: 5,
            child: TextField(
              autofocus: true,
              minLines: 6,
              maxLines: 12,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: vm.kind.prompt,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                counterText: '',
              ),
              onChanged: vm.setMessage,
            ),
          ),
          if (vm.wantsEmailField) ...[
            const SizedBox(height: 16),
            NeoCard(
              padding: const EdgeInsets.all(3),
              shadow: 3,
              child: TextField(
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: context.trText(
                    'Email - only if you’d like a reply (optional)',
                  ),
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                onChanged: vm.setEmail,
              ),
            ),
          ],
          const SizedBox(height: 18),
          NeoCard(
            tone: NeoTone.lime,
            shadow: 0,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, size: 18),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    context.trText(
                      'Sent along for context: ${_contextLine(vm)} - nothing else.',
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (vm.error != null) ...[
            const SizedBox(height: 14),
            const NeoCard(
              tone: NeoTone.coral,
              shadow: 3,
              child: Row(
                children: [
                  Icon(Icons.cloud_off_outlined),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Couldn't send. You might be offline. Your message is safe here; try again once connected.",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          _FeedbackSubmitButton(
            onPressed: vm.canSubmit ? vm.submit : null,
            busy: vm.isLoading,
          ),
        ],
      ),
    );
  }

  String _contextLine(FeedbackViewModel vm) {
    final diagnostics = vm.context;
    final packs = (diagnostics['packs'] as List).length;
    return '${diagnostics['platform']}, $packs pack${packs == 1 ? '' : 's'} installed, app state';
  }
}

class _ThankYou extends StatelessWidget {
  const _ThankYou();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: NeoCard(
              tone: NeoTone.acid,
              shadow: 8,
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: -0.08,
                    child: const NeoCard(
                      tone: NeoTone.magenta,
                      shadow: 4,
                      child: Icon(Icons.favorite_rounded, size: 52),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    context.trText('Thank you!'),
                    style: context.text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.trText(
                      'We read everything. It genuinely shapes what gets built next.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.jc.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  NeoPrimaryButton(
                    label: context.trText('Done'),
                    tone: NeoTone.ink,
                    onTap: () => context.pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: context.jc.ink,
                    blurRadius: 0,
                    offset: const Offset(3, 3),
                  ),
                ]
              : null,
        ),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          selectedColor: context.jc.acid,
          backgroundColor: context.jc.surface,
          side: BorderSide(color: context.jc.ink, width: 2.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
          labelStyle: TextStyle(
            color: context.jc.ink,
            fontWeight: FontWeight.w800,
          ),
          onSelected: (_) => onSelected(),
        ),
      );
}

class _FeedbackSubmitButton extends StatelessWidget {
  const _FeedbackSubmitButton({required this.onPressed, required this.busy});

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: context.jc.ink,
                    blurRadius: 0,
                    offset: const Offset(4, 4),
                  ),
                ],
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: context.jc.acid,
            foregroundColor: context.jc.ink,
            disabledBackgroundColor: context.jc.hairline,
            disabledForegroundColor: context.jc.muted,
            side: BorderSide(color: context.jc.ink, width: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: busy ? null : onPressed,
          child: busy
              ? SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: context.jc.ink,
                  ),
                )
              : Text(
                  context.trText('Send'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      );
}
