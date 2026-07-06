# jibiki — Flutter app (MVVM)

The client for the jibiki API. Strict **MVVM**: Views never touch the network;
they observe ViewModels, which call Repositories, which call Services, which call
the one `ApiClient`.

```
lib/
├── core/          ApiClient (dio) · ApiConfig · SessionStore · ApiException
├── models/        DTOs: word · kanji · kana · study · mnemonic · user · enums
├── services/      auth (allauth headless) · dictionary · study · mnemonic
├── repositories/  thin domain layer over services (+ caching for reference data)
├── viewmodels/    ChangeNotifier per screen + global AppState (session/mode)
├── routing/       go_router with an auth/onboarding redirect guard
├── theme/         Material 3 — ink-on-paper, vermilion (朱) accent
└── views/         auth · onboarding · shell · dictionary · kana · study · settings
```

### Layer rules

- **View** — widgets only. Reads a ViewModel via `context.watch`, dispatches
  intents via `context.read`. No repositories/services here.
- **ViewModel** — `extends BaseViewModel` (loading + error + `runGuarded`).
  Holds screen state; depends on repositories, never on Dio.
- **Repository** — the ViewModel-facing domain API; owns caching (e.g. the kana
  chart and per-kanji detail are memoized).
- **Service** — maps one API endpoint group to models.
- **AppState** — the single global ViewModel: who's signed in, their profile/mode,
  and the bootstrap status the router redirects on.

### Auth

`AuthService` posts to allauth headless (`/_allauth/app/v1/auth/{signup,login}`),
gets a `session_token`, and `AuthRepository` persists it via `SessionStore`. The
`ApiClient` interceptor then attaches it as `X-Session-Token` on every request, so
the domain API is authenticated by the same token allauth issued.

> `SessionStore` uses `shared_preferences` for simplicity. For production, swap in
> `flutter_secure_storage` for the token (Keychain/Keystore) — it's a one-file change.

### Run

This repo tracks `lib/`, `pubspec.yaml`, `test/` and `analysis_options.yaml` — the
hand-written app. The **platform scaffolding** (`android/`, `ios/`, `web/`,
`linux/`, …) is generated, so create it once before the first run:

```bash
cd app
flutter create .                 # generates the platform folders around lib/ (keeps lib/ intact)
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=JIBIKI_API_BASE=http://localhost:8000
```

The base URL defaults to `http://10.0.2.2:8000` on the Android emulator and
`http://localhost:8000` elsewhere; override with `--dart-define=JIBIKI_API_BASE=…`.

### ⚠️ Running on a physical Android device — read this

`10.0.2.2` is the **emulator-only** alias for the host. A **physical device cannot
reach it**, so any build without `--dart-define=JIBIKI_API_BASE` will sit on the
splash showing *"Can't reach the server"*. On a real device you MUST point the app
at the dev machine's LAN IP (or tunnel to it):

```bash
# Build / run for the physical device — ALWAYS pass the LAN IP:
flutter run   --dart-define=JIBIKI_API_BASE=http://192.168.1.6:8000
flutter build apk --release --target-platform android-arm64 \
  --dart-define=JIBIKI_API_BASE=http://192.168.1.6:8000
```

Gotcha that already bit us once: a bare `flutter run` (no `--dart-define`) installs
a **debug** build that targets `10.0.2.2` and **silently overwrites** a correctly
built release APK on the device — the app then can't reach the server. If you see
*"Can't reach the server"*, first check the target URL printed under the message,
then reinstall with the define. Confirm which build is actually installed with:

```bash
adb shell pm path app.jibiki.jibiki     # then pull + grep the APK for the baked URL
```

Fallback that works regardless of LAN IP (tunnels device `localhost` → host over USB):

```bash
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=JIBIKI_API_BASE=http://localhost:8000
```

The splash's *"Sign in instead"* button is an escape hatch: even when the server is
unreachable, a user is never trapped — they can always drop the session and reach
the login screen (see `SplashView` / `AppState.logout`).
