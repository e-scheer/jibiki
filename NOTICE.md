# Third-party data & licenses

jibiki uses free, openly-licensed Japanese language data. These licenses require
attribution (and, for CC BY-SA sources, share-alike on derivatives). This notice
satisfies the acknowledgement requirement; the app also shows the EDRDG credit in
Settings.

## EDRDG — JMdict, KANJIDIC2, KRADFILE/RADKFILE

- © Electronic Dictionary Research and Development Group (EDRDG), used under the
  [EDRDG License](https://www.edrdg.org/edrdg/licence.html).
- JMdict/EDICT and KANJIDIC are the property of the EDRDG and are used in
  conformance with the Group's licence. Commercial use is permitted with
  attribution.
- Files: `JMdict` (words, multi-language glosses), `KANJIDIC2` (kanji readings,
  meanings, stroke counts, JLPT/grade/frequency), `KRADFILE`/`RADKFILE`
  (kanji ↔ component decomposition).
- Importers: `server/dictionary/management/commands/import_{jmdict,kanjidic,kradfile}.py`.

## KanjiVG — stroke-order data (used)

- © Ulrich Apel / the [KanjiVG project](https://github.com/KanjiVG/kanjivg),
  licensed **CC BY-SA 3.0**. jibiki ingests the per-stroke SVG paths to animate
  stroke order (`import_kanjivg`; the bundled demo kanji ship their paths in
  `dictionary/seed_strokes.py`). Derivatives of these stroke assets must propagate
  **CC BY-SA 3.0** — the app credits KanjiVG and this share-alike term is binding.

## Tatoeba (when example sentences are added)

- Example sentences from the [Tatoeba Project](https://tatoeba.org), licensed
  **CC-BY 2.0 FR**. Attribution required.

## FSRS

- The scheduler implements **FSRS-6** (Free Spaced Repetition Scheduler), an
  open algorithm by the Open Spaced Repetition group. jibiki ships an independent
  implementation in `server/srs/fsrs.py`.

---

Community-contributed mnemonics and images are owned by their authors; by
contributing, users grant jibiki a license to display and distribute them within
the app. Content is never hard-deleted (moderation soft-hides), per the Memrise
lesson in `DEEP_SEARCH.md`.
