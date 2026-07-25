# Test V5 — せ / selle de cheval

```text
Use case: stylized-concept
Asset type: Japanese hiragana visual mnemonic

INPUT CONTRACT
Image 1 is the exact immutable white hiragana 「せ」 blueprint. Preserve its topology,
three visible stroke groups, crossings, spacing, endpoints, proportions and upright
orientation. Image 2 is style reference only; ignore all its UI and writing.

TARGET
Turn the exact white 「せ」 into the load-bearing structure of one horse saddle seen
from the side, with only a tiny broken fragment of a horse's back beneath it for
context. The saddle must not exist as a complete brick-red object behind the kana.

GEOMETRY-FIT DECISION
The two existing white uprights already occupy the correct positions for the raised
front pommel and rear cantle. The white crossbar already occupies the seat line. The
long lower white sweep and the inner white hook already occupy the positions of the
hanging leather, stirrup and saddle flap. Use these existing positions literally.

ABSOLUTE WHITE-PIXEL BUDGET
The supplied 「せ」 is the complete white layer. Create no other white pixel or white
shape anywhere. Never redraw, translate, rotate, crop, extend, cover or recolor it.

STROKE OWNERSHIP TABLE — LITERAL GEOMETRY
1. The long middle HORIZONTAL white stroke IS the saddle's seat and lower edge of its
   saddle blanket. The segment between the two uprights is the seat; its short
   overhangs are the blanket corners. Add a brick-red padded upper contour only ABOVE
   it. This red contour must terminate on the white stroke at both ends. Forbidden:
   any red lower seat edge or complete colored saddle seat.
2. The upper end of the LEFT white upright IS the front pommel. Add only a short red
   curved cap that terminates on its two sides. Forbidden: a second red pommel.
3. The upper end of the RIGHT white upright IS the raised rear cantle. Add only a
   short red curved cap attached to its sides. Forbidden: a second red cantle.
4. The descending LEFT white stroke IS the stirrup leather. Its long lower white
   sweep IS the load-bearing bottom bar of an exaggerated stirrup. Add only two red
   broken side arcs joining the vertical leather to that bottom bar. Forbidden: any
   complete red stirrup or parallel leather strap.
5. The descending RIGHT white stroke and its inward lower hook IS the front edge and
   bottom curve of the saddle flap. Add only a broken red outer flap contour whose
   endpoints touch the existing white hook. Forbidden: a complete red flap enclosing
   or replacing the white hook.

CONTACT GRAPH — REQUIRED
- Red seat padding touches the white crossbar at its left and right termination.
- Red pommel cap wraps the top endpoint of the left upright.
- Red cantle cap wraps the top endpoint of the right upright.
- Two red stirrup side fragments terminate on the white leather and white bottom bar.
- Red flap fragment terminates at both ends of the white inner hook.
- One thin broken red horse-back curve passes behind the saddle but remains visibly
  interrupted by the white saddle structure.

DEPTH
UNDER: only the small incomplete horse-back curve and a minimal blanket fill.
EXACT CHARACTER: the untouched white 「せ」.
OVER: only caps, attachment seams, two stirrup side fragments and one small buckle.

REMOVAL TEST
Hide all white pixels. What remains must be disconnected red fragments: two caps
without supports, padding without a seat edge, stirrup sides without leather or
bottom bar, and a flap outline missing its load-bearing edge. A complete saddle or
stirrup remaining in red is failure.

STRICT REJECTION GATES
- Any white shape outside the supplied 「せ」.
- A finished red saddle placed behind the kana.
- A red line parallel to the white seat, leather or hook.
- Caps floating above the white upright endpoints.
- The lower white sweep left as unused typography.
- A complete horse, rider, word, label or decorative icon.
- Any gradient, shadow, glow, lighting or additional color.

STYLE AND COLOR
Portrait 4:5, single centered pictogram occupying about 65% of the canvas. Flat,
hard-edged 1960s educational screen-print illustration, rounded, clever and sparse.
Exactly three solid colors: muted ochre background, warm white 「せ」, one dark saddle-
brown ink for every addition. No shading, texture, transparency effect, black or 3D.

NO TEXT
The single 「せ」 is the only written glyph. No word, Latin letter, number, other
Japanese character, UI, border, logo, signature or watermark.
```
