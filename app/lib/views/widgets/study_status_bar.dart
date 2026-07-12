import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../auth/auth_required_sheet.dart';
import '../study/study_chrome.dart';
import 'pressable.dart';

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
    final learning = widget.status == 'learning';
    final known = widget.status == 'known';
    return Container(
      decoration: BoxDecoration(
        color: context.jc.canvas,
        border: Border(top: BorderSide(color: context.jc.ink, width: 2.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: _StatusChoice(
                  selected: learning,
                  enabled: !_busy,
                  color: context.jc.acid,
                  icon: learning ? Icons.school : Icons.school_outlined,
                  label: learning ? 'Studying' : 'Study',
                  onTap: () {
                    Haptics.light();
                    if (accountReady) {
                      _setStatus(context, learning ? 'none' : 'learning');
                    } else {
                      showAuthRequiredSheet(context);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatusChoice(
                  selected: known,
                  enabled: !_busy,
                  color: context.jc.lime,
                  icon: known
                      ? Icons.check_circle_rounded
                      : Icons.check_circle_outline_rounded,
                  label: known ? 'Known' : 'I know it',
                  onTap: () {
                    Haptics.light();
                    if (accountReady) {
                      _setStatus(context, known ? 'none' : 'known');
                    } else {
                      showAuthRequiredSheet(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChoice extends StatelessWidget {
  const _StatusChoice({
    required this.selected,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final bool selected;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: Pressable(
          label: label,
          selected: selected,
          haptic: false,
          onTap: enabled ? onTap : null,
          child: StudyPanel(
            color: selected ? color : context.jc.surface,
            shadow: selected ? 3 : 0,
            radius: 10,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
