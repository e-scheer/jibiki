/// The mnemonic-language catalog. Deliberately OPEN but VALIDATED: any real
/// ISO 639-1 language is selectable (mnemonics are keyed (character,
/// language) server-side, English is always the display backup, and the
/// community can fill a language before we curate it) - but only real codes:
/// the full list comes from package:language_code and the server re-validates
/// against ISO 639 (pycountry), so a typo can never mint a phantom language.
library;

import 'package:language_code/language_code.dart';

class MnemonicLanguage {
  const MnemonicLanguage(this.code, this.nativeName, {this.seeded = false});

  final String code;
  final String nativeName;
  final bool seeded;
}

/// Languages shipping curated seed mnemonics today.
const Set<String> seededMnemonicCodes = {'en', 'fr'};

/// The one display/gloss backup, used wherever a chosen language has no
/// content yet. Stated once here instead of scattering the literal 'en'.
const String fallbackLanguage = 'en';

/// Shown first in the picker: seeded + the languages our research covers.
const List<String> _featuredCodes = [
  'en', 'fr', 'es', 'de', 'pt', 'it', 'nl', 'ru', 'ko', 'zh', 'th', 'id', 'vi',
];

MnemonicLanguage _fromLib(LanguageCodes l) => MnemonicLanguage(
      l.code,
      l.nativeName,
      seeded: seededMnemonicCodes.contains(l.code),
    );

List<MnemonicLanguage> get featuredMnemonicLanguages => [
      for (final code in _featuredCodes)
        _fromLib(LanguageCodes.fromCode(code)),
    ];

/// Every plain ISO 639-1 language (regional variants like pt_BR excluded -
/// mnemonic sound-anchors live at the language level).
List<MnemonicLanguage> get allMnemonicLanguages => [
      for (final l in LanguageCodes.values)
        if (!l.code.contains('_')) _fromLib(l),
    ];

bool isValidMnemonicLanguage(String code) {
  if (code.contains('_')) return false;
  try {
    LanguageCodes.fromCode(code);
    return true;
  } on StateError {
    return false;
  }
}

String mnemonicLanguageName(String code) {
  try {
    return LanguageCodes.fromCode(code).nativeName;
  } on StateError {
    return code.toUpperCase();
  }
}

/// The quick chips on onboarding: seeded languages + the current selection.
List<MnemonicLanguage> quickMnemonicLanguages(String current) => [
      for (final l in featuredMnemonicLanguages)
        if (l.seeded || l.code == current) l,
      if (!featuredMnemonicLanguages.any((l) => l.code == current) &&
          isValidMnemonicLanguage(current))
        MnemonicLanguage(current, mnemonicLanguageName(current)),
    ];
