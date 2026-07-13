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
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get authBackToSignIn => 'Retour à la connexion';

  @override
  String get authContinueToSignIn => 'Continuer vers la connexion';

  @override
  String get authCheckAgain => 'Vérifier à nouveau';

  @override
  String get authLinkUnavailableTitle => 'Impossible d’utiliser ce lien';

  @override
  String get authLinkUnavailableBody =>
      'Il est peut-être incomplet, expiré ou déjà utilisé. Revenez à la connexion ou demandez un nouveau lien.';

  @override
  String get verifyEmailEyebrow => 'VÉRIFICATION E-MAIL';

  @override
  String get verifyEmailHeadline => 'Une pression suffit.';

  @override
  String get verifyEmailDescription =>
      'Sécurisez votre compte jibiki et synchronisez tous vos appareils.';

  @override
  String get verifyEmailTitle => 'Vérifier votre adresse e-mail';

  @override
  String get verifyEmailCheckingTitle => 'Vérification du lien';

  @override
  String get verifyEmailCheckingBody => 'Cela ne prendra qu’un instant.';

  @override
  String get verifyEmailReadyTitle => 'Votre adresse est prête à être vérifiée';

  @override
  String get verifyEmailReadyBody =>
      'Confirmez cette adresse pour terminer la sécurisation de votre compte.';

  @override
  String get verifyEmailAction => 'Vérifier l’adresse';

  @override
  String get verifyEmailSuccessTitle => 'Adresse e-mail vérifiée';

  @override
  String get verifyEmailSuccessBody =>
      'Votre compte est prêt. Connectez-vous pour reprendre là où vous vous étiez arrêté.';

  @override
  String get passwordResetEyebrow => 'RÉCUPÉRATION DU COMPTE';

  @override
  String get passwordResetHeadline => 'Revenez sereinement.';

  @override
  String get passwordResetDescription =>
      'Récupérez votre accès sans perdre votre dictionnaire local ni votre historique d’étude.';

  @override
  String get passwordResetRequestTitle => 'Réinitialiser votre mot de passe';

  @override
  String get passwordResetRequestBody =>
      'Saisissez l’adresse e-mail de votre compte. Si elle correspond, nous enverrons un lien sécurisé.';

  @override
  String get emailFieldLabel => 'Adresse e-mail';

  @override
  String get enterValidEmail => 'Saisissez une adresse e-mail valide';

  @override
  String get sendResetLink => 'Envoyer le lien';

  @override
  String get passwordResetRequestSuccessTitle =>
      'Consultez votre boîte de réception';

  @override
  String get passwordResetRequestSuccessBody =>
      'Si un compte correspond à cette adresse, un lien de réinitialisation est en route.';

  @override
  String get passwordResetCheckingTitle =>
      'Vérification du lien de réinitialisation';

  @override
  String get passwordResetCheckingBody =>
      'Nous vérifions qu’il est toujours sécurisé et actif.';

  @override
  String get chooseNewPasswordTitle => 'Choisissez un nouveau mot de passe';

  @override
  String get chooseNewPasswordBody =>
      'Utilisez au moins 8 caractères. Une phrase de passe longue et unique est encore préférable.';

  @override
  String get newPasswordFieldLabel => 'Nouveau mot de passe';

  @override
  String get confirmPasswordFieldLabel => 'Confirmer le mot de passe';

  @override
  String get passwordAtLeastEight => 'Utilisez au moins 8 caractères';

  @override
  String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get setNewPassword => 'Définir le nouveau mot de passe';

  @override
  String get passwordResetSuccessTitle => 'Mot de passe mis à jour';

  @override
  String get passwordResetSuccessBody =>
      'Votre mot de passe a été modifié. Connectez-vous avec le nouveau.';

  @override
  String get requestAnotherResetLink => 'Demander un nouveau lien';

  @override
  String get socialAuthEyebrow => 'ÉTAT DE LA CONNEXION';

  @override
  String get socialAuthHeadline => 'La connexion s’est arrêtée.';

  @override
  String get socialAuthDescription =>
      'Votre compte reste protégé. Choisissez comment continuer.';

  @override
  String get socialAuthCancelledTitle => 'Connexion annulée';

  @override
  String get socialAuthCancelledBody =>
      'Rien n’a été modifié. Vous pourrez réessayer quand vous le souhaiterez.';

  @override
  String get socialAuthDeniedTitle => 'Connexion non autorisée';

  @override
  String get socialAuthDeniedBody =>
      'Le fournisseur n’a pas autorisé cette demande. Vérifiez ses permissions, puis réessayez.';

  @override
  String get socialAuthReauthenticationTitle =>
      'Reconnectez-vous pour continuer';

  @override
  String get socialAuthReauthenticationBody =>
      'Pour votre sécurité, le fournisseur demande une nouvelle connexion avant de terminer cette action.';

  @override
  String get socialAuthSignupClosedTitle => 'Création de compte indisponible';

  @override
  String get socialAuthSignupClosedBody =>
      'Les nouveaux comptes sociaux ne peuvent pas être créés actuellement. Essayez plutôt un compte existant.';

  @override
  String get socialAuthUnknownTitle => 'Impossible de terminer la connexion';

  @override
  String get socialAuthUnknownBody =>
      'Le fournisseur a renvoyé un résultat inattendu. Vos données jibiki n’ont pas été modifiées.';

  @override
  String get trySignInAgain => 'Réessayer la connexion';

  @override
  String get returnToJibiki => 'Retourner dans jibiki';

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
  String get privacy => 'Confidentialité';

  @override
  String get usageAnalytics => 'Statistiques d’usage';

  @override
  String get usageAnalyticsHelp =>
      'Partagez anonymement les écrans et fonctions utilisés pour améliorer jibiki. Les recherches et contenus étudiés ne sont jamais collectés.';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get diagnosticsHelp =>
      'Partagez les mesures de performance et rapports de plantage. Les informations du compte et contenus d’apprentissage sont exclus.';

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
