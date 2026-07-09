# WaniKani - analyse de la valeur ajoutée & écarts jibiki (juillet 2026)

Facts vérifiés sur pages publiques (détail et URLs : transcript de recherche du
2026-07-09 ; chiffres clés re-vérifiables sur wanikani.com et
knowledge.wanikani.com).

## 1. D'où vient réellement la valeur de WaniKani

| Actif | Détail | Poids |
|---|---|---|
| **Contenu mnémonique écrit main** | ~485 composants nommés, ~2 074 kanji, ~6 501 vocab - chaque item a une histoire de **sens** ET une histoire de **lecture** (大 = un type qui porte un t-shirt « **Tie Dye** » → たい/だい) | ⭐ le cœur. Des années de rédaction, non réplicable en scrapant (payant + copyrighté) |
| **Chaînage structurel** | composant (Guru) → débloque le kanji → débloque le vocab qui **recycle la lecture**. On ne voit jamais un kanji dont on ne connaît pas les pièces ; le vocab existe *pour* cimenter les lectures | ⭐ la pédagogie |
| **Boucle de motivation** | 60 niveaux, tiers nommés (Pleasant→Reality), gating « 90 % des kanji du niveau à Guru », stages nommés Apprentice→**Burned**, fast levels, record communautaire (344 j), dashboard (2025) | fort - c'est ce qui fait « tenir un an » |
| **Qualité AV** | 2 voix humaines (vocab uniquement), 3 phrases de contexte écrites main par vocab | moyen |
| **Écosystème** | API v2 ouverte (lecture **et écriture** → clients tiers complets), userscripts (wkof), wkstats, Tsurukame/Flaming Durtles, forum Discourse central | fort pour la rétention des power users |
| **Modèle** | $9/mois · $89/an · $299 lifetime (soldé $199), gratuit niveaux 1-3, **pas d'app officielle mobile** | - |

SRS : intervalles **fixes** 4 h → 8 h → 1 j → 2 j → 1 sem → 2 sem → 1 mois →
4 mois → Burned (plus jamais revu). Pénalité d'erreur par paliers. C'est du
pré-FSRS assumé.

## 2. Ce que jibiki a déjà - et fait parfois mieux

- **SRS** : FSRS-6 avec optimisation par utilisateur vs intervalles fixes ; ~20-30 % de reviews en moins à rétention égale ; « Burned » (arrêt définitif) est contestable, FSRS continue d'espacer à l'infini.
- **Rythme libre** : leur plainte n°1 (« locked pace », toujours vraie en 2026, pas de test de placement, 344 j minimum incompressibles) est notre force - batch par session + « Study more », `mark-known` pour sauter ce qu'on sait, pas de gating.
- **Kana** : WK ne les enseigne pas du tout (prérequis). Nous : chart complet, mnémoniques dessinés, multilingues, jeux.
- **Multi-langue by design** : WK est « only available in English » (KB officielle, 2026, sans plan d'évolution). Notre schéma `(character, language)` est le moat - confirmé par la lignée Japan Foundation.
- **Dictionnaire complet intégré offline** : 217k mots / 13 108 kanji / pitch / noms propres / exemples vs leurs 6,5k vocab fermés. WK n'est pas un dictionnaire.
- **Communauté** : mnémoniques contribués, votés, par langue, avec choix par caractère - chez WK le contenu est figé et propriétaire (seuls des synonymes/notes perso).
- **Tracés animés** KanjiVG natifs (WK : via userscripts seulement) ; radical-grid de recherche ; export Anki ; 4 jeux d'étude ; offline total ; achat unique.
- **Audio** : TTS on-device = toutes les entrées, offline, 0 coût - moins chaleureux que leurs 2 voix humaines mais couvre 100 % du contenu.

## 3. Les écarts (ce qui nous manque vraiment)

| # | Écart | État jibiki | Ce que fait WK |
|---|---|---|---|
| 1 | **Histoires mnémoniques kanji** | **0** histoire (45 composants nommés seulement) | sens + lecture pour 2 074 kanji |
| 2 | **Mnémoniques de LECTURE** | rien | ancre anglaise par on/kun - la partie la plus dure |
| 3 | **Ordre dépendance-d'abord** | decks plats (ordre d'enrôlement) | composant → kanji → vocab strictement |
| 4 | **Vocab qui cimente** | `kanji_words` affiché en détail, pas relié au SRS | vocab enseigné pour recycler la lecture du kanji |
| 5 | **Boucle de motivation** | streak + win overlays | stages nommés, niveaux, tiers, jalons, dashboard |
| 6 | **Phrases de contexte** | Tanaka en `LIKE` (non gradué, parfois bruité) | 3 phrases écrites main par vocab |
| 7 | **Recall inverse (L1→JP)** | non | non plus ! (KaniWani = tiers) - opportunité |
| 8 | **Vacation mode** | non (FSRS encaisse les pauses, mais le backlog s'empile) | gel exact des timers |
| 9 | **API/écosystème** | export Anki | API v2 R/W, userscripts, stats |

Donnée clé pour l'écart n°1-3 : nos **45 composants nommés couvrent déjà
entièrement 86 des 245 kanji N5/N4** (et partiellement 126). Étendre le
nommage à ~90-100 composants couvre l'essentiel du périmètre débutant.

## 4. Recommandations priorisées

1. **Tri topologique des decks kanji/mots** (petit, pur code) : au `enrollDeck`/queue, ordonner par disponibilité des composants (kanji dont tous les composants sont connus d'abord), et mots après leurs kanji - l'effet « je construis toujours sur du connu » de WK/jpdb, sans gating rigide. Données déjà locales (`kanji_components`, `kanji_words`).
2. **Seed d'histoires de sens N5** (moyen) : ~80 kanji × en/fr, chaînant les composants nommés de `content/mnemonic_briefs.json` - pipeline briefs → relecture humaine → seed, puis N4.
3. **Histoires de LECTURE par langue** (moyen-gros, différenciateur mondial) : ancres on/kun dérivées par langue (たい : EN "tie", FR « taille »…). Personne ne le fait hors anglais.
4. **Vocab post-graduation** (petit) : un kanji passe en review → proposer 2-3 mots courants de `kanji_words` en un tap (« cimente-le »).
5. **Stages nommés + progression** (petit-moyen) : mapper l'état FSRS sur des stages affichables (semis → pousse → arbre… à définir), jalons de deck, page progression. Ne pas copier « Burned ».
6. **Exemples filtrés par vocabulaire connu** (moyen) : n'afficher que les phrases Tanaka dont tous les autres mots sont `known` (nos `states` locaux le permettent - l'astuce jpdb citée par DEEP_SEARCH).
7. **Recall inverse** (petit-moyen) : mode de jeu L1→JP sur les jeux existants - combler le trou que WK laisse aux apps tierces.
8. **Vacation/étalement** (petit) : option « étaler le backlog sur N jours » au retour de pause.

Non prioritaire : audio humain (TTS couvre, coût élevé), API publique (plus
tard), 60 niveaux gamifiés (contraire à notre philosophie rythme libre - les
jalons de deck suffisent).
