// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'jibiki';

  @override
  String get forgotPassword => 'Forgot your password?';

  @override
  String get authBackToSignIn => 'Back to sign in';

  @override
  String get authContinueToSignIn => 'Continue to sign in';

  @override
  String get authCheckAgain => 'Check again';

  @override
  String get authLinkUnavailableTitle => 'We could not use this link';

  @override
  String get authLinkUnavailableBody =>
      'It may be incomplete, expired or already used. Return to sign in or request a new link.';

  @override
  String get verifyEmailEyebrow => 'EMAIL CHECK';

  @override
  String get verifyEmailHeadline => 'One tap to confirm.';

  @override
  String get verifyEmailDescription =>
      'Secure your jibiki account and keep every device in sync.';

  @override
  String get verifyEmailTitle => 'Verify your email';

  @override
  String get verifyEmailCheckingTitle => 'Checking your link';

  @override
  String get verifyEmailCheckingBody => 'This only takes a moment.';

  @override
  String get verifyEmailReadyTitle => 'Your email is ready to verify';

  @override
  String get verifyEmailReadyBody =>
      'Confirm this address to finish securing your account.';

  @override
  String get verifyEmailAction => 'Verify email';

  @override
  String get verifyEmailSuccessTitle => 'Email verified';

  @override
  String get verifyEmailSuccessBody =>
      'Your account is ready. Sign in to continue where you stopped.';

  @override
  String get passwordResetEyebrow => 'ACCOUNT RECOVERY';

  @override
  String get passwordResetHeadline => 'Back in, calmly.';

  @override
  String get passwordResetDescription =>
      'Reset access without losing your local dictionary or study history.';

  @override
  String get passwordResetRequestTitle => 'Reset your password';

  @override
  String get passwordResetRequestBody =>
      'Enter your account email. We will send a secure reset link if an account matches.';

  @override
  String get emailFieldLabel => 'Email';

  @override
  String get enterValidEmail => 'Enter a valid email';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get passwordResetRequestSuccessTitle => 'Check your inbox';

  @override
  String get passwordResetRequestSuccessBody =>
      'If an account matches that email, a reset link is on its way.';

  @override
  String get passwordResetCheckingTitle => 'Checking your reset link';

  @override
  String get passwordResetCheckingBody =>
      'We are making sure it is still secure and active.';

  @override
  String get chooseNewPasswordTitle => 'Choose a new password';

  @override
  String get chooseNewPasswordBody =>
      'Use at least 8 characters. A longer, unique passphrase is even better.';

  @override
  String get newPasswordFieldLabel => 'New password';

  @override
  String get confirmPasswordFieldLabel => 'Confirm password';

  @override
  String get passwordAtLeastEight => 'Use at least 8 characters';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get setNewPassword => 'Set new password';

  @override
  String get passwordResetSuccessTitle => 'Password updated';

  @override
  String get passwordResetSuccessBody =>
      'Your password was changed. Sign in with the new one.';

  @override
  String get requestAnotherResetLink => 'Request another link';

  @override
  String get socialAuthEyebrow => 'SIGN-IN STATUS';

  @override
  String get socialAuthHeadline => 'That handoff stopped.';

  @override
  String get socialAuthDescription =>
      'Your account stays safe. Choose how you want to continue.';

  @override
  String get socialAuthCancelledTitle => 'Sign-in cancelled';

  @override
  String get socialAuthCancelledBody =>
      'Nothing was changed. You can try again whenever you are ready.';

  @override
  String get socialAuthDeniedTitle => 'Sign-in was not approved';

  @override
  String get socialAuthDeniedBody =>
      'The provider did not approve this request. Check its permissions, then try again.';

  @override
  String get socialAuthReauthenticationTitle => 'Sign in again to continue';

  @override
  String get socialAuthReauthenticationBody =>
      'For your security, the provider needs a fresh sign-in before this action can finish.';

  @override
  String get socialAuthSignupClosedTitle => 'Account creation is unavailable';

  @override
  String get socialAuthSignupClosedBody =>
      'New social accounts cannot be created right now. Try an existing account instead.';

  @override
  String get socialAuthUnknownTitle => 'We could not finish sign-in';

  @override
  String get socialAuthUnknownBody =>
      'The provider returned an unexpected result. Your jibiki data was not changed.';

  @override
  String get trySignInAgain => 'Try sign-in again';

  @override
  String get returnToJibiki => 'Return to jibiki';

  @override
  String get settings => 'Settings';

  @override
  String get interfaceLanguage => 'Interface language';

  @override
  String get interfaceLanguageHelp =>
      'Changes menus and messages immediately. Mnemonic language remains a separate choice.';

  @override
  String get english => 'English';

  @override
  String get french => 'French';

  @override
  String get mode => 'Mode';

  @override
  String get dictionaryMode => 'Dictionary';

  @override
  String get dictionaryModeHelp => 'Search first, without review reminders.';

  @override
  String get middleMode => 'Balanced';

  @override
  String get middleModeHelp => 'Dictionary home with a gentle due-card badge.';

  @override
  String get learningMode => 'Learning';

  @override
  String get learningModeHelp =>
      'Review queue, goals, and streaks take priority.';

  @override
  String get mnemonicLanguage => 'Mnemonic language';

  @override
  String get mnemonicLanguageHelp =>
      'Any language works. Where content is missing, English is used as a fallback and the community can create the first set.';

  @override
  String get spacedRepetition => 'Spaced repetition';

  @override
  String get newCardsPerSession => 'New cards per session';

  @override
  String get newCardsHelp =>
      'How many new cards to start a session with. This is not a daily cap; choose Study more at the end to keep going.';

  @override
  String get desiredRetention => 'Desired retention';

  @override
  String get studyReminders => 'Study reminders';

  @override
  String get studyRemindersHelp => 'A gentle nudge when enough cards are due.';

  @override
  String get community => 'Community';

  @override
  String get mySubmissions => 'My submissions';

  @override
  String get mySubmissionsHelp =>
      'Your drawn mnemonics and their review status.';

  @override
  String get myPacks => 'My packs';

  @override
  String get myPacksHelp =>
      'Packs you created, drafts, in review, and published.';

  @override
  String get makeJibikiBetter => 'Make jibiki better';

  @override
  String get makeJibikiBetterHelp =>
      'Ideas, bugs, and love letters: we read every one.';

  @override
  String get data => 'Data';

  @override
  String get privacy => 'Privacy';

  @override
  String get usageAnalytics => 'Usage analytics';

  @override
  String get usageAnalyticsHelp =>
      'Share anonymous screen and feature usage to help improve jibiki. Search text and study content are never collected.';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get diagnosticsHelp =>
      'Share performance timings and crash reports. Reports exclude account details and learning content.';

  @override
  String get offlineStorage => 'Offline and storage';

  @override
  String get offlineStorageHelp =>
      'Dictionary packs on this device, updates, and sync status.';

  @override
  String get exportToAnki => 'Export to Anki';

  @override
  String get exportToAnkiHelp => 'Your deck as an Anki-importable TSV.';

  @override
  String get personalisedScheduling => 'Personalised scheduling';

  @override
  String get personalisedSchedulingHelp =>
      'Train FSRS on your own history once you have enough reviews.';

  @override
  String get account => 'Account';

  @override
  String get signOut => 'Sign out';

  @override
  String get syncWithAccount => 'Sync with an account';

  @override
  String get syncWithAccountHelp =>
      'Sign in or create an account. Your local progress stays on this device until you choose how to reconcile it with the cloud.';

  @override
  String get exportFailed => 'Export failed';

  @override
  String exportCards(int count) {
    return 'Export: $count cards';
  }

  @override
  String get close => 'Close';

  @override
  String get copy => 'Copy';

  @override
  String get ankiCopied =>
      'Copied. Paste into a .txt file and import it in Anki.';

  @override
  String reviewProgress(int current, int required) {
    return '$current / $required reviews';
  }

  @override
  String get fsrsReady => 'Ready. FSRS can now be tuned to your own memory.';

  @override
  String get fsrsKeepReviewing =>
      'Keep reviewing. FSRS uses solid defaults until then.';

  @override
  String get optimiseNow => 'Optimise now';

  @override
  String get schedulerPersonalised => 'Scheduler personalised to your history.';

  @override
  String get schedulerDefaultsKept =>
      'The defaults were kept because they already fit you well.';

  @override
  String get dictionaryCredits =>
      'jibiki · dictionary data © EDRDG (JMdict/KANJIDIC)';

  @override
  String get burnTitle => 'Learning burn';

  @override
  String burnDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
      zero: '0 days',
    );
    return '$_temp0';
  }

  @override
  String burnBest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return 'Best: $_temp0';
  }

  @override
  String get burnTodayCounted => 'Today is in. See you tomorrow.';

  @override
  String get burnComeBackToday => 'One review today keeps your burn going.';

  @override
  String burnNextBooster(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days to your next booster',
      one: '1 day to your next booster',
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
      other: '$count boosters to open',
      one: '1 booster to open',
    );
    return '$_temp0';
  }

  @override
  String get boosterShelfFull =>
      'Your shelf is full. Open a booster to make room for the next milestone.';

  @override
  String get boosterEarnedTitle => 'Booster earned!';

  @override
  String boosterEarnedBody(int milestone) {
    return 'Day $milestone of your burn. Open it whenever you like.';
  }

  @override
  String get boosterOpenAction => 'Open the booster';

  @override
  String get boosterOpenLater => 'Later';

  @override
  String get boosterSlideToOpen => 'Slide across the pack to open it';

  @override
  String get boosterTapToOpen => 'Tap to open';

  @override
  String get boosterSkipAnimation => 'Skip animation';

  @override
  String get boosterSwipeToReveal => 'Swipe to reveal';

  @override
  String get boosterTapToContinue => 'Tap to continue';

  @override
  String get boosterTapToReveal => 'Tap to reveal';

  @override
  String get boosterTiltHint => 'Drag the card to tilt it';

  @override
  String get boosterNewCard => 'New card';

  @override
  String boosterDuplicate(int count) {
    return 'Duplicate ×$count';
  }

  @override
  String get boosterSummaryTitle => 'Booster opened';

  @override
  String boosterSummaryNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new cards',
      one: '1 new card',
    );
    return '$_temp0';
  }

  @override
  String boosterSummaryDuplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplicates',
      one: '1 duplicate',
    );
    return '$_temp0';
  }

  @override
  String get boosterGoToCollection => 'See the collection';

  @override
  String get collectionTitle => 'Collection';

  @override
  String collectionSetProgress(int owned, int total) {
    return '$owned / $total cards';
  }

  @override
  String collectionShinyCount(int count) {
    return '$count shiny';
  }

  @override
  String get collectionFilterAll => 'All';

  @override
  String get collectionFilterOwned => 'Owned';

  @override
  String get collectionFilterMissing => 'Missing';

  @override
  String get collectionFilterDuplicates => 'Duplicates';

  @override
  String get collectionCardNotOwned => 'Not obtained yet';

  @override
  String get collectionEmptyBody =>
      'Real reviews feed your burn; milestones drop boosters full of Japan cards.';

  @override
  String collectionUnlocks(String what) {
    return 'Unlocks: $what';
  }

  @override
  String get collectionUnlocked => 'Unlocked';

  @override
  String get collectionVocab => 'Japanese to remember';

  @override
  String get collectionFlipCard => 'Flip the card';

  @override
  String get contentFallbackEnglish =>
      'Not yet written in your language; shown in English.';

  @override
  String get rarityCommon => 'Common';

  @override
  String get rarityRare => 'Rare';

  @override
  String get raritySpecial => 'Special';

  @override
  String get rarityShiny => 'Shiny';

  @override
  String get categoryPlace => 'Place';

  @override
  String get categoryCulture => 'Culture';

  @override
  String get categoryFood => 'Food & drink';

  @override
  String get categoryObject => 'Everyday object';

  @override
  String get categoryTransport => 'Trains & cities';

  @override
  String get categoryNature => 'Nature';

  @override
  String get categoryCraft => 'Craft';

  @override
  String get categoryPerson => 'Personality';

  @override
  String get categorySociety => 'Society';

  @override
  String get categoryHistory => 'History';

  @override
  String get categoryFestival => 'Festivals & seasons';

  @override
  String get paletteLockedLabel => 'Locked';

  @override
  String collectionPhotoCredit(String credit) {
    return 'Photo: $credit';
  }

  @override
  String paletteLockedHint(String card) {
    return 'Found in boosters: the $card card unlocks it.';
  }

  @override
  String get devToolsTitle => 'Developer tools';

  @override
  String get devToolsHelp =>
      'Local test data for the burn and the collection. Debug builds only, never shipped.';

  @override
  String devAddBurnDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count qualified days',
      one: 'Add 1 qualified day',
    );
    return '$_temp0';
  }

  @override
  String get devSeedApplied => 'Days added; milestones re-evaluated.';

  @override
  String get devResetRewards => 'Reset rewards';

  @override
  String get devResetRewardsHelp =>
      'Removes seeded days, every booster and the whole collection on this device.';

  @override
  String get devResetDone => 'Rewards reset.';

  @override
  String get devSyncNote =>
      'Seeded reviews never upload to an account; boosters and openings follow the normal account sync.';

  @override
  String get devNativeOnly => 'Available in the mobile and desktop apps only.';
}
