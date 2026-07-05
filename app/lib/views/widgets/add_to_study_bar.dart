import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A flat, pinned bottom action bar, the Instagram-appropriate replacement for a
/// Material FAB (Instagram has no FABs). Sits in the Scaffold's
/// `bottomNavigationBar` slot on detail screens: a hairline top border over the
/// canvas and one full-width primary button.
class AddToStudyBar extends StatelessWidget {
  const AddToStudyBar({
    super.key,
    required this.added,
    required this.onAdd,
    this.labelAdd = 'Add to study',
    this.labelAdded = 'In your deck',
  });

  final bool added;
  final Future<void> Function() onAdd;
  final String labelAdd;
  final String labelAdded;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Container(
      decoration: BoxDecoration(
        color: jc.canvas,
        border: Border(top: BorderSide(color: jc.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: added ? null : onAdd,
              style: added
                  ? FilledButton.styleFrom(
                      backgroundColor: jc.success,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: jc.success,
                      disabledForegroundColor: Colors.white,
                    )
                  : null,
              icon: Icon(added ? Icons.check : Icons.add, size: 20),
              label: Text(added ? labelAdded : labelAdd),
            ),
          ),
        ),
      ),
    );
  }
}
