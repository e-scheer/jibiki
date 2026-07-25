# Prompt v2 — kana utilisé comme tracé obligatoire du dessin

> Pour la version actuelle, plus narrative et fondée sur l'utilisation physique de
> tous les traits, utiliser `PROMPT-VISUAL-TRACE.md`. Le mode de décomposition IDS
> ci-dessous est conservé comme expérience, mais n'est plus la stratégie recommandée.

La contrainte centrale est structurelle : le kana n'est jamais posé sur une
illustration déjà complète. Ses traits sont directement utilisés comme des parties
physiques indispensables du sujet : défenses, bec, queue, crête de vague, manche,
corde, contour, etc.

## Choix du concept avant génération

Ne pas générer tant que ces champs ne peuvent pas être remplis précisément :

- `[KANA]` : caractère exact
- `[MNEMONIC]` : sujet mnémotechnique
- `[KANA_ROLE]` : partie physique que constitue le kana entier
- `[STROKE_MAP]` : rôle pictural de chaque trait ou segment du kana
- `[ATTACHMENT_POINTS]` : endroits où le dessin coloré rejoint les extrémités du kana
- `[REMOVAL_FAILURE]` : ce qui manque visiblement si le kana est supprimé
- `[FORBIDDEN_DUPLICATE]` : partie que le dessin ne doit surtout pas redessiner
- `[BACKGROUND]`, `[KANA_COLOR]`, `[DRAWING_COLOR]` : trois couleurs seulement

Si le mapping est forcé ou laisse des traits sans fonction, il faut changer de
mnémotechnique plutôt que placer un dessin décoratif autour du kana.

## Prompt final

```text
Use case: stylized-concept
Asset type: Japanese kana structural mnemonic illustration

REFERENCE PRINCIPLE
The reference images are construction and style references only. Follow their key
principle: the light kana strokes literally serve as indispensable physical parts of
the pictured subject, such as 「い」 being the elephant's ivory tusks. Do not reproduce
any reference UI, caption, word, status bar, screenshot layout, or existing subject.

CARD SPECIFICATION
Exact kana: 「[KANA]」
Mnemonic subject: [MNEMONIC]
The entire kana physically represents: [KANA_ROLE]
Stroke-by-stroke mapping: [STROKE_MAP]
Geometric attachment points: [ATTACHMENT_POINTS]
Without the kana, the subject visibly loses: [REMOVAL_FAILURE]
The drawing must never duplicate: [FORBIDDEN_DUPLICATE]
Background color: [BACKGROUND]
Kana color: [KANA_COLOR]
Single drawing color: [DRAWING_COLOR]

NON-NEGOTIABLE STRUCTURAL RULE — HIGHEST PRIORITY
Build the subject FROM the exact kana skeleton, never around or behind a complete
subject. The kana is a required physical component of the illustration, not an
overlay, annotation, frame, decorative crossing, symbol, or separate foreground
glyph. Every kana stroke and every visible segment must have the pictorial function
defined in STROKE-BY-STROKE MAPPING. No kana stroke may float unused.

The colored drawing must terminate cleanly at the specified kana endpoints or edges,
like adjoining pieces of one pictogram. Do not merely overlap the two layers. Do not
draw the kana's assigned object part a second time in the drawing color. There must be
one subject and one shared construction, not a complete illustration plus a kana.

MANDATORY REMOVAL TEST
Mentally remove every [KANA_COLOR] pixel. The remaining [DRAWING_COLOR] drawing must
be visibly and structurally incomplete because [REMOVAL_FAILURE] is entirely absent.
If the remaining drawing still depicts a complete subject, the design is wrong.

MANDATORY DUPLICATION TEST
The only depiction of [FORBIDDEN_DUPLICATE] is the kana itself. No colored duplicate,
outline, silhouette, substitute, or second version of that part may exist.

GLYPH ACCURACY
The shared physical part must still read instantly as one exact standard kana
「[KANA]」 in normal reading orientation. Preserve its correct stroke count, topology,
endpoints, crossings, loops, openings, direction, and recognizable proportions.
Do not rotate, mirror, split, close, deform, outline, decorate, or complete it with
extra [KANA_COLOR] shapes. Glyph readability takes priority over realism.

DRAWING
Add only the minimal [DRAWING_COLOR] shapes required to make [MNEMONIC] immediately
recognizable and to establish the specified attachment points. Sparse naïve flat
educational vector art, approximately 5–12 simple shapes or marks. Use negative-space
cutouts for tiny details when possible. No separate floating icon and no unnecessary
props.

COMPOSITION
Portrait 4:5. One compact centered shared kana-and-subject construction occupying
roughly 55–60% of the canvas height, with generous empty margins. The kana remains
large, fully visible, and visually dominant.

STRICT COLOR SYSTEM
Use exactly three flat colors in the entire image, plus unavoidable edge antialiasing:
1. [BACKGROUND] for the uniform background;
2. [KANA_COLOR] only for the exact kana and the physical part it represents;
3. [DRAWING_COLOR] only for every other illustration mark.

The drawing is strictly monochrome. No black, secondary outline, accent, highlight,
tint, transparent overlay, gradient, vignette, glow, lighting, shadow, shading,
texture, paper grain, blur, depth, or tonal variation.

NO-TEXT RULE
The single pictorial kana 「[KANA]」 is the only written glyph allowed anywhere.
No mnemonic word, Latin letter, caption, label, number, other kana, pseudo-Japanese
mark, decorative typography, UI, border, logo, signature, or watermark.

AVOID
A complete subject behind a floating kana; decorative overlap; a kana used as a
frame; duplicated body/object parts; unused kana segments; disconnected attachment
points; fake kana strokes; photorealism; 3D; busy details; extra subjects.
```

