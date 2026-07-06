import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'app.dart';
import 'core/session_store.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Hold the OS launch screen until bootstrap resolves, so there's no flash to a
  // second (Flutter) splash — the app is removed straight onto the real screen.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  final session = await SessionStore.create();
  runApp(JibikiApp(session: session));
}
