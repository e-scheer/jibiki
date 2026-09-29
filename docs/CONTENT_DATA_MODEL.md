# Format de consolidation Jibiki

Proposition du 29 septembre 2026. Deux types de données à produire pour le [chantier ponctuel](CONTENT_PRODUCTION_PLAN.md). Ce contrat de fichiers décrit le contenu à conserver ; il ne demande pas une nouvelle table pour chaque bloc. L'adaptation vers les modèles existants vient avec l'import.

## 1. Fiche de dictionnaire

Une fiche représente une entité japonaise ou un sujet pédagogique déjà présent dans l'application. Ses faits communs sont stockés une fois, ses textes sont déclinés en anglais, français et néerlandais. Les sujets de grammaire et les textes culturels gardent leur structure propre ; ils ne sont pas artificiellement transformés en entrées de vocabulaire.

| Champ | Contenu |
| --- | --- |
| `id` | Identité stable de la fiche, rattachée à l'identité actuelle quand elle existe |
| `kind` | `word`, `kanji`, `kana`, `component`, `name`, `reference_topic` ou `culture_card`, selon le contenu |
| `japanese` | Données japonaises structurées propres à ce type, voir ci-dessous |
| `senses` | Liste des sens distincts ; chaque sens a son identifiant, ses restrictions, ses sources et ses textes EN/FR/NL |
| `explanations` | Textes localisés d'usage, de grammaire, d'origine ou de distinction ; chaque explication précise son sujet et ses sources |
| `examples` | Japonais, lecture disponible, traductions disponibles et liens vers les sens concernés |
| `relations` | Liens vers composants, caractères, mots liés, variantes ou formes à distinguer, avec type de relation |
| `media` | Références des tracés, sons et autres médias disponibles, avec leur fonction et leur source |
| `sources` | Références vers les enregistrements d'origine utilisés, suffisamment précises pour les retrouver |

Le bloc `japanese` utilise une structure par type, pas un gros texte libre :

- **Mot :** formes écrites et lectures, restrictions entre elles, catégories grammaticales, conjugaison si disponible, accents par lecture, fréquence avec sa source, niveaux avec leur système.
- **Kanji :** caractère, on'yomi, kun'yomi, nanori, nombre et ordre des traits, composants et positions disponibles, radical de classement, variantes, grade, fréquence et niveaux sourcés.
- **Kana :** caractère, écriture hiragana/katakana, lecture, romanisation, catégorie, ligne, variantes ou signes associés, tracés disponibles. Les petits kana et combinaisons gardent leurs règles particulières.
- **Composant :** identité Unicode ou graphique, formes, nom japonais si connu, fonction de classement ou de décomposition, relations aux kanji. Une association mnémotechnique n'est pas une étymologie.
- **Nom propre :** écritures, lectures, catégories et restrictions disponibles.

Un sens contient : `id`, `source_refs`, `restrictions`, `labels` et `texts`. Dans `texts.en`, `texts.fr` et `texts.nl`, conserver des `glosses` courtes, une `definition` lorsque nécessaire et des `usage_notes` utiles. Une glose courte ne doit pas faire disparaître une distinction que les sources expliquent.

Les explications utilisent elles aussi des blocs localisés. Une explication historique, une note grammaticale et une différence d'usage restent identifiables séparément. Les exemples gardent leur japonais source ; leur traduction et leur rattachement aux sens peuvent être harmonisés.

### Règles de fusion

Deux définitions équivalentes deviennent un sens commun enrichi par leurs détails complémentaires. Deux usages différents deviennent deux sens. Une source plus générale et une source plus précise ne sont pas nécessairement contradictoires ; l'agent doit conserver cette distinction dans le résultat.

Les contradictions, rattachements incertains et informations impossibles à placer vont dans un fichier de travail `needs_review.jsonl`, associé à la fiche. Ils ne disparaissent pas. Si une information utile révèle un manque du format, on ajoute le champ correspondant avant le traitement massif, plutôt que de l'enterrer dans une note fourre-tout.

Une langue manquante reste absente. L'anglais ne remplit pas le champ français ou néerlandais. Les fichiers de sortie sont le contenu Jibiki consolidé ; les originaux restent disponibles séparément.

