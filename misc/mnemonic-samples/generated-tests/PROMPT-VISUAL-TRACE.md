# Prompt v4 — contrat sémantique trait par trait

Cette version abandonne la décomposition savante des kanji. Le caractère exact est
d'abord traité comme le squelette imposé d'une scène mémorable. Le dessin coloré est
ensuite construit autour de ses traits pour leur donner une fonction physique.

## Verrou obligatoire du caractère

Un prompt génératif ne suffit pas à garantir une structure exacte. Le caractère doit
être fourni comme une couche raster déterministe rendue depuis une police japonaise,
puis restauré après génération avec son masque. Les ajouts du modèle sont autorisés
uniquement dans la couleur du dessin.

Outils du projet :

- `tools/render-glyph-lock.ps1` produit l'image de base et le masque exacts ;
- `tools/apply-glyph-lock.ps1` restaure le caractère et supprime toute couleur de
  caractère inventée hors masque ;
- `tools/verify-glyph-lock.ps1` exige zéro pixel modifié dans le masque et zéro pixel
  de la couleur du caractère hors masque.

## Composition sandwich — arrière / caractère / avant

Le dessin peut passer devant le kana ou le kanji sans modifier sa structure. Conserver
trois fichiers transparents distincts et les composer dans cet ordre strict :

```text
background
  -> under_illustration.png
  -> exact_character.png
  -> over_illustration.png
```

- `under_illustration` contient ce qui passe physiquement derrière le caractère ;
- `exact_character` contient uniquement le glyphe rendu et reste immuable ;
- `over_illustration` contient ce qui le recouvre localement : main, corde, manche,
  tige, éclaboussure, vêtement, etc.

Le contrôle d'intégrité porte sur `exact_character.png`, pas sur tous ses pixels
visibles dans le composite : un calque avant peut légitimement les masquer. Son hash
doit rester identique avant et après composition.

Prototype : `tools/render-layered-a-umbrella.ps1` produit les quatre couches et le
composite de **あ / s'abriter**.

## Verrou de placement — obligatoire avant le dessin

Le bon ordre des calques ne suffit pas. Le caractère doit d'abord être rendu à sa
taille finale, puis sa boîte alpha réelle doit être mesurée. Cette boîte devient le
repère unique de toute la scène. Le modèle ne choisit jamais librement où replacer le
caractère.

- `GLYPH_BOX = (x, y, largeur, hauteur)` décrit les pixels non transparents du glyphe ;
- chaque élément reçoit des ancres normalisées dans cette boîte, par exemple
  `shaft_x = 0.50`, `canopy_bottom_y = 0.02`, `hand_y = 0.73` ;
- les coordonnées des dessins sont calculées depuis `GLYPH_BOX`, jamais depuis les
  bords du canvas ;
- les quatre couches gardent exactement la même taille et la même origine ;
- le glyphe n'est ni recentré, ni redimensionné, ni régénéré entre les couches.

Avant validation, superposer `exact_character` à 50 % d'opacité sur le composite :
les raccords prévus doivent tomber sur les mêmes pixels, sans décalage ni seconde
copie fantôme du caractère.

## Contrat sémantique des traits — priorité absolue

Le placement ne suffit pas : chaque trait important reçoit avant la génération une
fonction physique exclusive dans l'objet ou le personnage. Cette table est une
instruction de construction, pas une description facultative :

```text
STROKE_BINDING_TABLE
- [STROKE_ID]: [EXACT_VISUAL_LOCATION] IS the [PHYSICAL_ROLE].
  Colored additions allowed: [ALLOWED_ADDITIONS].
  Forbidden duplicate: [FORBIDDEN_COMPLETE_PART].
```

Le modèle doit dessiner la scène **incomplète autour du caractère**. Il ne doit jamais
dessiner l'objet complet puis poser le caractère dessus. Si un trait est le toit du
parapluie, le dessin coloré ne possède aucun autre bord inférieur de toile. Si un
trait est le manche, aucune ligne colorée parallèle ne peut servir de manche.