## Exemple rempli — く / coucou

```text
Exact kana: 「く」
Mnemonic subject: a cuckoo bird, side view
The entire kana physically represents: the bird's one and only open beak
Stroke-by-stroke mapping: the upper arm is the upper half of the beak; the lower arm
is the lower half; their left junction is the beak tip
Geometric attachment points: both right endpoints connect directly into the bird head
Without the kana, the subject visibly loses: its entire beak
The drawing must never duplicate: the beak
```

## Tests de validation

| Kana | Sujet | Utilisation structurelle |
|---|---|---|
| `く` | coucou | le kana entier est le bec ouvert |
| `し` | chien | le kana entier est la queue reliée à la croupe |
| `つ` | tsunami | le kana entier est l'unique crête d'écume de la vague |
| `ぬ` | nouilles | les deux traits sont toutes les nouilles sortant du bol |
| `ヌ` | rue | les deux traits sont deux rues et leur croisement est l'intersection |
| `桜` | sakura | `木` arbre + `⺍` petites pétales + `女` petite femme |

Le prompt a été validé sur un élément anatomique rigide, un appendice courbe et un
élément naturel. Le choix du couple kana–mnémotechnique reste déterminant : une bonne
correspondance géométrique est plus importante qu'une ressemblance phonétique parfaite.

Pour un kanji, appliquer le mapping à tous les composants et à tous les traits : aucun
radical ne doit rester une simple forme typographique. Le test de suppression reste le
même — sans le caractère, le sujet doit perdre toute sa structure principale.

## Mode kanji composé — décomposition IDS obligatoire

Avant de choisir l'illustration d'un kanji complexe, écrire sa décomposition IDS et
affecter un rôle visuel distinct à chaque composant terminal :

- `[IDS]` : structure complète, par exemple `⿰ 木 ⿱ ⺍ 女`
- `[COMPONENT_1]` : sens, rôle pictural et raccords du premier composant
- `[COMPONENT_2]` : sens, rôle pictural et raccords du deuxième composant
- `[COMPONENT_3...]` : poursuivre jusqu'à toutes les feuilles de l'IDS
- `[COMPONENT_STORY]` : une scène courte qui combine les composants dans leur ordre
  spatial exact
- `[COMPONENT_REMOVAL_TESTS]` : ce qui disparaît lorsqu'on retire chaque composant

Ajouter ce bloc au prompt :

```text
KANJI COMPONENT MODE — HIGHEST PRIORITY
Exact IDS decomposition: [IDS]
Component mnemonic mapping:
- [COMPONENT_1]
- [COMPONENT_2]
- [COMPONENT_3...]
Combined mnemonic scene: [COMPONENT_STORY]

Preserve the canonical spatial operator and relative placement encoded by the IDS.
Do not illustrate only the kanji's global meaning. Each terminal component must have
its own distinct literal pictorial role, recognizable independently while remaining
part of one exact coherent kanji. Do not move the components apart or turn them into
separate symbols.

Run a separate removal test for every component: [COMPONENT_REMOVAL_TESTS]. If one
component can be removed without deleting its assigned object or idea from the scene,
the mnemonic is invalid. Never duplicate a component's assigned role in the drawing
color.
```

Exemple pour `桜` : `⿰ 木 ⿱ ⺍ 女` devient un arbre `木`, trois toutes petites
pétales `⺍`, puis le corps d'une petite femme `女`. Les fleurs et la tête ajoutées ne
doivent jamais redessiner le tronc, les petites pétales ou le corps de la femme.
