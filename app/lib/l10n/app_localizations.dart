import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'jibiki'**
  String get appTitle;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotPassword;

  /// No description provided for @authBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get authBackToSignIn;

  /// No description provided for @authContinueToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Continue to sign in'**
  String get authContinueToSignIn;

  /// No description provided for @authCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get authCheckAgain;

  /// No description provided for @authLinkUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'We could not use this link'**
  String get authLinkUnavailableTitle;

  /// No description provided for @authLinkUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'It may be incomplete, expired or already used. Return to sign in or request a new link.'**
  String get authLinkUnavailableBody;

  /// No description provided for @verifyEmailEyebrow.
  ///
  /// In en, this message translates to:
  /// **'EMAIL CHECK'**
  String get verifyEmailEyebrow;

  /// No description provided for @verifyEmailHeadline.
  ///
  /// In en, this message translates to:
  /// **'One tap to confirm.'**
  String get verifyEmailHeadline;

  /// No description provided for @verifyEmailDescription.
  ///
  /// In en, this message translates to:
  /// **'Secure your jibiki account and keep every device in sync.'**
  String get verifyEmailDescription;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailCheckingTitle.
  ///
  /// In en, this message translates to:
  /// **'Checking your link'**
  String get verifyEmailCheckingTitle;

  /// No description provided for @verifyEmailCheckingBody.
  ///
  /// In en, this message translates to:
  /// **'This only takes a moment.'**
  String get verifyEmailCheckingBody;

  /// No description provided for @verifyEmailReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your email is ready to verify'**
  String get verifyEmailReadyTitle;

  /// No description provided for @verifyEmailReadyBody.
  ///
  /// In en, this message translates to:
  /// **'Confirm this address to finish securing your account.'**
  String get verifyEmailReadyBody;

  /// No description provided for @verifyEmailAction.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get verifyEmailAction;

  /// No description provided for @verifyEmailSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get verifyEmailSuccessTitle;

  /// No description provided for @verifyEmailSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your account is ready. Sign in to continue where you stopped.'**
  String get verifyEmailSuccessBody;

  /// No description provided for @passwordResetEyebrow.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT RECOVERY'**
  String get passwordResetEyebrow;

  /// No description provided for @passwordResetHeadline.
  ///
  /// In en, this message translates to:
  /// **'Back in, calmly.'**
  String get passwordResetHeadline;

  /// No description provided for @passwordResetDescription.
  ///
  /// In en, this message translates to:
  /// **'Reset access without losing your local dictionary or study history.'**
  String get passwordResetDescription;

  /// No description provided for @passwordResetRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get passwordResetRequestTitle;

  /// No description provided for @passwordResetRequestBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email. We will send a secure reset link if an account matches.'**
  String get passwordResetRequestBody;

  /// No description provided for @emailFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailFieldLabel;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterValidEmail;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @passwordResetRequestSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get passwordResetRequestSuccessTitle;

  /// No description provided for @passwordResetRequestSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'If an account matches that email, a reset link is on its way.'**
  String get passwordResetRequestSuccessBody;

  /// No description provided for @passwordResetCheckingTitle.
  ///
  /// In en, this message translates to:
  /// **'Checking your reset link'**
  String get passwordResetCheckingTitle;

  /// No description provided for @passwordResetCheckingBody.
  ///
  /// In en, this message translates to:
  /// **'We are making sure it is still secure and active.'**
  String get passwordResetCheckingBody;

  /// No description provided for @chooseNewPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get chooseNewPasswordTitle;

  /// No description provided for @chooseNewPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters. A longer, unique passphrase is even better.'**
  String get chooseNewPasswordBody;

  /// No description provided for @newPasswordFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordFieldLabel;

  /// No description provided for @confirmPasswordFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordFieldLabel;

  /// No description provided for @passwordAtLeastEight.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters'**
  String get passwordAtLeastEight;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @setNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get setNewPassword;

  /// No description provided for @passwordResetSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get passwordResetSuccessTitle;

  /// No description provided for @passwordResetSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your password was changed. Sign in with the new one.'**
  String get passwordResetSuccessBody;

  /// No description provided for @requestAnotherResetLink.
  ///
  /// In en, this message translates to:
  /// **'Request another link'**
  String get requestAnotherResetLink;

  /// No description provided for @socialAuthEyebrow.
  ///
  /// In en, this message translates to:
  /// **'SIGN-IN STATUS'**
  String get socialAuthEyebrow;

  /// No description provided for @socialAuthHeadline.
  ///
  /// In en, this message translates to:
  /// **'That handoff stopped.'**
  String get socialAuthHeadline;

  /// No description provided for @socialAuthDescription.
  ///
  /// In en, this message translates to:
  /// **'Your account stays safe. Choose how you want to continue.'**
  String get socialAuthDescription;

  /// No description provided for @socialAuthCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in cancelled'**
  String get socialAuthCancelledTitle;

  /// No description provided for @socialAuthCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing was changed. You can try again whenever you are ready.'**
  String get socialAuthCancelledBody;

  /// No description provided for @socialAuthDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was not approved'**
  String get socialAuthDeniedTitle;

  /// No description provided for @socialAuthDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'The provider did not approve this request. Check its permissions, then try again.'**
  String get socialAuthDeniedBody;

  /// No description provided for @socialAuthReauthenticationTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to continue'**
  String get socialAuthReauthenticationTitle;

  /// No description provided for @socialAuthReauthenticationBody.
  ///
  /// In en, this message translates to:
  /// **'For your security, the provider needs a fresh sign-in before this action can finish.'**
  String get socialAuthReauthenticationBody;

  /// No description provided for @socialAuthSignupClosedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account creation is unavailable'**
  String get socialAuthSignupClosedTitle;

  /// No description provided for @socialAuthSignupClosedBody.
  ///
  /// In en, this message translates to:
  /// **'New social accounts cannot be created right now. Try an existing account instead.'**
  String get socialAuthSignupClosedBody;

  /// No description provided for @socialAuthUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'We could not finish sign-in'**
  String get socialAuthUnknownTitle;

  /// No description provided for @socialAuthUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'The provider returned an unexpected result. Your jibiki data was not changed.'**
  String get socialAuthUnknownBody;

  /// No description provided for @trySignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Try sign-in again'**
  String get trySignInAgain;

  /// No description provided for @returnToJibiki.
  ///
  /// In en, this message translates to:
  /// **'Return to jibiki'**
  String get returnToJibiki;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @interfaceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Interface language'**
  String get interfaceLanguage;

  /// No description provided for @interfaceLanguageHelp.
  ///
  /// In en, this message translates to:
  /// **'Changes menus and messages immediately. Mnemonic language remains a separate choice.'**
  String get interfaceLanguageHelp;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @mode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// No description provided for @dictionaryMode.
  ///
  /// In en, this message translates to:
  /// **'Dictionary'**
  String get dictionaryMode;

  /// No description provided for @dictionaryModeHelp.
  ///
  /// In en, this message translates to:
  /// **'Search first, without review reminders.'**
  String get dictionaryModeHelp;

  /// No description provided for @middleMode.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get middleMode;

  /// No description provided for @middleModeHelp.
  ///
  /// In en, this message translates to:
  /// **'Dictionary home with a gentle due-card badge.'**
  String get middleModeHelp;

  /// No description provided for @learningMode.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get learningMode;

  /// No description provided for @learningModeHelp.
  ///
  /// In en, this message translates to:
  /// **'Review queue, goals, and streaks take priority.'**
  String get learningModeHelp;

  /// No description provided for @mnemonicLanguage.
  ///
  /// In en, this message translates to:
  /// **'Mnemonic language'**
  String get mnemonicLanguage;

  /// No description provided for @mnemonicLanguageHelp.
  ///
  /// In en, this message translates to:
  /// **'Any language works. Where content is missing, English is used as a fallback and the community can create the first set.'**
  String get mnemonicLanguageHelp;

  /// No description provided for @spacedRepetition.
  ///
  /// In en, this message translates to:
  /// **'Spaced repetition'**
  String get spacedRepetition;

  /// No description provided for @newCardsPerSession.
  ///
  /// In en, this message translates to:
  /// **'New cards per session'**
  String get newCardsPerSession;

  /// No description provided for @newCardsHelp.
  ///
  /// In en, this message translates to:
  /// **'How many new cards to start a session with. This is not a daily cap; choose Study more at the end to keep going.'**
  String get newCardsHelp;

  /// No description provided for @desiredRetention.
  ///
  /// In en, this message translates to:
  /// **'Desired retention'**
  String get desiredRetention;

  /// No description provided for @studyReminders.
  ///
  /// In en, this message translates to:
  /// **'Study reminders'**
  String get studyReminders;

  /// No description provided for @studyRemindersHelp.
  ///
  /// In en, this message translates to:
  /// **'A gentle nudge when enough cards are due.'**
  String get studyRemindersHelp;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @mySubmissions.
  ///
  /// In en, this message translates to:
  /// **'My submissions'**
  String get mySubmissions;

  /// No description provided for @mySubmissionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Your drawn mnemonics and their review status.'**
  String get mySubmissionsHelp;

  /// No description provided for @myPacks.
  ///
  /// In en, this message translates to:
  /// **'My packs'**
  String get myPacks;

  /// No description provided for @myPacksHelp.
  ///
  /// In en, this message translates to:
  /// **'Packs you created, drafts, in review, and published.'**
  String get myPacksHelp;

  /// No description provided for @makeJibikiBetter.
  ///
  /// In en, this message translates to:
  /// **'Make jibiki better'**
  String get makeJibikiBetter;

  /// No description provided for @makeJibikiBetterHelp.
  ///
  /// In en, this message translates to:
  /// **'Ideas, bugs, and love letters: we read every one.'**
  String get makeJibikiBetterHelp;

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @usageAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Usage analytics'**
  String get usageAnalytics;

  /// No description provided for @usageAnalyticsHelp.
  ///
  /// In en, this message translates to:
  /// **'Share anonymous screen and feature usage to help improve jibiki. Search text and study content are never collected.'**
  String get usageAnalyticsHelp;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @diagnosticsHelp.
  ///
  /// In en, this message translates to:
  /// **'Share performance timings and crash reports. Reports exclude account details and learning content.'**
  String get diagnosticsHelp;

  /// No description provided for @offlineStorage.
  ///
  /// In en, this message translates to:
  /// **'Offline and storage'**
  String get offlineStorage;

  /// No description provided for @offlineStorageHelp.
  ///
  /// In en, this message translates to:
  /// **'Dictionary packs on this device, updates, and sync status.'**
  String get offlineStorageHelp;

  /// No description provided for @exportToAnki.
  ///
  /// In en, this message translates to:
  /// **'Export to Anki'**
  String get exportToAnki;

  /// No description provided for @exportToAnkiHelp.
  ///
  /// In en, this message translates to:
  /// **'Your deck as an Anki-importable TSV.'**
  String get exportToAnkiHelp;

  /// No description provided for @personalisedScheduling.
  ///
  /// In en, this message translates to:
  /// **'Personalised scheduling'**
  String get personalisedScheduling;

  /// No description provided for @personalisedSchedulingHelp.
  ///
  /// In en, this message translates to:
  /// **'Train FSRS on your own history once you have enough reviews.'**
  String get personalisedSchedulingHelp;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @syncWithAccount.
  ///
  /// In en, this message translates to:
  /// **'Sync with an account'**
  String get syncWithAccount;

  /// No description provided for @syncWithAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account. Your local progress stays on this device until you choose how to reconcile it with the cloud.'**
  String get syncWithAccountHelp;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailed;

  /// No description provided for @exportCards.
  ///
  /// In en, this message translates to:
  /// **'Export: {count} cards'**
  String exportCards(int count);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @ankiCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied. Paste into a .txt file and import it in Anki.'**
  String get ankiCopied;

  /// No description provided for @reviewProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} / {required} reviews'**
  String reviewProgress(int current, int required);

  /// No description provided for @fsrsReady.
  ///
  /// In en, this message translates to:
  /// **'Ready. FSRS can now be tuned to your own memory.'**
  String get fsrsReady;

  /// No description provided for @fsrsKeepReviewing.
  ///
  /// In en, this message translates to:
  /// **'Keep reviewing. FSRS uses solid defaults until then.'**
  String get fsrsKeepReviewing;

  /// No description provided for @optimiseNow.
  ///
  /// In en, this message translates to:
  /// **'Optimise now'**
  String get optimiseNow;

  /// No description provided for @schedulerPersonalised.
  ///
  /// In en, this message translates to:
  /// **'Scheduler personalised to your history.'**
  String get schedulerPersonalised;

  /// No description provided for @schedulerDefaultsKept.
  ///
  /// In en, this message translates to:
  /// **'The defaults were kept because they already fit you well.'**
  String get schedulerDefaultsKept;

  /// No description provided for @dictionaryCredits.
  ///
  /// In en, this message translates to:
  /// **'jibiki · dictionary data © EDRDG (JMdict/KANJIDIC)'**
  String get dictionaryCredits;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
