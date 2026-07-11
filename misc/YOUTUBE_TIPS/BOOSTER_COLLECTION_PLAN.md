# Plan produit — Jibiki Japan Card Collection

## Vision

Les boosters deviennent l'unique récompense de jibiki. Ils remercient les
utilisateurs qui révisent réellement et reviennent régulièrement, sans ajouter
de monnaie secondaire, de bonus artificiel ou de récompense achetable.

La boucle cible est :

**réviser sérieusement → revenir régulièrement → gagner un booster → l'ouvrir
avec plaisir → découvrir des cartes sur le Japon → compléter sa collection**.

La référence d'expérience est la collection et l'ouverture de paquet de
Pokémon TCG Pocket, mais jibiki doit avoir ses propres cartes, visuels, sons,
animations et identité. On reprend la grammaire tactile — drag, résistance,
déchirement, anticipation, révélation — sans copier les assets Pokémon.

## Format d'un booster

Format de départ :

- 3 cartes normales ;
- 1 carte shiny garantie ;
- cartes nouvelles ou doublons ;
- cartes tirées dans le set actif ou la sélection saisonnière.

La shiny est une variante visuelle et émotionnelle, pas une carte plus puissante.
Elle peut avoir un traitement foil, une illustration alternative, un reflet ou
une animation particulière, mais elle ne modifie jamais la planification FSRS.

### Cadence de récompense proposée

La cadence exacte doit être testée, mais le premier scénario est :

- premier booster après 3 jours d'étude qualifiés ;
- milestones à 7, 14, 21 et 30 jours ;
- ensuite un booster tous les 7 jours réguliers ;
- maximum de 3 boosters non ouverts stockés ;
- un jour manqué n'efface pas la collection ni le meilleur burn ;
- possibilité de reprise ou de jour de grâce.

Une journée qualifiée signifie au moins une vraie révision terminée, pas une
simple ouverture de l'application. Une limite quotidienne évite de farmer des
boosters en répétant artificiellement la même action.

## Contenu des cartes

Les cartes parlent de tout ce qui rend le Japon intéressant :

- lieux et régions ;
- personnalités ;
- plats et boissons ;
- objets du quotidien ;
- animaux et nature ;
- histoire et société ;
- architecture et artisanat ;
- anime, jeux vidéo et culture populaire ;
- trains, villes et paysages ;
- fêtes, saisons et traditions.

Une carte contient :

### Recto

- image principale ;
- nom français ;
- nom japonais ;
- catégorie ;
- numéro de carte ;
- set et saison ;
- rareté ;
- indicateur nouvelle carte ou doublon à l'ouverture.

### Verso

- explication culturelle courte et vérifiée ;
- région, époque ou contexte ;
- vocabulaire japonais associé ;
- lecture et traduction ;
- lien éventuel vers le dictionnaire ;
- bouton éventuel « Ajouter le terme à l'étude ».

Les cartes de collection restent distinctes des cartes SRS. Elles peuvent
enrichir l'apprentissage, mais elles ne doivent pas polluer automatiquement la
file de révision.

## Images : placeholders puis illustrations générées

### Version initiale

Les premières cartes utilisent des placeholders. Le placeholder doit déjà
respecter :

- le ratio final de l'image ;
- la zone de sécurité pour les informations de la carte ;
- le niveau de contraste ;
- la palette et la texture du futur set ;
- la différence visuelle entre normal et shiny.

Le placeholder ne doit pas être un simple rectangle vide. Il peut être une
silhouette, une forme colorée ou une composition abstraite qui permet de tester
la lisibilité, la collection et l'ouverture du booster avant de produire les
images finales.

### Version finale

Les placeholders seront remplacés progressivement par des illustrations
générées avec ChatGPT et son modèle d'image choisi au moment de la production.
L'objectif est d'obtenir une collection cohérente, pas une suite d'images avec
un style différent par carte.

Pour chaque carte, il faudra conserver une fiche artistique :

- sujet exact ;
- angle et composition ;
- palette ;
- niveau de réalisme ;
- traitement de la lumière ;
- éléments à éviter ;
- prompt de référence ;
- version de l'image ;
- statut de validation.

Les images générées ne doivent pas contenir de texte intégré : les noms,
lectures et informations seront composés par l'interface pour rester nets,
traduisibles et accessibles.

