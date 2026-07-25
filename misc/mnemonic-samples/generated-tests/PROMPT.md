# Prompt v1 — kana mnémotechnique minimal (obsolète)

> Cette première version autorise une simple superposition dessin/kana et ne répond
> pas à la contrainte structurelle finale. Utiliser `PROMPT-STRUCTURAL.md`, où chaque
> trait du kana constitue obligatoirement une partie physique du dessin.

Ce prompt est conçu pour être utilisé avec 3 à 4 images du dossier `references/`
comme références de style. Elles servent uniquement à transmettre le langage visuel :
grand kana ivoire, dessin mnémotechnique mono-encre, superpositions devant/derrière,
formes plates et très peu de détails.

## Variables à remplacer

- `[KANA]` : le kana exact, par exemple `ね`
- `[MNEMONIC]` : l'objet ou personnage, par exemple `a human nose ("nez" in French)`
- `[INTEGRATION]` : comment le dessin exploite la forme, en une phrase concrète
- `[BACKGROUND]` : couleur de fond, idéalement avec code hex
- `[KANA_COLOR]` : couleur du kana, généralement ivoire
- `[DRAWING_COLOR]` : couleur unique de tout le dessin

## Prompt final

```text
Use case: stylized-concept
Asset type: Japanese kana mnemonic learning illustration

REFERENCE ROLE
The supplied images are STYLE REFERENCES ONLY. Reuse only their visual grammar:
one huge light-colored kana, one sparse single-ink mnemonic drawing cleverly
interlocked with the glyph, bold flat shapes, playful educational simplicity.
Do not reproduce any reference subject, caption, word, UI, navigation, status bar,
logo, or screenshot layout.

CARD VARIABLES
Exact kana: 「[KANA]」
Mnemonic object or character: [MNEMONIC]
Visual integration: [INTEGRATION]
Background ink: [BACKGROUND]
Kana ink: [KANA_COLOR]
Drawing ink: [DRAWING_COLOR]

PRIMARY REQUEST
Create one minimalist visual mnemonic in which the drawing is woven through and
around the exact kana 「[KANA]」. The mnemonic must explain or exploit the kana's
silhouette; it must not appear as a separate floating icon. Some drawing marks may
pass behind and in front of the kana, but must never replace, deform, disconnect,
or hide its real strokes. The kana must remain the largest element, structurally
exact, unmistakable, and instantly readable.

COMPOSITION
Portrait 4:5 canvas. One compact centered cluster occupying roughly 55–60% of the
canvas height, with generous empty margins. Use a large, thick, softly organic kana.
Keep the mnemonic sparse: one subject, roughly 8–15 simple marks or shapes, only the
details needed for immediate recognition.

STYLE
Minimalist flat mid-century educational vector illustration; naïve editorial line
art; clean screen-print aesthetic; bold organic geometry; charming and clever rather
than polished or realistic. Treat the artwork as a tiny rasterized SVG made only from
one full-canvas background rectangle, kana paths, and drawing paths. No effects.

STRICT COLOR SYSTEM
Use exactly three solid colors in the whole image, plus only unavoidable edge
antialiasing:
1. [BACKGROUND] for the completely uniform background;
2. [KANA_COLOR] only for every kana stroke;
3. [DRAWING_COLOR] only for every mnemonic drawing mark.

The drawing itself is strictly monochrome. Do not introduce black, white highlights,
secondary outlines, accent colors, tints, or transparent overlays. No gradient,
vignette, glow, lighting, shadow, shading, highlight, texture, paper grain, blur,
depth, color variation, or tonal transition. The background must have the same flat
RGB value from corner to corner.

GLYPH ACCURACY
Render one standard hiragana/katakana character: 「[KANA]」. Preserve its correct
stroke count, stroke topology, endpoints, crossings, loops, and recognizable
proportions. Keep every kana stroke thick, continuous, intact, and visually dominant.
The illustration is an annotation around the glyph, never a typographic substitute.

NO-TEXT RULE
The single central kana 「[KANA]」 is the only written glyph allowed anywhere.
No mnemonic word, Latin letter, caption, label, number, extra kana, pseudo-Japanese
mark, decorative typography, UI, border, logo, signature, or watermark.

AVOID
Photorealism, 3D, polished poster rendering, decorative background elements,
multiple subjects, busy detail, separate floating icon, outlined kana, fake kana
strokes, symbols that resemble additional writing.
```

## Tests réalisés

| Kana | Mnémotechnique | Résultat |
|---|---|---|
| `ぬ` | nouilles | Fusion kana/bol/nouilles, composition simplifiée après une itération |
| `ね` | nez | Profil et nez en une seule encre, attachés à la silhouette du kana |
| `ふ` | fou | Visage de fou et bonnet à grelots, test d'un kana à traits séparés |

## Réglage conseillé

Décrire explicitement l'interaction géométrique dans `[INTEGRATION]` améliore plus le
résultat qu'une longue description du style. Exemple : `place the profile on the left;
let the nose enter the kana's central negative space while all ivory strokes stay intact`.

Les générations de test respectent bien la mono-encre du dessin et l'absence de texte.
Le générateur peut néanmoins ajouter un très léger vignettage au fond malgré les
interdictions. Si un aplat RGB strict est requis en production, prévoir une validation
ou une normalisation du fond après génération.
