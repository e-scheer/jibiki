# Building a Dictionary-First Japanese Memorization Tool: Analysis and Technical Blueprint

## TL;DR
- **Build it — the data and algorithms you need are free and open.** Use FSRS-6 (the modern, benchmarked successor to SM-2/Anki) for spaced repetition, the EDRDG dictionary family (JMdict, KANJIDIC2, JMnedict, KRADFILE/RADKFILE) plus KanjiVG and Tatoeba for the dictionary, and Cloudflare R2 (zero egress fees) for community image hosting. Total data-and-hosting cost at community scale can be $0–25/month.
- **Your differentiating feature — community-contributed, language-dependent visual mnemonics — is a genuine market gap.** Memrise removed its beloved community "mems" on 5 September 2022 (and only reintroduced mem sharing in 2026), WaniKani's mnemonics are proprietary and English-only, and Kanji Koohii proved crowdsourced text stories work but has no images and no localization. Nobody currently does crowdsourced, per-language, image-based kana/kanji mnemonics with voting.
- **The cognitive science is real but nuanced.** Visual/keyword mnemonics reliably boost *immediate* recall (Atkinson & Raugh's 1975 study: 72% keyword vs 46% control), but *long-term* retention gains are contested for characters specifically — which is exactly why pairing mnemonics with SRS (and high-quality, vivid images) is the correct architecture rather than mnemonics alone.

## Key Findings

1. **SRS algorithm: use FSRS-6, not SM-2 or Leitner.** FSRS is open-source, benchmarked on hundreds of millions of reviews, needs 20–30% fewer reviews for the same retention, and has ready-made libraries in every language you'd use (Rust, TypeScript, Python, Go, Dart, PHP). It has been Anki's default since v23.10 (November 2023).
2. **Dictionary data is a solved problem, legally and technically.** The EDRDG files (JMdict/EDICT, KANJIDIC2, JMnedict, KRADFILE/RADKFILE) are free for commercial use under the EDRDG license (attribution required); KanjiVG is CC BY-SA 3.0; Tatoeba sentences are CC-BY. Jitendex (a modernized JMdict) and the jmdict-yomitan project give you clean, pre-processed JSON.
3. **Kanji decomposition data exists in multiple free forms** — RADKFILE/KRADFILE (radical↔kanji mapping), KanjiVG (stroke-level component grouping), and CJK IDS (Ideographic Description Sequences) — enough to build both radical lookup and animated composition breakdowns.
4. **The mnemonic-community model has a clear cautionary tale (Memrise) and a clear proof-of-concept (Kanji Koohii).** Memrise's removal of mems caused a user revolt; Koohii's voting-ranked, shareable stories are the template to copy — but you must add images, per-language segmentation, and moderation.
5. **Free hosting for user images is genuinely viable.** Cloudflare R2's permanent free tier (10 GB storage, zero egress) is the standout; combine with Supabase (Postgres + auth free tier) and an automated NSFW filter (Cloudflare Workers AI or Google SafeSearch's free 1,000/month) for moderation.

## Details

### Feature 1 — Flashcards with Spaced Repetition (SRS)

**Comparison of the algorithms:**

- **Leitner system (1970s):** physical boxes; cards move up/down a small number of boxes. Simplest to implement, but crude — fixed intervals, no per-card memory model. Fine for a beginner MVP but you'll outgrow it.
- **SM-2 (SuperMemo 2, Piotr Woźniak, 1987):** the classic. Tracks a single per-card "ease factor" and multiplies intervals. Powered Anki from 2006 to 2023 and is still the default in RemNote. Simple, transparent, battle-tested — but rigid: everyone gets the same curve, and you must hand-tune parameters.
- **FSRS (Free Spaced Repetition Scheduler, Jarrett Ye, 2022):** a data-driven model built on the DSR (Difficulty, Stability, Retrievability) memory model. It predicts your actual probability of recall and schedules each card to hit a **desired retention** target you set (default 90%). It trains ~17–21 weights on a user's own review history. In the open-spaced-repetition benchmark — the largest public comparison, run over roughly 9,999 Anki collections and hundreds of millions of filtered reviews — FSRS-6 with per-user optimization "achieves a mean log loss of 0.344," and "in 99.6 percent of collections, FSRS-6 has a lower log loss" than SM-2; students "need 20 to 30 percent fewer reviews to maintain the same retention rate." It became Anki's default in v23.10 (November 2023).

