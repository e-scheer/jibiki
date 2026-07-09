# jibiki - store metadata

Everything needed to publish jibiki on Google Play and the App Store, in English
and French (the app ships both). Character limits are noted per field.

- **App name:** jibiki
- **Bundle / application id:** `app.jibiki.jibiki`
- **Category:** Education
- **Content rating:** Everyone / 4+ - note **user-generated content** (community
  mnemonics are moderated: voting, reporting, auto-hide, never hard-deleted).
- **Website / support:** e.scheer@deuse.be
- **Brand:** vermilion 朱 (`#D4402A`), the wordmark glyph is 字. Icon = white 字 on
  the vermilion seal.

---

## Google Play

### English (en-US)

**Title** (≤30): `jibiki: Japanese dictionary`

**Short description** (≤80):
`Look up Japanese, then remember it - with community visual mnemonics and FSRS.`

**Full description** (≤4000):
```
jibiki is a dictionary-first way to learn Japanese: look a word up, break it into
its kanji and kana, and turn any entry into a spaced-repetition card - without
ever leaving the app.

What makes jibiki different is its community, per-language visual mnemonics: real
drawings that make a character stick, voted on and localized to your language
(English and French today). It's the feature the big apps dropped or never had.

• Dictionary-first - search any word by kanji, kana, romaji or meaning. Full
  hiragana and katakana charts, JLPT kanji, radicals, example sentences and
  animated stroke order.
• Remember it with FSRS-6 - the modern spaced-repetition scheduler (fewer reviews
  for the same retention), studied by swipe cards or multiple-choice quiz.
• Community visual mnemonics - browse image mnemonics per character in your
  language, upvote the best, or draw your own and share a pack.
• Learn your way - a Dictionary ↔ Learning spectrum: use it as a pure dictionary,
  or put the review queue front and centre. No "done for today" walls.
• Bootstrap your level - mark the kana and kanji you already know in one tap, so
  study starts where you are.
• Yours to keep - Anki-compatible export of your whole deck.

The dictionary works with no account. Study, mnemonics and sync need a free login.

Japanese dictionary data © EDRDG (JMdict, KANJIDIC2, KRADFILE), used under the
EDRDG licence. Stroke-order data from KanjiVG (CC BY-SA 3.0). Example sentences
from Tatoeba (CC-BY).
```

### Français (fr-FR)

**Titre** (≤30): `jibiki : dictionnaire japonais`

**Description courte** (≤80):
`Cherchez un mot japonais, puis retenez-le : mnémoniques visuelles et FSRS.`

**Description complète** (≤4000):
```
jibiki apprend le japonais en partant du dictionnaire : cherchez un mot,
décomposez-le en kanji et kana, et transformez n'importe quelle entrée en carte
de répétition espacée, sans jamais quitter l'app.

La différence jibiki, ce sont ses mnémoniques visuelles communautaires, par
langue : de vrais dessins qui font retenir un caractère, votés et localisés dans
votre langue (français et anglais aujourd'hui). La fonctionnalité que les grandes
apps ont retirée ou n'ont jamais eue.

• Le dictionnaire d'abord - cherchez par kanji, kana, romaji ou sens. Tables
  complètes des hiragana et katakana, kanji JLPT, radicaux, phrases d'exemple et
  ordre des traits animé.
• Retenez avec FSRS-6 - le planificateur de répétition espacée moderne (moins de
  révisions à mémorisation égale), en cartes à swiper ou en quiz à choix.
• Mnémoniques visuelles communautaires - parcourez les mnémoniques par caractère
  dans votre langue, votez pour les meilleures, ou dessinez les vôtres et
  partagez un pack.
• À votre rythme - un spectre Dictionnaire ↔ Apprentissage : dictionnaire pur, ou
  file de révision au premier plan. Pas de mur « terminé pour aujourd'hui ».
• Démarrez à votre niveau - marquez d'un geste les kana et kanji que vous
  connaissez déjà.
• Vos données - export de tout votre paquet, compatible Anki.

Le dictionnaire fonctionne sans compte. Étude, mnémoniques et synchro demandent
une connexion gratuite.

Données de dictionnaire © EDRDG (JMdict, KANJIDIC2, KRADFILE), sous licence EDRDG.
Ordre des traits : KanjiVG (CC BY-SA 3.0). Phrases d'exemple : Tatoeba (CC-BY).
```

---

## App Store (iOS)

### English (en-US)

**Name** (≤30): `jibiki`
**Subtitle** (≤30): `Japanese dictionary & SRS`
**Promotional text** (≤170):
`Learn Japanese from the dictionary out: look a word up, break it into kanji, and remember it with community visual mnemonics.`
**Keywords** (≤100, comma-separated):
`japanese,kanji,kana,hiragana,katakana,dictionary,JLPT,flashcards,SRS,mnemonics,FSRS,jisho,study`
**Description** (≤4000): reuse the Play full description above.

### Français (fr-FR)

**Nom** (≤30): `jibiki`
**Sous-titre** (≤30): `Dictionnaire japonais & SRS`
**Texte promotionnel** (≤170):
`Apprenez le japonais depuis le dictionnaire : cherchez un mot, décomposez-le en kanji, et retenez-le avec des mnémoniques visuelles.`
**Mots-clés** (≤100):
`japonais,kanji,kana,hiragana,katakana,dictionnaire,JLPT,cartes,SRS,mnémoniques,FSRS,jisho,étude`
**Description** (≤4000): réutiliser la description complète Play ci-dessus.

---

## Asset checklist (to produce before submission)

- **App icon:** generated - `assets/icon/icon.png` (1024², white 字 on vermilion),
  declined to all densities + Android adaptive/monochrome + iOS + web via
  `flutter_launcher_icons`.
- **Feature graphic** (Play, 1024×500): not yet - vermilion field, 字 wordmark left,
  a review card + mnemonic drawing right.
- **Screenshots** (phone, 2–8): Explore/search, kana chart (with "I know these"),
  a swipe review card, a kanji breakdown with stroke order, a community mnemonic
  feed, the draw studio. Capture in both light and dark.
- **Privacy:** collects email (account) and user-generated content (mnemonic text
  + images; EXIF/GPS stripped on upload). No third-party ad tracking.
</content>
