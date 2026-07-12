import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../auth/auth_required_sheet.dart';
import 'neo_pop.dart';

class StudyStatusBar extends StatefulWidget {
  const StudyStatusBar({
    super.key,
    required this.status,
    required this.onSetStatus,
  });

  final String status;
  final Future<void> Function(String target) onSetStatus;

  @override
  State<StudyStatusBar> createState() => _StudyStatusBarState();
}

class _StudyStatusBarState extends State<StudyStatusBar> {
  bool _busy = false;

  Future<void> _setStatus(BuildContext context, String target) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSetStatus(target);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountReady = context.watch<AppState>().isAuthenticated;
    final selected = switch (widget.status) {
      'learning' => 'learning',
      'known' => 'known',
      _ => null,
    };
    return Container(
      decoration: BoxDecoration(
        color: context.jc.canvas,
        border: Border(top: BorderSide(color: context.jc.ink, width: 2.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: NeoSegmentedControl<String?>(
            height: 54,
            enabled: !_busy,
            selected: selected,
            selectionColor:
                selected == 'known' ? context.jc.lime : context.jc.acid,
            segments: [
              NeoSegment<String?>(
                'learning',
                selected == 'learning' ? 'Studying' : 'Study',
                icon: selected == 'learning'
                    ? Icons.school
                    : Icons.school_outlined,
              ),
              NeoSegment<String?>(
                'known',
                selected == 'known' ? 'Known' : 'I know it',
                icon: selected == 'known'
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline_rounded,
              ),
            ],
            onChanged: (target) {
              Haptics.light();
              if (!accountReady) {
                showAuthRequiredSheet(context);
                return;
              }
              _setStatus(context, selected == target ? 'none' : target!);
            },
          ),
        ),
      ),
    );
  }
}
