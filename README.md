# jibiki 字引き

A **dictionary-first Japanese memorization tool**. Search any word, break it into
its kanji and components, and turn any entry into a spaced-repetition card
scheduled by **FSRS-6** - with **community, per-language visual mnemonics** as the
differentiating feature (the market gap identified in [`DEEP_SEARCH.md`](DEEP_SEARCH.md)).

This monorepo holds a **Flutter MVVM app** (`app/`) and a **Django + DRF API**
(`server/`). The backend reuses the deployment/config stack of the sibling
`tusorsou` project: `uv`, Postgres, Docker Compose, Caddy, ruff, gunicorn,
12-factor env config, and swappable S3 media (here → Cloudflare R2).

```
jibiki/
├── app/           Flutter app (MVVM plus native offline infrastructure)
├── server/        Django API (dictionary · mnemonics · contentpacks · srs)
├── docs/          Product, data architecture and research notes
├── var/           Generated packs and local media (ignored)
├── compose.yaml   Postgres + api [+ caddy]           (prod topology)
├── compose.production.yaml   prod-only secret validation
├── compose.override.yaml   dev-only (exposes the DB port)
├── caddy/Caddyfile
├── Makefile       one-liners for every workflow
└── DEEP_SEARCH.md the product research this is built from
```

---

## Architecture

```
Flutter app (MVVM)                         Django API (DRF)
┌────────────────────────────┐            ┌──────────────────────────────┐
│ View → ViewModel            │            │ accounts   email user+profile │
│   → Repository → Service    │  HTTPS/JSON│ dictionary JMdict/KANJIDIC/kana│
│   → ApiClient (dio)         │───────────▶│ srs        FSRS-6 scheduler    │
│                             │            │ mnemonics  community + votes   │
│ auth: allauth headless      │            │ auth: allauth headless         │
│ X-Session-Token on every    │            │ + XSessionTokenAuthentication  │
│ authenticated request       │            │ (one token, one auth system)   │
└────────────────────────────┘            └──────────────────────────────┘
                                                     │
                                              Postgres · R2 (media)
```

**Auth is unified through allauth.** The app signs up / logs in against allauth
**headless** (`/_allauth/app/v1/…`), receives a `session_token`, and sends it back
as `X-Session-Token` on every call. DRF authenticates the domain API with allauth's
own `XSessionTokenAuthentication` - so the *same* token allauth issued authorizes
`/api/v1/*`. Email verification, password reset, social login (Google/Apple) and
MFA come from allauth for free.

---

## Run it

### Backend

