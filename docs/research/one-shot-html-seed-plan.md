# One-Shot HTML Seed Plan

This plan assumes a **single ingestion pass** over the HTML pages already stored
under `var/site_mirror`, with no requirement to make the pipeline future-proof
or generic. The goal is to extract the maximum amount of useful Japanese
learning content from the mirrored pages, then pass that raw structured content
through a large multi-agent LLM cleanup/adjudication phase to produce a
high-quality `jibiki` seed.

## Scope

- Input is **only** the HTML already stored locally.
- No new live scraping is required for this pass.
- We do not optimize for a durable crawler architecture.
- We do optimize for:
  - high recall on useful content
  - aggressive extraction of page-specific structure
  - strong provenance
  - LLM-assisted consolidation into a stable pedagogical dataset

## Source boundary

Only parse mirrored HTML from:

- `var/site_mirror/kanjidraw/mirror`
- `var/site_mirror/kanshudo/mirror`
- `var/site_mirror/tanoshii_japanese/mirror`
- `var/site_mirror/the_kanji_map/mirror`
- `var/site_mirror/wanikani/mirror`

Assets such as PNG previews or JS are not the target output. They may be read
only if they help recover metadata already referenced by HTML pages.

## Output layers

Produce four concrete layers.

### 1. Raw page extraction

For each HTML page, extract a page JSON with:

- `site`
- `url`
- `saved_path`
- `page_type`
- `entity_hint`
- `page_title`
- `core page fields`
- `all extracted evidence blocks`

This layer should be wide and permissive. It is allowed to keep overlapping or
messy fields if they preserve signal.

### 2. Candidate entities

Transform page JSON into entity candidates:

- `kanji`
- `kana`
- `word`
- `reading`
- `radical`
- `component`
- `example_sentence`
- `conjugation`
- `mnemonic`
- `classification metadata`

At this stage, one real entity may exist multiple times from multiple sites.

### 3. Adjudicated canonical entities

Merge and arbitrate candidates into canonical records with:

- chosen values
- alternate values
- per-field provenance
- confidence
- conflict notes

### 4. DA-adapted content

Create the final seed used by `jibiki`:

- stable pedagogical glosses
- normalized readings
- cleaned component/radical data
- rewritten example sentences
- rewritten teaching copy in the DA

Keep all rewritten content explicitly separate from source-faithful content.

## Content model

The target model should be centered around `lexical entities`, not around pages.

### Kanji record

- character
- meanings
- on readings
- kun readings
- nanori if present
- stroke count
- radical
- components
- grade
- JLPT
- frequency
- variants
- source mnemonics
- linked vocabulary
- linked sentences

### Kana record

- character
- script
- romaji
- stroke count
- examples
- variant/voiced/diphthong relations

### Word record

- primary surface
- alternate surfaces
- primary reading
- alternate readings
- part of speech
- core senses
- extended/editorial senses
- component kanji
- usage/frequency/JLPT metadata
- conjugations
- related examples

### Sentence record

- source Japanese sentence
- source English gloss/translation if present
- linked words
- linked kanji
- source site/page
- rewritten DA sentence
- rewritten DA meaning/explanation

## Extraction strategy

This pass should not rely on one minimal parser per site. It should extract
`all recoverable useful blocks` from each page family.

### WaniKani

Extract from `kanji`, `vocabulary`, `radicals` pages:

- meaning sections
- reading sections
- mnemonic sections
- hints
- context sentences
- related subject grids
- component/radical decomposition

Store mnemonics as source editorial content, not yet canonical truth.

### The Kanji Map

Extract from kanji pages:

- canonical character id
- meanings
- on/kun readings
- stroke count
- radical
- parts
- graph links
- frequency/grade/JLPT

This source is likely one of the cleanest structural anchors for kanji graph
relations.

### KanjiDraw

Extract from:

- dictionary pages
- radical pages
- collection pages
- kana pages and kana detail overlays

Important targets:

- embedded preload JSON
- collection cards
- radical membership
- kana tables
- example words
- stroke/practice metadata

### Kanshudo

Extract from:

- word pages
- kanji pages
- component pages
- kanji draw pages only when they contain useful explanatory signal

Important targets:

- usefulness/frequency/JLPT signals
- word readings and alternate forms
- example sentences
- kanji/component relations
- public component/reference information

Do not overvalue Kanshudo page chrome; focus only on lexical or pedagogical
content blocks.

### Tanoshii Japanese

Extract from:

- `entry_details`
- `stroke_order_details`
- `conjugation_details`
- `sentence_details`
- `kanji_details`
- `kanji_stroke_order_details`
- browse/index pages only to discover relations

Important targets:

- entry forms
- readings
- part of speech
- English meanings
- synonym/hyponym tables
- linked kanji meanings
- conjugation inventories
- sample sentences
- sentence vocabulary decomposition

Tanoshii is likely the richest source for sentence-linked vocabulary structure.

## One-shot extraction philosophy

Because this is a one-shot, extraction should be deliberately redundant.

