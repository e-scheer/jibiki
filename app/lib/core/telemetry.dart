import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:uuid/uuid.dart';

import 'session_store.dart';
import 'telemetry_consent_bridge.dart';
import 'telemetry_config.dart';

enum TelemetryConsent { undecided, denied, partial, granted }

/// Privacy-reviewed product events. Keep this list closed so a call site can
/// never send an improvised event name or learner content by mistake.
abstract final class TelemetryEvent {
  static const cardRated = 'card_rated';
  static const deckEnrolled = 'deck_enrolled';
  static const deckPublished = 'deck_published';
  static const emailVerificationResult = 'email_verification_result';
  static const feedbackSent = 'feedback_sent';
  static const guestContinue = 'guest_continue';
  static const interfaceLanguageChanged = 'interface_language_changed';
  static const login = 'login';
  static const loginResult = 'login_result';
  static const mnemonicCreated = 'mnemonic_created';
  static const mnemonicReported = 'mnemonic_reported';
  static const mnemonicSaved = 'mnemonic_saved';
  static const mnemonicViewed = 'mnemonic_viewed';
  static const mnemonicVoted = 'mnemonic_voted';
  static const mnemonicLanguageChanged = 'mnemonic_language_changed';
  static const onboardingComplete = 'onboarding_complete';
  static const passwordResetRequested = 'password_reset_requested';
  static const passwordResetResult = 'password_reset_result';
  static const packDownloadCompleted = 'pack_download_completed';
  static const packInstallCompleted = 'pack_install_completed';
  static const searchResults = 'search_results';
  static const searchSubmitted = 'search_submitted';
  static const signUp = 'sign_up';
  static const signUpResult = 'sign_up_result';
  static const studyCardAdded = 'study_card_added';
  static const studyCardRemoved = 'study_card_removed';
  static const studyMore = 'study_more';
  static const studySessionCompleted = 'study_session_completed';
  static const studySessionStarted = 'study_session_started';
  static const syncCompleted = 'sync_completed';
  static const themeChanged = 'theme_changed';
  static const tutorialComplete = 'tutorial_complete';
  static const writingPracticeCompleted = 'writing_practice_completed';
  static const writingPracticeStarted = 'writing_practice_started';

  static const allowedNames = <String>{
    cardRated,
    deckEnrolled,
    deckPublished,
    emailVerificationResult,
    feedbackSent,
    guestContinue,
    interfaceLanguageChanged,
    login,
    loginResult,
    mnemonicCreated,
    mnemonicReported,
    mnemonicSaved,
    mnemonicViewed,
    mnemonicVoted,
    mnemonicLanguageChanged,
    onboardingComplete,
    passwordResetRequested,
    passwordResetResult,
    packDownloadCompleted,
    packInstallCompleted,
    searchResults,
    searchSubmitted,
    signUp,
    signUpResult,
    studyCardAdded,
    studyCardRemoved,
    studyMore,
    studySessionCompleted,
    studySessionStarted,
    syncCompleted,
    themeChanged,
    tutorialComplete,
    writingPracticeCompleted,
    writingPracticeStarted,
  };
}

abstract interface class TelemetrySink {
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  });
}

/// Consent-first entry point for analytics, diagnostics and performance data.
///
/// No provider is initialized until the learner explicitly opts in. Event
/// parameters are deliberately limited to small scalar values and known
/// sensitive keys are discarded before they reach any SDK.
class Telemetry extends ChangeNotifier implements TelemetrySink {
  Telemetry({
    this.config = const TelemetryConfig.fromEnvironment(),
    this.installGlobalHandlers = true,
  });

  static final Telemetry instance = Telemetry();
  static const _uuid = Uuid();
  static const _allowedContextKeys = {
    'account_state',
    'app_mode',
    'form_factor',
    'interface_language',
    'mnemonic_language',
    'palette',
    'plan',
    'platform',
  };
  static const _allowedParameterKeys = {
    'added_count',
    'action',
    'app_mode',
    'cached',
    'card_count',
    'card_state',
    'count',
    'download_selected',
    'deck_kind',
    'duration_bucket',
    'error_type',
    'gloss_language',
    'input_kind',
    'interface_language',
    'item_type',
    'kind',
    'length_bucket',
    'library',
    'method',
    'mnemonic_language',
    'name_count',
    'new_count',
    'placement',
    'rating',
    'request_id',
    'result',
    'reviewed_count',
    'route',
    'source',
    'status',
    'theme_mode',
    'palette',
    'view_model',
    'word_count',
  };

