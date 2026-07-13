.PHONY: sync db migrate makemigrations seed run test lint check shell \
        up down prod prod-check prod-down logs superuser import-jmdict import-kanjidic app-get app-run \
        app-web site-get site-run site-build caddy-check sync-vectors

UV := uv run --project server
SERVER := cd server &&
PORT ?= 8000

# ── Local dev (native Python + DB in a container) ────────────────────────────

sync:            ## install/refresh backend dependencies (uv)
	uv sync --project server

db:              ## start Postgres only (dev, port 5432 exposed)
	docker compose up -d db

makemigrations:  ## generate Django migrations
	$(SERVER) $(UV) python manage.py makemigrations

migrate:         ## apply Django migrations
	$(SERVER) $(UV) python manage.py migrate

seed:            ## load the curated demo dictionary + kana mnemonics
	$(SERVER) $(UV) python manage.py seed_demo

run:             ## Django dev server on :$(PORT)
	$(SERVER) $(UV) python manage.py runserver $(PORT)

superuser:       ## create an admin user (email-only)
	$(SERVER) $(UV) python manage.py createsuperuser

test:            ## backend tests (Postgres - run `make db` first)
	$(SERVER) $(UV) pytest -q

lint:            ## ruff check + format check
	$(UV) ruff check server
	$(UV) ruff format --check server

check:           ## Django system checks
	$(SERVER) $(UV) python manage.py check

shell:
	$(SERVER) $(UV) python manage.py shell

sync-vectors:    ## regenerate the FSRS parity vectors (server fsrs.py <-> app fsrs.dart)
	python3 scripts/gen_fsrs_vectors.py

build-base-pack: ## rebuild the bundled offline dictionary asset from the local DB
	$(SERVER) $(UV) python manage.py build_packs --base --out ../app/assets/packs

build-packs:     ## build downloadable runtime artifacts into var/packs
	$(SERVER) $(UV) python manage.py build_packs --out ../var/packs

# ── Loading the full EDRDG data (one-shot batch, over the seed) ───────────────

import-jmdict:   ## make import-jmdict FILE=JMdict_e.xml LANGS=en,fr
	$(SERVER) $(UV) python manage.py import_jmdict $(FILE) --langs $(or $(LANGS),en)

import-kanjidic: ## make import-kanjidic FILE=kanjidic2.xml LANGS=en,fr
	$(SERVER) $(UV) python manage.py import_kanjidic $(FILE) --langs $(or $(LANGS),en)

# ── Full stack in containers ─────────────────────────────────────────────────

up:              ## api + caddy + db in containers (prod rehearsal)
	docker compose --profile web up --build

down:
	docker compose down

# ── Server-side (run ON the VPS) ─────────────────────────────────────────────

prod-check:      ## reject mutable or mismatched production Web artifacts
	@docker compose -f compose.yaml -f compose.production.yaml --profile web config --quiet
	@docker compose -f compose.yaml -f compose.production.yaml --profile web config --images | grep -Eq '^ghcr\.io/[^/]+/[^/]+@sha256:[0-9a-f]{64}$$' || (echo 'WEB_IMAGE must be a GHCR image pinned by sha256 digest' && exit 1)

prod: prod-check  ## build the API, pull the immutable Web image, then start
	docker compose -f compose.yaml -f compose.production.yaml --profile web build api
	docker compose -f compose.yaml -f compose.production.yaml --profile web pull caddy
	docker compose -f compose.yaml -f compose.production.yaml --profile web up -d --no-build

prod-down:
	docker compose -f compose.yaml -f compose.production.yaml --profile web down

logs:
	docker compose logs -f api

# ── Flutter app ──────────────────────────────────────────────────────────────

app-get:         ## fetch Flutter dependencies
	cd app && flutter pub get

app-run:         ## run the app (point it at the API via --dart-define)
	cd app && flutter run --dart-define=JIBIKI_API_BASE=http://localhost:$(PORT)

app-web:         ## production Flutter Web build for my.jibiki.app
	cd app && flutter build web --release --source-maps --dart-define=JIBIKI_API_BASE=$${JIBIKI_API_BASE:-https://api.jibiki.app}

# Marketing site
site-get:        ## install the Astro site dependencies
	cd site && npm ci

site-run:        ## run the SEO site locally on :4321
	cd site && npm run dev -- --host 0.0.0.0

site-build:      ## build the static SEO site
	cd site && npm run build

caddy-check:     ## validate the edge configuration in a clean Caddy image
	docker run --rm -e ROOT_DOMAIN=jibiki.app -e APP_DOMAIN=my.jibiki.app -e API_DOMAIN=api.jibiki.app -v "$(CURDIR)/caddy/Caddyfile:/etc/caddy/Caddyfile:ro" caddy:2.10.2-alpine@sha256:4c6e91c6ed0e2fa03efd5b44747b625fec79bc9cd06ac5235a779726618e530d caddy validate --config /etc/caddy/Caddyfile
