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
}
