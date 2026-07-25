# Burn, boosters et collection

Spécification appliquée du plan produit (voir `misc/YOUTUBE_TIPS/ANALYSIS_AND_PLAN.md`
et `misc/YOUTUBE_TIPS/BOOSTER_COLLECTION_PLAN.md`). Ce document décrit les règles
implémentées, pas les intentions.

## Burn d'apprentissage

- Un jour est **qualifié** quand au moins une vraie révision est soumise ce
  jour-là (fuseau local de l'appareil). Ouvrir l'app ne compte pas.
- Le burn est le nombre de jours qualifiés consécutifs se terminant aujourd'hui
  ou hier (le burn reste vivant tant que la journée courante n'est pas finie).
- Le **meilleur burn** est conservé pour toujours; un jour manqué ne l'efface
  jamais, et n'efface évidemment ni la collection ni les cartes apprises.
- Le wording est positif: on invite à revenir aujourd'hui, on ne menace pas de
  tout perdre.

## Attribution des boosters

- Milestones: 3, 7, 14, 21 et 30 jours de burn, puis un booster tous les
  7 jours au-delà de 30.
- Chaque milestone d'une même série ne donne un booster qu'une seule fois
  (idempotent, y compris en cas de rejeu d'événements).
- Maximum **3 boosters non ouverts** stockés. Un milestone atteint alors que la
  réserve est pleine est marqué honoré mais ne crée pas de booster.
- Les boosters ne sont **jamais achetables** et ne modifient jamais la
  planification FSRS.

## Contenu d'un booster

- 4 cartes: 3 normales + 1 shiny garantie.
- Tirage dans le set actif, probabilités fixes, doublons possibles.
- La shiny est une variante visuelle et émotionnelle, jamais un avantage.
- Raretés: commune, rare, spéciale, shiny. La rareté change l'apparence et
  l'animation, pas la valeur pédagogique.

## Cartes consommables

Certaines cartes (rareté « spéciale ») portent un déblocage cosmétique à usage
permanent, par exemple une nouvelle palette de couleurs de l'app. Règles:

- le déblocage s'applique dès que la carte entre dans la collection;
- la carte reste visible dans l'album comme preuve, avec son état débloqué;
- un doublon d'une carte consommable n'apporte rien de plus (le déblocage est
  déjà actif) mais reste compté comme doublon;
- une palette verrouillée est visible dans les réglages avec une explication
  claire de comment l'obtenir, jamais cachée ni vendue.

## Collection

- Album par set avec progression, filtres (rareté, nouvelles, doublons,
  manquantes), compteur global et compteur shiny.
- Fiche détaillée recto/verso: contenu culturel court, vocabulaire japonais
  associé, lien éventuel vers le dictionnaire.
- Les doublons sont comptés (normal et shiny séparément) et jamais supprimés.

## Contenu seedé et langues

- Le catalogue de cartes est un asset local versionné
  (`assets/data/collection_sets.json`).
- Chaque champ de texte visible est scoped par langue (`fr`, `en`), déclaré
  explicitement. Aucun texte de carte n'est traité comme neutre.
- Si une langue manque pour une carte, l'app affiche le fallback comme tel,
  jamais comme du contenu authored dans la langue sélectionnée.
- Les visuels des cartes sont des photographies (direction artistique unique:
  que des photos, sujet net, couleurs vives) sélectionnées sur Wikimedia
  Commons par `scripts/fetch_card_art.py`, embarquées dans
  `assets/art/cards/`. Chaque photo est sous licence libre (domaine public,
  CC0, CC BY ou CC BY-SA); l'auteur et la licence sont conservés dans
  `assets/art/cards/ATTRIBUTIONS.json`, dans le champ `art.credit` de la
  carte, et affichés dans le détail de la carte. Le placeholder composé par
  l'interface (silhouette, palette du set) reste le fallback de chargement,
  d'erreur, et des cartes sans photo. Aucun texte n'est intégré aux images.

## Ouverture

- Séquence: pack fermé, trancher d'un geste (glissé lent bord à bord ou flick
  rapide, la coupe suit la ligne exacte du doigt), couture lumineuse et ticks
  haptiques pendant la traversée, flash et étincelles à la coupe, les deux
  moitiés s'écartent selon l'énergie du geste, révélation des 3 normales par
  tap, shiny révélée en dernier avec un traitement spécial, écran de synthèse.
- Accessibilité: ouverture possible par tap, variante `reduce motion` sans
  rotation ni particules, haptique désactivable, bouton passer l'animation
  après la première ouverture. Aucune information n'est cachée derrière
  l'animation.

## Hors ligne et sync

- Tout fonctionne localement (invité inclus): burn, grants, ouvertures et
  collection sont persistés dans la base locale. Rien n'attend le réseau.
- Avec un compte, les récompenses suivent l'utilisateur: chaque grant et
  chaque ouverture enfile un op (`booster_grant`, `booster_open`) dans
  l'outbox, rejoué par le SyncEngine vers `/study/sync`. Le serveur les
  applique de façon idempotente (ledger SyncedOp + `grant_id` déterministe
  `streak:<début-de-série>:<palier>`), reconstruit la collection côté compte
  et renvoie l'état complet des récompenses dans chaque réponse de sync.
- Le merge côté client est monotone: les compteurs de doublons prennent le
  MAX local/serveur et un booster ouvert localement n'est jamais rétrogradé,
  donc une ouverture faite pendant qu'une requête est en vol n'est jamais
  perdue.
- Deux appareils qui atteignent le même palier convergent vers un seul grant
  (id déterministe); la première ouverture gagne, et le tirage étant
  déterministe par grant, les deux appareils voient les mêmes cartes.
- Résolution de conflit invité/cloud: « utiliser le cloud » purge les tables
  locales de récompenses puis le pull les repeuple depuis le compte;
  « garder le local » régénère les ops grant/open depuis l'état local et
  reconstruit le cloud à l'identique (le serveur purge d'abord ses lignes en
  mode `replace_cloud`). Le burn, lui, se recalcule toujours depuis
  l'historique de révisions.
