import 'package:flutter/material.dart';

import 'app.dart';
import 'core/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await SessionStore.create();
  runApp(JibikiApp(session: session));
}