  final TelemetryConfig config;
  final bool installGlobalHandlers;

  SessionStore? _store;
  bool? _analyticsConsent;
  bool? _diagnosticsConsent;
  bool _initialized = false;
  bool _handlersInstalled = false;
  bool _firebaseReady = false;
  bool _sentryReady = false;
  Future<void>? _providerInitialization;
  FirebaseAnalytics? _analytics;
  FirebasePerformance? _performance;
  FirebaseCrashlytics? _crashlytics;
  String? _installId;
  final Map<String, String> _context = {};
  final Map<String, String> _appliedContext = {};

  TelemetryConsent get consent {
    if (_analyticsConsent == null && _diagnosticsConsent == null) {
      return TelemetryConsent.undecided;
    }
    if (analyticsConsentGranted && diagnosticsConsentGranted) {
      return TelemetryConsent.granted;
    }
    if (!analyticsConsentGranted && !diagnosticsConsentGranted) {
      return TelemetryConsent.denied;
    }
    return TelemetryConsent.partial;
  }

  bool get analyticsConsentGranted => _analyticsConsent == true;
  bool get diagnosticsConsentGranted => _diagnosticsConsent == true;
  bool get isConfigured => config.hasFirebase || (kIsWeb && config.hasSentry);
  bool get isActive =>
      (analyticsConsentGranted || diagnosticsConsentGranted) &&
      (_firebaseReady || _sentryReady);

  Future<void> initialize(SessionStore store) async {
    if (_initialized) return;
    _initialized = true;
    _store = store;
    if (installGlobalHandlers) _installGlobalErrorHandlers();
    _analyticsConsent = store.telemetryAnalyticsConsent;
    _diagnosticsConsent = store.telemetryDiagnosticsConsent;
    final sharedConsent = await readSharedTelemetryConsent();
    if (sharedConsent != null) {
      final analytics = sharedConsent.analytics ?? _analyticsConsent ?? false;
      final diagnostics =
          sharedConsent.diagnostics ?? _diagnosticsConsent ?? false;
      await store.setTelemetryConsent(
        analytics: analytics,
        diagnostics: diagnostics,
      );
      _analyticsConsent = analytics;
      _diagnosticsConsent = diagnostics;
    }
    if (analyticsConsentGranted || diagnosticsConsentGranted) {
      await _enableProviders();
    }
    notifyListeners();
  }

  Future<void> setAnalyticsConsent(bool enabled) => setConsent(
        analytics: enabled,
        diagnostics: _diagnosticsConsent ?? false,
      );

  Future<void> setDiagnosticsConsent(bool enabled) => setConsent(
        analytics: _analyticsConsent ?? false,
        diagnostics: enabled,
      );

  Future<void> setConsent({
    required bool analytics,
    required bool diagnostics,
  }) async {
    final store = _store;
    if (store == null) return;
    await store.setTelemetryConsent(
      analytics: analytics,
      diagnostics: diagnostics,
    );
    await writeSharedTelemetryConsent(
      analytics: analytics,
      diagnostics: diagnostics,
    );
    final analyticsWasEnabled = analyticsConsentGranted;
    final diagnosticsWereEnabled = diagnosticsConsentGranted;
    _analyticsConsent = analytics;
    _diagnosticsConsent = diagnostics;
    notifyListeners();
    final initialization = _providerInitialization;
    if (initialization != null) await _ignoreFailure(initialization);
    if (!analytics && analyticsWasEnabled) await _disableAnalytics();
    if (!diagnostics && diagnosticsWereEnabled) await _disableDiagnostics();
    if (analytics || diagnostics) {
      await _enableProviders();
    }
    if (!analytics && !diagnostics) {
      await store.setTelemetryInstallId(null);
      _installId = null;
    }
    notifyListeners();
  }

