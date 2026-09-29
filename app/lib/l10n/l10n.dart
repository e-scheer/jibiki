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
  'Sorted by relevance.': 'Tri par pertinence.',
  'Sorted by relevance. Romaji is transliterated.':
      'Tri par pertinence. Le rōmaji est translittéré.',
  'A word, kanji or kana...': 'Un mot, un kanji ou un kana…',
  'A word, kanji or romaji...': 'Un mot, un kanji ou du rōmaji…',
  'Radical data: Kanji alive · CC BY 4.0. Source: https://github.com/kanjialive/kanji-data-media · Licence: https://creativecommons.org/licenses/by/4.0/':
      'Données des radicaux : Kanji alive · CC BY 4.0. Source : https://github.com/kanjialive/kanji-data-media · Licence : https://creativecommons.org/licenses/by/4.0/',
  'Origin explanation · source not documented':
      'Explication de l’origine · source non documentée',
  'Glyph origin from Wiktionary · CC BY-SA':
      'Origine graphique issue de Wiktionary · CC BY-SA',
  'Phono-semantic': 'Phono-sémantique',
  'Ideogrammic': 'Idéographique',
  'Pictogram': 'Pictogramme',
  'Simplified': 'Simplifié',
  'Variant': 'Variante',
  'Abbreviation': 'Abréviation',
  'Phonetic loan': 'Emprunt phonétique',
  'Compound': 'Composé',
  'Contraction': 'Contraction',
  '{label} · {term}': '{label} · {term}',
  '音符 · sound component': '音符 · composant phonétique',
  '{component} suggests a reading for this character.':
      '{component} suggère une lecture de ce caractère.',
  'This historical entry is absent from the current source snapshot. It remains available for your saved cards.':
      'Cette entrée historique est absente de la version actuelle de la source. Elle reste accessible pour vos cartes enregistrées.',
  'Radical in Kanji alive': 'Radical selon Kanji alive',
  'Position: {position}': 'Position : {position}',
  'This source uses a special glyph font; its name is shown here.':
      'Cette source utilise une police spéciale ; son nom est présenté ici.',
  'Suggested study strategy': 'Stratégie d’étude suggérée',
  'Look at the character and choose an image that helps you recall its meaning.':
      'Observez le caractère et choisissez une image qui vous aide à retrouver son sens.',
  'Content language: {language}': 'Langue du contenu : {language}',
  'Usage': 'Usage',
  'Field': 'Domaine',
  'Used with these spellings': 'Avec ces graphies',
  'Used with these readings': 'Avec ces lectures',
  'Dialect': 'Dialecte',
  'Related entries': 'Entrées liées',
  '{label}: {values}': '{label} : {values}',
  'Words containing {kana}': 'Mots contenant {kana}',
  'JMdict reading match · editorial review not recorded':
      'Lecture concordante avec JMdict · relecture non documentée',
  'Open dictionary entry': 'Ouvrir la fiche du dictionnaire',
  'English': 'anglais',
  'French': 'français',
  'Content in {language} · English translation unavailable':
      'Contenu en {language} · traduction française indisponible',
  'Editorial review recorded': 'Relecture éditoriale documentée',
  'Editorial review recorded · origin undocumented':
      'Relecture éditoriale documentée · origine non documentée',
  'No documented editorial review': 'Relecture non documentée',
  'No documented editorial review · origin undocumented':
      'Relecture non documentée · origine non documentée',
  'Continue with or without an account to save your settings.':
      'Continuez avec ou sans compte pour enregistrer vos réglages.',
  'Dictionary': 'Dictionnaire',
  'Community': 'Communauté',
  'Profile': 'Profil',
  'Cards due: {count}': 'Cartes à réviser : {count}',
  'This page is unavailable.': 'Cette page est indisponible.',
  'Return to Jibiki': 'Retour à Jibiki',
  'Saving your answer…': 'Enregistrement de votre réponse…',
  'No reviews are due. Choose a pack to keep learning.':
      'Aucune révision en attente. Choisissez un paquet pour continuer à apprendre.',
  '{count} due in total. About {minutes} minutes.':
      '{count} cartes à réviser. Environ {minutes} minutes.',
  '{count} new cards are available.':
      '{count} nouvelles cartes sont disponibles.',
  'No reviews are due for this pack.':
      'Aucune révision en attente dans ce paquet.',
  'Load more': 'Afficher la suite',
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
  'Choose the exact foundation you already know. You can change this later.':
      'Choisissez précisément les bases que vous connaissez déjà. Vous pourrez les modifier plus tard.',
  'Choose a starting point': 'Choisissez un point de départ',
  'Kana you already know': 'Kana que vous connaissez déjà',
  'Kanji by JLPT': 'Kanji par niveau JLPT',
  'Hiragana': 'Hiragana',
  'Katakana': 'Katakana',
  'All kana': 'Tous les kana',
  'Mark the full hiragana syllabary as known.':
      'Marquer tout le syllabaire hiragana comme connu.',
  'Mark the full katakana syllabary as known.':
      'Marquer tout le syllabaire katakana comme connu.',
  'Hiragana and katakana, including their variants.':
      'Hiragana et katakana, avec toutes leurs variantes.',
  'Canonical kanji for this level.': 'Les kanji canoniques de ce niveau.',
  'N5 plus the canonical N4 kanji.': 'Le N5 avec les kanji canoniques du N4.',
  'N5 through N3 from the canonical lists.':
      'Du N5 au N3 selon les listes canoniques.',
  'N5 through N2 from the canonical lists.':
      'Du N5 au N2 selon les listes canoniques.',
  'The complete canonical JLPT kanji ladder.':
      'L’ensemble complet des kanji JLPT canoniques.',
  'Only kana and kanji are counted.':
      'Seuls les kana et les kanji sont comptés.',
  'We could not load this level. Check your connection and try again.':
      'Impossible de charger ce niveau. Vérifiez votre connexion et réessayez.',
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
  'Japanese reference': 'Fiches de référence',
  'Reference cards': 'Fiches de référence',
  'Particles, conjugation, readings and other quick references.':
      'Particules, conjugaison, lectures et autres rappels rapides.',
  'Statistics': 'Statistiques',
  'See retention, accumulated knowledge and review trends.':
      'Suivez la rétention, les connaissances accumulées et les tendances de révision.',
  'Short, practical notes for grammar and reading. Open a card when you need a reminder, then return to your study.':
      'Notes courtes et pratiques sur la grammaire et la lecture. Ouvrez une fiche en cas de doute, puis reprenez votre étude.',
  'Find a reference': 'Rechercher une fiche',
  'No reference found.': 'Aucune fiche trouvée.',
  'Refresh': 'Actualiser',
  'Knowledge accumulation': 'Accumulation des connaissances',
  'Last 14 days': '14 derniers jours',
  'Answer profile': 'Profil des réponses',
  'What these numbers mean': 'Signification de ces chiffres',
  'Accuracy counts Hard, Good and Easy as a successful recall. Mature retention only measures cards already in review, so it reflects durable knowledge rather than first exposure.':
      'L’exactitude considère Difficile, Bien et Facile comme un rappel réussi. La rétention mature mesure seulement les cartes déjà en révision : elle reflète donc les connaissances durables plutôt que la première exposition.',
  'Cards known': 'Cartes maîtrisées',
  'Reviews': 'Révisions',
  'Accuracy': 'Exactitude',
  'Mature recall': 'Rappel mature',
  'New': 'Nouvelles',
  'Learning': 'En apprentissage',
  'Review': 'Révision',
  'Idea': 'Id\u00e9e',
  'Bug': 'Bug',
  'Love': 'Coup de c\u0153ur',
  'Other': 'Autre',
  'Reference': 'R\u00e9f\u00e9rence',
  'Ref': 'R\u00e9f.',
  'Swap': 'Inverser',
  'Refresh profile': 'Actualiser le profil',
  'Refresh review packs': 'Actualiser les packs de r\u00e9vision',
  'Refresh community packs': 'Actualiser les packs communautaires',
  'Refresh submissions': 'Actualiser les contributions',
  'Again': 'Encore',
  'Hard': 'Difficile',
  'Good': 'Bien',
  'Easy': 'Facile',
  'Open full details': 'Ouvrir les détails complets',
};