### Photo ou illustration

Pour un lieu réel ou une personnalité, une illustration générée peut être
préférable à une fausse photo. La carte devra alors être présentée comme une
illustration, et non comme un document historique ou une photographie réelle.

Les vraies photos ne seront utilisées que lorsque la source, la licence et les
droits de réutilisation sont clairs. Le pipeline doit donc accepter trois types
d'assets :

1. placeholder interne ;
2. illustration générée et validée ;
3. photographie ou illustration externe sous licence vérifiée.

## Première collection proposée

### Set 001 — Japon essentiel

Un premier set d'environ 120 cartes :

- 25 lieux ;
- 20 personnalités ;
- 20 plats et boissons ;
- 20 éléments de culture ;
- 15 animaux et éléments naturels ;
- 10 objets du quotidien ;
- 10 éléments d'histoire et de société.

La répartition est un point de départ éditorial, pas une contrainte définitive.
Le premier objectif est de tester la variété et le désir de collectionner.

### Sélections suivantes

Les cartes peuvent être organisées en sets permanents et sélections saisonnières
temporaires :

- Tokyo de nuit ;
- Japon traditionnel ;
- Kansai ;
- nourriture japonaise ;
- nature et saisons ;
- trains et villes ;
- anime et jeux vidéo ;
- artisanat et architecture.

Les sélections actives changent l'ambiance et le pool de tirage, mais les cartes
obtenues restent toujours visibles dans la collection.

## Raretés

Raretés proposées :

- commune ;
- rare ;
- spéciale ;
- shiny.

La rareté doit influencer l'apparence, la finition et l'animation, jamais la
valeur pédagogique ou l'accès à une fonctionnalité. Une carte commune doit être
aussi intéressante à lire qu'une carte shiny.

## Ouverture du booster

### Séquence principale

1. Le booster fermé apparaît avec une vraie présence physique.
2. L'utilisateur glisse le doigt pour l'ouvrir.
3. Le paquet se plie légèrement sous le doigt et résiste avant le seuil.
4. Le déchirement déclenche une vibration, un son papier et un flash lumineux.
5. Les trois cartes normales sont révélées une par une par swipe.
6. La carte shiny est conservée pour la fin.
7. La shiny reçoit une révélation plus spectaculaire : reflet, profondeur,
   particules sobres et haptique dédiée.
8. Un écran de synthèse affiche nouvelles cartes, doublons et progression du
   set.
9. L'utilisateur peut aller directement à la carte, à la collection ou revenir
   à l'étude.

### Sensation recherchée

Le geste doit avoir :

- une résistance progressive ;
- une inertie crédible ;
- une réponse visuelle au point de contact ;
- un seuil clair ;
- une anticipation avant la révélation ;
- un rythme différent entre cartes normales et shiny.

L'ouverture doit être spectaculaire la première fois, puis rapide et agréable
pour les ouvertures répétées. Après la première ouverture, un bouton permet de
passer l'animation.

### Accessibilité et performance

- ouverture par tap ou bouton pour les personnes qui ne peuvent pas slider ;
- variante `reduce motion` sans rotation ni particules ;
- sons et vibrations désactivables séparément ;
- animation allégée sur les appareils modestes ;
- aucune étape obligatoire ne doit être cachée derrière l'animation.

## Doublons

### Version 1

- afficher `Doublon ×2`, `Doublon ×3`, etc. ;
- distinguer clairement `Nouvelle carte` et `Déjà dans la collection` ;
- conserver l'historique des tirages ;
- compter séparément les doublons normaux et shiny ;
- filtrer la collection par cartes manquantes et doublons.

Les doublons ne sont pas supprimés et ne sont pas convertis immédiatement en
monnaie. La collection doit d'abord être agréable et compréhensible.

### Version ultérieure

Si les doublons créent une frustration mesurée, ils pourraient servir à :

- débloquer des cadres ou effets visuels ;
- compléter une wishlist ;
- faire des échanges entre utilisateurs ;
- obtenir une variante esthétique d'une carte déjà possédée.

Cette économie ne doit être ajoutée qu'après observation du comportement réel.

## Collection

L'espace collection doit proposer :

