import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The detail-screen study controls: two independent toggles pinned in the
/// Scaffold's bottom slot. **Study** queues the item to learn (you'll be
/// quizzed); **I know it** marks it already known (mature, skipped in reviews).
/// The two are mutually exclusive; tapping a lit toggle removes the item.
class StudyStatusBar extends StatelessWidget {
  const StudyStatusBar({super.key, required this.status, required this.onSetStatus});

  /// One of `none` | `learning` | `known`.
  final String status;
  final Future<void> Function(String target) onSetStatus;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final learning = status == 'learning';
    final known = status == 'known';
    return Container(
      decoration: BoxDecoration(color: jc.canvas, border: Border(top: BorderSide(color: jc.hairline))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: _Toggle(
                  selected: learning,
                  color: jc.brand,
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
                child: _Toggle(
                  selected: known,
                  color: jc.success,
                  icon: known ? Icons.check_circle : Icons.check_circle_outline,
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

/// A pill that reads as filled when its state is on, outlined when off.
class _Toggle extends StatelessWidget {
  const _Toggle({
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
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
    return SizedBox(
      height: 48,
      child: selected
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
              child: content,
            )
          : OutlinedButton(onPressed: onTap, child: content),
    );
  }
}
