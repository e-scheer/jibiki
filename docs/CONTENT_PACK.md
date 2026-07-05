# jibiki content pack — the data model you own

The dictionary lives in **jibiki's own versioned JSON model**, not in any upstream
format. Upstream sources (JMdict / KANJIDIC2 / KRADFILE / KanjiVG) are parsed
**once** by `scripts/build_content_pack.py`; everything downstream — the backend
DB, the app's offline store — consumes this pack and never touches XML again.

**Enrich by adding to the model, not by re-scraping.** Meanings and glosses are
keyed by language code, so adding French/German/… is adding a key. Add a new
mnemonic language, fix a gloss, add a field: edit the JSON (or your own generator),
bump the version, reload. No dependency on EDRDG's format or on parsing.

## Layout

```
content/
├── manifest.json     # schema, version, counts, per-file sha256, attribution
├── kana.json
├── radicals.json
├── kanji.json
└── words.json
```

`manifest.json`:

```json
{
  "schema": "jibiki-content/1",
  "version": "2026.07.05",
  "source": "seed",                     // or "edrdg"
  "languages": ["en", "fr"],
  "counts": { "kana": 142, "radicals": 20, "kanji": 43, "words": 30 },
  "files": [{ "name": "kanji.json", "sha256": "…", "bytes": 29520, "count": 43 }],
  "attribution": { "words": "JMdict © EDRDG …", "strokes": "KanjiVG © … CC BY-SA 3.0" }
}
```

## Schema `jibiki-content/1`

**kana.json** — `[{ char, romaji, script, kind, row, order }]`

**radicals.json** — `[{ literal, strokes, reading, meaning }]`

**kanji.json**
```json
{
  "literal": "水", "grade": 1, "stroke_count": 4, "jlpt": 5, "freq_rank": 130,
  "radical_number": null, "on": ["スイ"], "kun": ["みず"], "nanori": [],
  "meanings": { "en": ["water"], "fr": ["eau"] },
  "components": ["水"],
  "strokes": { "viewbox": "0 0 109 109", "paths": ["M…", "…"] }
}
```

**words.json**
```json
{
  "id": 6, "seq": 1358280, "common": true, "jlpt": 5, "freq_rank": null,
  "kanji": [{ "text": "食べる", "common": true }],
  "kana":  [{ "text": "たべる", "common": true }],
  "senses": [
    { "pos": ["v1", "vt"], "misc": [], "glosses": { "en": ["to eat"], "fr": ["manger"] } }
  ]
}
```

`meanings` (kanji) and `senses[].glosses` (words) are **language-maps** — the one
design decision that makes enrichment trivial.

## Pipeline

```bash
# 1. Build the pack ONCE (curated seed — instant, always available):
python scripts/build_content_pack.py --from-seed --server server --out content

#    …or from the full downloaded EDRDG + KanjiVG (also one-shot):
python scripts/build_content_pack.py --out content --langs en,fr \
    --jmdict JMdict_e.xml --kanjidic kanjidic2.xml \
    --kradfile kradfile --kanjivg kanjivg/kanji

# 2. Backend loads the pack into the DB (never the XML):
cd server && uv run python manage.py load_pack ../content

# 3. Backend serves it for the app to download for offline use:
#    GET /api/v1/content/manifest      GET /api/v1/content/file/<name>
```

The committed `content/` is the curated seed pack (small, ships in the repo). Full
EDRDG packs are large — build locally and host them; the manifest's version +
sha256 let the app cache and update.
