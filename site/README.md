# jibiki marketing site

Static Astro site for `jibiki.app`. It is the indexable, multilingual public
surface. The Flutter Web product remains separate at `my.jibiki.app`.

Requires Node.js 22.12 or newer. The verified local build used Node.js 22.23.1.

## Commands

```bash
npm install
npm run dev
npm run check
npm run build
```

The production output is `site/dist`.

`npm run assets` copies the canonical local fonts from `../app/assets/fonts` and
generates the 1200 x 630 Open Graph PNG from the source SVG. Generated font and
PNG files are ignored because every build recreates them.

## Configuration

Copy `.env.example` to `.env` when local overrides are required. All variables
are public build-time values:

- `PUBLIC_SITE_URL`, default `https://jibiki.app`
- `PUBLIC_APP_URL`, default `https://my.jibiki.app`
- `PUBLIC_API_URL`, default empty
- `PUBLIC_GA_MEASUREMENT_ID`, default empty and therefore analytics is disabled
- `PUBLIC_GOOGLE_SITE_VERIFICATION`, default empty

Analytics is consent-first. When no GA4 measurement ID is supplied, no Google
script is loaded and tracking remains a no-op. The shared consent UI remains
available because it controls both analytics and Flutter diagnostics. Search
text is never sent as an analytics parameter.

Withdrawing analytics consent sends a denied Consent Mode update, removes
first-party `_ga*` cookies for the current host and `.jibiki.app`, then reloads
the page when an analytics session was active. This guarantees that the current
page no longer keeps the previously initialized GA runtime alive.
