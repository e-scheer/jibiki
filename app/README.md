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
