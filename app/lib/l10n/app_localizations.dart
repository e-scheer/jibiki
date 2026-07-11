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