Test obligatoire : masquer le caractère doit supprimer les pièces structurelles
nommées dans la table et rendre l'objet physiquement incomplet.

## Variables

- `[CHARACTER]` : kana ou kanji exact
- `[MEMORABLE_SCENE]` : une action unique, concrète et légèrement exagérée
- `[TRACE_ROLES]` : rôle physique des groupes de traits dans cette scène
- `[CONNECTIONS]` : interactions importantes entre le dessin et les traits
- `[BACKGROUND]`, `[CHARACTER_COLOR]`, `[DRAWING_COLOR]` : trois couleurs
- `[UNDER_ELEMENTS]` : parties du dessin situées derrière le caractère
- `[OVER_ELEMENTS]` : parties du dessin situées devant le caractère
- `[GLYPH_BOX]` : boîte exacte du caractère déjà placé dans le canvas
- `[ANCHORS]` : points de raccord normalisés, exprimés relativement à `GLYPH_BOX`
- `[STROKE_BINDING_TABLE]` : rôle physique obligatoire de chaque groupe de traits

## Prompt

```text
Use case: stylized-concept
Asset type: Japanese character visual-trace mnemonic illustration

TARGET
Exact Japanese character: 「[CHARACTER]」
Memorable single action scene: [MEMORABLE_SCENE]
Physical roles of the exact character strokes: [TRACE_ROLES]
Required drawing-to-stroke connections: [CONNECTIONS]
Locked glyph bounds in the shared canvas: [GLYPH_BOX]
Normalized attachment anchors inside those bounds: [ANCHORS]
Mandatory stroke-to-object bindings: [STROKE_BINDING_TABLE]
Background: [BACKGROUND]
Character strokes: [CHARACTER_COLOR]
Drawing: one single [DRAWING_COLOR] ink

TRACE-FIRST RULE — HIGHEST PRIORITY
Start from one exact, large, standard 「[CHARACTER]」. Lock every character stroke,
crossing, endpoint, loop, gap, and proportion before designing the picture. Build the
scene AROUND this fixed skeleton. Do not start with a complete illustration and place
the character over it.

STROKE-ROLE CONTRACT — SAME HIGHEST PRIORITY
Treat every row of [STROKE_BINDING_TABLE] as literal geometry. The named character
stroke IS that physical part; it does not merely overlap, decorate, resemble, or sit
near it. Draw only the missing colored contours and connectors needed to make that
role readable. Never draw a second complete version of the assigned part in drawing
ink. The character and drawing must share endpoints, joints and load-bearing edges.

IMMUTABLE CHARACTER-COLOR LAYER
The supplied [CHARACTER_COLOR] character layer is read-only. Never create any new
[CHARACTER_COLOR] pixel for anatomy, clothing, objects, connectors, highlights, or
decoration. Never remove, move, extend, shorten, thicken, thin, bend, join, split, or
recolor an existing character pixel. Everything not already present in the supplied
character mask must use [DRAWING_COLOR]. A deterministic post-process will reject all
character-color pixels outside the mask and restore the original mask pixel-for-pixel.

DEPTH LAYERS
Generate the illustration as two aligned transparent drawing layers around the same
immutable character template:
- UNDER layer: [UNDER_ELEMENTS]. These elements are composited behind the character.
- OVER layer: [OVER_ELEMENTS]. These elements are composited after the character and
  may cover it locally, but must never alter the stored character layer.

Both drawing layers use only [DRAWING_COLOR]. Keep their canvas size and coordinates
identical to the character layer. The final order is background -> UNDER -> exact
character -> OVER. Never flatten or regenerate the character between these steps.

PLACEMENT LOCK
The supplied character is already at its final pixel coordinates. Treat its alpha
bounds as the only coordinate system for the mnemonic. Resolve every canopy, limb,
hand, handle, joint, contour break, and contact point from [GLYPH_BOX] and [ANCHORS].
Do not auto-center, scale, crop, translate, trace again, or visually approximate the
character on either drawing layer. A correct idea at the wrong coordinates is a
failed result.

Every major character stroke must become load-bearing physical anatomy or structure
inside the scene: a limb, trunk, branch, rope, tool, garment fold, road, wave, tusk,
handle, contour, or another concrete part defined in TRACE ROLES. No important stroke
may remain unused typography.

The colored drawing must touch, terminate at, wrap around, continue from, or be
interrupted by the character strokes at the specified CONNECTIONS. Use the drawing
ink mainly for broken outer contours, joints, hands, faces, hair, material details,
and motion cues that make the stroke roles immediately legible.

NEVER DUPLICATE THE STRUCTURE
Do not draw a complete version of any assigned body or object part in the drawing
color. If a character stroke is an arm, there is no second colored arm underneath. If
it is a trunk, colored bark contours remain broken and cannot form a trunk alone.
Character and drawing must be interdependent pieces of one pictogram.

ONE ACTION, NOT A COLLAGE
All pictorial elements participate in one clear action with visible cause and effect.
At least one colored hand, joint, attachment, grip, impact, or contact point must make
the scene physically interact across different areas of the character. Avoid separate
icons, isolated components, and objects merely placed beside each other.

REMOVAL TEST
Mentally remove every [CHARACTER_COLOR] pixel. The remaining [DRAWING_COLOR] marks
must collapse into disconnected fragments: incomplete contours, detached hands,
faces without bodies, material details without objects, and motion lines without a
subject. If a complete subject or understandable generic scene remains, the design is
wrong.

DECORATION TEST
Flowers, leaves, sparks, stars, droplets, labels, and other small motifs cannot be the
main mnemonic mechanism. They may identify the scene sparingly, but placing them on
stroke tips does not count as using the trace. The memory must come from the physical
role and action of the large strokes.

GLYPH ACCURACY
Preserve the exact standard Japanese 「[CHARACTER]」 in normal upright orientation:
correct stroke count, topology, crossings, endpoints, openings, spacing, and
proportions. Do not rotate, mirror, move, merge, omit, add, bend, split, outline,
cover, or replace strokes. Glyph readability takes priority over realism.

VISUAL STYLE
Portrait 4:5. One centered shared character-and-scene construction occupying roughly
60–65% of the canvas height, generous margins. Flat mid-century educational vector /
naïve editorial line art, like a clever 1960s visual mnemonic. Bold, playful,
slightly absurd, sparse enough that the exact character remains dominant, but worked
enough that the action is unmistakable.

STRICT COLOR SYSTEM
Exactly three flat colors total: [BACKGROUND], [CHARACTER_COLOR], and one identical
[DRAWING_COLOR] for every illustration mark. No secondary accent, black, highlight,
gradient, vignette, glow, shadow, shading, texture, transparency, 3D, or tonal variation.

NO TEXT
The single pictorial character 「[CHARACTER]」 is the only written glyph. No mnemonic
word, Latin letter, caption, label, number, other Japanese character, pseudo-writing,
UI, border, logo, signature, or watermark.

AVOID
Decorating stroke endpoints; generic illustration behind a floating character;
complete subjects in drawing color; separate semantic components; weak overlaps;
unused strokes; fake glyph strokes; realistic busy scenery.
```

## Exemple — 桜

- Scène : une femme appelée Sakura est emportée par une bourrasque et s'agrippe à un
  cerisier.
- Traits : la partie gauche porte réellement le tronc et les branches ; le grand trait
  horizontal devient les bras tendus ; les traits inférieurs deviennent kimono et
  jambes ; les petits traits supérieurs passent dans les cheveux soulevés.
- Raccord clé : une main colorée se referme autour du tronc blanc.
- Décoration : seulement deux petits groupes floraux pour identifier le cerisier.
