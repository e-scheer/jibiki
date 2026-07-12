import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jibiki/l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../widgets/neo_pop.dart';
import '../widgets/jibiki_brand.dart';

enum ReportItemType {
  kanji('kanji', 'this kanji'),
  kana('kana', 'this kana'),
  word('word', 'this word');

  const ReportItemType(this.wire, this.noun);
  final String wire;
  final String noun;
}

enum _ReportReason {
  wrong('wrong', "Something's wrong"),
  missing('missing', 'Something is missing'),
  typo('typo', 'Typo or formatting'),
  other('other', 'Something else');

  const _ReportReason(this.wire, this.label);
  final String wire;
  final String label;
}

class ReportItemAction extends StatelessWidget {
  const ReportItemAction({
    super.key,
    required this.type,
    required this.itemRef,
    required this.label,
  });

  final ReportItemType type;
  final String itemRef;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(4),
        child: NeoIconButton(
          icon: Icons.flag_outlined,
          label: context.trText('Report an issue'),
          onTap: () => showReportItemSheet(
            context,
            type: type,
            itemRef: itemRef,
            label: label,
          ),
        ),
      );
}

Future<void> showReportItemSheet(
  BuildContext context, {
  required ReportItemType type,
  required String itemRef,
  required String label,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (_) => _ReportSheet(
        type: type,
        itemRef: itemRef,
        label: label,
      ),
    );

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.type,
    required this.itemRef,
    required this.label,
  });

  final ReportItemType type;
  final String itemRef;
  final String label;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  _ReportReason? _reason;
  String _message = '';
  bool _busy = false;
  bool _failed = false;

  Future<void> _submit() async {
    if (_reason == null || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await context.read<FeedbackService>().reportContent(
        itemType: widget.type.wire,
        itemRef: widget.itemRef,
        reason: _reason!.wire,
        message: _message.trim(),
        context: {
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'label': widget.label,
        },
      );
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text("Thanks, we'll take a look.")),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authed = context.select<AppState, bool>((state) {
      return state.isAuthenticated;
    });
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomInset),
      child: NeoCard(
        shadow: 0,
        radius: 18,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        child: authed ? _form(context) : _signInPrompt(context),
      ),
    );
  }

  Widget _sheetHeading(BuildContext context, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 54,
              height: 7,
              decoration: BoxDecoration(
                color: context.jc.ink,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NeoBadge('FLAG', tone: NeoTone.magenta, rotate: -2),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.trText('Report an issue'),
                      style: context.text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.jc.body,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );

  Widget _form(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHeading(
            context,
            context.trText(
              'Tell us what looks off with ${widget.type.noun} (${widget.label}).',
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 9,
            children: [
              for (final reason in _ReportReason.values)
                _ReasonChip(
                  label: reason.label,
                  selected: _reason == reason,
                  enabled: !_busy,
                  onTap: () => setState(() => _reason = reason),
                ),
            ],
          ),
          const SizedBox(height: 16),
          NeoCard(
            padding: const EdgeInsets.all(3),
            shadow: 3,
            child: TextField(
              enabled: !_busy,
              minLines: 3,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: context.trText('Anything to add? (optional)'),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                counterText: '',
              ),
              onChanged: (value) => _message = value,
            ),
          ),
          if (_failed) ...[
            const SizedBox(height: 12),
            const NeoCard(
              tone: NeoTone.coral,
              shadow: 0,
              padding: EdgeInsets.all(11),
              child: Text(
                "Couldn't send. You might be offline. Try again in a moment.",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: 18),
          _SheetFilledButton(
            label: context.trText('Send report'),
            busy: _busy,
            onPressed: _reason != null && !_busy ? _submit : null,
          ),
        ],
      );

  Widget _signInPrompt(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHeading(
            context,
            context.trText(
              'Sign in to report a correction. It keeps reports accountable and lets us reply if we need a detail.',
            ),
          ),
          const SizedBox(height: 18),
          NeoCard(
            tone: NeoTone.lime,
            shadow: 0,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    context.trText(
                        'Your account is only used to follow up on the correction.'),
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SheetFilledButton(
            label: context.trText('Sign in'),
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/login');
            },
          ),
        ],
      );
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          labelStyle: TextStyle(
            color: context.jc.ink,
            fontWeight: FontWeight.w800,
          ),
          onSelected: enabled ? (_) => onTap() : null,
        ),
      );
}

class _SheetFilledButton extends StatelessWidget {
  const _SheetFilledButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        height: 54,
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
              ? const NeoChaseLoader.small()
              : Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      );
}