  /// Adds privacy-safe context used to segment reliability and product data.
  /// Values must describe the app state, never the learner's content.
  Future<void> setContext(Map<String, String> values) async {
    final sanitized = <String, String>{};
    for (final entry in values.entries) {
      final key = _sanitizeKey(entry.key);
      if (key == null ||
          !_allowedContextKeys.contains(key) ||
          _isSensitiveKey(key) ||
          !_isAsciiCategory(entry.value)) {
        continue;
      }
      sanitized[key] = _truncate(entry.value, 100);
    }
    if (!mapEquals(_context, sanitized)) {
      _context
        ..clear()
        ..addAll(sanitized);
    }
    if (!analyticsConsentGranted && !diagnosticsConsentGranted) return;
    if (mapEquals(_appliedContext, sanitized)) return;

    final analytics = _analytics;
    if (analytics != null) {
      for (final entry in sanitized.entries) {
        await _ignoreFailure(
          analytics.setUserProperty(name: entry.key, value: entry.value),
        );
      }
    }
    final crashlytics = _crashlytics;
    if (crashlytics != null) {
      for (final entry in sanitized.entries) {
        await _ignoreFailure(
          crashlytics.setCustomKey(entry.key, entry.value),
        );
      }
    }
    if (_sentryReady) {
      await Sentry.configureScope((scope) async {
        for (final entry in sanitized.entries) {
          await scope.setTag(entry.key, entry.value);
        }
      });
    }
    _appliedContext
      ..clear()
      ..addAll(sanitized);
  }

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async {
    if (!analyticsConsentGranted && !diagnosticsConsentGranted) return;
    final eventName = _sanitizeEventName(name);
    if (eventName == null || !TelemetryEvent.allowedNames.contains(eventName)) {
      return;
    }
    final safeParameters = sanitizeParameters(parameters);

    final analytics = _analytics;
    if (analyticsConsentGranted && analytics != null) {
      await _ignoreFailure(
        analytics.logEvent(name: eventName, parameters: safeParameters),
      );
    }
    if (diagnosticsConsentGranted && _sentryReady) {
      await Sentry.addBreadcrumb(
        Breadcrumb(
          category: 'product',
          message: eventName,
          data: safeParameters,
          level: SentryLevel.info,
        ),
      );
    }
    if (diagnosticsConsentGranted) {
      await _ignoreFailure(_crashlytics?.log('event:$eventName'));
    }
  }