Requirements: [uv](https://docs.astral.sh/uv/), Docker (for Postgres).

```bash
docker compose up -d db          # Postgres on localhost:5432 (the one and only DB)
make sync                        # uv sync (installs deps)
make migrate                     # apply migrations
make seed                        # load the curated demo dictionary + kana mnemonics
make run                         # dev server on http://localhost:8000
make test                        # backend test suite (against Postgres - needs `make db`)
make lint                        # ruff check + format check
```

**Postgres everywhere.** Dev, tests and prod all run on Postgres - there is no
SQLite fallback. Tests create a throwaway `test_jibiki` on the same server, so
migrations, trigram search indexes and SQL behaviour are exercised exactly as in
production. Start the DB (`make db`) before `make run` / `make test`.

#### Windows setup

`make` is not present on Windows by default, and Docker Desktop needs the WSL2
platform. One-time setup:

1. **Enable the WSL2 Windows components** (Docker Desktop's backend). In an
   **administrator** PowerShell:
   ```powershell
   wsl --install --no-distribution
   ```
   then **reboot**. Virtualization must be enabled in the BIOS (VT-x / AMD-V).
   Note the WSL app can already be installed while the optional OS component is
   still off, which surfaces as Docker's misleading "Virtualization support not
   detected".
2. Launch **Docker Desktop** and wait for the engine to report running (from a
   terminal you can start it with `Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"`).

Then run the same workflow without `make` (PowerShell, from the repo root):

```powershell
docker compose up -d db                              # Postgres on localhost:5432
cd server
uv run --project . python manage.py migrate          # apply migrations
uv run --project . python manage.py seed_demo         # demo dictionary + kana mnemonics
uv run --project . python manage.py runserver 8000    # dev server on http://localhost:8000
```

`uv run` auto-installs dependencies, so a separate sync step is not needed. Any
other `make <target>` maps the same way: take the recipe body from the `Makefile`
and run its `uv run --project . python manage.py ...` command from inside `server\`.

Or the whole stack in containers (what runs on the server):

```bash
docker compose --profile web up --build
```

The demo seed makes the API immediately useful offline: the full hiragana +
katakana tables, ~40 JLPT-N5 kanji, ~30 common words (EN + FR glosses), radicals,
and ~20 seeded kana mnemonics in English **and** French.

**Loading the real EDRDG data** (one-shot batch, over the seed):

```bash
make import-jmdict   FILE=JMdict_e.xml     LANGS=en,fr
make import-kanjidic FILE=kanjidic2.xml    LANGS=en,fr
# components/decomposition:
uv run --project server python server/manage.py import_kradfile kradfile
```

### App

Requirements: Flutter SDK (3.6+). The repo pins Flutter 3.44.5 via fvm
(`.fvmrc`); a stock Flutter on PATH also works. On Windows without fvm, call
`flutter` directly (drop the `fvm` prefix).

```bash
cd app
flutter pub get
flutter analyze
flutter test
# point the app at your API (Android emulator uses 10.0.2.2 automatically):
flutter run --dart-define=JIBIKI_API_BASE=http://localhost:8000
```

Run it as a **web app** (handy on Windows, no emulator needed):

```powershell
cd app
flutter pub get
flutter run -d web-server --web-port 3000 --dart-define=JIBIKI_API_BASE=http://localhost:8000
# then open http://localhost:3000
```

---

## API contract (v1)

| Area | Endpoint |
|---|---|
| **Auth** (allauth headless) | `POST /_allauth/app/v1/auth/signup` · `.../login` · `DELETE .../session` |
| Profile | `GET`/`PATCH /api/v1/auth/me` |
| Dictionary (public) | `GET /api/v1/dict/search?q=&lang=` · `/dict/words/{id}` · `/dict/kanji/{literal}` · `/dict/kanji?jlpt=` · `/dict/kana?script=` |
| Study (auth) | `GET /api/v1/study/queue` · `/study/stats` · `POST /study/add` · `POST /study/cards/{id}/review` · `GET/DELETE /study/cards[/{id}]` · `GET/POST /study/optimize` · `GET /study/export` (Anki TSV) |
| Mnemonics | `GET /api/v1/mnemonics/?character=&language=&kind=` · `POST /mnemonics/create` · `POST /mnemonics/{id}/vote` · `POST /mnemonics/{id}/report` |

The dictionary is **public** (usable with no account, the DEEP_SEARCH stage-1
principle). Study and mnemonic writes require the session token.

---

## How the DEEP_SEARCH blueprint maps to code

| Feature | Where |
|---|---|
| **SRS = FSRS-6** (not SM-2) | `server/srs/fsrs.py` - self-contained 21-param FSRS-6; full `ReviewLog` from day one for later per-user training |
| **Excellent dictionary** (JMdict/KANJIDIC/kana) | `server/dictionary/` - normalized Word→Form/Sense→Gloss + real EDRDG importers + curated seed |
| **Localized content model** | neutral entities plus language-tagged child rows; mnemonics remain independent language-native content. See `docs/CONTENT_PACK.md` |
| **Offline content packs** | `server/contentpacks/` owns schema v2, manifest v3, build and serving; `app/lib/infrastructure/` owns install, registry and local reads |
| **Configurable modes** (Dictionary ↔ Learning) | one `AppMode` flag on the profile drives home layout, the due badge and notification defaults - not three code paths |
| **Kanji decomposition + stroke order** | `KRADFILE` components + `component_details` (tappable, jpdb-style) + **KanjiVG stroke-order animation** (`server/dictionary/management/commands/import_kanjivg.py`, `app/.../stroke_order_view.dart`) |
| **Community, language-dependent mnemonics** (the moat) | `server/mnemonics/` - `(character, language, kind)` first-class entity, votes, trust tiers, auto-hide moderation, never hard-deleted; app: `MnemonicPanel` |
| **Free image hosting** | `django-storages` → **Cloudflare R2** (zero egress), EXIF/GPS stripped + WebP re-encode on ingest (`mnemonics/imaging.py`) |

**Implemented now:** the full core loop - auth, dictionary search + detail, kanji
breakdown, kana chart, FSRS review, community mnemonics with voting + moderation
+ **image upload** (WebP re-encode, EXIF-stripped), the mode spectrum, settings -
plus **per-user FSRS weight training** (`/study/optimize`, guarded to only adopt a
fit that beats the defaults on your own data), **Anki-compatible export**
(`/study/export`, TSV), and **KanjiVG stroke-order animation** on the kanji detail
(strokes trace in order; tap to replay). **Deliberately deferred** (DEEP_SEARCH
stage 3): push notifications (needs FCM/native config) and handwriting search
(needs a recognizer model).

---

## License & attribution (mandatory)

jibiki bundles/ingests free data whose licenses require acknowledgement - see
[`NOTICE.md`](NOTICE.md): **JMdict / KANJIDIC2 / KRADFILE © EDRDG** (used under the
EDRDG licence), **KanjiVG** (CC BY-SA 3.0) and **Tatoeba** (CC-BY) when their
importers are used. The app surfaces the EDRDG credit in Settings.
