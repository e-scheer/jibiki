# Kana and mnemonic quality audit

Date: 2026-09-06; completion pass: 2026-09-09. Scope: local PostgreSQL content, versioned seed inputs,
loaders, the KanjiDraw extracted snapshot and their language/review boundaries.
No stories were translated, regenerated or imported from the LLM prototype.

## What exists, and what is actually published

The initial database snapshot contained:

| Content | Total | Languages |
| --- | ---: | --- |
| Kana targets | 208 | Language-neutral |
| Kana origin explanations | 208 | English only |
| Grammatical usage explanations | 19 | English only |
| Grammatical example sentences | 38 | English translations only |
| Visible seed kana mnemonics | 184 | 92 English, 92 French |
| Kanji meaning or reading mnemonics | 0 | None published in this database |

Each script has 46 basic targets, 20 dakuten, 5 handakuten and 33 yoon.
The 208 targets are a pedagogical subset, not an exhaustive repertoire of kana
orthography. Small kana as individual targets, sokuon (`っ`, `ッ`), the length
mark (`ー`), extended katakana combinations and historical forms are outside
this catalogue. Existing yoon include small kana as parts of composite targets.
The 92-story baseline intentionally covers only the 46 basic characters in each
script. Filling every variant with a newly generated story would be misleading.

The versioned kanji briefs are a separate, unpublished content pool:

| Level file | Meaning targets | Reading targets | Languages |
| --- | ---: | ---: | --- |
| n5 | 79 | 79 | en, fr |
| n4 | 166 | 166 | en, fr |
| n3 | 367 | 366 | en, fr |
| n2 | 367 | 367 | en, fr |
| n1 | 1,232 | 1,225 | en, fr |
| Total | 2,211 | 2,203 | en, fr |

Every target has a nonempty story in both declared languages. This checks
coverage, not truth, phonetic usefulness or linguistic review. A source file's
`generated` date does not establish whether AI authored its text. There is an
explicit LLM candidate under `var/llm_prototype/english_sample_candidate.json`;
its presence does not establish that it supplied the published 184 stories.
No per-story authoring or review evidence was recorded in the legacy inputs.
Their origin therefore remains **unknown**, not proven human or proven AI.

## Defects corrected

1. `seed_kana_context` and `seed_demo` used to delete all origin translations,
   grammatical usage rows and examples before recreating English content. A
   rerun could erase French work. Both now share `dictionary/kana_seeding.py`:
   English upserts preserve all other languages. Japanese examples retain their
   identity and translations; a custom example occupying a seed position is
   retained and the new example is appended. Rerunning is idempotent.
2. Kana validation previously accepted any 46 codepoints in each Unicode block
   with any nonempty romanization. It now checks the exact canonical basic
   glyph/romaji pairs, real unique ISO 639-1 language codes and complete,
   distinct language stories. This does not claim their sound anchors are good.
3. Kanji brief loaders previously accepted incomplete schema/duplicate targets
   and published every input as visible. They now verify schema, strategy,
   declared counts, unique targets, language codes, story types and katakana
   reading shape. New content without review evidence is pending.
4. Seed reruns used to set hidden/removed content back to visible. Existing
   moderation state is retained. A changed visible story without fresh review
   returns to pending; unchanged legacy text stays visible. Kana seed matching now includes `is_seed=True`,
   so an anonymized user's contribution cannot be overwritten as a system seed.
   Existing deck items are preserved.
5. `Mnemonic.provenance` records source path, source SHA-256, story SHA-256,
   language, strategy, generation method and editorial review status. API and
   admin expose this data. Migration 0006 marks legacy seeds unverified without
   changing their text or visibility. An unverified visible legacy seed is not
   represented as a verified one.
6. A review claim now needs a language-specific record containing reviewer,
   ISO review date and the exact story checksum. An edited story cannot reuse
   that checksum. These fields record accountable review; they cannot prove
   that a named reviewer actually performed a good linguistic review.
7. The app labels the actual fallback language beside kana origin notes,
   grammatical explanations and example translations. An English paragraph in
   a French interface is explicitly marked as English with French translation
   unavailable. Mnemonic cards distinguish publication from recorded editorial
   review; legacy stories display that their review and origin are undocumented.
   The model retains provenance after votes and offline pack reads. Older packs
   without this optional metadata remain unverified.
8. Language validation rejects uppercase aliases accepted by the underlying
   ISO catalogue: `EN` must not silently create a separate database language
   from `en`. Recorded review dates use the explicit YYYY-MM-DD calendar form.

