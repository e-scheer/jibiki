import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/session_store.dart';
import 'core/speech.dart';
import 'repositories/auth_repository.dart';
import 'repositories/dictionary_repository.dart';
import 'repositories/mnemonic_deck_repository.dart';
import 'repositories/mnemonic_repository.dart';
import 'repositories/study_repository.dart';
import 'routing/app_router.dart';
import 'services/auth_service.dart';
import 'services/dictionary_service.dart';
import 'services/mnemonic_deck_service.dart';
import 'services/mnemonic_service.dart';
import 'services/study_service.dart';
import 'theme/app_theme.dart';
import 'viewmodels/app_state.dart';

/// Composition root: wires SessionStore → ApiClient → services → repositories →
/// AppState once, exposes the repositories + AppState via Provider, and hands the
/// router (which redirects on AppState) to MaterialApp.
class JibikiApp extends StatefulWidget {
  const JibikiApp({super.key, required this.session});
  final SessionStore session;

  @override
  State<JibikiApp> createState() => _JibikiAppState();
}

class _JibikiAppState extends State<JibikiApp> {
  late final ApiClient _api = ApiClient(widget.session);

  late final DictionaryRepository _dictRepo = DictionaryRepository(DictionaryService(_api));
  late final StudyRepository _studyRepo = StudyRepository(StudyService(_api));
  late final MnemonicRepository _mnemonicRepo = MnemonicRepository(MnemonicService(_api));
  late final MnemonicDeckRepository _mnemonicDeckRepo =
      MnemonicDeckRepository(MnemonicDeckService(_api));
  late final AuthRepository _authRepo = AuthRepository(AuthService(_api), widget.session);

  late final AppState _app = AppState(_authRepo);
  late final GoRouter _router = buildRouter(_app);

  // Built once, ColorScheme.fromSeed does real colour science; recomputing it on
  // every rebuild is pure waste.
  final ThemeData _light = AppTheme.light();
  final ThemeData _dark = AppTheme.dark();

  @override
  void initState() {
    super.initState();
    // Resolve the session behind the held native splash, then reveal the app
    // straight onto its real first screen (no second splash, no flash). Runs
    // regardless of outcome — success, login, or the offline retry state.
    _app.bootstrap().whenComplete(FlutterNativeSplash.remove);
    // Warm the TTS engine after the first frame so the first "play audio" tap
    // fires instantly instead of cold-starting the platform voice.
    WidgetsBinding.instance.addPostFrameCallback((_) => Speech.instance.warmUp());
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: _dictRepo),
        Provider.value(value: _studyRepo),
        Provider.value(value: _mnemonicRepo),
        Provider.value(value: _mnemonicDeckRepo),
        Provider.value(value: _authRepo),
        ChangeNotifierProvider.value(value: _app),
      ],
      child: MaterialApp.router(
        title: 'jibiki',
        debugShowCheckedModeBanner: false,
        theme: _light,
        darkTheme: _dark,
        routerConfig: _router,
        // Premium touch: tapping anywhere outside a field dismisses the keyboard.
        // Translucent so empty space is captured while buttons/fields still win
        // their own taps.
        builder: (context, child) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        ),
      ),
    );
  }
}
