import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';

/// The three dictionary surfaces a learner can flag. [wire] is the value the
/// report API expects for `item_type`.
enum ReportItemType {
  kanji('kanji', 'this kanji'),
  kana('kana', 'this kana'),
  word('word', 'this word');

  const ReportItemType(this.wire, this.noun);
  final String wire;
  final String noun;
}

/// Why an entry is being flagged. Mirrors the server's ContentReportReason so
/// the picked value posts straight through.
enum _ReportReason {
  wrong('wrong', "Something's wrong"),
  missing('missing', 'Something is missing'),
  typo('typo', 'Typo or formatting'),
  other('other', 'Something else');

  const _ReportReason(this.wire, this.label);
  final String wire;
  final String label;
}

/// An app-bar flag button that opens the report sheet for one dictionary entry.
/// [label] is the entry's human name (its glyph or headword), shown in the sheet
/// and attached to the report so staff see what was flagged without a lookup.
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
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.flag_outlined),
      tooltip: 'Report an issue',
      onPressed: () =>
          showReportItemSheet(context, type: type, itemRef: itemRef, label: label),
    );
  }
}

/// Opens the "report an issue" sheet. Signed-out learners get a gentle sign-in
/// prompt instead of the form (a correction has to carry an account).
Future<void> showReportItemSheet(
  BuildContext context, {
  required ReportItemType type,
  required String itemRef,
  required String label,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportSheet(type: type, itemRef: itemRef, label: label),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.type, required this.itemRef, required this.label});
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
    // Captured before the await so we can act after the sheet closes.
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
    final authed = context.select<AppState, bool>((s) => s.isAuthenticated);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
      child: authed ? _form(context) : _signInPrompt(context),
    );
  }

  Widget _form(BuildContext context) {
    final jc = context.jc;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Report an issue', style: context.text.titleLarge),
        const SizedBox(height: 4),
        Text('Tell us what looks off with ${widget.type.noun} (${widget.label}).',
            style: TextStyle(color: jc.muted, height: 1.35)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in _ReportReason.values)
              ChoiceChip(
                label: Text(r.label),
                selected: _reason == r,
                onSelected: (_) => setState(() => _reason = r),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          minLines: 2,
          maxLines: 5,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Anything to add? (optional)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md)),
            counterText: '',
          ),
          onChanged: (v) => _message = v,
        ),
        if (_failed) ...[
          const SizedBox(height: 10),
          Text(
            "Couldn't send, you might be offline. Try again in a moment.",
            style: TextStyle(color: jc.ratingAgain, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: jc.brand),
            onPressed: (_reason != null && !_busy) ? _submit : null,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Send report'),
          ),
        ),
      ],
    );
  }

  Widget _signInPrompt(BuildContext context) {
    final jc = context.jc;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Report an issue', style: context.text.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Sign in to report a correction. It keeps reports accountable and lets '
          'us reply if we need a detail.',
          style: TextStyle(color: jc.muted, height: 1.4),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: jc.brand),
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/login');
            },
            child: const Text('Sign in'),
          ),
        ),
      ],
    );
  }
}
