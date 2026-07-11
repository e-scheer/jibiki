import 'dart:async' show StreamSubscription, unawaited;
import 'dart:io' show Directory;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'core/api_client.dart';
import 'core/api_config.dart';
import 'core/db/user_db.dart';
import 'core/session_store.dart';
import 'core/speech.dart';
import 'infrastructure/local/local_dictionary_data_source.dart';
import 'infrastructure/local/local_study_store.dart';
import 'infrastructure/packs/pack_manager.dart';
import 'infrastructure/user_db_handle.dart';
import 'repositories/auth_repository.dart';
import 'repositories/dictionary_repository.dart';
import 'repositories/mnemonic_deck_repository.dart';
import 'repositories/mnemonic_repository.dart';
import 'repositories/study_repository.dart';
import 'routing/app_router.dart';
import 'services/auth_service.dart';
import 'services/dictionary_service.dart';
import 'services/feedback_service.dart';
import 'services/mnemonic_deck_service.dart';
import 'services/mnemonic_service.dart';
import 'services/study_service.dart';
import 'services/sync_service.dart';
import 'sync/sync_engine.dart';
import 'theme/app_theme.dart';
import 'viewmodels/app_state.dart';
import 'views/widgets/sync_conflict_gate.dart';

/// Composition root: wires SessionStore → ApiClient → services → repositories →
/// AppState once, exposes the repositories + AppState via Provider, and hands the
/// router (which redirects on AppState) to MaterialApp.
class JibikiApp extends StatefulWidget {
  const JibikiApp({super.key, required this.session});
  final SessionStore session;

  @override
  State<JibikiApp> createState() => _JibikiAppState();
}

class _JibikiAppState extends State<JibikiApp> with WidgetsBindingObserver {
  late final ApiClient _api = ApiClient(widget.session);

  // Offline content packs (native only - web keeps the HTTP dictionary).
  // Constructed synchronously; the async bootstrap runs in ensureReady().
  late final PackManager? _packs = kIsWeb
      ? null
      : PackManager(
          root: () async => Directory(
              '${(await getApplicationSupportDirectory()).path}/packs'),
          dio: Dio(BaseOptions(baseUrl: ApiConfig.baseUrl)),
          loadAsset: rootBundle.load,
        );

  // Dictionary reads come from the local packs on mobile (HTTP as a safety
  // net during the offline-first transition), from the API on web.
  late final LocalDictionaryDataSource? _localDict =
      _packs == null ? null : LocalDictionaryDataSource(_packs);
  late final DictionaryRepository _dictRepo = _localDict == null
      ? DictionaryRepository(DictionaryService(_api))
      : DictionaryRepository(_localDict, fallback: DictionaryService(_api));

  // Study is local-first on mobile: ratings are scheduled on-device (Dart
  // FSRS) and replayed to the server by the sync engine. Web stays HTTP.
  late final StudyService _studyService = StudyService(_api);
  late final UserDbHandle? _userDb = kIsWeb
      ? null
      : UserDbHandle(() async => UserDb.open(
          '${(await getApplicationSupportDirectory()).path}/user.db'));
  late final SyncEngine? _sync = _userDb == null
      ? null
      : SyncEngine(_userDb, SyncService(_api),
          canSync: () => _app.isAuthenticated);
  late final StudyRepository _studyRepo = _userDb == null
      ? StudyRepository(_studyService, _studyService)
      : StudyRepository(
          LocalStudyStore(
            _userDb,
            _packs!,
            _localDict!,
            onLocalMutation: () => _sync!.requestSync(),
          ),
          _studyService,
        );
  late final MnemonicRepository _mnemonicRepo =
      MnemonicRepository(MnemonicService(_api), packs: _packs);
  late final MnemonicDeckRepository _mnemonicDeckRepo =
      MnemonicDeckRepository(MnemonicDeckService(_api));
  late final AuthRepository _authRepo =
      AuthRepository(AuthService(_api), widget.session);

  late final AppState _app = AppState(_authRepo);
  late final GoRouter _router = buildRouter(_app);

  // Built once, ColorScheme.fromSeed does real colour science; recomputing it on
  // every rebuild is pure waste.
  final ThemeData _light = AppTheme.light();
  final ThemeData _dark = AppTheme.dark();

  StreamSubscription<List<ConnectivityResult>>? _connectivity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Resolve the session behind the held native splash, then reveal the app
    // straight onto its real first screen (no second splash, no flash). Runs
    // regardless of outcome - success, login, or the offline retry state.
    final bootstrap = _app.bootstrap().whenComplete(FlutterNativeSplash.remove);
    // Install/refresh the bundled dictionary pack in the background; local
    // reads wait on readiness, and the HTTP fallback covers any failure.
    _packs?.ensureReady();
    // Sync triggers: app start (post-bootstrap), sign-in, connectivity
    // regained, resume - plus the debounced poke after every local mutation.
    final sync = _sync;
    if (sync != null) {
      _app.addListener(_onAuthChanged);
      sync.init().then((_) async {
        final results = await Connectivity().checkConnectivity();
        sync.setOnline(
            results.any((result) => result != ConnectivityResult.none));
        await bootstrap;
        await sync.accountChanged(_app.user?.id);
      });
      _connectivity = Connectivity().onConnectivityChanged.listen((results) {
        sync.setOnline(
            results.any((result) => result != ConnectivityResult.none));
      });
    }
    // Warm the TTS engine after the first frame so the first "play audio" tap
    // fires instantly instead of cold-starting the platform voice.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => Speech.instance.warmUp());
  }

  void _onAuthChanged() {
    final sync = _sync;
    if (sync != null) unawaited(sync.accountChanged(_app.user?.id));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync?.requestSync(debounce: const Duration(seconds: 5));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivity?.cancel();
    _app.removeListener(_onAuthChanged);
    final packs = _packs;
    if (packs != null) unawaited(packs.close());
    final userDb = _userDb;
    if (userDb != null) unawaited(userDb.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // PackManager and SyncEngine are ChangeNotifiers, so plain Provider trips
        // Provider's Listenable check at launch. They are read-only handles here
        // (nothing watches them), so .value keeps identical behavior without the
        // false-positive assertion, and never disposes what _JibikiAppState owns.
        ChangeNotifierProvider<PackManager?>.value(value: _packs),
        ChangeNotifierProvider<SyncEngine?>.value(value: _sync),
        Provider.value(value: _dictRepo),
        Provider.value(value: _studyRepo),
        Provider.value(value: _mnemonicRepo),
        Provider.value(value: _mnemonicDeckRepo),
        Provider.value(value: _authRepo),
        Provider(create: (_) => FeedbackService(_api)),
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
        builder: (context, child) => SyncConflictGate(
          sync: _sync,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child!,
          ),
        ),
      ),
    );
  }
}