### Corriger sans infrastructure supplémentaire

Un même identifiant de sens ou de section relie les formulations EN/FR/NL. Une correction de traduction touche sa langue. Une correction du fait ou du sens exige de revoir les formulations de toutes les langues concernées. Cela se fait ponctuellement, avec un script ou un agent appelé ici, sans nouvelle table de tâches ou service de synchronisation éditoriale.

Une explication générale peut avoir son propre identifiant et être référencée depuis plusieurs fiches. Par exemple, la règle d'une particule ne doit pas devenir deux textes indépendants et contradictoires dans le guide grammatical et dans la fiche kana. Les formulations d'affichage peuvent être plus courtes, mais leur relation au même sujet doit rester identifiable.

## 2. Proposition mnémotechnique

Une proposition représente une association pédagogique dans **une langue**, avec sa phrase et son éventuel dessin. Plusieurs propositions peuvent viser la même entrée. Elles partagent le même format pour le set standard et les contributions communautaires.

| Champ | Contenu |
| --- | --- |
| `id` | Identifiant de la proposition |
| `target` | Type et clé de l'entrée ; sens ou lecture exacte si concernés ; objectifs : forme, sens, lecture |
| `language` | Langue dans laquelle l'association fonctionne |
| `story` | Phrase ou histoire, éventuellement absente pour une idée purement visuelle |
| `anchor` | Mot et segment sonore utilisés, son japonais visé, explication du lien ; absent pour une idée sans jeu phonétique |
| `visual` | Idée de dessin, correspondance avec les parties du glyphe si déjà étudiée, référence d'image disponible |
| `origin` | Source extraite, seed historique, proposition utilisateur, proposition d'agent ou contribution communautaire ; références et auteur connus |
| `review` | `pending`, `accepted`, `changes_requested` ou `rejected`, avec commentaire et décision de l'utilisateur lorsqu'elle existe |

Le lien à un pack et les mécanismes de votes, modération et choix personnels restent ceux de l'application. L'acceptation éditoriale du set officiel n'est pas équivalente à une contribution autorisée à être visible. Le champ `review` ne remplace pas les statuts de modération existants.

Une clé kana ou kanji peut être le caractère déjà unique dans la base. Pour un mot, utiliser son identifiant, pas seulement son écriture. Une mnémotechnique de lecture précise la lecture ciblée ; elle ne s'applique pas arbitrairement à toutes les lectures du caractère.

### Informations absentes et inférences

Lors de la reprise d'un texte existant, conserver d'abord ce qui est réellement présent. Les champs manquants restent `null` ou vides. Si un agent reconstitue une ancre ou propose une scène, cette interprétation est indiquée dans le commentaire de revue et reste à valider.

Pour une nouvelle idée, les champs servent à expliquer pourquoi elle pourrait fonctionner. La phrase seule est insuffisante pour juger si le son est juste et si le dessin sera utile. Une histoire adaptée dans une autre langue devient une autre proposition, avec sa propre validation.

Après acceptation, `visual.idea` et `visual.glyph_mapping` servent de brief à l'agent image. L'image retenue remplit ensuite `visual.image`. Aucune collection de tables de briefs et de révisions n'est nécessaire pour cette opération. Conserver les fichiers de travail et les résultats précédents suffit pour revenir sur une décision.

## 3. Exemples et intégration

L'[exemple carapace](content-contract-examples/ka-fr-concept.draft.json) montre une nouvelle idée à valider. Les [deux histoires historiques de か](content-contract-examples/kana-ka.existing-candidates.json) montrent la reprise des textes EN/FR actuellement présents dans le seed, sans leur inventer une validation ou des détails visuels.

Ces exemples sont des fichiers documentaires, pas des seeds à publier. Pour l'application, réutiliser `Mnemonic` et les modèles du dictionnaire, en ajoutant les champs structurés et les cibles qui manquent. L'import doit traduire le format de travail vers ces modèles et préserver leurs identifiants.

Le premier lot réel permettra de vérifier que le format conserve les enrichissements des différentes sources. On l'ajuste sur les cas rencontrés, puis on traite le corpus. La banque mnémotechnique peut être normalisée immédiatement ; les choix officiels et les images attendent la validation de l'utilisateur.
