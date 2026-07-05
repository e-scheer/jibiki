/// Central API contract, base URL + every endpoint path in one place.
///
/// The base URL is injected at build time:
///   flutter run --dart-define=JIBIKI_API_BASE=http://localhost:8000
/// Defaults suit the common cases: an Android emulator reaches the host at
/// 10.0.2.2, everything else at localhost.
library;

import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static const String _override = String.fromEnvironment('JIBIKI_API_BASE');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    // Android emulator maps the host loopback to 10.0.2.2. defaultTargetPlatform
    // is web-safe (no dart:io), so the same code compiles for web builds too.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  // ── allauth headless (app client), auth flows ──────────────────────────────
  static const String authSignup = '/_allauth/app/v1/auth/signup';
  static const String authLogin = '/_allauth/app/v1/auth/login';
  static const String authSession = '/_allauth/app/v1/auth/session'; // GET current / DELETE logout

  // ── domain (authenticated by the same session token via X-Session-Token) ────
  static const String me = '/api/v1/auth/me';

  static const String dictSearch = '/api/v1/dict/search';
  static const String dictWords = '/api/v1/dict/words'; // browse (category), paginated
  static String dictWord(int id) => '/api/v1/dict/words/$id';
  static const String dictKanjiList = '/api/v1/dict/kanji';
  static String dictKanji(String literal) => '/api/v1/dict/kanji/$literal';
  static const String dictKana = '/api/v1/dict/kana';
  static String dictKanaDetail(String char) => '/api/v1/dict/kana/$char';
  static const String dictRadicals = '/api/v1/dict/radicals';

  static const String studyQueue = '/api/v1/study/queue';
  static const String studyStats = '/api/v1/study/stats';
  static const String studyOptimize = '/api/v1/study/optimize';
  static const String studyExport = '/api/v1/study/export';
  static const String studyDecks = '/api/v1/study/decks';
  static String deckEnroll(String id) => '/api/v1/study/decks/$id/enroll';
  static String deckQueue(String id) => '/api/v1/study/decks/$id/queue';
  static String cardFavorite(int id) => '/api/v1/study/cards/$id/favorite';
  static const String studyAdd = '/api/v1/study/add';
  static const String studyAddBulk = '/api/v1/study/add/bulk';
  static const String studyStates = '/api/v1/study/states'; // {item_ref: state}
  static const String studyCards = '/api/v1/study/cards';
  static String studyCardReview(int id) => '/api/v1/study/cards/$id/review';
  static String studyCard(int id) => '/api/v1/study/cards/$id';

  // Trailing slash: the list is the collection root under a slashed include.
  static const String mnemonics = '/api/v1/mnemonics/';
  static const String mnemonicCreate = '/api/v1/mnemonics/create';
  static const String mnemonicsMine = '/api/v1/mnemonics/mine';
  static const String mnemonicsSaved = '/api/v1/mnemonics/saved';
  static String mnemonicVote(int id) => '/api/v1/mnemonics/$id/vote';
  static String mnemonicSave(int id) => '/api/v1/mnemonics/$id/save';
  static String mnemonicReport(int id) => '/api/v1/mnemonics/$id/report';

  // Community decks of mnemonics (draw → pack → propose).
  static const String mnemonicDecks = '/api/v1/mnemonics/decks';
  static const String mnemonicDeckCreate = '/api/v1/mnemonics/decks/create';
  static String mnemonicDeck(int id) => '/api/v1/mnemonics/decks/$id';
  static String mnemonicDeckPublish(int id) => '/api/v1/mnemonics/decks/$id/publish';
  static String mnemonicDeckVote(int id) => '/api/v1/mnemonics/decks/$id/vote';
  static String mnemonicDeckEnroll(int id) => '/api/v1/mnemonics/decks/$id/enroll';
}
