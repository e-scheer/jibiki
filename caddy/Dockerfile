# syntax=docker/dockerfile:1.7

# Local and CI rehearsal image. Production is assembled only after the Sentry
# upload by .github/workflows/release-web.yml using Dockerfile.runtime.

FROM node:22.23.1-alpine AS site_build

WORKDIR /build/site
COPY site/package.json site/package-lock.json ./
RUN npm ci
COPY site/ ./
COPY app/assets/fonts/SpaceGrotesk-Medium.ttf \
     app/assets/fonts/SpaceGrotesk-SemiBold.ttf \
     app/assets/fonts/SpaceGrotesk-Bold.ttf \
     app/assets/fonts/ZenKakuGothicNew-Bold.ttf \
     app/assets/fonts/ZenKakuGothicNew-Black.ttf \
     /build/app/assets/fonts/

ARG PUBLIC_SITE_URL=https://jibiki.app
ARG PUBLIC_APP_URL=https://my.jibiki.app
ARG PUBLIC_API_URL=https://api.jibiki.app
ARG PUBLIC_GA_MEASUREMENT_ID
ARG PUBLIC_GOOGLE_SITE_VERIFICATION
ENV PUBLIC_SITE_URL=${PUBLIC_SITE_URL} \
    PUBLIC_APP_URL=${PUBLIC_APP_URL} \
    PUBLIC_API_URL=${PUBLIC_API_URL} \
    PUBLIC_GA_MEASUREMENT_ID=${PUBLIC_GA_MEASUREMENT_ID} \
    PUBLIC_GOOGLE_SITE_VERIFICATION=${PUBLIC_GOOGLE_SITE_VERIFICATION}
RUN npm run build

FROM debian:bookworm-slim AS app_build

ARG FLUTTER_VERSION=3.44.5
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${PATH}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
    && git clone --depth 1 --branch ${FLUTTER_VERSION} \
        https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && git config --global --add safe.directory ${FLUTTER_HOME} \
    && flutter config --enable-web \
    && flutter precache --web \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build/app
COPY app/pubspec.yaml app/pubspec.lock ./
RUN flutter pub get --enforce-lockfile
COPY app/ ./

ARG JIBIKI_API_BASE=https://api.jibiki.app
ARG JIBIKI_ENVIRONMENT=production
ARG JIBIKI_RELEASE=local
ARG FIREBASE_API_KEY
ARG FIREBASE_APP_ID
ARG FIREBASE_MESSAGING_SENDER_ID
ARG FIREBASE_PROJECT_ID
ARG FIREBASE_AUTH_DOMAIN
ARG FIREBASE_STORAGE_BUCKET
ARG FIREBASE_MEASUREMENT_ID
ARG SENTRY_DSN

RUN flutter build web --release --source-maps \
    --dart-define=JIBIKI_API_BASE=${JIBIKI_API_BASE} \
    --dart-define=JIBIKI_ENVIRONMENT=${JIBIKI_ENVIRONMENT} \
    --dart-define=JIBIKI_RELEASE=${JIBIKI_RELEASE} \
    --dart-define=FIREBASE_API_KEY=${FIREBASE_API_KEY} \
    --dart-define=FIREBASE_APP_ID=${FIREBASE_APP_ID} \
    --dart-define=FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID} \
    --dart-define=FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID} \
    --dart-define=FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN} \
    --dart-define=FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET} \
    --dart-define=FIREBASE_MEASUREMENT_ID=${FIREBASE_MEASUREMENT_ID} \
    --dart-define=SENTRY_DSN=${SENTRY_DSN} \
    && find build/web -type f -name '*.map' -delete

FROM caddy:2.10.2-alpine@sha256:4c6e91c6ed0e2fa03efd5b44747b625fec79bc9cd06ac5235a779726618e530d

ARG JIBIKI_RELEASE=local
ENV JIBIKI_RELEASE=${JIBIKI_RELEASE}

COPY caddy/Caddyfile /etc/caddy/Caddyfile
COPY --from=site_build /build/site/dist /srv/site
COPY --from=app_build /build/app/build/web /srv/app
