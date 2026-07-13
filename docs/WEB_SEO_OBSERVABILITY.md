# Web, SEO and observability

## Production topology

The public surfaces have separate responsibilities:

| Host | Responsibility | Indexing |
| --- | --- | --- |
| `jibiki.app` | Astro marketing site and public SEO pages | index |
| `www.jibiki.app` | permanent redirect to `jibiki.app` | no separate index |
| `my.jibiki.app` | Flutter Web application | `noindex` |
| `api.jibiki.app` | Django API, media, static files and packs | API only |

Do not embed Flutter in an iframe. Public calls to action link directly to
`my.jibiki.app`. Search engines receive real localized HTML from Astro, while
Flutter keeps control of the authenticated and offline application experience.

Public word, kana and kanji pages can be added to the Astro build from the
Django public API. Their primary call to action should open the matching Flutter
route. Search result pages with arbitrary query parameters must remain
`noindex,follow`.

## Analytics and diagnostics

The production stack uses complementary tools instead of forcing every signal
into one product:

| Surface | Product | Signals |
| --- | --- | --- |
| Astro site | GA4 | acquisition, landing funnels and app handoff |
| Flutter Android and iOS | Firebase Analytics, Performance and Crashlytics | product events, traces, fatal and nonfatal errors |
| Flutter Web | Firebase Analytics, Performance and Sentry | product events, traces and browser errors |
| Django | JSON logs and Sentry | request latency, backend errors and traces |
| Caddy | privacy-filtered JSON access logs | traffic and status classes |

Crashlytics is not used as the Web or Django error backend. Firebase Analytics
and Performance support Flutter Web, but Crashlytics targets the native apps.

Use separate Firebase and Sentry projects for development and production. Use
one GA4 property with separate streams for the marketing site, Flutter Web,
Android and iOS. Register `surface` as a custom dimension when cross-surface
reports need it.

### Consent model

Collection starts disabled until the user has made a choice. Persist three
categories:

1. Essential storage, always active.
2. Diagnostics, controlling Crashlytics and Sentry.
3. Analytics, controlling GA4 and Firebase Analytics.

For the European launch, load no GA script before analytics consent. Keep
`ad_storage`, `ad_user_data` and `ad_personalization` denied because jibiki does
not use advertising. The same preference should be readable on `jibiki.app` and
`my.jibiki.app`, with an equivalent control in the Flutter privacy settings.

Never send the following values to analytics or diagnostics:

- email addresses, credentials, auth tokens or WaniKani tokens
- raw dictionary queries or mnemonic text
- feedback bodies or user image URLs
- request bodies, cookies or authorization headers
- dynamic item identifiers in screen names

Use normalized routes such as `/word/:id` and low-cardinality properties such as
locale, item type, study mode, form factor and result count bucket.

## Required external configuration

Copy `.env.example` to `.env` on the deployment host. At minimum, configure:

```dotenv
ROOT_DOMAIN=jibiki.app
APP_DOMAIN=my.jibiki.app
API_DOMAIN=api.jibiki.app
PUBLIC_SITE_URL=https://jibiki.app
PUBLIC_APP_URL=https://my.jibiki.app
PUBLIC_API_URL=https://api.jibiki.app
JIBIKI_API_BASE=https://api.jibiki.app
CORS_ALLOWED_ORIGINS=https://jibiki.app,https://my.jibiki.app
DJANGO_CSRF_TRUSTED_ORIGINS=https://api.jibiki.app,https://my.jibiki.app
HEADLESS_FRONTEND_BASE=https://my.jibiki.app/#
```

Then add the project-specific Firebase, GA4, Search Console and Sentry values
already listed in `.env.example`. Empty analytics identifiers are valid: all
providers stay inert and builds remain testable, but no production event can be
verified until real projects are connected.

Firebase client configuration is public application configuration. Service
account JSON, Sentry upload tokens, signing keys and deploy credentials are
secrets and must exist only in the CI secret store or on the deployment host.

### Reproducible Web release

`.github/workflows/release-web.yml` is the only production Web release path.
It runs manually or for a `v*` tag, behind the GitHub `production` environment:

1. Astro and Flutter Web build from the same full commit SHA.
2. Flutter uses version 3.44.5 and the committed lockfile is enforced.
3. `JIBIKI_RELEASE` is fixed to `jibiki-web@<full commit SHA>`.
4. Sentry injects Debug IDs, uploads the JavaScript and maps, and finalizes that
   exact release before runtime packaging starts.