- une grille ou un album ;
- progression par set, saison et catégorie ;
- filtres par rareté ;
- filtre nouvelles cartes ;
- filtre doublons ;
- filtre cartes manquantes ;
- compteur global et compteur shiny ;
- fiche détaillée avec recto/verso ;
- favoris ;
- vitrine personnelle pour quelques cartes choisies.

Chaque carte peut renvoyer vers le dictionnaire et proposer d'étudier son terme
japonais, sans transformer la collection en deuxième parcours obligatoire.

## Pipeline éditorial

Pour ajouter régulièrement des cartes, il faut un processus simple :

1. proposer un sujet ;
2. vérifier le fait culturel ;
3. rédiger le texte court et le vocabulaire japonais ;
4. choisir le type d'image ;
5. créer un placeholder ;
6. générer ou sélectionner l'image finale ;
7. vérifier le style, la lisibilité et les droits ;
8. publier la carte dans un set ou une sélection.

Chaque carte doit conserver sa source, son statut de validation, son asset et sa
version éditoriale. Les sets peuvent donc être agrandis sans casser les
collections existantes.

## Modèle de données conceptuel

Le futur système aura besoin de concepts séparés :

- définition d'une carte ;
- définition d'un set ;
- sélection saisonnière ;
- modèle de booster ;
- entrée de collection d'un utilisateur ;
- ouverture de booster ;
- récompense de milestone ;
- asset et métadonnées de licence ;
- version éditoriale de la carte.

Le tirage devra être attribué de manière cohérente et résistant aux doublons
d'événements, tout en restant compatible avec le mode hors ligne de jibiki. Ces
choix techniques viennent après validation du contenu et de l'expérience, pas
avant.

## Plan par phases

### Phase 0 — cadrage

- confirmer `3 normales + 1 shiny` ;
- confirmer que les boosters ne sont jamais achetables ;
- définir la journée d'étude qualifiée ;
- choisir le style graphique du premier set ;
- définir les règles de burn, reprise et jours de grâce.

### Phase 1 — mini-collection

Créer 20 cartes avec placeholders :

- 10 normales ;
- 6 rares ;
- 4 shiny ;
- plusieurs catégories du Japon.

Objectif : valider le désir de collectionner, la lisibilité et le ton éditorial
avant de produire une centaine d'images.

### Phase 2 — prototype d'ouverture

Prototyper uniquement la séquence d'ouverture, avec des cartes fictives :

- booster fermé ;
- slider et déchirure ;
- trois révélations normales ;
- révélation shiny ;
- nouvelle carte ;
- doublon ;
- écran de synthèse ;
- skip et reduce motion.

Objectif : valider le feeling physique avant toute intégration produit.

### Phase 3 — collection

- album ;
- filtres ;
- progression ;
- détail recto/verso ;
- compteur de doublons ;
- vitrine personnelle.

### Phase 4 — récompense

- attribution basée sur les révisions ;
- stockage des boosters ;
- ouverture idempotente ;
- historique ;
- synchronisation local/compte ;
- protection contre le farming artificiel.

### Phase 5 — production visuelle

- remplacer les placeholders prioritaires par des illustrations générées ;
- maintenir une direction artistique commune ;
- documenter prompts et versions ;
- vérifier les sujets sensibles, les personnalités et les faits historiques ;
- enrichir les sets par lots saisonniers.

### Phase 6 — mesure et évolution

Mesurer :

- jours de révision qualifiés ;
- boosters gagnés et ouverts ;
- nouvelles cartes découvertes ;
- taux de doublons ;
- visites de collection ;
- sorties pendant l'ouverture ;
- retour à J7 et J30 ;
- cartes ajoutées à l'étude depuis la collection.

Le succès est une meilleure récurrence de révision et une collection appréciée,
pas seulement un taux élevé de clic sur « ouvrir ».

## Décisions à valider avant développement

1. Le format exact du booster est-il bien **3 cartes normales + 1 shiny** ?
2. La shiny est-elle une variante brillante d'un sujet existant ou un sujet
   exclusivement rare ?
3. Veux-tu une direction plutôt photo documentaire, illustration éditoriale,
   gravure japonaise, anime, ou mélange contrôlé ?
4. Les doublons restent-ils purement collectionnables dans la première version ?
5. Le premier set doit-il avoir 60, 120 ou 200 cartes ?
6. Veux-tu une sélection saisonnière limitée dans le temps, ou seulement des
   sets permanents enrichis progressivement ?