The raw text of every English and French kana story is unchanged. New unverified
seed catalogues remain pending, including on a fresh installation. Existing
public content keeps its moderation state. Publication of an existing pending
row remains a separate moderation action. API tests explicitly publish their
fixture catalogue; seed-policy tests verify pending defaults independently.

## Extracted kana examples: a concrete source-quality problem

`var/site_extract/kanjidraw/pages.jsonl` contains 186 kana detail pages, 186 unique
targets and 370 lexical examples. Its SHA-256 at audit time is
`81f846990302c7f3c0cddc9b6279be33d138f159abfd9b258d71f4c265eb61b1`.

There are 184 targets in common with Jibiki, with matching romanization strings.
The source also contains `っ` and `ッ`, but lacks the 24 voiced yoon targets formed
from gya, ja, bya and pya across the three vowels and two scripts. It is therefore
an enrichment input, not a replacement for the existing chart.

Seven extracted examples do not contain the glyph they would purport to teach:

| Target | Extracted example | Problem |
| --- | --- | --- |
| ひゃ | さんびゃく | Contains びゃ, not the target |
| ひゅ | びゅうびゅう | Contains びゅ, not the target |
| ヂ | ラジオ | Contains ジ, not the target |
| ヂ | メディア | Contains ディ, not the target |
| ヅ | プロデュース | Contains デュ, not the target |
| ヅ | デュエット | Contains デュ, not the target |
| ヒャ | サンビャク | Contains ビャ, not the target |

They may be useful in an explicitly labelled comparison of related sounds, but
cannot be published as direct examples of these target kana. The audit script
separates **363 structural candidates** from **7 quarantined rows**, retaining
source URL, extraction location, source hash and validation reasons. The
structural audit alone does not publish any row. A target occurrence alone is
insufficient to establish a correct reading or translation. The canonical
linking step described below adds a separate dictionary-reading check.

Run from the repository root:

```powershell
python scripts/audit_kana_examples.py
```

Outputs: `var/quality_audit/kana_examples/{summary.json,candidates.jsonl,quarantine.jsonl}`.
The extractor itself remains unchanged. The audit can run again against a new
snapshot without changing source files or published data.

## Structure and remaining work

The separation of neutral kana, localized origin notes, grammatical usage,
Japanese example segments and localized translations is a useful foundation.
A lexical kana example is a different relationship from a grammatical-particle
example. The 370 extracted lexical examples must not be inserted into
`KanaUsageExample`, which would incorrectly imply that ordinary kana are
particles. `KanaWordExample` now references a canonical word, its exact reading
and the source evidence. It does not assert a particular sense: its UI displays
canonical dictionary definitions and links to the full entry. A future exercise
targeting one meaning must use an explicit sense choice, not an arbitrary first
English gloss.

`Kana.romaji` currently serves both chart lookup and a displayed sound cue. It
has no declared romanization system or separate pronunciation description. The
matching source strings are therefore evidence of consistent spelling, not a
phonetic validation. Sound mnemonics need independent review in each language;
meaning-image mnemonics may share a visual composition but still need accurate
localized prose. Text differences alone do not prove independent authorship.

The next content pass should:

- Review the 184 existing stories by language and record evidence per story.
- Enrich French origin/usage/example translations from identified reviewed
  sources. Missing French remains missing instead of padded with translations.
- Add special kana and length marks as explicit learning categories with a
  coordinated schema, chart, detail, stroke and pack contract. Do not put sokuon
  into the 46 basic targets simply to make it visible in the current grid.
- Resolve the 7 quarantined examples against their source context. Compare
  candidates with canonical word readings and meanings before publication.
- Keep editorial stories separate from etymological claims. A plausible visual
  story is not evidence for a kanji's historical formation.
- Validate each kanji reading brief against the corresponding canonical reading
  inventory before any publication; the current loader validates its structure,
  not that its chosen reading is pedagogically primary.

The audit fixes destructive loaders and untraceable publication. It does not
claim that all linguistic content has been independently reviewed.

## Canonical lexical-example integration

Migration 0012 adds `KanaWordExample` separately from grammatical examples.
`import_kana_word_examples` accepts the audited JSONL and produces a machine
readable report. All 363 candidate spellings contain only kana, so their exact
spelling can be checked as a reading without generating romanization or
guessing kanji. Acceptance requires an existing target inside the spelling,
source evidence, and exactly one canonical JMdict entry with that exact kana
reading. Script conversion and gloss-based homograph guessing are not used.
Demonstration entries and canonical aliases are excluded.

