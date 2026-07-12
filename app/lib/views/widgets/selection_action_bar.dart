import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../study/study_chrome.dart';

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
    final enabled = count > 0 && !busy;
    return Container(
      decoration: BoxDecoration(
        color: context.jc.canvas,
        border: Border(top: BorderSide(color: context.jc.ink, width: 2.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 9, 16, 11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    count == 0 ? 'Select characters' : '$count selected',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.trText('Learn adds reviews. Known skips them.'),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.jc.body,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: StudyActionButton(
                      label: count > 0 ? 'Learn ($count)' : 'Learn',
                      icon: Icons.school_outlined,
                      color: context.jc.acid,
                      height: 52,
                      shadow: 3,
                      onTap: enabled ? onAdd : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StudyActionButton(
                      label: count > 0 ? 'Known ($count)' : 'Known',
                      icon: Icons.done_all_rounded,
                      color: context.jc.lime,
                      height: 52,
                      shadow: 3,
                      busy: busy,
                      onTap: enabled ? onKnown : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