- Prefer extracting `too much` rather than pruning early.
- Keep block-level evidence in the raw page JSON.
- Preserve exact source text before any rewriting.
- Preserve URL/query-derived identifiers like `entry_id`, `sentence_id`,
  `character_id`, `conjugation_type_id`.

The cleanup should happen after extraction, not during extraction.

## Multi-agent LLM phase

The LLM layer should be treated as a `massive parallel transformation pass`
over already extracted raw structured data.

### Core idea

Split the dataset into tens of thousands of small adjudication jobs and run
`dozens of agents in parallel`.

Examples of parallel job units:

- one kanji across all sources
- one word across all sources
- one sentence cluster
- one conjugation family
- one component/radical family
- one conflict set for a single field

### Agent roles

Use specialized agent roles instead of one monolithic pass.

#### Extractor QA agent

- checks raw parsed page JSON
- flags obviously broken fields
- recovers missed structure from evidence blocks

#### Entity merger agent

- groups duplicate candidates into one entity
- aligns alternate surfaces/readings
- links words to kanji/components/sentences

#### Field adjudicator agent

- chooses the best value for each field
- ranks sources
- keeps alternates when ambiguity is legitimate

#### Pedagogy agent

- rewrites meanings into consistent teaching-friendly glosses
- orders senses for learner usefulness
- tags difficulty/usefulness

#### Sentence rewrite agent

- rewrites example sentences into the DA
- keeps the semantic intent
- changes wording enough to avoid direct reuse of source phrasing
- outputs:
  - `source_sentence`
  - `normalized_source_meaning`
  - `da_sentence`
  - `da_explanation`

#### Consistency judge agent

- validates internal consistency across entity graph
- catches:
  - kanji/reading mismatch
  - impossible stroke metadata
  - bad sentence-word links
  - contradictory JLPT/grade/frequency assignments

### Parallelization shape

Recommended one-shot batching:

- batch `kanji` entities in shards
- batch `word` entities in shards
- batch `sentence` entities in shards
- batch `conflict review` entities in shards

For each shard:

1. load raw candidates plus evidence
2. run merger agent
3. run adjudicator agent
4. run consistency judge
5. if sentence-bearing, run sentence rewrite agent
6. emit canonical + DA outputs

This is a good use case for launching `dozens of agents at once`, because each
entity or entity shard is mostly independent.

## Source ranking heuristic

For this one-shot pass, use a pragmatic ranking rather than a formal scoring
system.

Suggested defaults:

- `the_kanji_map` strong for kanji structure
- `kanjidraw` strong for kanji/radical/kana structural teaching data
- `tanoshii_japanese` strong for word/sentence/conjugation webs
- `wanikani` strong for pedagogical framing and curated mnemonic-style content
- `kanshudo` strong for usefulness/frequency/JLPT-style enrichment and word
  variants

No source should be globally authoritative for everything.

## Conflict handling

The LLM should not silently flatten disagreements.

For each canonical field:

- keep `selected_value`
- keep `alternative_values`
- keep `source_evidence`
- keep `selection_rationale`

Typical conflicts:

- multiple gloss phrasings
- common reading vs listed reading
- pedagogical meaning vs dictionary meaning
- frequency/JLPT disagreements
- sentence translation differences

If the conflict is harmless, keep one canonical value plus alternates.
If the conflict changes interpretation, mark it for human review.

## Sentence rewrite policy

The final dataset should not ship raw source sentences as the main pedagogical
surface if the plan is to reshape everything into the DA.

Recommended structure:

- `source_sentence_ja`
- `source_sentence_en_or_gloss`
- `sentence_semantic_core`
- `da_sentence_ja`
- `da_sentence_en`
- `tone_tags`
- `difficulty_tags`

Rules for DA rewriting:

- preserve the target vocabulary or grammar objective
- preserve overall meaning/function
- change syntax/lexical framing enough to create a new pedagogical sentence
- avoid awkward literal rewrites
- prefer high naturalness and consistency with `jibiki`

## Minimal operational sequence

This is the simplest one-shot execution plan.

1. Re-run local page parsing over all mirrored HTML.
2. Emit maximal raw page JSON.
3. Convert page JSON to candidate entities.
4. Build cross-source clusters by:
   - character
   - normalized surface
   - normalized reading
   - query ids
   - URL-derived ids
5. Launch many LLM agents in parallel on clustered entities.
6. Merge agent outputs into canonical entities.
7. Launch a second LLM consistency pass on the merged result.
8. Launch sentence/DA rewriting agents on example content.
9. Emit final seed packages.

## Deliverables

The one-shot run should output:

- `raw_pages.jsonl`
- `entity_candidates.jsonl`
- `entity_clusters.jsonl`
- `canonical_kanji.jsonl`
- `canonical_kana.jsonl`
- `canonical_words.jsonl`
- `canonical_sentences.jsonl`
- `da_sentences.jsonl`
- `review_conflicts.jsonl`
- `provenance_manifest.json`

## Success criterion

The pass is successful if the final seed is:

- broader than any single source
- cleaner than the raw parsed HTML
- internally consistent enough for `jibiki`
- pedagogically shaped for the DA
- backed by recoverable provenance when a field is questioned later

For this run, that is more important than building a perfect reusable pipeline.
