import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'app.dart';
import 'core/session_store.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Hold the static OS launch screen until Flutter paints its matching animated
  // brand screen. JibikiApp removes it after the first Flutter frame.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  final session = await SessionStore.create();
  runApp(JibikiApp(session: session));
}
