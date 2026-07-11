// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'jibiki';

  @override
  String get settings => 'Réglages';

  @override
  String get interfaceLanguage => 'Langue de l’interface';

  @override
  String get interfaceLanguageHelp =>
      'Modifie immédiatement les menus et les messages. La langue des mnémotechniques reste un choix distinct.';

  @override
  String get english => 'Anglais';

  @override
  String get french => 'Français';

  @override
  String get mode => 'Mode';

  @override
  String get dictionaryMode => 'Dictionnaire';

  @override
  String get dictionaryModeHelp =>
      'La recherche d’abord, sans rappel de révision.';

  @override
  String get middleMode => 'Équilibré';

  @override
  String get middleModeHelp =>
      'Le dictionnaire en accueil avec un badge discret pour les cartes à revoir.';

  @override
  String get learningMode => 'Apprentissage';

  @override
  String get learningModeHelp =>
      'La file de révision, les objectifs et les séries passent en priorité.';

  @override
  String get mnemonicLanguage => 'Langue des mnémotechniques';

  @override
  String get mnemonicLanguageHelp =>
      'Toutes les langues sont possibles. Si un contenu manque, l’anglais sert de repli et la communauté peut créer le premier jeu.';

  @override
  String get spacedRepetition => 'Répétition espacée';

  @override
  String get newCardsPerSession => 'Nouvelles cartes par session';

  @override
  String get newCardsHelp =>
      'Nombre de nouvelles cartes au début d’une session. Ce n’est pas une limite quotidienne; choisissez Continuer à étudier à la fin pour poursuivre.';

  @override
  String get desiredRetention => 'Rétention souhaitée';

  @override
  String get studyReminders => 'Rappels d’étude';

  @override
  String get studyRemindersHelp =>
      'Un rappel discret lorsqu’assez de cartes sont à revoir.';

  @override
  String get community => 'Communauté';

  @override
  String get mySubmissions => 'Mes contributions';

  @override
  String get mySubmissionsHelp =>
      'Vos mnémotechniques dessinées et leur statut de validation.';

  @override
  String get myPacks => 'Mes packs';

  @override
  String get myPacksHelp =>
      'Packs créés, brouillons, en validation et publiés.';

  @override
  String get makeJibikiBetter => 'Améliorer jibiki';

  @override
  String get makeJibikiBetterHelp =>
      'Idées, bugs et mots doux : nous lisons tout.';

  @override
  String get data => 'Données';

  @override
  String get offlineStorage => 'Hors ligne et stockage';

  @override
  String get offlineStorageHelp =>
      'Packs de dictionnaire sur cet appareil, mises à jour et état de synchronisation.';

  @override
  String get exportToAnki => 'Exporter vers Anki';

  @override
  String get exportToAnkiHelp =>
      'Votre deck au format TSV importable dans Anki.';

  @override
  String get personalisedScheduling => 'Planification personnalisée';

  @override
  String get personalisedSchedulingHelp =>
      'Entraîne FSRS sur votre historique lorsque vous avez assez de révisions.';

  @override
  String get account => 'Compte';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get syncWithAccount => 'Synchroniser avec un compte';

  @override
  String get syncWithAccountHelp =>
      'Connectez-vous ou créez un compte. Votre progression locale reste sur cet appareil jusqu’au choix de résolution avec le cloud.';

  @override
  String get exportFailed => 'Échec de l’export';

  @override
  String exportCards(int count) {
    return 'Export : $count cartes';
  }

  @override
  String get close => 'Fermer';

  @override
  String get copy => 'Copier';

  @override
  String get ankiCopied =>
      'Copié. Collez le contenu dans un fichier .txt puis importez-le dans Anki.';

  @override
  String reviewProgress(int current, int required) {
    return '$current / $required révisions';
  }

  @override
  String get fsrsReady =>
      'Prêt. FSRS peut maintenant s’adapter à votre mémoire.';

  @override
  String get fsrsKeepReviewing =>
      'Continuez les révisions. FSRS utilise de bons réglages par défaut jusque-là.';

  @override
  String get optimiseNow => 'Optimiser maintenant';

  @override
  String get schedulerPersonalised =>
      'Planification personnalisée selon votre historique.';

  @override
  String get schedulerDefaultsKept =>
      'Les réglages par défaut sont conservés car ils vous correspondent déjà.';

  @override
  String get dictionaryCredits =>
      'jibiki · données du dictionnaire © EDRDG (JMdict/KANJIDIC)';
}