**Verdict: FSRS-6.** It is the modern, evidence-backed choice, it's open-source, and — critically for you — it has maintained implementations you can drop in: `ts-fsrs` (TypeScript), `py-fsrs` (Python), `go-fsrs`, `rs-fsrs`/`fsrs-rs` (Rust, includes the optimizer/trainer via the Burn ML framework), plus Dart, PHP, Swift, and Java bindings — all under the Open Spaced Repetition GitHub org. Use the lightweight scheduler libraries (e.g., `ts-fsrs`) for real-time scheduling on device/server, and `fsrs-rs` when you want to *train* personalized parameters from accumulated review logs. One caveat: the canonical deployment guidance is that FSRS needs about **1,000 reviews before its per-user weights beat the default weights**, and a few thousand before the benefit is obvious; below that it uses sensible defaults and performs about like SM-2.

**Design specifics to copy:** store per-card state (stability, difficulty, last review, due date) and a full review-log table (card, timestamp, rating, elapsed time). The four-button rating scale (Again/Hard/Good/Easy) is standard. Expose "desired retention" as an advanced setting. Add a **daily new-card limit** and **load balancing** (spread due cards to avoid pile-ups) — both are proven Anki/FSRS-addon features. Offer a **vacation/suspend mode** (WaniKani has this) so reviews don't avalanche after time away.

### Feature 2 — Smart Notifications

Research is clear that reminders work *but can backfire*. A 2024 study in *npj Science of Learning* found smartphone study reminders can be a "double-edged sword" — poorly timed or excessive reminders reduce compliance. Best practices distilled from the learning-app literature:

- **Trigger on due-review count, not fixed clock times.** Because FSRS already knows when each card is due, fire a notification when a meaningful batch (e.g., ≥15 cards) comes due, ideally at the user's historically most-active time.
- **Be specific, not vague.** "Review 23 kanji now (5 min)" beats "Time to study!" Research on reminders repeatedly shows specific, action-framed reminders get acted on; vague ones get dismissed.
- **Respect timezone and context; cap frequency.** Two to three personalized pushes per week is a reasonable ceiling for education apps; let users choose reminder windows and a daily quiet period.
- **Interactive/retrieval notifications.** The MemoryMate study (*Behaviour & Information Technology*, 2024) found notifications containing an actual mini-retrieval task ("what does 食 mean?") drove engagement, and two-thirds of participants felt notifications improved memory and retention — worth prototyping as a "review from the notification" action.
- **Technically:** on web, use the Push API + Service Workers (free, no vendor needed); on mobile, Firebase Cloud Messaging (free) is the standard cross-platform transport. Compute the *what/when* server-side (or on-device from the local schedule) so you're not paying for a notification SaaS.

### Feature 3 — Configurable Modes (Dictionary ↔ Learning)

Few Japanese apps do this explicitly; most are *either* a dictionary (Jisho, Takoboto) *or* a learning system (WaniKani, Ringotan). Your onboarding-selectable spectrum is a genuine UX differentiator. Concrete design:

- **Dictionary mode:** search-first home screen, no daily review nagging, notifications off by default, "add to study" is an opt-in button on each entry. Think Takoboto/Jisho.
- **Learning mode:** review queue is the home screen, daily new-item goals, notifications on, streaks/progress front-and-center. Think WaniKani/jpdb.
- **Middle mode:** dictionary search home, but a persistent "N reviews due" badge and gentle reminders; looking up a word offers one-tap add-to-SRS.

Implement this as a small set of feature flags (home layout, notification defaults, review prominence, gamification visibility) rather than three separate code paths, and make it changeable in settings at any time. jpdb.io is a good model of a "dictionary that is also an SRS" — every dictionary lookup is a potential card, and it tracks what you know globally.

### Feature 4 — Excellent Dictionary

**Free/open data sources and their licenses:**

