import 'package:flutter/material.dart';

import '../../core/breakpoints.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../widgets/jibiki_brand.dart';
import '../widgets/neo_pop.dart';

/// Shared NeoPop stage for the two account entry points.
///
/// The compact layout uses the same blue masthead and overlapping paper card as
/// the HTML exploration. On tablets the masthead becomes a permanent editorial
/// panel instead of stretching the form across the screen.
class AuthChrome extends StatelessWidget {
  const AuthChrome({
    super.key,
    required this.eyebrow,
    required this.headline,
    required this.description,
    required this.form,
    this.onBack,
  });

  final String eyebrow;
  final String headline;
  final String description;
  final Widget form;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
    return Scaffold(
      backgroundColor: context.jc.canvas,
      body: SafeArea(
        child: wide ? _wide(context) : _compact(context),
      ),
    );
  }

  Widget _wide(BuildContext context) => Row(
        children: [
          Expanded(
            flex: 9,
            child: SizedBox.expand(
              child: _BrandPanel(
                eyebrow: eyebrow,
                headline: headline,
                description: description,
                onBack: onBack,
                expanded: true,
              ),
            ),
          ),
          Expanded(
            flex: 11,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: NeoCard(
                    shadow: 8,
                    radius: 16,
                    padding: const EdgeInsets.all(28),
                    child: form,
                  ),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _compact(BuildContext context) => SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 300,
              width: double.infinity,
              child: _BrandPanel(
                eyebrow: eyebrow,
                headline: headline,
                description: description,
                onBack: onBack,
                expanded: false,
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -50),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: NeoCard(
                  shadow: 7,
                  radius: 16,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                  child: form,
                ),
              ),
            ),
          ],
        ),
      );
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({
    required this.eyebrow,
    required this.headline,
    required this.description,
    required this.expanded,
    this.onBack,
  });

  final String eyebrow;
  final String headline;
  final String description;
  final bool expanded;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: jc.brand,
        border: Border(
          right:
              expanded ? BorderSide(color: jc.ink, width: 3) : BorderSide.none,
          bottom:
              expanded ? BorderSide.none : BorderSide(color: jc.ink, width: 3),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: expanded ? 34 : 20,
            top: expanded ? 42 : 24,
            child: Transform.rotate(
              angle: 0.16,
              child: Container(
                width: expanded ? 34 : 24,
                height: expanded ? 34 : 24,
                decoration: BoxDecoration(
                  color: jc.magenta,
                  border: Border.all(color: jc.ink, width: 3),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
          Positioned(
            right: expanded ? 82 : 58,
            top: expanded ? 96 : 63,
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: expanded ? 80 : 54,
                height: 18,
                decoration: BoxDecoration(
                  color: jc.acid,
                  border: Border.all(color: jc.ink, width: 3),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              expanded ? 44 : 18,
              expanded ? 42 : 16,
              expanded ? 42 : 18,
              expanded ? 48 : 72,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:
                  expanded ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (onBack != null) ...[
                      NeoIconButton(
                        icon: Icons.arrow_back_rounded,
                        label: context.trText('Back'),
                        onTap: onBack!,
                      ),
                      const SizedBox(width: 12),
                    ],
                    const JibikiWordmark(
                      fontSize: 24,
                      variant: JibikiBrandVariant.negative,
                      dotOutline: JibikiBrandColors.ink,
                    ),
                  ],
                ),
                Spacer(flex: expanded ? 2 : 1),
                NeoBadge(eyebrow, tone: NeoTone.acid, rotate: -2),
                SizedBox(height: expanded ? 22 : 14),
                Text(
                  headline,
                  style: TextStyle(
                    color: jc.surface,
                    fontSize: expanded ? 45 : 29,
                    height: 0.98,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: TextStyle(
                    color: jc.surface,
                    fontSize: expanded ? 16 : 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (expanded) const Spacer(flex: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.autofillHints,
    this.obscureText = false,
    this.enabled = true,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 7),
          Opacity(
            opacity: enabled ? 1 : .56,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: context.jc.ink,
                          blurRadius: 0,
                          offset: const Offset(4, 4),
                        ),
                      ]
                    : null,
              ),
              child: TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                autofillHints: autofillHints,
                obscureText: obscureText,
                enabled: enabled,
                validator: validator,
                onFieldSubmitted: onFieldSubmitted,
                decoration: InputDecoration(
                  hintText: label,
                  prefixIcon: Icon(icon),
                  disabledBorder: _authFieldBorder(context.jc.muted),
                ),
              ),
            ),
          ),
        ],
      );
}

InputBorder _authFieldBorder(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: 2.5),
    );

class AuthInlineError extends StatelessWidget {
  const AuthInlineError(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.jc.coral,
          border: Border.all(color: context.jc.ink, width: 2.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}