5. The packaging script verifies the release string and injected Debug IDs,
   removes every `.map`, then writes the Debug ID, runtime hash, release metadata
   and `SHA256SUMS`.
6. The same directory becomes both the downloadable workflow artifact and the
   multi-architecture Caddy image pushed to GHCR.
7. BuildKit publishes an SBOM and provenance, then GitHub records a separate
   build provenance attestation for the published image digest.

The workflow pins its GitHub Actions to full commit SHAs, Node to 22.23.1,
Flutter to 3.44.5, and the Caddy runtime base to an image digest. Dependency
installation uses the committed npm and Dart lockfiles.

The Sentry upload token is used only by the Sentry action. It is never passed to
Flutter, Docker BuildKit, an artifact, or an image layer. Firebase Web options,
the Sentry DSN and analytics measurement IDs are public client configuration
and are compiled into the browser applications by design.

Configure these GitHub `production` environment values before the first run:

- Variables: `MARKETING_GA_MEASUREMENT_ID`, `GOOGLE_SITE_VERIFICATION`,
  `FIREBASE_API_KEY`, `FIREBASE_WEB_APP_ID`,
  `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`,
  `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`,
  `FIREBASE_WEB_MEASUREMENT_ID`, and `FLUTTER_SENTRY_DSN`.
- Secrets: `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, and `SENTRY_PROJECT`.

Use a Sentry organization token with only the CI and release scopes required by
the Sentry project. Do not add a service-account file to this workflow.

Run `flutterfire configure` separately for development and production to create
the native Android and iOS app registrations. Keep generated production config
files out of public support bundles. The Docker Web build receives its public
Firebase options through `--dart-define` values.

## Local verification

Marketing site:

```powershell
cd site
npm ci
npm run dev -- --host 0.0.0.0
```

Production builds:

```powershell
make site-build
make app-web
make caddy-check
docker compose -f compose.yaml --profile web build
```

The multi-stage `caddy/Dockerfile` is for local rehearsal. Production uses the
source-map-aware workflow output. Copy the release and digest from the workflow
summary into `.env`, then use the secret-checking overlay:

```dotenv
WEB_IMAGE=ghcr.io/<owner>/<repository>@sha256:<digest>
```

```powershell
make prod
```

`make prod` builds only Django, pulls the immutable Caddy image, and starts with
`--no-build`. The production overlay refuses missing Django, database, image,
or digest values. `prod-check` also rejects a mutable image tag. The exact
release is baked into the image and is not overridden by Compose. This prevents
a local rebuild or runtime setting from drifting away from the source maps
already stored in Sentry.

If the GHCR package is private, authenticate the deployment host with a
read-only package token before `make prod`. Keep that token in the host secret
store, never in `.env`, Compose, or the Caddy image.

Before release, verify:

- mobile, tablet and desktop layouts
- keyboard navigation and reduced motion
- canonical, `hreflang`, Open Graph and structured data output
- `robots.txt`, sitemap and localized 404 behavior
- no analytics request before consent
- a GA4 DebugView event after consent
- a symbolicated native Crashlytics test in a non-production build
- a symbolicated Flutter Web Sentry test
- a Django test exception carrying the same release and request ID as its log

## DNS and first deployment

The current OVH DNS records for the apex and `www` still point to the OVH
redirect service. Replace them only when the server is ready:

1. Point `jibiki.app`, `my.jibiki.app` and `api.jibiki.app` to the deployment
   server with A and optional AAAA records.
2. Keep the existing OVH NS, MX and SPF records unchanged.
3. Point `www.jibiki.app` to the same server. Caddy performs the canonical 308
   redirect.
4. Set a strong `DJANGO_SECRET_KEY` and `POSTGRES_PASSWORD`, copy `WEB_IMAGE`
   from the release summary, then run `make prod`. Caddy provisions all TLS
   certificates.
5. Verify the three HTTPS hosts before removing any temporary old endpoint.

The `.app` top-level domain is HTTPS-only in modern browsers, so DNS should not
be switched to a host that cannot immediately answer TLS.

## Operational alerts

Initial production thresholds:

- crash-free sessions below 99.5 percent
- fatal error spike compared with the previous 30 minutes
- API 5xx rate above 2 percent for 5 minutes
- API p95 above 1 second for 10 minutes
- sync or pack failure rate above 5 percent
- any public host unavailable for 2 consecutive checks

Tune sampling and thresholds from real traffic. Remote Config may change safe
sampling values, but must never control authorization, entitlements or security
rules.