| Source | Content | License | Format |
|---|---|---|---|
| **JMdict/JMdict-EDICT** (EDRDG, Jim Breen) | ~200k+ words, multi-language glosses (EN, plus FR/DE/RU/NL etc.), readings, POS, cross-refs | EDRDG license (attribution; **commercial use allowed**) | XML (UTF-8); EDICT2 legacy text |
| **KANJIDIC2** (EDRDG) | ~13,000 kanji: readings, meanings, stroke count, JLPT, grade, frequency, SKIP codes, radicals | EDRDG (special conditions; attribution) | XML |
| **JMnedict** (EDRDG) | ~740k proper names | EDRDG | XML |
| **KRADFILE/RADKFILE** (EDRDG) | kanji↔radical/component decomposition (6,355 + JIS X 0212 extension) | EDRDG / CC BY-SA 3.0 | text |
| **KanjiVG** (Ulrich Apel) | per-stroke SVG, stroke order, component grouping | CC BY-SA 3.0 | SVG/XML |
| **Tatoeba** | example sentences with translations | CC-BY | TSV/API |
| **Kanjium** (mifunetoshiro) | pitch accent, frequency, variants, consolidated data | open (see repo) | data files |
| **JLPT/frequency lists** | ordering/tagging | various | data files |

Note the EDRDG license explicitly permits commercial use and bundling with closed-source software, requiring only satisfactory acknowledgement; where you profit, a donation is "suggested." Since 2023, JMdict ships a subset of ~10k JMnedict entries by default — use `JMdict_english_without_proper_names` if you load JMnedict separately, to avoid duplication.

**Don't parse raw XML yourself if you don't want to.** Pre-processed pipelines exist: **Jitendex** (a modernized, richer JMdict-derived dictionary built with Tatoeba data, by stephenmk), the **jmdict-yomitan** project (daily-built JSON for JMdict/JMnedict/KANJIDIC), and the **jamdict** Python library (ships JMdict + KanjiDic2 + KRADFILE + JMnedict in a queryable SQLite package). These save weeks of ingestion work.

**What makes Jisho and Takoboto good (copy these):** Jisho's radical-grid lookup, handwriting/draw search, wildcard search, JLPT/common-word tagging, stroke-order diagrams (from KanjiVG), and Tatoeba example sentences; Takoboto's full **offline** operation, custom word lists, pitch-accent data, and multi-script input (kanji/kana/romaji/Latin). **What's missing / where you can improve:** Jisho has no native offline mode and no personal word-list/SRS integration; most dictionaries don't connect lookups to a memory system, don't show *why* a kanji looks the way it does (mnemonic/composition), and don't localize beyond English glosses well. Your dictionary-first + SRS + mnemonic + multi-language architecture directly fills those gaps. Also consider **pitch-accent display** (Kanjium data), **inflection/deconjugation lookup** (so a user can search a conjugated verb), and **"words that contain this kanji"** cross-linking — all high-value, all buildable from the free data.

### Feature 5 — Gamified Visual Mnemonics for Kana + Kanji (the key feature)

**Existing systems and what to learn from each:**

