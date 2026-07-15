# Source Ingestion Audit (2026-07-14)

This note classifies the external kanji/vocabulary sources we may want to use
for `jibiki`, with one practical goal: **prefer direct imports from open
datasets, and only scrape websites when the rights and operational constraints
are clear**.

The user goal for this track is a **personal, non-commercial, educational**
knowledge base. That reduces risk, but it does not erase copyright, robots, or
terms-of-service constraints. We therefore separate:

- `import_direct`: download structured open data directly from the upstream
  dataset/repository/API the author exposes for reuse.
- `scrape_cautiously`: scraping may be technically possible, but should stay
  narrow, rate-limited, and secondary to open data.
- `avoid_default`: do not build the default pipeline on this source; either the
  content is proprietary/editorial, duplicates open upstream data, or the reuse
  terms are too unclear.

## Current repo baseline

The repository already imports or seeds several strong upstreams:

- `JMdict` via [`server/dictionary/management/commands/import_jmdict.py`](/C:/Users/sauron/Documents/Personnal/jibiki/server/dictionary/management/commands/import_jmdict.py)
- `KANJIDIC2` via [`server/dictionary/management/commands/import_kanjidic.py`](/C:/Users/sauron/Documents/Personnal/jibiki/server/dictionary/management/commands/import_kanjidic.py)
- `KRADFILE` via [`server/dictionary/management/commands/import_kradfile.py`](/C:/Users/sauron/Documents/Personnal/jibiki/server/dictionary/management/commands/import_kradfile.py)
- `KanjiVG` via [`server/dictionary/management/commands/import_kanjivg.py`](/C:/Users/sauron/Documents/Personnal/jibiki/server/dictionary/management/commands/import_kanjivg.py)
- `Wiktionary` via [`server/dictionary/management/commands/import_wiktionary.py`](/C:/Users/sauron/Documents/Personnal/jibiki/server/dictionary/management/commands/import_wiktionary.py)
- example sentences via [`server/dictionary/management/commands/import_examples.py`](/C:/Users/sauron/Documents/Personnal/jibiki/server/dictionary/management/commands/import_examples.py)

That means many public websites in the Japanese-learning ecosystem are already
wrappers around data we either have or can ingest more cleanly from upstream.

## Classification

### Tier A: import directly first

| Source | Why | Notes |
|---|---|---|
| EDRDG `JMdict` / `KANJIDIC2` / `KRADFILE` | Canonical structured dictionary data | Already supported in repo. |
| `KanjiVG` | Best stroke-order/component SVG source | Already supported in repo. |
| `Tatoeba` | Open example sentences | Prefer bulk dataset/import, not page scraping. |
| `Kanji Alive` GitHub data repo | Openly licensed, structured CSV/XLSX, includes examples, radicals, media mapping | Strong first expansion source. No mnemonic hints in the published dump. |
| `Jitendex` | Open derived dictionary, convenient normalized packaging | Good optional enrichment layer. |
| `jmdict-yomitan` | Prebuilt JSON packages for JMdict/JMnedict/KANJIDIC | Good operational shortcut when raw XML is inconvenient. |
| `Kanjium` | Open enrichment for pitch/frequency/components | Good candidate for later enrichment. |

### Tier B: scrape only if there is a gap we cannot fill upstream

| Source | Why not first | Safe use |
|---|---|---|
| `Jisho.org` | Mostly repackages open dictionary data; robots advertises `Crawl-delay: 40`; no obvious open bulk license for site-specific presentation | Use upstream EDRDG/Tatoeba/KanjiVG instead. Scrape only narrow presentation details if truly unavailable elsewhere. |
| `KanjiDraw` | Robots is permissive, but site-level data license still needs review | Possible future source for feature ideas or lookup UX, not default ingestion. |
| `the-kanji-map.com` | Robots allows crawling, but data rights are not obvious from the public site | Treat as manual research until explicit reuse terms are found. |

### Tier C: avoid as default ingestion sources

