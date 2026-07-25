# Test V7 — せ / selle western isolée

```text
Use case: stylized-concept
Asset type: Japanese hiragana visual mnemonic

INPUT CONTRACT
Image 1 is the exact immutable warm-white 「せ」 and the entire permitted white layer.
Image 2 supplies only sparse flat educational style. Ignore its UI and writing.

ONE SEMANTIC NUCLEUS
Create one isolated western horse saddle seen exactly from the side. No horse, rider,
stable, ground, rope, text or scenery. The saddle must be physically incomplete
without the exact white 「せ」.

ZERO-NEW-WHITE RULE
Preserve every supplied white pixel and create zero new white pixels. Never redraw,
cover, translate, distort, rotate, extend or reinterpret the glyph.

STROKE OWNERSHIP TABLE
1. The middle white horizontal stroke IS the complete load-bearing lower edge of the
   saddle seat and blanket. Add one brown concave padded seat contour only above the
   segment between the uprights. It must terminate directly on the white line at both
   ends. No brown lower edge and no second seat.
2. The left white upright above the seat IS the front pommel and saddle-horn support.
   Add a small brown horn-shaped cap wrapping its endpoint. The right white upright
   above the seat IS the raised rear cantle support; add one taller brown curved cap
   wrapping its endpoint. No floating or duplicate supports.
3. The left white stroke below the seat and its long lower sweep IS the dominant
   lower edge of the large leather saddle skirt/fender. Add only two disconnected
   brown outer leather contours: one starts at the left white crossbar overhang and
   stops on the descending white stroke; the other starts near the curve and stops at
   the far-right endpoint of the lower white sweep. Never close a complete brown
   fender around it.
4. The right white descending stroke and inward J hook IS the near-side stirrup
   leather and the load-bearing inner/bottom edge of the stirrup. Add one small brown
   buckle around the vertical section and only two short brown outer stirrup arcs
   whose endpoints terminate on the white J hook. No separate complete stirrup.
5. The white crossbar overhangs ARE the visible corners of the saddle blanket. Add
   only one small brown triangular fold touching each white endpoint.

CONTACT GRAPH
- Brown seat contour touches the white crossbar at two endpoints.
- Brown horn and cantle caps wrap their white upright endpoints.
- Both broken fender contours terminate on the long lower white stroke.
- Brown buckle wraps the right white vertical.
- Two brown stirrup arcs terminate on the white J hook.
- Brown blanket folds touch the left and right crossbar endpoints.

SILHOUETTE AND REMOVAL TEST
With white visible, the combined construction reads immediately as one western
saddle. Hide white: brown ink becomes unrelated fragments — caps without supports,
seat padding without a base, fender fragments without a lower edge, buckle and arcs
without a stirrup. A complete brown saddle or stirrup is failure.

REJECT IF
- Any horse or second subject appears.
- Any new white shape or accessory appears.
- Any complete brown seat, fender, blanket or stirrup exists independently.
- Any brown line duplicates a white load-bearing edge.
- Any contact floats near rather than touching the assigned white stroke.
- Any glyph stroke changes, disappears or becomes hidden.
- Any text, extra glyph, gradient, glow, shadow, texture or extra color appears.

STYLE AND OUTPUT LAYERS
Portrait 4:5, isolated centered pictogram occupying 60–65% of canvas, generous empty
margin. Flat hard-edged 1960s educational screen-print style, bold rounded geometry,
clever and sparse. Keep three logically isolated, perfectly aligned layers:
BACKGROUND, EXACT_WHITE_せ and SADDLE_ADDITIONS. Their preview colors are only
high-contrast placeholders; the application recolors each layer according to its
theme. Never place saddle pixels in the character layer or character pixels in the
saddle layer.

NO TEXT
Only 「せ」. No words, Latin letters, numbers, other glyphs, UI, logo or watermark.
```