- **"Remembering the Kana" (Heisig) & Kana Pict-o-Graphix (Michael Rowley):** picture-per-kana where the image resembles the character and cues the sound (your く-as-bird's-beak example is exactly this genre). Users report learning a syllabary in days — *but* reviewers repeatedly criticize Heisig's kana mnemonics as too vague/abstract (e.g., "foul substance oozing from the ceiling" for the お/オ sound). **Lesson: vague images fail; concrete, specific, vivid images win.**
- **WaniKani (radical → kanji → vocabulary):** the gold standard for structured mnemonic learning. It invents ~500 concrete, visual "radical" names (leaf, fins, viking, tofu) that aren't official Kangxi radicals but make better stories, then chains them: radical mnemonic → kanji meaning story → kanji reading story (continuing the same story), all on SRS. **Lesson: consistent, reusable, concrete component-keywords + narrative chaining + strict radical→kanji→vocab ordering.** Downsides to avoid: it's rigid/locked-pace, proprietary, English-only, subscription-gated.
- **Heisig's RTK & Kanji Koohii:** RTK teaches meaning-first via "primitive" stories; Koohii is the community layer (see Feature 6).
- **KanjiDamage:** orders by visual structure (similar shapes grouped, base kanji before compounds), uses deliberately crude/funny mnemonics + readings + example words.
- **The Japan Foundation's free "Hiragana/Katakana Memory Hint" apps:** government-made picture-mnemonic apps with quizzes — proof the exact model you want works and is well-received.

**The cognitive science (be honest about it):**
- The **picture superiority effect** and **dual-coding theory** (Paivio) explain why images beat words: dual visual+verbal encoding gives two retrieval routes. This is robust and heavily replicated.
- The **keyword mnemonic method** has strong evidence for *immediate* vocabulary recall. Atkinson & Raugh's foundational 1975 Russian study (*Journal of Experimental Psychology* 104:126–133) states: "On all measures the keyword method proved to be highly effective, yielding for the most critical test a score of 72 percent correct for the keyword group compared to 46 percent for the control group"; the advantage persisted at six weeks (43% vs 28%), and a companion Spanish study reported 88% vs 28%. Pressley, Levin & Delaney's 1982 review (*Review of Educational Research*) of ~50 studies found the keyword method consistently outperformed other strategies — and found **image vividness matters more than bizarreness**.
- **Crucial caveat for characters:** Wang & Thomas (1992, *Language Learning* 42(3):359–376) found that for *Chinese characters* specifically, "in no instance was there any indication that imagery-based mnemonics conferred an advantage beyond the immediate test of recall. In fact, greater forgetting was found under conditions of mnemonic learning compared to rote learning." This is the single most important nuance in your whole product thesis: **mnemonics get characters into memory fast, but they do not by themselves keep them there.** The resolution supported by the literature: (a) use vivid, picture-backed images (Wang/Thomas follow-ups found that *providing pictures* of the keyword improved long-term retention), and (b) pair mnemonics with spaced retrieval practice — which is precisely why your SRS + mnemonic combination is the right architecture, and why mnemonics should be presented as training wheels that fade as SRS takes over (WaniKani, Migaku, and Koohii users all describe mnemonics "fading into the background" after enough exposure).
- **Method of loci / memory palace:** the Magnetic Memory Method's kana approach adds spatial placement to avoid "border blur" between similar characters (シ/ツ, ソ/ン) — a smart optional feature.

**Design recommendation:** for each kana, show (1) the character, (2) a community image that visually morphs the character into the mnemonic object, (3) a one-line concrete story tying the object to the sound. For kanji, show the component breakdown (Feature 7) with a chained story. Gamify with reveal animations, "guess the reading from the picture" quiz cards, and streaks — but keep gamification toggleable (respect Dictionary mode).

### Feature 6 — Community-Contributed, Language-Dependent Content

**The Memrise cautionary tale (directly relevant):** Memrise was co-founded by Ed Cooke (a Grand Master of Memory) and built its early identity on **"mems"** — user-generated mnemonics (text and images) that others could browse, use, and rate. In November 2021, Memrise announced their removal; per its official notice, "We're now officially scheduling the removal of mems for Monday 5th September 2022." Community courses and the forum followed (forum closed 8 December 2023). Wikipedia notes the removal happened "despite overwhelmingly negative feedback"; users called it the removal of "everything that made them unique" and migrated to Anki. **Notably, "in 2026, the function of sharing mems has been reintroduced to the official Memrise courses"** — an implicit admission the feature had value. **Lessons: (1) crowdsourced mnemonics are a genuine retention/differentiation asset; (2) never delete user-contributed content people have invested in; (3) there is a proven, currently-underserved audience for exactly your feature.**

**The Kanji Koohii proof-of-concept:** Koohii lets users write RTK "stories," **share them publicly, vote on the ones that work, and copy/adapt others'** — the exact voting-ranked crowdsourcing model you want. It also **collapses offensive mnemonics by default** (a built-in moderation/quality signal). Its weaknesses to improve on: text-only (no images), single-language (English), and tied to RTK ordering.

**The moderation problem is real and must be designed in from day one.** The most-downloaded RTK Anki decks are riddled with complaints about sexist, sexual, and juvenile community mnemonics unsuitable for younger learners. Design accordingly:
- **Voting/ranking:** upvote/downvote per mnemonic; surface the top-ranked per character *per language*; let users pick a personal favorite.
- **Automated pre-screen:** run every uploaded image through an NSFW classifier (see Feature 8) before it's publicly visible; queue borderline scores for human review.
- **Community flagging + a "clean by default" filter** (Koohii's model): hide flagged/explicit content unless a user opts in; consider an all-ages default.
- **Reputation/trust levels** (Stack Overflow / Discourse style): new contributors' items are held for review; trusted contributors post directly.
- **Never hard-delete:** hide/soft-delete so contributor effort is preserved (the Memrise lesson).

**Localization — the standout insight in your vision.** Because kana mnemonics rely on *sound* association, they are inherently language-specific: く="ku" as a cuckoo's beak works in English, but a French speaker might key off "coucou," a Spanish speaker off a different word entirely. **Architect the mnemonic as a first-class localized entity**: a schema of `(character, language, image_id, story_text, votes, author, status)`, with UI that segments and ranks mnemonics *by the user's chosen mnemonic-language* (separate from UI language). This is something no existing product does, and it's your defensible moat. Seed each language with a few high-quality mnemonics (e.g., adapt the free Japan Foundation picture set and Tofugu's hiragana mnemonic chart for English) so contributors have a baseline to improve on.

### Feature 7 — Kanji Decomposition

**Data sources:**
- **RADKFILE/KRADFILE** (EDRDG): the canonical radical-decomposition dataset — RADKFILE maps each radical/component to the kanji containing it (for multi-radical lookup); KRADFILE is the inverse (kanji → its components). Covers 6,355 JIS X 0208 kanji plus a JIS X 0212 extension (to ~13,108 characters via kradfile2). A clean **Unicode/JSON conversion** exists (hoffmannjp/krad-unicode: 253 components, CC BY-SA 3.0) so you don't fight the legacy substitute-character encoding.
- **KanjiVG** (CC BY-SA 3.0): each SVG groups strokes by component/element and tags radicals — ideal for *animated* decomposition where components highlight in sequence and for stroke-order practice. The "Kan-G" project offers simplified, dark-mode-ready, CDN-hosted KanjiVG SVGs.
- **CJK IDS (Ideographic Description Sequences):** describe *structural layout* (⿰ left-right, ⿱ top-bottom, etc.) — e.g., 話 = ⿰言舌. Repos: cjkvi/cjkvi-ids, hfhchan/ids, CHISE. Use IDS when you want to render *how* components are spatially arranged, not just which ones are present.
- **Kanjium** consolidates components/IDS/frequency in one place.

**How best-in-class apps visualize composition (copy these):**
- **WaniKani:** strict radical→kanji→vocabulary hierarchy with named components and chained stories.
- **jpdb.io:** *dynamically* decomposes each vocabulary word into kanji, and each kanji into components, teaching bottom-up so "the next thing you're learning always builds upon what you've already learned" (learning 食べる pulls in 食 → 人 + 良 → …, ~7 prerequisite cards). This dependency-graph approach is excellent for a tool with no fixed lesson order.
- **Kanji Alive / Kanji Study (Chase Colburn):** rich per-kanji component breakdowns, stroke order, radical meanings.

**Design recommendation:** for each kanji, render the component tree (from KRADFILE/IDS), label each component with its meaning/keyword and its *community mnemonic image*, animate the stroke-by-stroke build (KanjiVG), and show the composition story. Make each component tappable to become its own study item (jpdb-style prerequisite graph). Because a kanji = multiple components each with their own drawing, your "decompose into multiple drawings" vision maps directly onto composing the component images into a single scene — the classic method-of-loci story.

### Feature 8 — Free Hosting / Upload for Community Images

**Object storage (the images themselves):**
- **Cloudflare R2 — top recommendation.** Per Cloudflare's official R2 pricing docs, the permanent free tier is **10 GB-month Standard storage, 1,000,000 Class A (write) ops/month, 10,000,000 Class B (read) ops/month**, and — uniquely — "Egressing directly from R2… does not incur data transfer (egress) charges and is free." Paid overage is only $0.015/GB-month. Zero egress is the killer feature for a community image app where the same mnemonic images are served repeatedly. (Note: a credit card is required to enable R2 even on the free tier.) 10 GB ≈ tens of thousands of web-optimized WebP mnemonic images.
- **Backblaze B2:** 10 GB free storage; egress is free when served via the Bandwidth Alliance/Cloudflare. Solid alternative/backup target.
- **Supabase Storage:** ~1 GB free file storage (tighter); best if you're already using Supabase for DB/auth and want one stack. Serve via its CDN so downloads don't hit the small egress cap.
- **Firebase Storage:** ~5 GB free; easy on mobile but NoSQL-oriented and egress-metered.
- **Cloudflare Images:** paid (per-image + per-delivery) but bundles resize/optimize/variants; consider only if you want managed transformations rather than doing it yourself.
- **Avoid** relying on imgur/free image hosts for a real app — no SLA, ToS risk, and they can vanish.

**Database + backend (metadata, votes, users):**
- **Supabase (recommended):** the 2026 free tier gives a real Postgres DB (500 MB), 50,000 monthly active users for auth, 5 GB egress, Row-Level Security, and Edge Functions — a relational model that fits your `(character, language, mnemonic, votes, author)` schema far better than Firestore. **Watch-outs:** free projects **pause after 7 days of inactivity** (mitigate with a cron/GitHub Actions ping or UptimeRobot), no automatic backups (script your own to R2), and a 500 MB DB ceiling. Pro is $25/mo when you outgrow it.
- **Firebase (alternative):** more generous initial storage/bandwidth and great mobile SDKs, but per-operation billing "punishes successful apps," and NoSQL is a worse fit for ranked, relational mnemonic data.
- Because you're technically skilled, **self-hosting Postgres + a Rust/Node API + R2** on a cheap VPS is entirely viable and keeps costs flat and predictable.

**Moderation pipeline (essential for public image uploads):**
- **Cloudflare Workers AI** can run image-classification inference *at the edge* on upload — Cloudflare publishes a reference architecture that does exactly this (Workers AI moderation + R2 storage + signed URLs). This keeps moderation inside your free/cheap Cloudflare stack.
- **Google Cloud Vision SafeSearch:** free for the first 1,000 units/month, then ~$1.50/1,000 — a cheap, reliable baseline (adult/violence/racy/medical/spoof).
- **NudeNet** (open-source, self-hostable) if you want zero external calls — but note its AGPL-3.0 license and 2023-era model.
- **Recommended flow:** on upload → auto-classify → auto-approve low-risk, auto-reject high-confidence explicit, queue mid-range for human review → publish → community flagging as a backstop → all changes soft-delete only. Always resize/re-encode uploads to WebP/AVIF server-side (strip EXIF, cap dimensions) before storing — saves storage and egress, and strips location metadata.

### Cross-cutting: Learning Order

There is **no single best order** — offer several and let the user pick (align with their onboarding mode/goal):
- **Frequency-based:** fastest path to reading real text; best for the "I want to read" learner.
- **JLPT levels (N5→N1):** best if the user targets the proficiency test or "words I'll actually use"; note there's no *official* per-level kanji list, so you'll use a community-standard mapping.
- **Grade/school order (教育漢字/Jōyō):** mirrors how Japanese children learn; intuitive but sometimes teaches visually-simple-but-rare kanji before common ones.
- **Heisig/RTK order:** builds by component complexity (simple shapes → compounds) — best for pure memorization efficiency and pairs naturally with mnemonics.
- **jpdb-style dynamic/dependency order:** no preset list — the next item is chosen by what a target word/text requires, taught bottom-up. This is arguably the best fit for a *dictionary-first tool*, since it lets a user paste text or pick a word and learn exactly the prerequisites.

### Cross-cutting: Clever features worth stealing
- **jpdb:** paste any text → auto-extract vocabulary → learn prerequisites first; "show only example sentences where you already know every other word"; media/deck recommendations tuned to known vocabulary.
- **Ringotan (free):** teaches kanji by *writing* with input-detection, fading stroke hints from tracing → memory; WaniKani API sync; lets you pick a starting level and cap new kanji/day; multiple textbook orderings. Writing recall is a powerful, under-served mode.
- **WaniKani:** SRS stage names (Apprentice→Guru→Master→Enlightened→Burned) as motivating progress metaphors; vacation mode; user synonyms.
- **Renshuu / Bunpro:** granular progress tracking and self-adjusting queues.
- **Kanji Study (Chase Colburn):** superb per-kanji reference + custom study sets + writing challenges — a great model for the "reference meets study" middle mode.
- **Anki shared decks:** the import/export ecosystem — supporting **Anki-compatible export** of a user's cards lowers switching costs and builds goodwill.

## Recommendations

**Stage 1 — MVP (prove the core loop):**
1. Ship the **dictionary** first, from Jitendex/jmdict-yomitan JSON or jamdict: word/kana/kanji search, radical-grid + wildcard lookup, KanjiVG stroke order, Tatoeba examples. This is immediately useful and needs no accounts.
2. Add **FSRS-6 SRS** via `ts-fsrs`/`py-fsrs` with an "add to study" button on every entry. Store full review logs from day one (you'll need them to train personalized FSRS weights later).
3. Add the **onboarding mode selector** (Dictionary / Middle / Learning) as feature flags.
4. Seed **kana mnemonics** in English (adapt the free Japan Foundation set / Tofugu chart) with static, high-quality images bundled in the app — no upload infrastructure needed yet.

**Stage 2 — Memorization depth:**
5. Add **kanji decomposition** (KRADFILE/IDS component trees + animated KanjiVG builds) and the radical→kanji→vocab chained-story UI.
6. Add **local/on-device notifications** driven by the FSRS due-schedule, specific and capped (start opt-in, one reminder at the user's active time).

**Stage 3 — Community (the moat):**
7. Stand up **Cloudflare R2 (images) + Supabase or self-hosted Postgres (metadata/auth/votes)**.
8. Ship **language-segmented, voted, image-based mnemonics** with a moderation pipeline (auto NSFW screen → human queue → community flagging → soft-delete only) and reputation tiers **before** you open uploads publicly.
9. Seed each new mnemonic-language with baseline content so contributors improve rather than start from nothing.

**Benchmarks / thresholds that change the plan:**
- **Cross ~1,000 reviews per active user →** enable per-user FSRS parameter training (`fsrs-rs`); below that, keep default weights.
- **Approach 10 GB R2 / 500 MB Supabase DB / 5 GB egress →** enforce stricter image compression and pagination first; upgrade to R2 paid ($0.015/GB) and Supabase Pro ($25/mo) only when optimization is exhausted.
- **If community uploads exceed human moderation capacity →** raise the auto-approve confidence threshold and lean on reputation tiers; add a paid moderation API tier (Google SafeSearch beyond 1,000/mo) only if volume justifies it.
- **If a mnemonic language has fewer than ~20 quality items →** keep it seeded/curated rather than fully open, to protect first-impression quality.

## Caveats
- **Long-term retention from mnemonics alone is genuinely contested for characters.** Wang & Thomas (1992) found imagery mnemonics gave no lasting advantage over rote for Chinese characters, and sometimes more forgetting. Treat mnemonics as fast on-ramps whose gains are *realized and protected by the SRS*, and prefer vivid, picture-backed images (which the follow-up literature found does help long-term). Don't over-promise "learn kanji forever with pictures."
- **The generation-effect intuition is only partly supported.** For keyword mnemonics specifically, self-generated keywords often do *not* beat provided ones (Atkinson & Raugh themselves noted supplied keywords worked better; Shapiro & Waters 2005 found vividness mattered more than authorship; Campos et al. 2004 even found *peer-generated* keywords beat self-generated for high-vividness words). Implication: your community/expert-provided top-ranked mnemonics are legitimately valuable, not inferior to self-made ones — but let users write their own too.
- **License compliance is mandatory:** display EDRDG attribution (with the specified URLs), propagate **CC BY-SA 3.0** for anything derived from KanjiVG or RADKFILE (share-alike may affect how you license *derived* mnemonic assets), and CC-BY attribution for Tatoeba. These allow commercial use, but the attribution/share-alike terms are binding.
- **Free-tier pauses and caps bite unexpectedly:** Supabase's 7-day inactivity pause will take down a low-traffic community app if unmitigated; set up a keep-alive ping and your own backups (no free-tier backups) from launch.
- **The FSRS efficiency figures come from large-scale benchmark analysis of logged Anki data, not a randomized controlled trial of live learners.** It is the best available evidence and reflects ~9,999 collections, but should be described as a benchmark result rather than clinical proof.
- **A few numbers vary across sources** (e.g., Supabase's stated free file-storage and egress figures range from 1–5 GB and 2–5 GB across write-ups, reflecting recent plan changes); verify current limits against the official Supabase and Cloudflare pricing pages at build time, as free tiers change.
