# LLM HTML Sample Exercise

This exercise uses **stored HTML only** and does **not** depend on the current
site extractor outputs for content fields.

## Files

- Raw HTML sample packets:
  - `var/llm_prototype/raw_html_sample.json`
- English-only candidate output:
  - `var/llm_prototype/english_sample_candidate.json`
- Prototype scripts:
  - `scripts/prototype_llm_html_sample.py`
  - `scripts/build_en_llm_sample_candidate.py`

## Sample scope

- `10` kana pages from `kanjidraw`
- `10` kanji pages:
  - `5` from `wanikani`
  - `5` from `tanoshii_japanese`
- `10` word pages:
  - `5` from `wanikani`
  - `5` from `tanoshii_japanese`

Total: `30` HTML pages.

## What this prototype is

This is a **one-shot experiment** to answer one question:

Can we take stored HTML, isolate the useful blocks, and produce a stable
English seed candidate that is good enough to justify a real LLM stage later?

The answer is: **yes, but unevenly**.

## What works well

### 1. Kana pages are already close to seed-ready

The `kanjidraw` kana pages are compact and regular. We reliably get:

- kana symbol
- romaji
- script type
- stroke count
- small example pairs

This category is the cleanest one in the whole exercise.

### 2. WaniKani kanji pages normalize very well

The public lesson pages expose a strong learner-oriented structure:

- primary gloss
- alternative glosses
- on/kun readings
- mnemonic text
- linked example vocabulary

The English candidate output for these pages is already highly usable.

### 3. WaniKani vocabulary pages also survive normalization well

For the sampled vocabulary pages, we consistently recover:

- surface form
- reading
- part of speech
- main meaning
- explanatory note
- at least one context sentence

These are good candidates for a first-pass lexical seed.

### 4. Tanoshii content is useful, but needs adjudication

`tanoshii_japanese` exposes rich material:

- dictionary meanings
- example sentences
- cross-links to kanji
- category/synonym material

That makes it valuable as a source, but it is not clean enough to promote raw.

## What breaks or degrades

### 1. Tanoshii function words explode into sense dumps

Entries such as `も` and `の` are exactly why a real LLM pass is needed.

The source page mixes:

- multiple grammar functions
- register notes
- usage notes
- sentence-final discourse functions

A stable seed must split those into distinct learner-facing senses instead of
preserving one giant flat meaning blob.

### 2. Tanoshii kanji pages are not uniformly English-first

Some kanji pages expose a linked dictionary entry with English glosses.
Others expose Japanese meaning text plus other-language blocks, but no clean
direct English headword summary in the same place.

For this prototype, the English candidate layer needed manual/semantic
adjudication for sampled kanji such as:

- `女`
- `木`
- `楽`
- `巣`

This is acceptable for a true LLM stage, but not for a pure rule parser.

### 3. Raw block boundaries are still noisy

Examples:

- `kana` example text can bleed into the adjacent `Practice` block
- WaniKani sections sometimes merge `Mnemonic` and `Hints`
- Tanoshii section text can contain navigation noise or action labels

This does not kill the experiment, but it confirms that the HTML packetization
step should stay simple and let the LLM do the final semantic cleanup.

## Coverage summary

From the generated English candidate output:

- `30/30` items were normalized into a usable object
- `10/10` kana have all target fields populated
- `10/10` kanji have stable gloss + reading coverage
- `10/10` words have stable surface/reading/meaning coverage

Observed missing fields:

- kanji:
  - `1/10` missing alternative glosses
  - `5/10` missing mnemonic text
    - these are the `tanoshii_japanese` kanji pages, not a parser failure
- words:
  - `2/10` missing `kanji_glosses_en`
    - these are function-word pages with no meaningful kanji breakdown

## Verdict

For a **one-shot seed experiment**, this is strong enough to continue.

But I would **not** keep the current candidate builder as the final
implementation, because:

- it still contains hand-tuned assumptions for sampled `tanoshii` items
- it is good for proving the shape of the pipeline, not for scaling as-is

What is worth keeping:

- the HTML-only sampling step
- the packetization idea
- the target English schema
- the conclusion that `WaniKani` and `KanjiDraw` are easy wins
- the conclusion that `Tanoshii` needs semantic adjudication rather than raw
  promotion

## Recommendation for the real implementation

Build the production flow like this:

1. HTML-only packet extraction
2. English normalization LLM pass
3. cross-source merge and adjudication
4. second LLM pass for non-English localization / DA rewriting

That sequence matches what this sample shows:

- source isolation is feasible
- English canonicalization should happen before multilingual expansion
- function words and polysemous kanji are where the LLM adds the most value
