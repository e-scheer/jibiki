import 'package:firebase_core/firebase_core.dart';

/// Public, build-time telemetry identifiers.
///
/// None of these values is a secret. Provider credentials that can mutate a
/// project, such as a Sentry auth token, must stay in CI and never reach Dart.
class TelemetryConfig {
  const TelemetryConfig({
    required this.environment,
    required this.release,
    required this.firebaseApiKey,
    required this.firebaseAppId,
    required this.firebaseMessagingSenderId,
    required this.firebaseProjectId,
    required this.firebaseAuthDomain,
    required this.firebaseStorageBucket,
    required this.firebaseMeasurementId,
    required this.sentryDsn,
  });

  const TelemetryConfig.fromEnvironment()
      : environment = const String.fromEnvironment(
          'JIBIKI_ENVIRONMENT',
          defaultValue: 'development',
        ),
        release = const String.fromEnvironment('JIBIKI_RELEASE'),
        firebaseApiKey = const String.fromEnvironment('FIREBASE_API_KEY'),
        firebaseAppId = const String.fromEnvironment('FIREBASE_APP_ID'),
        firebaseMessagingSenderId =
            const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
        firebaseProjectId = const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        firebaseAuthDomain =
            const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
        firebaseStorageBucket =
            const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
        firebaseMeasurementId =
            const String.fromEnvironment('FIREBASE_MEASUREMENT_ID'),
        sentryDsn = const String.fromEnvironment('SENTRY_DSN');

  final String environment;
  final String release;
  final String firebaseApiKey;
  final String firebaseAppId;
  final String firebaseMessagingSenderId;
  final String firebaseProjectId;
  final String firebaseAuthDomain;
  final String firebaseStorageBucket;
  final String firebaseMeasurementId;
  final String sentryDsn;

  bool get hasFirebase =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;

  bool get hasSentry => sentryDsn.isNotEmpty;

  FirebaseOptions? get firebaseOptions => hasFirebase
      ? FirebaseOptions(
          apiKey: firebaseApiKey,
          appId: firebaseAppId,
          messagingSenderId: firebaseMessagingSenderId,
          projectId: firebaseProjectId,
          authDomain: firebaseAuthDomain.isEmpty ? null : firebaseAuthDomain,
          storageBucket:
              firebaseStorageBucket.isEmpty ? null : firebaseStorageBucket,
          measurementId:
              firebaseMeasurementId.isEmpty ? null : firebaseMeasurementId,
        )
      : null;
}
