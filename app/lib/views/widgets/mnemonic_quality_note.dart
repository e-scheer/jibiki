import 'package:flutter/material.dart';

import '../../models/mnemonic.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Editorial review and publication are separate states.
class MnemonicQualityNote extends StatelessWidget {
  const MnemonicQualityNote({super.key, required this.mnemonic, this.color});

  final Mnemonic mnemonic;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final reviewed = mnemonic.hasEditorialReview;
    final unknownOrigin = mnemonic.isSeed &&
        (mnemonic.provenance['generation_method'] == null ||
            mnemonic.provenance['generation_method'] == 'unknown');
    final label = switch ((reviewed, unknownOrigin)) {
      (true, true) =>
        context.trText('Editorial review recorded · origin undocumented'),
      (true, false) => context.trText('Editorial review recorded'),
      (false, true) =>
        context.trText('No documented editorial review · origin undocumented'),
      (false, false) => context.trText('No documented editorial review'),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(label,
          style: TextStyle(color: color ?? context.jc.muted, fontSize: 11.5)),
    );
  }
}
