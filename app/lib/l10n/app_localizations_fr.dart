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

  @override
  String get burnTitle => 'Burn d\'apprentissage';

  @override
  String burnDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
      zero: '0 jour',
    );
    return '$_temp0';
  }

  @override
  String burnBest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return 'Record : $_temp0';
  }

  @override
  String get burnTodayCounted => 'Aujourd\'hui est compté. À demain.';

  @override
  String get burnComeBackToday =>
      'Une révision aujourd\'hui prolonge votre burn.';

  @override
  String burnNextBooster(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours avant votre prochain booster',
      one: '1 jour avant votre prochain booster',
    );
    return '$_temp0';
  }

  @override
  String get boosterShelfTitle => 'Boosters';

  @override
  String boosterToOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count boosters à ouvrir',
      one: '1 booster à ouvrir',
    );
    return '$_temp0';
  }

  @override
  String get boosterShelfFull =>
      'Votre réserve est pleine. Ouvrez un booster pour faire de la place au prochain palier.';

  @override
  String get boosterEarnedTitle => 'Booster gagné !';

  @override
  String boosterEarnedBody(int milestone) {
    return 'Jour $milestone de votre burn. Ouvrez-le quand vous voulez.';
  }

  @override
  String get boosterOpenAction => 'Ouvrir le booster';

  @override
  String get boosterOpenLater => 'Plus tard';

  @override
  String get boosterSlideToOpen =>
      'Glissez à travers le booster pour l\'ouvrir';

  @override
  String get boosterTapToOpen => 'Touchez pour ouvrir';

  @override
  String get boosterSkipAnimation => 'Passer l\'animation';

  @override
  String get boosterSwipeToReveal => 'Glissez pour révéler';

  @override
  String get boosterTapToContinue => 'Appuyez pour continuer';

  @override
  String get boosterTapToReveal => 'Appuyez pour révéler';

  @override
  String get boosterTiltHint => 'Faites glisser la carte pour l\'incliner';

  @override
  String get boosterNewCard => 'Nouvelle carte';

  @override
  String boosterDuplicate(int count) {
    return 'Doublon ×$count';
  }

  @override
  String get boosterSummaryTitle => 'Booster ouvert';

  @override
  String boosterSummaryNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouvelles cartes',
      one: '1 nouvelle carte',
    );
    return '$_temp0';
  }

  @override
  String boosterSummaryDuplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doublons',
      one: '1 doublon',
    );
    return '$_temp0';
  }

  @override
  String get boosterGoToCollection => 'Voir la collection';

  @override
  String get collectionTitle => 'Collection';

  @override
  String collectionSetProgress(int owned, int total) {
    return '$owned / $total cartes';
  }

  @override
  String collectionShinyCount(int count) {
    return '$count shiny';
  }

  @override
  String get collectionFilterAll => 'Toutes';

  @override
  String get collectionFilterOwned => 'Obtenues';

  @override
  String get collectionFilterMissing => 'Manquantes';

  @override
  String get collectionFilterDuplicates => 'Doublons';

  @override
  String get collectionCardNotOwned => 'Pas encore obtenue';

  @override
  String get collectionEmptyBody =>
      'Les vraies révisions nourrissent votre burn ; les paliers offrent des boosters remplis de cartes du Japon.';

  @override
  String collectionUnlocks(String what) {
    return 'Débloque : $what';
  }

  @override
  String get collectionUnlocked => 'Débloqué';

  @override
  String get collectionVocab => 'Le japonais à retenir';

  @override
  String get collectionFlipCard => 'Retourner la carte';

  @override
  String get contentFallbackEnglish =>
      'Pas encore rédigé dans votre langue ; affiché en anglais.';

  @override
  String get rarityCommon => 'Commune';

  @override
  String get rarityRare => 'Rare';

  @override
  String get raritySpecial => 'Spéciale';

  @override
  String get rarityShiny => 'Shiny';

  @override
  String get categoryPlace => 'Lieu';

  @override
  String get categoryCulture => 'Culture';

  @override
  String get categoryFood => 'Plats et boissons';

  @override
  String get categoryObject => 'Objet du quotidien';

  @override
  String get categoryTransport => 'Trains et villes';

  @override
  String get categoryNature => 'Nature';

  @override
  String get categoryCraft => 'Artisanat';

  @override
  String get categoryPerson => 'Personnalité';

  @override
  String get categorySociety => 'Société';

  @override
  String get categoryHistory => 'Histoire';

  @override
  String get categoryFestival => 'Fêtes et saisons';

  @override
  String get paletteLockedLabel => 'Verrouillée';

  @override
  String collectionPhotoCredit(String credit) {
    return 'Photo : $credit';
  }

  @override
  String paletteLockedHint(String card) {
    return 'Se trouve dans les boosters : la carte $card la débloque.';
  }

  @override
  String get devToolsTitle => 'Outils développeur';

  @override
  String get devToolsHelp =>
      'Données de test locales pour le burn et la collection. Uniquement en build debug, jamais livré.';

  @override
  String devAddBurnDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ajouter $count jours qualifiés',
      one: 'Ajouter 1 jour qualifié',
    );
    return '$_temp0';
  }

  @override
  String get devSeedApplied => 'Jours ajoutés ; paliers réévalués.';

  @override
  String get devResetRewards => 'Réinitialiser les récompenses';

  @override
  String get devResetRewardsHelp =>
      'Supprime les jours générés, tous les boosters et toute la collection sur cet appareil.';

  @override
  String get devResetDone => 'Récompenses réinitialisées.';

  @override
  String get devSyncNote =>
      'Les révisions générées ne partent jamais vers un compte ; les boosters et ouvertures suivent la sync normale du compte.';

  @override
  String get devNativeOnly =>
      'Disponible uniquement dans les apps mobile et desktop.';
}
