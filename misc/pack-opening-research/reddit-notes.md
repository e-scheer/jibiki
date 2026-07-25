# Notes: ouverture de booster (retours Reddit)

Sources lues le 17 juillet 2026 (le contenu a été collé manuellement, Reddit bloque
l'accès direct depuis l'environnement de build).

1. r/godot, "I tried making a satisfying card pack opening animation in Godot"
   par Tobisurvivor. https://www.reddit.com/r/godot/comments/1nsnrhs/
2. r/blenderhelp, "I want to create an animation where a package opens by
   tearing off the top part" par rjuman.
   https://www.reddit.com/r/blenderhelp/comments/1j174vh/

Ce sont des retours de développeurs sur ce qui rend une ouverture satisfaisante.
La référence citée plusieurs fois est Pokémon TCG Pocket (swipe pour couper).

## Thread r/godot: verbatim des retours utiles

Découpe / déchirure:
- cheezballs: "the top just magically razoring off is kinda unsatisfying. You
  gotta make it more like an actual pack getting opened. Just having the top
  magically separate perfectly along a horizontal axis doesn't feel right."
- feralfantastic: "Or a messy diagonal tear that reveals a bit of the first card."
- corezon: "More like turning the pack around, and splitting it along the foil
  like you would naturally open a card pack. No one is breaking out scissors."
- Kureji: "roll up a corner to start a tear and then move the bend further along
  the top to continue the tear until you finish and then you let it drop behind
  the pack ... maybe have it drop like a feather so it sways back and forth a
  little as gravity pulls it down."
- cheezballs (2): "what if the pack flipped over and opened along the sealed line
  ... open along the seam in the back like a jacket zipper?"
- therkleon: "the cut on the top looks too neat, making it a bit rougher might
  look better."
