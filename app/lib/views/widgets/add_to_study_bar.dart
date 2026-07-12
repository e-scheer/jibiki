import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../study/study_chrome.dart';

class AddToStudyBar extends StatelessWidget {
  const AddToStudyBar({
    super.key,
    required this.added,
    required this.onAdd,
    this.labelAdd = 'Learn this',
    this.labelAdded = 'In your deck',
  });

  final bool added;
  final Future<void> Function() onAdd;
  final String labelAdd;
  final String labelAdded;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.jc.canvas,
          border: Border(top: BorderSide(color: context.jc.ink, width: 2.5)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: StudyActionButton(
              label: added ? labelAdded : labelAdd,
              icon: added ? Icons.check_rounded : Icons.add_rounded,
              color: added ? context.jc.lime : context.jc.acid,
              onTap: added ? null : onAdd,
            ),
          ),
        ),
      );
}