The relation stores source URL, input hashes, line positions, the JMdict stable
sequence and snapshot hash. Its review status is `structural_match`, never
`verified`. Scraped translations are not stored or displayed: API and offline
packs resolve the word's canonical definitions in the selected language, with
explicit fallback-language notices. Up to eight lexical entries are shown per
kana; each opens its full dictionary entry. They are displayed separately from
the particle-usage section on mobile and tablet.

The command's dry run does not write rows. Applying it is idempotent, and a
previously imported link that becomes ambiguous is withdrawn without deleting
an independently authored relation. Unmatched and ambiguous candidates remain
in the report with their source reference. Neither matching nor a dictionary
definition establishes that the original scrape intended a particular sense.

From `server/`, preview with:

```powershell
python manage.py import_kana_word_examples ../var/quality_audit/kana_examples/candidates.jsonl --dry-run --report ../var/quality_audit/kana_examples/dictionary_preview.json
```

After checking that report, the same command without `--dry-run` writes the
relations and an import report.

The actual import ran on 2026-09-09 after the 218,726-entry JMdict import,
provenance refresh, alias reconciliation and migrations 0012/0013. Its result:

| Result | Count |
| --- | ---: |
| Audited input candidates | 363 |
| Imported lexical relations | 214 |
| Distinct canonical words linked | 211 |
| Kana with at least one lexical example | 145 |
| Quarantined homograph readings | 119 |
| Quarantined missing exact readings | 26 |
| Quarantined examples for absent `っ`/`ッ` targets | 4 |

The 26 unmatched readings include kana phrases such as `てをあらう` and
`ほんをよむ`, which must not be manufactured as dictionary lexemes, and source
spellings that differ from canonical readings. They were not silently rewritten.
The 149 mapping quarantines are additional to the seven original target-mismatch
quarantines: all 370 extracted examples are accounted for as 214 accepted links
and 156 rows held for review.

Actual reports are `var/audit/kana_word_examples_import.json` and
`var/audit/kana_word_examples_rerun.json`. A second actual import compared every
stored relation before and after and found exact equality, including primary
keys and provenance. No duplicates or changed rows were introduced. A read-only
API check on the real database returned HTTP 200 for `う`, with the canonical
`うた` entry, French definitions `chanson` and `poème`, and its structural source
evidence. This confirms integration and localization, not human linguistic review.

## Reviewable extension catalogue

`server/content_sources/kana_extension_candidates.json` records 25 missing
character candidates: 12 small hiragana, 12 small katakana and the length mark.
Character identity and codepoints were checked against the Unicode 17.0
[Hiragana chart](https://www.unicode.org/charts/PDF/U3040.pdf) and
[Katakana chart](https://www.unicode.org/charts/PDF/U30A0.pdf). These references
establish encoded character identity, not the correctness of a teaching story.
The two small tsu are proposed as a separate sokuon category. No copied teaching
prose, fabricated examples or standalone sound values were supplied.

This file is deliberately separate from the production seed contract. That
contract requires one of four categories, a romanization used for chart pairing
and quiz answers, and a two-script choice. A length mark is shared, and treating
small tsu as an ordinary `tsu` quiz target would teach the wrong distinction.
Integrating these candidates requires a contextual pronunciation/exercise
contract, a special-character chart section, and explicit stroke fallback.
The candidate list also does not purport to cover historical forms, iteration
marks, Ainu phonetic extensions or all katakana loanword combinations.

## Validation evidence

- Existing seed/content/API regression run: 55 tests passed, recorded in
  `server/kana-audit-tests.log` during the first pass.
- Completion pass: seven pure validation tests passed (source review evidence
  and kana extraction quarantine). No production database was used as a test
  fixture.
- Completion pass: 25 Flutter tests passed for language/review notices, origin
  and grammar rendering, kana authentication boundaries and two-script writing.
  The writing tests include 360, 390 and 550 pixel widths, larger French text,
  a short phone and a tablet. Native screenshot capture remains unavailable as
  recorded in the application audit.
- Lexical integration: four server regressions passed for dry-run/idempotence,
  exact matching, ambiguity, canonical aliases, preservation of independently
  authored relations and canonical API definitions. Seventeen Flutter tests
  passed including navigation to the dictionary at 390 and 1024 pixels and the
  existing phone/tablet writing and authentication scenarios. Flutter analysis
  reported no issues before the final data import.
