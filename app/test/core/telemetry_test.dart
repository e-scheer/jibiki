import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/core/telemetry.dart';
import 'package:jibiki/core/telemetry_config.dart';
import 'package:jibiki/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _emptyConfig = TelemetryConfig(
  environment: 'test',
  release: '',
  firebaseApiKey: '',
  firebaseAppId: '',
  firebaseMessagingSenderId: '',
  firebaseProjectId: '',
  firebaseAuthDomain: '',
  firebaseStorageBucket: '',
  firebaseMeasurementId: '',
  sentryDsn: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts undecided and keeps every provider inactive without config',
      () async {
    final store = await SessionStore.create();
    final telemetry = Telemetry(
      config: _emptyConfig,
      installGlobalHandlers: false,
    );

    await telemetry.initialize(store);

    expect(telemetry.consent, TelemetryConsent.undecided);
    expect(telemetry.isConfigured, isFalse);
    expect(telemetry.isActive, isFalse);
  });

  test('persists consent and removes the pseudonymous id on revoke', () async {
    final store = await SessionStore.create();
    final telemetry = Telemetry(
      config: _emptyConfig,
      installGlobalHandlers: false,
    );
    await telemetry.initialize(store);

    await telemetry.setConsent(analytics: true, diagnostics: true);

    expect(telemetry.consent, TelemetryConsent.granted);
    expect(store.telemetryAnalyticsConsent, isTrue);
    expect(store.telemetryDiagnosticsConsent, isTrue);
    expect(store.telemetryInstallId, isNotEmpty);

    await telemetry.setConsent(analytics: false, diagnostics: false);

    expect(telemetry.consent, TelemetryConsent.denied);
    expect(store.telemetryAnalyticsConsent, isFalse);
    expect(store.telemetryDiagnosticsConsent, isFalse);
    expect(store.telemetryInstallId, isNull);
  });

  test('migrates the former combined consent preference', () async {
    SharedPreferences.setMockInitialValues({'telemetry_consent': true});
    final store = await SessionStore.create();
    final telemetry = Telemetry(
      config: _emptyConfig,
      installGlobalHandlers: false,
    );

    await telemetry.initialize(store);

    expect(telemetry.analyticsConsentGranted, isTrue);
    expect(telemetry.diagnosticsConsentGranted, isTrue);
  });

  test('represents category-specific consent without hiding the active choice',
      () async {
    final store = await SessionStore.create();
    final telemetry = Telemetry(
      config: _emptyConfig,
      installGlobalHandlers: false,
    );
    await telemetry.initialize(store);

    await telemetry.setAnalyticsConsent(true);

    expect(telemetry.consent, TelemetryConsent.partial);
    expect(telemetry.analyticsConsentGranted, isTrue);
    expect(telemetry.diagnosticsConsentGranted, isFalse);
  });

  test('drops sensitive and unsupported event parameters', () {
    final sanitized = Telemetry.sanitizeParameters({
      'result': 'success',
      'count': 2,
      'cached': true,
      'email': 'learner@example.test',
      'token': 'secret',
      'request_body': {'unsafe': true},
      'message': 'private learner message',
      'character': '日本',
      'status': '成功',
      'unreviewed_parameter': 'must not leave the device',
    });

    expect(sanitized, {
      'result': 'success',
      'count': 2,
      'cached': 1,
    });
  });

  test('normalizes routes and strips query strings', () {
    expect(Telemetry.normalizeRoute('/word/128?source=search'), '/word/:id');
    expect(Telemetry.normalizeRoute('/kana/%E3%81%82'), '/kana/:id');
    expect(
      Telemetry.normalizeRoute('/verify-email/private-key?next=/profile'),
      '/verify-email/:token',
    );
    expect(
      Telemetry.normalizeRoute('/reset-password/private-key#ignored'),
      '/reset-password/:token',
    );
    expect(
      Telemetry.normalizeHttpPath('/api/v1/dict/kanji/%E6%97%A5?lang=fr'),
      '/api/v1/dict/kanji/:character',
    );
    expect(
      Telemetry.normalizeHttpPath('/api/v1/study/cards/42/review'),
      '/api/v1/study/cards/:id/review',
    );
  });

  test('creates opaque request correlation ids', () {
    final telemetry = Telemetry(
      config: _emptyConfig,
      installGlobalHandlers: false,
    );

    final first = telemetry.createRequestId();
    final second = telemetry.createRequestId();

    expect(first, isNot(second));
    expect(first, hasLength(36));
  });

  test('conversion events are centrally allowlisted', () {
    expect(
      TelemetryEvent.allowedNames,
      containsAll(const {
        TelemetryEvent.studyCardAdded,
        TelemetryEvent.studyCardRemoved,
        TelemetryEvent.deckEnrolled,
        TelemetryEvent.deckPublished,
        TelemetryEvent.mnemonicViewed,
        TelemetryEvent.mnemonicVoted,
        TelemetryEvent.mnemonicSaved,
        TelemetryEvent.mnemonicCreated,
        TelemetryEvent.mnemonicReported,
        TelemetryEvent.packDownloadCompleted,
        TelemetryEvent.packInstallCompleted,
        TelemetryEvent.syncCompleted,
        TelemetryEvent.writingPracticeStarted,
        TelemetryEvent.writingPracticeCompleted,
        TelemetryEvent.feedbackSent,
        TelemetryEvent.interfaceLanguageChanged,
        TelemetryEvent.mnemonicLanguageChanged,
        TelemetryEvent.themeChanged,
      }),
    );
  });

  test('theme conversions contain only reviewed low-cardinality fields',
      () async {
    final store = await SessionStore.create();
    final recorder = _RecordingTelemetry();
    final controller = ThemeController(store, telemetry: recorder);

    await controller.setPalette(ThemePalette.harmonie);
    await controller.setMode(ThemeModeSetting.dark);

    expect(recorder.events.map((event) => event.name), [
      TelemetryEvent.themeChanged,
      TelemetryEvent.themeChanged,
    ]);
    expect(recorder.events[0].parameters, {
      'palette': 'harmonie',
      'source': 'palette',
    });
    expect(recorder.events[1].parameters, {
      'theme_mode': 'dark',
      'source': 'mode',
    });
  });
}

class _RecordingTelemetry implements TelemetrySink {
  final events = <({String name, Map<String, Object?> parameters})>[];

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async {
    events.add((name: name, parameters: Map.of(parameters)));
  }
}
