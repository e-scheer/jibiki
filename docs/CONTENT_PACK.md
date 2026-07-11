# Content architecture

Jibiki has one explicit data flow:

```text
versioned sources -> import and seed commands -> PostgreSQL -> SQLite pack artifacts
```

PostgreSQL is the canonical runtime store. JSON source files are inputs, never a
second database. SQLite files are generated release artifacts, never edited by
hand or imported back into PostgreSQL.

## Directory ownership

| Path | Owner | Lifecycle |
| --- | --- | --- |
| `server/content_sources/` | Source control | Small, reviewed inputs used by seed commands |
| External JMdict, KANJIDIC2, KanjiVG and similar files | Operator | Downloaded outside the repository and passed to import commands |
| PostgreSQL | Django domain models | Canonical imported, curated and community content |
| `var/media/` | Django storage | Local development uploads only, replaced by S3 or R2 in production |
| `var/packs/` | `build_packs` | Generated downloadable artifacts, ignored by Git |
| `app/assets/packs/` | Mobile release | Generated bundled base pack committed for offline first launch |

The old JSON pack, `load_pack`, `build_content_pack.py` and their endpoints no
longer exist. The API only serves SQLite pack artifacts declared by the current
manifest.

## Localized content and language-native content

Translated reference content uses a neutral parent and language-tagged children:

- `Sense` and `SenseNote`
- `Radical` and `RadicalMeaning`
- `Kanji` with `KanjiMeaning` and `KanjiExplanation`
- `Kana` with `KanaExplanation`, `KanaUsageTranslation` and example translations
- `ExampleSentence` and `ExampleTranslation`
- `Name` and `NameTranslation`

The field name is always `language`. A requested language can fall back to English
for display, but that fallback remains labelled as English.

A mnemonic follows a different rule. Its image, story, sound association and deck
metadata are authored for one language. They are not translations of a neutral
mnemonic. The identity of a reading mnemonic is:

```text
(kind, character, reading, language)
```

This is why a French mnemonic and an English mnemonic for the same kana are two
independent contributions. Translating one mechanically does not create the other.

## Pack schema

`contentpacks` owns generation, SQLite DDL and download endpoints. `dictionary`
does not know how artifacts are packaged.

Schema version 2 separates neutral and localized tables:

- `dict-core`: words, forms, senses, kanji, kana, radicals and writing data
- `dict-locale-<language>`: glosses, meanings, notes and localized explanations
- `names`: names and their language-tagged translations
- `examples-<language>`: Japanese examples with one translation language
- `mnemonics-<language>`: language-native seed stories and optional WebP image BLOBs
- `dict-base`: a self-contained mobile bootstrap containing core plus selected locales

Images uploaded by the community remain storage objects referenced by the canonical
`Mnemonic` row. Only reviewed seed images are embedded in an offline mnemonic pack.
The story and image therefore travel atomically in that pack, while ordinary UGC is
served from media storage.

The manifest uses `jibiki-packs/3` and records stable id, content type, schema
version, dataset revision, hashes, languages, dependencies, sizes, localized title
and attribution for every artifact.

## Build and serve

```bash
# Bundled base pack for the mobile release
make build-base-pack

# Downloadable catalog in var/packs
make build-packs

# Direct invocation
cd server
uv run python manage.py build_packs \
  --out ../var/packs \
  --packs core,locale-en,locale-fr,names,examples-en,mnemonics-en
```

The public download surface is:

```text
GET /api/v1/content/packs/manifest
GET /api/v1/content/packs/file/<manifest-declared-file>
```

File downloads support byte ranges. A filename not declared by the manifest is
rejected.

## Release checklist

1. Run the relevant import and seed commands against PostgreSQL.
2. Review localized rows and language-native mnemonics independently.
3. Run migrations and both test suites.
4. Build the base pack and downloadable catalog.
5. Verify manifest hashes and commit only the bundled base artifact.
