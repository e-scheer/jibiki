import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'app.dart';
import 'core/session_store.dart';
import 'core/telemetry.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    final binding = WidgetsFlutterBinding.ensureInitialized();
    // Hold the static OS launch screen until Flutter paints its matching animated
    // brand screen. JibikiApp removes it after the first Flutter frame.
    FlutterNativeSplash.preserve(widgetsBinding: binding);
    final session = await SessionStore.create();
    // Provider startup never blocks the first Flutter frame. The synchronous
    // part installs error handlers and reads the persisted consent decision.
    unawaited(Telemetry.instance.initialize(session));
    runApp(JibikiApp(session: session));
  }, (error, stackTrace) {
    unawaited(Telemetry.instance.recordError(
      error,
      stackTrace,
      fatal: true,
      mechanism: 'root_zone',
    ));
  });
}
