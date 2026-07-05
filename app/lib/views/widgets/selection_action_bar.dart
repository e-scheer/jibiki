import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The bulk action bar shown while multi-selecting dictionary items: mark the
/// picked items as already known, or add them to study as new. Shared by the kana
/// chart and the kanji browser so "I know all of these" reads the same way.
class SelectionActionBar extends StatelessWidget {
  const SelectionActionBar({
    super.key,
    required this.count,
    required this.busy,
    required this.onKnown,
    required this.onAdd,
  });
  final int count;
  final bool busy;
  final VoidCallback onKnown;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final enabled = count > 0 && !busy;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(color: jc.canvas, border: Border(top: BorderSide(color: jc.hairline))),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: enabled ? onAdd : null,
                child: const Text('Add to study'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: enabled ? onKnown : null,
                child: busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(count > 0 ? 'I know these ($count)' : 'I know these'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
