# Kanji alive structured enrichment

Completed 2026-09-09 against the local source harvest and canonical dictionary.
This pass integrates reusable radical data into the API, offline packs and kanji
detail screens. It does not import mnemonics or invent translations.

## Source and actual scope

The archived normalized snapshot is
`var/source_harvest/upstreams/kanjialive/normalized/kanji_alive.json`.
Its SHA-256 is
`164fd32d111dc2914e3bf88803da50fdf4bdcc2d5b9a588579c0ff803104a439`,
matching the Kanji alive entry in `var/source_harvest/open_manifest.json`.
The importer requires this manifest and rejects a changed snapshot before any
write. The source declares [CC BY 4.0](https://github.com/kanjialive/kanji-data-media/blob/master/LICENSE.md).
Attribution, repository URL, license URL and snapshot hash are retained in
provenance; the app and pack manifest include attribution.

An exhaustive comparison against the two archived raw CSV files checked the
radical glyph, Japanese name, English meaning and position for all 322 radical
rows and all 1,235 kanji rows. It found zero mismatches in those imported fields.
The comparison and raw-file checksums are recorded in
`var/audit/kanjialive_raw_parity.json`. This confirms that the normalized input
preserves these source fields, rather than silently substituting generated prose.

The snapshot has 1,235 rows in its kanji collection and 322 radical rows. One
row in each collection is the iteration mark `々`, with `n/a` radical data and
no stroke count. Those rows are not imported as kanji or radicals. Actual useful
content here is 1,234 kanji relationships and 321 radical catalogue records.
The source's older README counts are not treated as a current completeness test.

The source also contains 10,156 lexical example records. They are not glyph-origin
explanations, and this importer does not reinterpret them as etymology. The
repository explicitly excludes its copyrighted mnemonic hints. None is inferred
from the open files or fetched from the separate web application's detail view.

## Structural traps corrected before integration

- `ka_data.csv` radical order and `japanese-radicals.csv` radical ID are different
  namespaces. A numeric join would mismatch 1,204 source glyph relationships.
  For example, `何` has radical order 11 in the kanji CSV, while its `⺅` catalogue
  entry has ID 12. Neither is the KANJIDIC Kangxi radical number 9. The importer
  validates the normalized snapshot's glyph-based catalogue match and preserves
  both source identifiers separately.
- Sixty radical catalogue glyphs use private-use Unicode points that require the
  source's custom font. They are not added as broken glyphs to the public radical
  picker. The 266 affected kanji still receive their exact source radical name,
  English meaning and position, with an explicit `glyph_available: false` marker.
  The UI shows the name and meaning and explains the unavailable glyph.
- Standard radical glyphs use Unicode NFKC normalization while retaining their
  original source glyph. `羽` and `⽻` merge to `羽` with identical source data.
  Two `⾂` records merge to `臣`, but disagree on six versus seven strokes. A
  missing stroke count is left unknown instead of arbitrarily choosing a value.
  The related `臨` and `臣` source records also expose this disagreement in the
  audit report. Their existing canonical stroke counts remain unchanged.
- Meaning comparison preserves English word boundaries. Only spacing and
  parentheses typography are normalized when checking the two source tables.
  A match does not translate or rewrite either published meaning.

## Imported result

| Result | Count |
| --- | ---: |
| Standard normalized radical glyphs represented by the source | 259 |
| New radical rows | 240 |
| New English radical meanings | 240 |
| Total radical rows after import | 260 |
| Kanji with source-scoped radical metadata | 1,234 |
| Relationships with portable glyphs | 968 |
| Relationships shown by name without a private-use glyph | 266 |
| Existing differing English meanings preserved | 10 |
| Placeholder rows quarantined | 2 |

`Radical.provenance`, added by migration 0014, records source evidence and which
previously missing fields were supplied. Existing readings, stroke counts and
localized meanings are preserved. Radical meanings are explicitly English.

The kanji relationship lives under `Kanji.metadata.kanjialive.radical` with its
source evidence under `Kanji.provenance.kanjialive`. It is a separate named-radical
classification. The importer does not replace KANJIDIC definitions, readings,
grades, Kangxi radical numbers, KRADFILE components or origin explanations.

The kanji detail screen displays this source relationship separately from its
KRADFILE composition and glyph-origin sections. A French interface labels the
English meaning as untranslated. Radical browsing matches either the existing
component inventory or this explicit source relationship, so selecting `⺅`
can find `何` without falsely rewriting its KRAD components as `⺅`.

## Reproducibility and checks

From `server/`:

```powershell
python manage.py import_kanjialive ../var/source_harvest/upstreams/kanjialive/normalized/kanji_alive.json --manifest ../var/source_harvest/open_manifest.json --dry-run --report ../var/audit/kanjialive_preview.json
```

The reviewed actual import used the same command without `--dry-run`. Its
reports are `var/audit/kanjialive_import.json` and
`var/audit/kanjialive_rerun.json`. All changes are transactional. The dry run
does not save rows. A second actual run compared every affected kanji, radical
and radical-meaning row before and after and found exact equality, including
primary keys, canonical fields and provenance.

Tests cover source checksum rejection, distinct catalogue IDs, preservation of
canonical and multilingual content, idempotence, private-use glyph handling,
and withholding the iteration-mark placeholder. Widget tests cover French
rendering and attribution at 390 and 1024 pixels without displaying private-use
glyphs. This verifies source integration and data boundaries; it does not claim
an independent human linguistic review of every source description.
The final targeted server run passed all four tests; the six-test Flutter run
covered the new radical widget and existing detail authentication boundaries.
