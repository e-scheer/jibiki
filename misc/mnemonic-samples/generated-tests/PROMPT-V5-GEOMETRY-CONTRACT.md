# Prompt V5 — geometry ownership contract

This version treats the Japanese character as a mandatory construction drawing, not
as text to decorate. The prompt is organized around physical ownership, contact
points and rejection tests.

## Improvements learned from the tests

1. **Geometry fit before semantics.** Reject an idea if a stroke must float, stretch
   or be duplicated to explain it. The role must already fit the stroke's location.
2. **One owner per physical part.** A part belongs either to a character stroke or to
   the drawing ink, never both.
3. **Literal bindings.** Write “the stroke IS the part”, not “resembles”, “suggests”,
   “overlaps” or “is near”.
4. **Contact graph.** Specify exactly which drawing fragment terminates, grips or
   wraps at each character endpoint or crossing.
5. **Character-layer budget.** The supplied character is the complete character
   layer. No illustration mark may leak into or extend this layer.
6. **Fragment-only additions.** Colored marks are incomplete contours, joints and
   identifiers. They may not contain a complete duplicate subject.
7. **Removal test.** Hiding the character must remove the target object's essential
   structure.
8. **Explicit rejection.** List likely visual shortcuts as failed outputs.
9. **Physical scale fit.** A long dominant stroke cannot represent a tiny buckle,
   fingertip or short stirrup bar. The assigned part must plausibly match the stroke's
   length, orientation and visual weight, otherwise the model will invent a duplicate.
10. **One semantic nucleus.** Context must not become a second large subject. If the
    mnemonic target is a saddle, do not introduce a horse whose silhouette competes
    with the character or encourages the model to use strokes as horse anatomy.
11. **Controlled expressivity.** Structural dependence does not mean sterile
    minimalism. Use facial acting, asymmetry, motion, tension and material details to
    make the mnemonic memorable, while keeping every structural contour fragmentary.

## Reusable prompt template

```text
Use case: stylized-concept
Asset type: Japanese character visual mnemonic

INPUT CONTRACT
Image 1 is the immutable character blueprint. Preserve its exact topology, stroke
placement, crossings, openings, endpoints and orientation. Other images are style
references only and must never override Image 1.

TARGET
Exact character: [CHARACTER]
Mnemonic object/action: [TARGET_SCENE]

GEOMETRY-FIT GATE — BEFORE RENDERING
Mentally inspect the supplied character. Confirm that every major stroke can perform
its assigned role at its existing location without moving, extending, duplicating or
covering it. If one role requires a parallel replacement stroke, reject the concept
before drawing.

PHYSICAL SCALE GATE
Compare each stroke's length and visual weight with its proposed physical role. A
dominant stroke must own a dominant part of the scene. Never assign a large stroke to
a small accessory and then compensate by drawing the real accessory elsewhere.

SINGLE-NUCLEUS GATE
The target object or action is the only large semantic subject. Context, if any, is
limited to tiny incomplete cues. Never split the character between two competing
subjects unless the mnemonic explicitly requires that interaction.

EXPRESSIVITY BUDGET
Create a worked, characterful mnemonic illustration rather than a bare icon. Include:
- one strong focal expression or physical reaction;
- two to four motion, tension, impact or environmental cues;
- three to six small material/anatomical details attached to assigned strokes;
- intentional asymmetry and one exaggerated gesture or silhouette feature.

These additions may pass in front of or behind the character, but they remain short
fragments, markings and contact points. They cannot close a second complete silhouette
or duplicate a physical part owned by the character.

Concentrate expressive density in eyes, mouths, joints, motion cues, splashes, impact
marks and surface details — not in large body fills. Preserve deliberate gaps between
outer-contour fragments so the subject cannot survive without the character layer.

CHARACTER-LAYER BUDGET
The supplied [CHARACTER] is the complete character layer. Generate no new pixels in
that layer outside its mask. Do not place highlights, eyes, clothing, anatomy,
objects, borders or decoration in the character layer.

STROKE OWNERSHIP TABLE — LITERAL GEOMETRY
[For every visual stroke group:]
- [STROKE LOCATION] IS [PHYSICAL PART].
- Allowed drawing fragments: [FRAGMENTS].
- Required contacts: [ENDPOINTS / CROSSINGS / GRIPS].
- Forbidden duplicate: [COMPLETE PART THAT MUST NOT BE DRAWN].

CONTACT GRAPH
[List every required physical junction between drawing ink and character strokes.]
Every important colored contour must start, stop, grip, wrap around, or be visibly
interrupted at one of these contacts. Proximity without contact is failure.

CONSTRUCTION ORDER
1. Lock the exact character.
2. Treat assigned character strokes as already-finished object parts.
3. Add only the missing UNDER fragments.
4. Add only the missing OVER contacts and identifiers.
5. Do not regenerate, trace or reinterpret the character.

REMOVAL TEST
Hide the character color. The mnemonic target must lose its essential load-bearing
parts and collapse into disconnected fragments. If the colored ink still contains a
complete generic target, reject and rebuild.

REJECTION GATES
- Topology gate: any changed, missing or invented character stroke fails.
- Ownership gate: any duplicated assigned physical part fails.
- Contact gate: any required contact that merely floats nearby fails.
- Coverage gate: any important unused character stroke fails.
- Independence gate: a complete colored subject without the character fails.
- Layer-isolation gate: background, exact character and illustration must remain
  cleanly separable masks with no cross-layer contamination. Exact preview hues are
  placeholders and are not a validation criterion because the application recolors
  each isolated layer according to its active theme.
- Text gate: any writing except the target character fails.

STYLE AND OUTPUT LAYERS
One large centered shared construction in an expressive mid-century educational
editorial-illustration style: bold, playful, slightly exaggerated, worked but still
immediately legible. Produce three logically isolated full-canvas layers with identical dimensions
and coordinates: BACKGROUND, EXACT_CHARACTER and ILLUSTRATION. Preview colors may be
convenient contrasting placeholders; the application applies theme-dependent color
overlays later. Layer separation and clean masks matter more than hue stability.
```
