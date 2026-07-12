import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../study/study_chrome.dart';
import 'pressable.dart';

class StudyStatusBar extends StatelessWidget {
  const StudyStatusBar({
    super.key,
    required this.status,
    required this.onSetStatus,
  });

  final String status;
  final Future<void> Function(String target) onSetStatus;

  @override
  Widget build(BuildContext context) {
    final learning = status == 'learning';
    final known = status == 'known';
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
                  color: context.jc.acid,
                  icon: learning ? Icons.school : Icons.school_outlined,
                  label: learning ? 'Studying' : 'Study',
                  onTap: () {
                    Haptics.light();
                    onSetStatus(learning ? 'none' : 'learning');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatusChoice(
                  selected: known,
                  color: context.jc.lime,
                  icon: known
                      ? Icons.check_circle_rounded
                      : Icons.check_circle_outline_rounded,
                  label: known ? 'Known' : 'I know it',
                  onTap: () {
                    Haptics.light();
                    onSetStatus(known ? 'none' : 'known');
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
  });

  final bool selected;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: Pressable(
          label: label,
          selected: selected,
          haptic: false,
          onTap: onTap,
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
