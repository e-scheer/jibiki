# jibiki - working notes for Claude

## Writing style: NO em dashes, ever

Never use em dashes (`—`, U+2014) or en dashes (`–`, U+2013) as prose
punctuation, anywhere: UI copy, code comments, docstrings, JSON content
(mnemonic stories), docs, commit messages, PR descriptions, and chat replies.
They read as AI-generated and the project has been scrubbed of them.

Instead, use one of:
- a comma, colon, or full stop to separate clauses,
- parentheses for an aside,
- a plain spaced hyphen ` - ` when a dash-like break is genuinely wanted.

En dashes are fine ONLY inside numeric/level ranges that were already written
that way in source data (e.g. an imported "N5-N1" string). Do not introduce
new ones. When in doubt, rewrite the sentence so no dash is needed.

Quick self-check before finishing any text edit: grep the changed files for
`—` and `–` and remove any you added.

## Internationalization is mandatory

Every user-visible string must be inside the translation boundary when it is
introduced. This is required even when the product currently ships the text in
only one language, so catalogs can be extracted or generated later.

Use the native translation mechanism for the layer:

- Django templates: `{% trans %}` or `{% blocktrans %}`.
- Python: `gettext`, `gettext_lazy`, or `pgettext` when context is needed.
- Flutter: a generated ARB localization getter, or `context.trText(...)` while
  a screen is still on the migration bridge.

Never add raw UI copy for titles, labels, buttons, hints, errors, empty states,
tooltips, semantic labels, dialogs, notifications, or accessibility text.
Parameterized and plural text must use named placeholders and the appropriate
plural API. Do not assemble a translated sentence by concatenating fragments.

## Seeded content is language-scoped

The same obligation applies to user-visible seeded content. Every seed record
containing copy must declare its language explicitly, and seed loaders, queries,
uniqueness rules, and fallbacks must preserve that language scope. Do not treat
seed text as language-neutral, and do not silently expose one locale's seed as
if it belonged to another locale.

Mnemonics need special care. A mnemonic is often built from the sounds, puns,
rhythm, or cultural associations of its source language, so a literal
translation can be wrong or useless. Each mnemonic locale must therefore be
authored or linguistically adapted as its own language-scoped content. Reuse or
translate a mnemonic only when its mechanism genuinely survives in the target
language, and validate that explicitly. Never machine-translate mnemonic seeds
or copy an English mnemonic into another locale merely to fill a gap.

It is valid for a mnemonic to be unavailable in a language. In that case, show
an explicit missing-content state or a clearly identified fallback according to
the product rules. A fallback must never masquerade as content authored in the
selected language.

Before finishing a UI or seed change, verify that:

- all new visible strings are discoverable by the translation generator,
- every user-visible seed has an explicit language scope,
- mnemonic content has been authored or validated for that exact language.

## Mobile and tablet ship together

Every new or modified screen, component, interaction, and navigation flow must
be designed, implemented, and verified for mobile and tablet in the same change.
A UI task is not complete when only one form factor works.

Do not treat tablet as a stretched phone layout. Use the available space
deliberately, with an appropriate tablet composition such as split views,
workspace panels, or vertical navigation when they improve the experience.
Keep the mobile composition compact, touch-friendly, and easy to use with one
hand where appropriate.

For both form factors, check breakpoints, portrait and landscape behavior,
safe areas, navigation, dialogs and sheets, keyboard appearance, scrolling,
overflow cues, touch targets, transitions, and text scaling. Add or update
responsive tests whenever an affected layout or interaction can regress.