  Future<void> screenView(String routeName) async {
    if (!analyticsConsentGranted && !diagnosticsConsentGranted) return;
    final normalized = normalizeRoute(routeName);
    final analytics = _analytics;
    if (analyticsConsentGranted && analytics != null) {
      await _ignoreFailure(
        analytics.logScreenView(
          screenName: normalized,
          screenClass: 'flutter_route',
        ),
      );
    }
    if (diagnosticsConsentGranted && _sentryReady) {
      await Sentry.addBreadcrumb(
        Breadcrumb(
          category: 'navigation',
          type: 'navigation',
          data: {'to': normalized},
          level: SentryLevel.info,
        ),
      );
    }
    if (diagnosticsConsentGranted) {
      await _ignoreFailure(_crashlytics?.log('screen:$normalized'));
    }
  }

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    String mechanism = 'caught',
    Map<String, Object?> context = const {},
  }) async {
    if (!diagnosticsConsentGranted) return;
    final safeContext = sanitizeParameters({
      ...context,
      'error_type': error.runtimeType.toString(),
    });
    final safeError = _PrivacySafeTelemetryException(
      error.runtimeType.toString(),
    );
    final crashlytics = _crashlytics;
    if (crashlytics != null) {
      await _ignoreFailure(
        crashlytics.recordError(
          safeError,
          stackTrace,
          fatal: fatal,
          reason: mechanism,
          information: safeContext.entries,
          printDetails: false,
        ),
      );
    }
    if (_sentryReady) {
      await Sentry.captureException(
        safeError,
        stackTrace: stackTrace,
        withScope: (scope) async {
          await scope.setTag('mechanism', mechanism);
          await scope.setTag('fatal', fatal.toString());
          if (safeContext.isNotEmpty) {
            await scope.setContexts('telemetry', safeContext);
          }
        },
      );
    }
  }

  TelemetryRequestTrace? startRequestTrace({
    required String method,
    required String path,
  }) {
    final performance = _performance;
    if (!diagnosticsConsentGranted || performance == null) return null;
    final normalizedPath = normalizeHttpPath(path);
    try {
      final trace = performance.newTrace('api_request');
      trace.putAttribute('method', method.toUpperCase());
      trace.putAttribute('route', _truncate(normalizedPath, 100));
      return TelemetryRequestTrace._(trace, trace.start());
    } catch (_) {
      return null;
    }
  }

  String createRequestId() => _uuid.v4();

  Future<void> _enableProviders() {
    final running = _providerInitialization;
    if (running != null) return running;
    final future = _initializeProviders();
    _providerInitialization = future;
    return future.whenComplete(() => _providerInitialization = null);
  }

  Future<void> _initializeProviders() async {
    if (!analyticsConsentGranted && !diagnosticsConsentGranted) return;
    final store = _store;
    if (store == null) return;
    _installId ??= store.telemetryInstallId;
    if (_installId == null) {
      _installId = _uuid.v4();
      await store.setTelemetryInstallId(_installId);
    }

    if (config.hasFirebase) await _initializeFirebase();
    if (diagnosticsConsentGranted &&
        kIsWeb &&
        config.hasSentry &&
        !_sentryReady) {
      try {
        await Sentry.init((options) {
          options
            ..dsn = config.sentryDsn
            ..environment = config.environment
            ..release = config.release.isEmpty ? null : config.release
            ..sendDefaultPii = false
            ..attachStacktrace = true
            ..tracesSampleRate = 0;
        });
        _sentryReady = true;
        await Sentry.configureScope((scope) async {
          await scope.setUser(SentryUser(id: _installId));
        });
      } catch (error) {
        debugPrint('Sentry telemetry is unavailable: $error');
      }
    }
    _appliedContext.clear();
    await setContext(_context);
  }

  Future<void> _initializeFirebase() async {
    try {
      final options = config.firebaseOptions;
      if (options == null) return;
      final app = Firebase.apps.isEmpty
          ? await Firebase.initializeApp(options: options)
          : Firebase.app();

      if (diagnosticsConsentGranted) {
        final performance = FirebasePerformance.instanceFor(app: app);
        await performance.setPerformanceCollectionEnabled(true);
        _performance = performance;
      }

      if (analyticsConsentGranted) {
        final analytics = FirebaseAnalytics.instanceFor(app: app);
        if (await analytics.isSupported()) {
          await analytics.setConsent(
            analyticsStorageConsentGranted: true,
            adStorageConsentGranted: false,
            adPersonalizationSignalsConsentGranted: false,
            adUserDataConsentGranted: false,
          );
          await analytics.setAnalyticsCollectionEnabled(true);
          await analytics.setUserId(id: _installId);
          _analytics = analytics;
        }
      }

      if (diagnosticsConsentGranted &&
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        final crashlytics = FirebaseCrashlytics.instance;
        await crashlytics.setCrashlyticsCollectionEnabled(true);
        await crashlytics.setUserIdentifier(_installId ?? '');
        _crashlytics = crashlytics;
      }
      _firebaseReady = true;
    } catch (error) {
      debugPrint('Firebase telemetry is unavailable: $error');
    }
  }

  Future<void> _disableAnalytics() async {
    final analytics = _analytics;
    if (analytics != null) {
      await _ignoreFailure(
        analytics.setConsent(
          analyticsStorageConsentGranted: false,
          adStorageConsentGranted: false,
          adPersonalizationSignalsConsentGranted: false,
          adUserDataConsentGranted: false,
        ),
      );
      await _ignoreFailure(analytics.setAnalyticsCollectionEnabled(false));
      await _ignoreFailure(analytics.setUserId());
      await _ignoreFailure(analytics.resetAnalyticsData());
    }
    _analytics = null;
    _appliedContext.clear();
  }

  Future<void> _disableDiagnostics() async {
    await _ignoreFailure(
      _performance?.setPerformanceCollectionEnabled(false),
    );
    _performance = null;
    final crashlytics = _crashlytics;
    if (crashlytics != null) {
      await _ignoreFailure(
        crashlytics.setCrashlyticsCollectionEnabled(false),
      );
      await _ignoreFailure(crashlytics.setUserIdentifier(''));
      await _ignoreFailure(crashlytics.deleteUnsentReports());
    }
    _crashlytics = null;
    if (_sentryReady) await Sentry.close();
    _sentryReady = false;
    _appliedContext.clear();
    _firebaseReady = _analytics != null;
  }

  void _installGlobalErrorHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;
    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (previousFlutterHandler != null) {
        previousFlutterHandler(details);
      } else {
        FlutterError.presentError(details);
      }
      unawaited(recordError(
        details.exception,
        details.stack ?? StackTrace.current,
        fatal: true,
        mechanism: 'flutter_framework',
        context: {
          if (details.library != null) 'library': details.library,
        },
      ));
    };

    final dispatcher = PlatformDispatcher.instance;
    final previousPlatformHandler = dispatcher.onError;
    dispatcher.onError = (error, stack) {
      unawaited(recordError(
        error,
        stack,
        fatal: true,
        mechanism: 'platform_dispatcher',
      ));
      return previousPlatformHandler?.call(error, stack) ?? true;
    };
  }

  static Map<String, Object> sanitizeParameters(
    Map<String, Object?> parameters,
  ) {
    final safe = <String, Object>{};
    for (final entry in parameters.entries) {
      final key = _sanitizeKey(entry.key);
      if (key == null ||
          !_allowedParameterKeys.contains(key) ||
          _isSensitiveKey(key)) {
        continue;
      }
      final value = entry.value;
      if (value is String) {
        if (!_isAsciiCategory(value)) continue;
        safe[key] = _truncate(value, 100);
      } else if (value is bool) {
        safe[key] = value ? 1 : 0;
      } else if (value is num) {
        safe[key] = value;
      }
    }
    return safe;
  }

  static String normalizeRoute(String route) {
    final withoutQuery = route.split('?').first.split('#').first;
    var normalized = withoutQuery.isEmpty ? '/' : withoutQuery;
    normalized = normalized.replaceAll(RegExp(r'/\d+(?=/|$)'), '/:id');
    normalized = normalized.replaceAllMapped(
      RegExp(r'/(verify-email|reset-password)/[^/]+'),
      (match) => '/${match.group(1)}/:token',
    );
    normalized = normalized.replaceAllMapped(
      RegExp(r'/(word|kanji|kana)/[^/]+'),
      (match) => '/${match.group(1)}/:id',
    );
    return _truncate(normalized, 100);
  }

  static String normalizeHttpPath(String path) {
    final uri = Uri.tryParse(path);
    final rawPath = uri?.path.isNotEmpty == true ? uri!.path : path;
    var normalized = rawPath.split('?').first;
    normalized = normalized.replaceAll(RegExp(r'/\d+(?=/|$)'), '/:id');
    normalized = normalized.replaceAllMapped(
      RegExp(r'/(kanji|kana)/[^/]+'),
      (match) => '/${match.group(1)}/:character',
    );
    return _truncate(normalized, 100);
  }

  static String? _sanitizeEventName(String name) {
    final value = name.trim().toLowerCase();
    if (!RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(value)) return null;
    if (value.startsWith('firebase_') ||
        value.startsWith('google_') ||
        value.startsWith('ga_')) {
      return null;
    }
    return value;
  }

  static String? _sanitizeKey(String key) {
    final value = key.trim().toLowerCase();
    if (!RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(value)) return null;
    return value;
  }

  static bool _isSensitiveKey(String key) {
    if (key.contains('email') ||
        key.contains('password') ||
        key.contains('token') ||
        key.contains('query') ||
        key.contains('message')) {
      return true;
    }
    if (key == 'text' ||
        key.endsWith('_text') ||
        key == 'url' ||
        key.endsWith('_url') ||
        key == 'headers' ||
        key.endsWith('_headers')) {
      return true;
    }
    return const {
      'feedback',
      'character',
      'account_id',
      'card_id',
      'deck_id',
      'detail',
      'id',
      'install_id',
      'item_id',
      'mnemonic_id',
      'mnemonic_text',
      'mnemonic_story',
      'ref',
      'reason',
      'request_body',
      'response_body',
      'source_sentence',
      'user_id',
      'learning_content',
    }.contains(key);
  }

  static bool _isAsciiCategory(String value) => value.runes.every(
        (rune) => rune >= 0x20 && rune <= 0x7e,
      );

  static String _truncate(String value, int maxLength) =>
      value.length <= maxLength ? value : value.substring(0, maxLength);

  static Future<void> _ignoreFailure(Future<void>? operation) async {
    if (operation == null) return;
    try {
      await operation;
    } catch (_) {
      // Telemetry must never alter product behavior.
    }
  }
}

/// Carries only an exception class to remote providers. The original stack is
/// retained, while messages that could contain learner content stay on-device.
class _PrivacySafeTelemetryException implements Exception {
  const _PrivacySafeTelemetryException(this.originalType);

  final String originalType;

  @override
  String toString() => originalType;
}

class TelemetryRequestTrace {
  TelemetryRequestTrace._(this._trace, this._started)
      : _stopwatch = Stopwatch()..start();

  final Trace _trace;
  final Future<void> _started;
  final Stopwatch _stopwatch;
  bool _stopped = false;

  Future<void> finish({required String outcome, int? statusCode}) async {
    if (_stopped) return;
    _stopped = true;
    _stopwatch.stop();
    try {
      await _started;
      _trace.putAttribute('outcome', outcome);
      if (statusCode != null) {
        _trace.putAttribute('status', statusCode.toString());
      }
      _trace.setMetric('duration_ms', _stopwatch.elapsedMilliseconds);
      await _trace.stop();
    } catch (_) {
      // A performance trace cannot be allowed to fail an API request.
    }
  }
}
