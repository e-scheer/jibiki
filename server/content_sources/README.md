# Versioned content sources

This directory contains small, versioned source inputs for seed commands. It does
not contain generated packs, scraped dumps, uploaded media or database exports.

`mnemonics/` contains language-native mnemonic sources. `kana_stories.json`
stores one language-scoped story per glyph and language for the 46 basic
hiragana and 46 basic katakana. The kanji files store meaning and reading briefs.

Adding a language means completing and reviewing its own 92-kana catalogue. A
research note or an English translation is not enough to publish a default deck.

The `strategy` field makes the editorial contract explicit:

- `visual_meaning` stories may share a language-neutral shape composition, but
  their prose is still stored and reviewed per language.
- `phonetic_reading` and `shape_plus_native_sound_anchor` require independent
  sound anchors in every language. Mechanical translation is invalid.

Large upstream datasets stay outside the repository and are passed directly to
the commands in `dictionary/management/commands/`.

## Editorial verification

The legacy files do not record a named reviewer, authoring method or per-story
review checksum. Their previous prose claims of review are not evidence. The
existing stories remain unchanged, with `review_status: unverified` and
`generation_method: unknown` in installed provenance. This means neither human
nor AI authorship can be established from the files alone.

New unverified seed rows are pending. Re-running a seed does not undo an existing
moderation decision. Existing visible rows retain their visibility while their story is unchanged.
Changing visible text without review returns it to pending; the migration
marks their editorial evidence unverified. Every source installation records the
source path, source file SHA-256, exact story SHA-256, language and strategy.

To record a real linguistic review, add an entry-level `reviews` object keyed by
language. A verified review requires `status: verified`, `reviewer`,
`reviewed_at` (ISO date) and `story_sha256` matching the trimmed UTF-8 story. This
is a review record, not an automated verdict. A change to the story invalidates
the checksum and cannot reuse that verification. Publication/moderation remains
a separate action for existing rows.
