# Versioned content sources

This directory contains small, reviewed source inputs for seed commands. It does
not contain generated packs, scraped dumps, uploaded media or database exports.

`mnemonics/` contains language-native mnemonic sources. `kana_stories.json`
stores one independently authored story per glyph and language for the 46 basic
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
