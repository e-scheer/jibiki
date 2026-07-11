import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

extension LocalizedBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Migration bridge for older screens. Every user-visible literal goes
  /// through the active locale immediately; named ARB getters replace these
  /// fallbacks as copy is reviewed by translators.
  String trText(String source) {
    if (Localizations.localeOf(this).languageCode != 'fr') return source;
    return _legacyFrench[source] ?? source;
  }
}

const _legacyFrench = <String, String>{
  'Back': 'Retour',
  'Cancel': 'Annuler',
  'Check': 'Vérifier',
  'Close': 'Fermer',
  'Continue': 'Continuer',
  'Delete': 'Supprimer',
  'Done': 'Terminé',
  'Edit': 'Modifier',
  'Enter a valid email': 'Saisissez une adresse e-mail valide',
  'Error': 'Erreur',
  'Loading…': 'Chargement…',
  'Next': 'Suivant',
  'Retry': 'Réessayer',
  'Save': 'Enregistrer',
  'Search': 'Rechercher',
  'Settings': 'Réglages',
  'Skip': 'Passer',
  'Study': 'Étudier',
  'Submit': 'Envoyer',
  'At least 6 characters': 'Au moins 6 caractères',
  'Use at least 8 characters': 'Utilisez au moins 8 caractères',
};
