# Product

## Register

product

## Users

Japanese learners across the whole spectrum: from someone who just wants to look a
word up (a dictionary user) to a committed learner grinding a daily review queue.
Their context is mostly mobile and short-session — a lookup wedged between tasks, a
review batch on the commute, an occasional mnemonic contribution. They are
multilingual: glosses and mnemonics come in the user's own language (English and
French today), never English-only.

The job to be done: **understand a Japanese word or kanji now, and remember it
later** — turning any dictionary lookup into scheduled memory without leaving the
tool.

## Product Purpose

jibiki is a **dictionary-first Japanese memorization tool**. Search any word, break
it into its kanji and components, and turn any entry into a spaced-repetition card
scheduled by FSRS-6.

The differentiator, and the identified market gap, is **community-contributed,
per-language visual mnemonics** — image-based, voted, and moderated. WaniKani's
mnemonics are proprietary and English-only; shared Anki decks have no localization
and uneven quality; Memrise removed its beloved "mems" and only reintroduced
sharing years later. Nobody currently offers crowdsourced, per-language,
image-based kana/kanji mnemonics with voting.

A **mode spectrum (Dictionary ↔ Learning)** lets one app serve a casual
looker-upper and a serious learner from a single set of feature flags. Success: a
lookup becomes a remembered word; the dictionary stays fully usable with no
account; contributed mnemonics accumulate and are never deleted.

## Brand Personality

**Warm and encouraging, on a clean, content-first base.** The interface should feel
like a knowledgeable, supportive study partner: confident and uncluttered — the
content (the character, the reading, the mnemonic) is the loudest thing — but
warmed by an accent colour, typography, and imagery rather than by decoration or
gamified noise.

Three words: **warm, encouraging, uncluttered.** Emotional goal: steady momentum
and quiet confidence, not test anxiety and not childish reward-chasing. Voice:
plain, specific, human; it celebrates real progress without hype.

**Visual direction (resolve the specifics in DESIGN.md):** repositioning *warmer*
than the current cold "Instagram" blue-on-white system. The warmth is carried by a
**warm accent** — the heritage vermilion (朱, the red-orange of torii gates and
hanko seals) is the natural candidate for a Japanese tool — sitting on a
true-neutral base. Warmth must **not** come from the body background (see
anti-references).

## Anti-references

- **Duolingo's loud gamification** — cartoon mascots, pop-ups, streak-guilt,
  infantilizing reward loops.
- **WaniKani's rigidity** — locked pace, crimson "textbook" feel, proprietary and
  English-only.
- **Anki's dated, cluttered power-user UI.**
- **The generic "cream + AI" SaaS aesthetic** — warm-neutral beige/sand/paper body
  backgrounds, identical icon-heading-text card grids, tiny all-caps tracked
  eyebrows above every section. Warmth in jibiki never comes from a cream
  background.

## Design Principles

1. **Content is the loudest thing.** Chrome recedes; the character, reading, and
   mnemonic dominate every screen.
2. **Dictionary-first, no wall.** The dictionary works fully with no account.
   Memorization is an invitation, never a gate.
3. **Mnemonics are training wheels that fade.** Present them as scaffolding that
   recedes as spaced retrieval takes over — vivid enough to encode fast, never
   sold as the permanent product (the retention literature is explicit that images
   alone don't keep characters in memory; SRS does).
4. **Never delete what users make.** Community mnemonics are voted and moderated,
   auto-hidden when needed, but never hard-deleted. The Memrise lesson.
5. **No artificial walls.** New cards are a per-session batch with "Study more,"
   never a "done for today" gate. The learner sets the pace, not the app.
6. **One spectrum, not three apps.** Dictionary ↔ Learning is a set of feature
   flags on one codebase, changeable anytime — not separate modes or code paths.

## Accessibility & Inclusion

Target: **WCAG 2.2 AA**, including the gaps surfaced by the technical audit.

- **Contrast:** all body text ≥ 4.5:1, large/bold text ≥ 3:1. No muted-gray-on-
  white body text; placeholders held to the same 4.5:1.
- **Reduced motion:** respect the OS setting (`MediaQuery.disableAnimations`) with
  crossfade/instant alternatives for the card flip, the swipe fling, and page
  transitions.
- **Screen readers:** custom interactive controls (the `GestureDetector`-based
  grade buttons, kana cells, carousel controls) exposed via `Semantics(button:)`;
  network images carry a `semanticLabel` or are marked decorative.
- **Colour independence:** never encode meaning by colour alone (the Again/Hard/
  Good/Easy rating already pairs colour + icon + text — keep that everywhere).
- **Multilingual by design:** content localized to the user's language, not
  English-only.