- Phosphero (humour, mais pointe l'imperfection organique): tear catches, corner
  rips off, papercut, retry.
- te0dorit0: "add some sort of slash/flash effect to the slicing."
- That-Abbreviations-8: "Pokémon TCG mobile ... you swipe to cut the booster
  pack.. really satisfying."

Anticipation / timing / juice:
- shiek200: "The animations currently are incredibly consistent, and being
  overly consistent is bad. Animations should change speed over time, get faster
  (and possibly then slower) as they go. Try making the cards come out faster the
  longer the animation is playing." ET "The 'pack shaking' animation is a bit
  short, there's no 'anticipation' building. Try making it like 3 times longer,
  with a gentle shake that builds in intensity."
- starsrift: "A little more of an initial shake would help. Motions should often
  be exaggerated."
- therkleon: "particle effects make everything better." ET "the cards all come
  out at exactly the same speed and end up on exactly the same line, a little bit
  of variation might make it look more natural."
- Tobisurvivor (auteur): "The cards themselves could have an idle animation, to
  make them look less static."

Révélation carte par carte (thème le plus récurrent):
- PurpleFlurpDerp: "having the cards appear face-down so that the mystery ... is
  preserved. That way you could have special reveal animation play when the
  player gets a special card." (aime le mouvement "snappy, like classic
  solitaire").
- te0dorit0: "missing the most fun part about opening a pack, which is flipping
  each one by one to reveal what they are."
- [deleted] (le plus complet): "Opening packs feels satisfying when it emphasizes
  ritual and anticipation. Pauses before the reveal, flipping cards one by one and
  the suspense of a rare card. Build up that tension, then 'pop the rhythm' with a
  fun visual when that rare shows up, and finish by laying out all the cards
  clearly for players to inspect and enjoy. Blizzard's Hearthstone does this
  really well ... stretched buildup, staggered yet snappy (player-triggered)
  reveals, clear rarity cues and a final overview."

Rareté:
- Beneficial_Layer_458: "particle effects on rarer/stronger cards?"

Autres pistes:
- nerdmor: "move the pack itself away, as someone throwing away the wrapper, then
  pull the cards from a pile as if they were in your hand."
- MinimumEquivalent966: référence Plants vs Zombies Garden Warfare.
- TheJackiMonster: "watch some pack openings on YouTube as reference. They pretty
  much perfected dramatic suspense."
- carllacan: "if you were to animate the opening of the pack it would look 10
  times better."

## Thread r/blenderhelp: comment déchirer (si un jour on pré-rend en 3D)

- ZaMaruko: deux mesh séparés (sac + morceau arraché qui se courbe), parentés au
  même contrôleur, curve modifier pour courber le morceau, shape keys utiles.
- emiCouchPotato: texture de papier déchiré (photo) en alpha sur l'arête, second
  canal UV pour ne pas casser la texture principale, inverser pour le bas afin
  que la couture corresponde, géométrie qui se chevauche ("lip") à la coupe,
  anim avec quelques bones.
- ArtOf_Nobody (Experienced Helper): geometry nodes. Marquer une rangée de verts
  sur la largeur, animer un gradient mask qui traverse; le mask pilote Split
  Edges puis Set Position; map range (float curve) pour le falloff; déplacer
  l'arête déchirée avec un bruit haute fréquence (subdiviser avant); stocker les
  masks en attributs pour piloter aussi le shader.
- Datalock: +1 geometry nodes.
- Free-Advertising6184: "just the pokemon pocket tcg animation?", préfère shape
  keys.

## Synthèse: les principes qui reviennent

1. La déchirure ne doit pas être trop propre ni parfaitement horizontale: bord
   rugueux, légèrement diagonal/organique, et de préférence le long de la couture
   foil comme un vrai paquet.
2. Anticipation avant la révélation: un shake qui monte en intensité, plus long,
   des pauses. La tension est le cœur du plaisir.
3. Ne rien rendre trop uniforme: varier vitesses, courbes, positions; accélérer
   puis ralentir.
4. Révéler les cartes face cachée puis les retourner une par une (le "most fun
   part"), avec révélation spéciale et cue de rareté quand une rare/shiny sort.
5. Particules et flash surtout sur les cartes rares.
6. Terminer par une vue d'ensemble claire de toutes les cartes.
7. Effet de coupe: un "slash/flash" qui suit le trait, morceau arraché qui tombe
   en voletant.

## Mapping avec l'implémentation jibiki actuelle

Déjà en place:
- Swipe pour couper, coupe en deux avec bord déchiqueté, couture de lumière,
  éclat + rayons (couvre: swipe-to-cut, slash/flash, découpe non propre).
- Révélations déclenchées par tap une par une, slide + rotation, inclinaison 3D,
  holo + rayons + sparkles sur la shiny (couvre: staggered player-triggered,
  cue de rareté, particules sur rare).
- Écran de synthèse final en grille (couvre: final overview).
- La shiny est gardée pour la fin en face cachée avec teaser (couvre partiellement
  le "flip to reveal").

Manques prioritaires (issus des retours réels):
- P1: Anticipation avant la déchirure. Aujourd'hui le pack a un léger flottement
  mais pas de shake qui monte. Ajouter un tremblement qui s'intensifie pendant le
  drag (et un petit build au seuil). [shiek200, starsrift]
- P1: Face cachée + flip pour TOUTES les cartes, pas seulement la shiny. C'est le
  "most fun part" cité par 3 personnes. Chaque tap retourne la carte suivante.
  [PurpleFlurpDerp, te0dorit0, deleted]
- P2: Rendre la déchirure moins régulière: bruit haute fréquence sur le zigzag,
  léger biais diagonal, et le morceau du haut qui tombe en voletant plutôt que de
  filer tout droit. [therkleon, feralfantastic, Kureji]
- P2: Casser l'uniformité des révélations: variation de courbe/vitesse/légère
  rotation aléatoire par carte. [shiek200, therkleon]
- P3: Particules dédiées au moment "nouvelle carte" (pas que la shiny). [therkleon,
  Beneficial_Layer_458]
- P3: Idle subtil sur la carte révélée (respiration/brillance) pour la rendre
  moins statique. [Tobisurvivor]

Optionnel / plus lourd:
- Retourner le pack et ouvrir le long de la couture foil arrière. [corezon,
  cheezballs]
- Pré-rendu 3D Blender (geometry nodes ou deux mesh + curve modifier) pour un
  tear ultra-réaliste, mais figé et lourd. [thread blenderhelp]
