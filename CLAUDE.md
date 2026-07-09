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
