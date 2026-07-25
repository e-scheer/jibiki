# Test V6 — せ / selle montée sur un cheval fragmentaire

```text
Use case: stylized-concept
Asset type: Japanese hiragana visual mnemonic

INPUT CONTRACT
Image 1 is the exact immutable warm-white 「せ」 blueprint. It is the entire white
layer. Preserve every stroke, crossing, endpoint, opening, proportion and position.
Image 2 is style reference only; ignore its text and UI.

TARGET
Build one side-view horse saddle mounted on a deliberately incomplete horse-body
fragment. The exact white 「せ」 must supply both the saddle's load-bearing geometry
and the large underside of the horse. Add only dark saddle-brown fragments.

GEOMETRY AND SCALE FIT
The middle crossbar has the right length and height to be the saddle seat. The two
upper prongs have the right position to support pommel and cantle. The inner J hook
has the right size for saddle flap and stirrup. The very long lower stroke is far too
large to be a stirrup, so it must own a large anatomical role: the horse's chest and
belly contour.

ZERO-NEW-WHITE RULE
The supplied 「せ」 is every white pixel permitted in the image. Create no other white
mark, fill, highlight, stirrup, horse part or decoration.

STROKE OWNERSHIP TABLE
1. The middle white HORIZONTAL crossbar IS the rigid lower edge of the saddle seat.
   Add one brown padded seat contour only above the segment between the uprights. Its
   endpoints must touch that white stroke. No parallel brown lower seat line.
2. The upper LEFT white prong IS the front pommel support. A small brown pommel cap
   wraps its endpoint. The upper RIGHT white prong IS the rear cantle support. A
   slightly taller brown cantle cap wraps its endpoint. Neither cap may float.
3. The RIGHT descending white stroke and inward J hook IS the saddle's side flap and
   hanging stirrup. Add only one tiny brown buckle around the vertical segment and two
   short brown leather seams that terminate on the white hook. Draw no separate
   stirrup, strap, flap outline or white accessory.
4. The LEFT white stroke below the seat IS the horse's front chest contour. Its long
   lower white sweep IS the horse's belly contour continuing toward the hindquarters.
   Add only a broken brown neck/shoulder contour at the left and a broken brown rear-
   haunch contour at the right endpoint. Never draw a complete horse body around it.
5. The short portions of the middle white crossbar outside the uprights ARE the two
   visible corners of the saddle blanket. Add only tiny brown triangular folds above
   them; no complete colored blanket.

CONTACT GRAPH
- Seat padding terminates on the white crossbar at both ends.
- Pommel and cantle caps wrap their exact white endpoints.
- Brown buckle wraps the right white vertical; brown seams terminate on the J hook.
- Broken horse shoulder touches the descending left white stroke.
- Broken rear haunch touches the far-right endpoint of the lower white belly sweep.
- Blanket folds touch the two white crossbar overhangs.

REMOVAL TEST
Hide white 「せ」. Brown ink must become fragments: seat cushion with no supporting
edge, caps with no supports, buckle with no flap or stirrup, and horse fragments with
no chest or belly. No complete saddle, stirrup or horse may remain.

REJECT IF
- Any new white shape appears, especially a separate white stirrup.
- The long lower white sweep is unused or assigned to a tiny accessory.
- A complete brown saddle or horse is visible without the glyph.
- Any required contact floats nearby instead of touching.
- Any glyph stroke changes or becomes hidden.
- Any text, extra glyph, gradient, glow, shadow, texture or additional color appears.

STYLE AND COLOR
Portrait 4:5, one centered construction, 65% of canvas. Flat hard-edged 1960s
educational screen-print pictogram. Exactly three uniform solid colors: muted ochre
background, original warm white 「せ」, one dark saddle-brown for every addition. No
lighting, shading, gradient, texture, black, transparency effect or 3D.

NO TEXT
Only 「せ」. No word, Latin letter, number, extra Japanese glyph, UI, logo or watermark.
```
