import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('visible literals go through the localization layer', () {
    final offenders = <String>[];
    final rawText = RegExp(r"(?<!tr)Text\(\s*'[A-Za-z]", multiLine: true);
    final rawField = RegExp(
      r"(?:labelText|hintText|tooltip):\s*'[A-Za-z]",
      multiLine: true,
    );

    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path.contains('app_localizations')) {
        continue;
      }
      final source = file.readAsStringSync();
      if (rawText.hasMatch(source) || rawField.hasMatch(source)) {
        offenders.add(file.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Wrap visible copy with context.l10n or context.trText: $offenders',
    );
  });
}