| Source | Why |
|---|---|
| `WaniKani` website | Proprietary editorial layer. Public pages are useful for product study, but not a clean default data-ingestion source. Their public ToS discusses scraping, yet this still does not make their mnemonic/editorial corpus a good bulk-import target. |
| `Kanshudo` | Valuable product/reference site, but unclear reuse rights for a bulk personal mirror and likely heavy editorial content. |
| `Tanoshii Japanese` | Public content exists, but robots includes explicit content-signal language and site-specific constraints; also likely contains proprietary editorial text. |
| `Remembering the Kanji` full mnemonic text / PDFs | Book content is copyrighted. Use only metadata, indexing, or separately licensed derivative assets. Do not build a bulk extractor for story text from the book. |

## Site notes from the 2026-07-14 audit

### Jisho

- `https://jisho.org/robots.txt` returned `200`.
- For `User-agent: *`, it allows crawling and sets `Crawl-delay: 40`.
- Operationally this is a signal to be conservative even for personal scraping.
- Product-wise, it is usually better to import the upstream open datasets rather
  than scrape Jisho's rendered pages.

### WaniKani

- `https://www.wanikani.com/robots.txt` returned `200`.
- The file includes `Content-Signal: search=yes, ai-train=no, use=reference`.
- Public `Terms` are available at `https://www.wanikani.com/terms`.
- WaniKani is useful as a **product benchmark** and as a source of ideas about
  decomposition, mnemonic layering, and vocab presentation.
- It is **not** the right first target for building a large personal mirror of
  mnemonic/editorial content.

### Tanoshii Japanese

- `https://www.tanoshiijapanese.com/robots.txt` returned `200`.
- The file also contains `Content-Signal` language and a `Crawl-delay: 10`.
- That makes it a poor first ingestion target compared to open upstreams.

### Kanshudo

- `https://www.kanshudo.com/robots.txt` returned `200`.
- The file does not globally disallow crawling, but that is not the same thing
  as granting rights to bulk-reuse editorial content.
- Treat it as a reference product, not a default dataset.

### Kanji Alive

- The public GitHub repository exposes structured files under a
  `CC BY 4.0` license.
- The `language-data/ka_data.csv` dump includes kanji, readings, meanings,
  examples, and radical metadata.
- The published dump explicitly excludes mnemonic hints for copyright reasons.
- This is exactly the kind of source we should automate first.

### RTK-adjacent repos

- `cyphar/heisig-rtk-index` and `sschmidTU/mr-kanji-search-wtk` are useful for
  index/decomposition work, but they are not substitutes for a licensed dump of
  Heisig's book text.
- Treat them as derivative tooling/index sources, not as authorization to ingest
  RTK story text.

## Recommended ingestion order

1. `Kanji Alive` open GitHub data and media maps.
2. `Kanjium` enrichment.
3. `Jitendex` or `jmdict-yomitan` only if they simplify operational packaging.
4. Narrow, justified scraping only when a field is unavailable in open upstreams.

## Implemented harvest helpers

The repo now includes:

- [`scripts/fetch_kanjialive_open_data.py`](/C:/Users/sauron/Documents/Personnal/jibiki/scripts/fetch_kanjialive_open_data.py)
- [`scripts/source_harvest.py`](/C:/Users/sauron/Documents/Personnal/jibiki/scripts/source_harvest.py)
- [`scripts/extract_kanjium_data.py`](/C:/Users/sauron/Documents/Personnal/jibiki/scripts/extract_kanjium_data.py)

Together they:

- download open upstream datasets into `var/source_harvest/upstreams/`;
- normalize `Kanji Alive` into JSON;
- extract `Kanjium` pitch accents and kanji tables into repo-friendly files;
- unpack harvested Yomitan/Jitendex zip archives into local extracted folders;
- normalize the published RTK search index from `hochanh.github.io/rtk`;
- capture measured `robots.txt` + sample-page snapshots for the reference sites.
