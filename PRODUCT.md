# Product

## Register

product

## Users

Japanese learners across the whole spectrum: from someone who just wants to look a
word up (a dictionary user) to a committed learner grinding a daily review queue.
Their context is mostly mobile and short-session - a lookup wedged between tasks, a
review batch on the commute, an occasional mnemonic contribution. They are
multilingual: glosses and mnemonics come in the user's own language (English and
French today), never English-only.

The job to be done: **understand a Japanese word or kanji now, and remember it
later** - turning any dictionary lookup into scheduled memory without leaving the
tool.

## Product Purpose

jibiki is a **dictionary-first Japanese memorization tool**. Search any word, break
it into its kanji and components, and turn any entry into a spaced-repetition card
scheduled by FSRS-6.

The differentiator, and the identified market gap, is **community-contributed,
per-language visual mnemonics** - image-based, voted, and moderated. WaniKani's
mnemonics are proprietary and English-only; shared Anki decks have no localization
and uneven quality; Memrise removed its beloved "mems" and only reintroduced
sharing years later. Nobody currently offers crowdsourced, per-language,
image-based kana/kanji mnemonics with voting.

A **mode spectrum (Dictionary ↔ Learning)** lets one app serve a casual
looker-upper and a serious learner from a single set of feature flags. Success: a
lookup becomes a remembered word; the dictionary stays fully usable with no
account; contributed mnemonics accumulate and are never deleted.

## Brand Personality

**Bold, encouraging and content-first.** The interface feels like a knowledgeable
study partner with the energy of a well-made Japanese culture magazine. Characters,
readings and mnemonics remain the loudest content. Strong outlines, offset shadows
and vivid colour make actions and state changes immediately legible without adding
gamified noise.

Three words: **bold, clear, encouraging.** Emotional goal: visible momentum and
confidence, not test anxiety or childish reward-chasing. Voice remains plain,
specific and human. It celebrates real progress without hype.

**Visual direction:** Neo-pop geometry defined by `design-explorations/10-neopop.html`,
with `16-neopop-tablette.html` as the tablet layout contract and
`17-neopop-marque.html` as the identity, splash and loading contract.
The default palette combines cold off-white, near-black ink, Klein blue, acid
yellow, magenta, lime and lavender. Colour is token-based rather than hard-coded in
components. Users can switch complete palettes like an editor theme, including the
more harmonious analogue palette from `12-neopop-harmonie.html`.

The HTML exploration is the visual contract for the production UI, including its
3 px outlines, offset shadows, compact radii, colour blocks, segmented controls,
status marks, loading states and pressed translations. The primary navigation is
Dictionary, Kana, Review, Community and Profile. Kanji browsing belongs inside the
dictionary flow; drawing and pack creation belong inside the community flow.

The core mark is the `字` character inside an acid square with an ink outline and
hard offset shadow. The wordmark is `jibiki` followed by a small rotated acid
square. The web and in-app runtime splash use the full Klein or ink brand field,
centered mark and wordmark, the three-block chase loader, and the line
"dictionnaire libre, mémoire durable". Native OS launch screens intentionally use
only the solid brand field, then hand off to that responsive branded runtime
splash so no device stretches a bitmap lockup. Space Grotesk is the Latin display
family; Zen Kaku Gothic New is the Japanese display family.

The dictionary landing is also the daily return loop: search remains first, then
the due-review callout, a tappable word of the day and a compact recent-history
strip. History is local-first and useful without an account. Kana and kanji browse
screens use dense, shadow-free matrices so progress colours stay readable; hard
shadows are reserved for hierarchy and actions rather than repeated on every cell.

Japanese reference cards are reachable from both Settings and Review. Japanese
text inside them stays actionable: a kana or kanji opens its detail directly, and
longer words or sentences open a character breakdown. Scrollable surfaces expose
subtle edge fades when content continues, while pull-to-refresh uses the branded
three-block chase instead of a platform-default spinner.

Settings expose the complete display system. Light, dark and automatic appearance
can be combined with a runtime palette, currently Neo-pop and Harmonie, while the
same semantic colour roles preserve hierarchy and interaction states.

Onboarding treats prior knowledge as a real placement step rather than a binary
shortcut. Learners can start fresh, mark hiragana, katakana or all kana as known,
paste specific characters, or select canonical JLPT N5–N1 kanji. These choices
only seed personal study status; dictionary reference content remains available.

Tablet is a distinct workspace, not a stretched phone. A fixed 76 px rail remains
compact at every tablet width. At expanded widths the dictionary keeps a 340 px
result list beside a persistent detail pane. Kana keeps a 524 px matrix beside the
selected glyph detail, with an always-visible switcher for Basic, Dakuten,
Handakuten and Yōon instead of hiding variants below a nested scroll; the `Both`
mode keeps hiragana and katakana visible together in that detail pane. The home
dashboard becomes a dense three-column grid
for due reviews, word of the day, forecast, history and community. Landscape review
removes the rail and uses a 55/45 card-and-grading split on a lavender field.

## Anti-references

- **Duolingo's loud gamification** - cartoon mascots, pop-ups, streak-guilt,
  infantilizing reward loops.
- **WaniKani's rigidity** - locked pace, crimson "textbook" feel, proprietary and
  English-only.
- **Anki's dated, cluttered power-user UI.**
- **The generic "cream + AI" SaaS aesthetic** - warm-neutral beige, sand or paper
  body backgrounds, identical icon-heading-text card grids, and tiny tracked
  eyebrows above every section.

## Design Principles

1. **Content is the loudest thing.** Chrome recedes; the character, reading, and
   mnemonic dominate every screen.
2. **Dictionary-first, no wall.** The dictionary works fully with no account.
   Memorization is an invitation, never a gate.
3. **Mnemonics are training wheels that fade.** Present them as scaffolding that
   recedes as spaced retrieval takes over - vivid enough to encode fast, never
   sold as the permanent product (the retention literature is explicit that images
   alone don't keep characters in memory; SRS does).
4. **Never delete what users make.** Community mnemonics are voted and moderated,
   auto-hidden when needed, but never hard-deleted. The Memrise lesson.
5. **No artificial walls.** New cards are a per-session batch with "Study more,"
   never a "done for today" gate. The learner sets the pace, not the app.
6. **One spectrum, not three apps.** Dictionary ↔ Learning is a set of feature
   flags on one codebase, changeable anytime - not separate modes or code paths.
7. **Motion explains cause and effect.** Page changes, loading, selection and
   grading use short, GPU-friendly transitions and haptic feedback. Reduced-motion
   preferences always collapse non-essential movement.
8. **One layout system, three densities.** Phones use compact bottom navigation;
   tablets use the fixed 76 px rail and persistent working panes; expanded windows
   use the dashboard grid and master-detail layouts without stretching reading
   content.
9. **Palettes are data.** Components consume semantic colour tokens so a complete
   palette can change at runtime without altering hierarchy, contrast or meaning.

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
  Good/Easy rating already pairs colour + icon + text - keep that everywhere).
- **Multilingual by design:** content localized to the user's language, not
  English-only.
