.PHONY: sync db migrate makemigrations seed run test lint check shell \
        up down prod prod-down logs superuser import-jmdict import-kanjidic app-get app-run

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

test:            ## backend tests (sqlite in-memory, no network)
	$(SERVER) $(UV) pytest -q

lint:            ## ruff check + format check
	$(UV) ruff check server
	$(UV) ruff format --check server

check:           ## Django system checks
	$(SERVER) $(UV) python manage.py check

shell:
	$(SERVER) $(UV) python manage.py shell

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

prod:            ## bring the full stack up detached (server)
	docker compose --profile web up -d --build

prod-down:
	docker compose --profile web down

logs:
	docker compose logs -f api

# ── Flutter app ──────────────────────────────────────────────────────────────

app-get:         ## fetch Flutter dependencies
	cd app && flutter pub get

app-run:         ## run the app (point it at the API via --dart-define)
	cd app && flutter run --dart-define=JIBIKI_API_BASE=http://localhost:$(PORT)
