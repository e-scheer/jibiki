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
  'WaniKani integration': 'Intégration WaniKani',
  'Read-only import with a preview': 'Import en lecture seule avec aperçu',
  'Jibiki never changes your WaniKani account and never imports without your confirmation. Different SRS calendars stay separate.':
      'Jibiki ne modifie jamais votre compte WaniKani et n’importe rien sans confirmation. Les calendriers SRS restent séparés.',
  'WaniKani API token': 'Jeton API WaniKani',
  'Paste your read-only token': 'Collez votre jeton en lecture seule',
  'Known from': 'Considérer comme connu à partir de',
  'Preview import': 'Prévisualiser l’import',
  'Import preview': 'Aperçu de l’import',
  'Apply import': 'Appliquer l’import',
  'Refresh preview': 'Actualiser l’aperçu',
  'Cancel import': 'Annuler l’import',
  'Disconnect WaniKani': 'Déconnecter WaniKani',
  'Connected': 'Connecté',
  'WaniKani token stored securely': 'Jeton WaniKani stocké de façon sécurisée',
  'Guru': 'Guru',
  'Master': 'Master',
  'Burned': 'Brûlé',
  'Import': 'Importer',
  'Review WaniKani import': 'Vérifier l’import WaniKani',
  'Source captured from reading': 'Source capturée pendant la lecture',
  'Where should we place you?': 'Où devons-nous vous placer ?',
  'Start fresh': 'Commencer de zéro',
  'Everything begins in the new queue.':
      'Tout commence dans la file des nouveautés.',
  'I know hiragana': 'Je connais les hiragana',
  'Mark the basic hiragana as known.':
      'Marquer les hiragana de base comme connus.',
  'I know specific characters': 'Je connais certains caractères',
  'Paste kana or kanji you already read.':
      'Collez les kana ou kanji que vous lisez déjà.',
  'Known characters': 'Caractères connus',
  'Example: 日本語かな': 'Exemple : 日本語かな',
  'Capture source': 'Capturer la source',
  'Capture reading context': 'Capturer le contexte de lecture',
  'Source sentence': 'Phrase source',
  'Paste the sentence from your reader':
      'Collez la phrase depuis votre lecteur',
  'Source title': 'Titre de la source',
  'Source URL': 'URL de la source',
  'Paste': 'Coller',
  'Capture': 'Capturer',
  'Source captured': 'Source capturée',
};
