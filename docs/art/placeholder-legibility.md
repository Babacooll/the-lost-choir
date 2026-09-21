## Placeholder legibility layer — throwaway, delete on asset arrival

> **This document is not art direction.** It describes a scaffold that exists so the
> vertical slice can be playtested against untextured blockout geometry. Nothing in it
> may be cited as precedent, inherited into a finished asset, or copied into
> `docs/art/vertical-slice-art-direction.md`. It is deleted, whole, when the Aseprite
> assets in `docs/art/aseprite-handoff.md` land. See **Deletion** at the bottom.
>
> Scope: `MICH-613`. Authored by Art Direction on 2026-09-21 against the failed
> playtest `MICH-578`. It changes no palette value and no shader constant.

### 1. What is actually broken

Every visual in the slice is an untextured `Polygon2D`. `assets/art/` holds a `.gitkeep`
and nothing else. The cold-derive in `shaders/cold_warm.gdshader` is correct and is not
the fault: desaturating 72% and pulling 18% toward `#39424f` is a transform that expects
texture, material and internal value structure to be carrying the separation. Applied to
flat fills there is no other channel left doing the work, so seven elements collapse into
one desaturated band.

Measured in the cold state as rendered, against the two grounds every element sits on:

| element | vs terrain solid | vs backdrop |
|---|---:|---:|
| Player (the Listener) | 1.75:1 | 7.63:1 |
| Reed Husk | 2.11:1 | 2.07:1 |
| Keening Husk | 2.39:1 | 1.82:1 |
| Verse-bearer (R6) | 2.68:1 | 1.63:1 |
| Bell-frame | 1.73:1 | 2.52:1 |
| Membrane (α 0.85, composited) | 2.26:1 | 1.52:1 |
| Gated door | 1.75:1 | 2.49:1 |
| Open door (α 0.35, composited) | 1.02:1 | 1.77:1 |

3.0:1 is the WCAG 2.1 SC 1.4.11 floor for non-text graphics. Nothing clears it against
either ground. The one strong relationship on screen is terrain-vs-backdrop at 4.35:1 —
the architecture is legible and everything the player must act on is not.

### 2. Why no flat fill can fix this

The two grounds are **4.35:1 apart**. Clearing 3:1 against both ends of a band requires
**9:1 of band**. There is not enough band, and no choice of colour changes that:

- lighter than the terrain solid needs relative luminance ≥ **1.0189** — the brightest
  colour that exists is 1.0000;
- darker than the backdrop needs relative luminance ≤ **−0.0227** — the darkest colour
  that exists is 0.0000;
- between the two needs ≥ 0.1955 **and** ≤ 0.0688 — an empty interval.

Pure white, the best a flat fill can possibly do, reaches **2.95:1** against the terrain
solid. `python3 tools/art/legibility_check.py --why` prints this bound from the live
constants.

So the element cannot be one value. It has to be two.

### 3. The construction

**Every gameplay element is a fill plus a hard contour.** The fill carries identity; the
contour carries separation. Against either ground, at least one of the two values clears
3:1 by a wide margin, so the element's boundary is perceivable on both — which is what
the floor is actually for.

Rules, all of them non-negotiable for the layer to pass its gate:

1. **Contour width 2 px**, uniform, no anti-aliasing, drawn outside the fill polygon so
   it does not eat the collision silhouette. At the slice's 1:1 pixel scale (1152×648
   viewport, no camera zoom) that is ~11% of the 18 px-wide player. It is meant to look
   crude.
2. **Every fill is fully opaque.** The membrane's α 0.85 and the open door's α 0.35 are
   overridden to 1.0 for the duration of this layer — a composited fill is a fill whose
   contrast depends on what is behind it, which is exactly the failure being fixed.
3. **No element runs the cold-derive.** The layer is state-independent by construction:
   `WarmthVisual` drops its `ShaderMaterial` while the layer is on. This is why the
   table below holds in the warm state too, which matters because R7/R8 are authored
   warm-on-first-sight (art doc §4.3) and a playtester reaches them.
4. **Every colour here is deliberately outside `docs/art/palettes/lost-choir-slice.json`.**
   A placeholder colour that could be mistaken for a palette entry is a bug.
5. **Nothing may composite a covered element while the layer is on.** No `modulate`, no
   `self_modulate`, no non-opaque alpha, no blend mode. `modulate` inherits down the tree,
   so a dim applied to a parent washes out the fill *and* the contour together and takes
   the whole construction with it — see §7's note on `Door._refresh_visual()`, which is
   exactly this failure and cost a round.
6. **The contour shares its fill's z-index.** It draws behind the fill by tree order
   (`show_behind_parent`), not by sinking to a lower z. A contour at `z_index = -1` falls
   below the terrain solids at z 0, so it is painted over wherever an element overlaps
   terrain — which is precisely where it is the only value clearing the floor.

### 4. The table

| element | fill | contour | vs solid | vs backdrop | fill vs contour |
|---|---|---|---:|---:|---:|
| Player (the Listener) | `#ffffff` | `#000000` | 7.13:1 | 12.83:1 | 21.00:1 |
| Reed Husk | `#ff4a3a` | `#000000` | 7.13:1 | 3.84:1 | 6.29:1 |
| Keening Husk | `#35d6ff` | `#000000` | 7.13:1 | 7.46:1 | 12.21:1 |
| Verse-bearer (R6) | `#ffe14a` | `#000000` | 7.13:1 | 9.85:1 | 16.12:1 |
| Bell-frame | `#b06fff` | `#000000` | 7.13:1 | 4.01:1 | 6.56:1 |
| Membrane | `#3cff7d` | `#000000` | 7.13:1 | 9.65:1 | 15.79:1 |
| Gated door | `#ff44ab` | `#000000` | 7.13:1 | 4.07:1 | 6.67:1 |
| Open door | `#05060a` | `#ff44ab` | 6.87:1 | 4.07:1 | 6.43:1 |

Lowest margin in the table is 3.84:1 — 28% clear of the floor, not 2.9.

## 4b. The silhouette contract — criteria 6–8

Added 2026-09-21 by amendment. Contrast made the slice *visible*; it did not make it
*identifiable*. Every actor was the same axis-aligned rectangle within 4 px of width and
8 px of height, so four bright sticks still told a player nothing about which one they
were or which were dangerous. Numbered `4b` rather than inserted as a new §5 because the
section numbers in this document are referenced from code comments in
`scripts/art/placeholder_legibility.gd`, `scripts/art/warmth_visual.gd` and
`scripts/levels/door.gd`, and renumbering would silently falsify all of them.

Same fencing as the contour, for the same reason: **throwaway, deleted with the layer,
establishes nothing.** The shapes below are deliberately crude angular primitives. The
approved direction's silhouette grammar is "rounded and resonant — bell curves, horn
bells, larynx curvature — never angular, segmented, chitinous"; these are angular *on
purpose*, exactly as the contour is a forbidden motif on purpose. A scaffold built from
what the direction rules out cannot be inherited by accident.

### The rules

| | rule | applies to |
|---|---|---|
| **S0** | No actor or interactable is an axis-aligned rectangle. Terrain and backdrop keep theirs. | all six classes |
| **S1** | Pairwise bounding-box aspect ratios differ by ≥ 1.25× | all six classes |
| **S2** | Pairwise fill ratios (silhouette area ÷ bbox area) differ by ≥ 0.12 | the four actor classes |
| **S3** | The two husks are exempt from S2 and must *share* a fill ratio — same primitive, different proportions | Reed + Keening |
| **S4** | The player is the only asymmetric **actor** class | the four actors |
| **S5** | All classes flattened to solid black on white must be tellable apart by a human | the contact sheet |

**Doors are exempt from S0.** A door is architecture; it is rectangular because it is an
opening in a wall, and §4's two constructions already carry its state distinction
structurally.

**Collision shapes are frozen.** Every polygon here is visual only. Hitboxes, reach and the
420 ms compression floor are approved tuning. A visual that overhangs its collider is
accepted — it is one more thing that makes the scaffold obviously temporary.

**S4's scope is the actor classes.** The bell-frame and the membrane are asymmetric too,
deliberately: art doc §9.1 requires the membrane's sag to be off-centre because "a centred
circular depression … reads as a hole", and §9.2 specifies tubes of *stepped* length. That
does not weaken S4, whose job is that the player survives a value-only and a colour-blind
read against the things it could be confused with — and nothing shares an aspect-ratio band
with a 64 × 10 horizontal strip. The gate checks this rather than asserting it.

**No attack telegraphy.** Static idle silhouettes only: nothing that changes on wind-up and
nothing that flashes. H2 and H6 test whether the *audio* tell carries the fight, and that
hypothesis is falsified by a good visual wind-up more easily than by anything else.

### The shapes

Visual polygons in `.tscn` units, origin at the element's own anchor, y negative is up.

| class | bbox | ratio | fill | the read |
|---|---|---:|---:|---|
| Player (the Listener) | 24 × 40 | 0.600 | 0.812 | upright wrapped column with a one-sided shoulder yoke — the only asymmetric thing on screen |
| Reed Husk | 32 × 22 | 1.455 | 0.656 | squat wedge, wide rooted base, short taper |
| Keening Husk | 18 × 48 | 0.375 | 0.667 | the same wedge drawn long — narrow, rooted, a long taper |
| Verse-bearer | 40 × 38 | 1.053 | 0.434 | flared mouth carried on two ribs, with real negative space beneath |
| Bell-frame | 48 × 14 | 3.429 | 0.536 | tuned tubes of stepped length hanging mouth-down from a yoke |
| Membrane | 64 × 10 | 6.400 | 0.700 | slack skin, sag off-centre |

```
player        (-9,0) (-9,-40) (9,-40) (9,-30) (15,-30) (15,-20) (9,-20) (9,0)
reed_husk     (-16,0) (-5,-22) (5,-22) (16,0)
keening_husk  (-9,0) (-3,-48) (3,-48) (9,0)
verse_bearer  (-20,0) (-20,-18) (-16,-18) (-8,-38) (8,-38) (16,-18) (20,-18) (20,0)
              (15,0) (15,-18) (-15,-18) (-15,0)
bell_frame    (-24,-6) (24,-6) (24,-2) (20,-2) (20,2) (12,2) (12,-2) (4,-2) (4,5)
              (-4,5) (-4,-2) (-12,-2) (-12,8) (-20,8) (-20,-2) (-24,-2)
membrane      (-32,-4) (32,-4) (32,0) (-10,6) (-32,0)
```

### Why these shapes and not others

**The husk pair is one primitive at two proportions, and both taper toward the aperture.**
Art doc §7.2's rule is "short aperture = short note = short lead; long aperture = long note
= long lead" — so the taper length *is* the note length, and the silhouette teaches the same
rule the audio does. Both keep the chamber low and the base rooted, per §7.2's "rooted:
frame members fuse into a base that meets the floor as one mass". They separate on S1 alone
(3.88×) and share a fill ratio to within 0.010, which is S3's both-halves: visibly kin
*because* the primitive is identical, separately recognisable *because* the proportion is not.

**The player's asymmetry is a shoulder yoke, not a head protrusion.** Art doc §6 makes "no
ears" an explicit rejection criterion at the critic gate, and a protrusion at the crown reads
as an ear or a horn before it reads as anything else. The yoke sits at shoulder height, is
equipment rather than anatomy, and §6 already names "frame = the shoulder yoke" as part of
the Listener's approved three-mass read. It spends no identity.

**The Verse-bearer's ribs protrude past the chamber and the mouth stands clear of the
ground.** Those are art doc §8's two stated geometric requirements, and the negative space
beneath the mouth is what makes the third mass legible in black fill. The scaffold carries
the mass distribution and the gap; it does not attempt §8's rib-versus-chamber separation,
which is a 64 × 72 finished-art requirement a 40 px blockout cannot hold.

**The bell-frame's tube gaps are 8 px wide.** At 4 px they would close: a 2 px contour on
each side of a gap consumes it entirely and the comb renders as a solid bar with black
stripes. 8 px leaves 4 px of background visible between tubes.

**The membrane's sag is off-centre.** Art doc §9.1: "off-centre and asymmetric — deepest
point ~⅓ across, never at the middle", because a centred depression reads as a hole.

### The contour mechanism has to change

`PlaceholderLegibility._expand()` offsets each vertex away from the centroid, per axis. Its
own comment says that is exact "for axis-aligned rectangles" and "not a general
polygon-offset for arbitrary shapes" — which was true and is now a defect, because none of
these shapes is a rectangle. On a sloped edge it produces a contour thinner than 2 px
perpendicular; at a concave vertex it offsets in the wrong direction entirely.

Replace it with a **closed `Line2D` of width `2 × CONTOUR_WIDTH` centred on the silhouette
outline**, `show_behind_parent = true`, sharp joints, anti-aliasing off. Exactly half the
stroke lies outside the fill and the fill covers the inner half, so the visible contour is
2 px on any polygon, convex or concave, with no offset maths to get wrong. Doors keep the
same mechanism — one construction for everything.

### The gate

```
python3 tools/art/legibility_check.py --silhouette           # S0–S3
python3 tools/art/legibility_check.py --contact-sheet o.png  # S5, black on white
```

S0–S3 are the cheap numeric proxy. **S5 — the contact sheet — is the actual gate**, and a
human looks at it. The sheet renders every class as solid black on white with no colour and
no contour, at slice scale and at 4×, because nobody can judge an 18 px shape on a modern
display.

### 5. Identity

The player is the only achromatic element and the brightest thing on screen. The two
husks sit at opposite ends of the hue circle (red 8°, cyan 191°) *and* 1.94:1 apart in
value, so they separate under a value-only read as well as a hue read — `H6` asks whether
players build one mental model across both, which first requires telling them apart.

The doors are one class in two states: gated is a solid magenta block, open is a dark
hole in a magenta frame. Same hue, inverted construction — the scheme reads as "wall"
versus "opening" before any colour is decoded.

The bell-frame and the Verse-bearer are brass in the real direction. They are not brass
here. Identity in this layer is hue-as-label only and carries no material meaning.

### 6. The contour is a forbidden motif, on purpose

`docs/art/vertical-slice-art-direction.md` §2 forbids "crisp ink outlines, uniform 1-px
contour lines", and §5 says "value step, not contour"; the approved creative direction
says "edges are painterly and textured … not crisp ink outlines". A uniform hard contour
is precisely the thing this project's visual language rules out.

That is the point, and it is why this is safe to ship as a scaffold. The layer is built
out of a motif the critic gate rejects on sight, so it cannot be quietly inherited into a
finished asset and cannot be mistaken for a direction anybody approved. Its ugliness is
load-bearing.

Nothing here establishes line/edge treatment, palette, or material language. If a later
asset arrives with a uniform contour, the answer is no, and this document is not a
precedent for it.

### 7. Implementation contract

For whoever builds this — it is engine integration, not asset production.

- One new script owns the table and the toggle. Elements declare a **role**; the layer
  resolves role → (fill, contour). No element hard-codes a placeholder colour.
- **Do not modify** `docs/art/palettes/lost-choir-slice.json`, `tools/art/build_palette.py`,
  or any constant in `shaders/cold_warm.gdshader`. The layer switches the material off; it
  does not change what the material does.
- The toggle is a single flag. With it off, the build renders exactly as it does today —
  the slice's existing behaviour must remain reachable, because the cold/warm contract in
  art doc §4.4 and `tools/art/warmth_check.py` is measured against the derived scene, not
  against this one.
- `tools/art/warmth_check.py` must still pass with the layer **off**. It is expected to
  fail with the layer on; that is not a regression, it is two different scenes.
- Elements to cover: player, Reed Husk, Keening Husk, Verse-bearer, bell-frame, membrane,
  gated door, open door. Nothing else. Terrain and backdrop keep the derive.
- **`Door._refresh_visual()` sets `visual.modulate.a = 0.55` on a gated door.** That dim
  predates this layer and must survive its deletion, but it cannot apply while the layer
  is on: it multiplies into both the fill and the contour and drops the gated door to
  1.78:1 against the backdrop. Suppress it for the layer's lifetime, do not delete it. The
  gated/open distinction is already carried by the two constructions in §4 — solid block
  versus dark hole in a bright frame — so nothing is lost by holding the alpha at 1.0.
- Anything else that later wants to tint, fade or flash a covered element (hit flashes,
  death fades, gating states) hits the same wall. While the layer is on, those effects
  have to route around the fill colour or be suppressed.

### 8. The gate

```
python3 tools/art/legibility_check.py                      # the table gate; exit 0 = pass
python3 tools/art/legibility_check.py --why                # the flat-fill impossibility bound
python3 tools/art/legibility_check.py --frame shot.png ... # the rendered-frame gate
```

The **table gate** mirrors the shader's cold-derive and re-derives every ratio in §4 from
the live `room.gd` ground colours, so the table above is checked rather than asserted. It
covers G1 (vs terrain solid), G2 (vs backdrop), G3 (fill vs its own contour) and G4
(mutual distinguishability), in the cold state and the warm one.

The **rendered-frame gate** grades real pixels, and it exists because the table gate is
not enough. A table gate cannot see a `modulate`, an alpha, a material or a z-order; the
first implementation of this layer passed the table gate at a claimed 4.07:1 while the
gated door was actually on screen at 1.78:1. `--frame` asserts the invariant that makes a
flat-fill placeholder scene checkable at all: **every pixel is either a ground colour or a
colour from §4's table.** A third colour means something is compositing an element, and it
names the colour, its area, and its real ratios. Both gates must pass, and the frame gate
must be run on a room containing each covered element — a frame that does not contain an
element says nothing about it.

A passing gate is a floor, not a verdict. The human read — can a playtester who has never
seen the slice tell the player from a husk, and a gated door from an open one — is a
separate and non-negotiable check.

### 9. Deletion

This layer is done when `assets/art/` has real sprites. Deleting it is:

1. remove the placeholder script and every `role` declaration that feeds it;
2. remove `tools/art/legibility_check.py`;
3. remove this file, and the contact sheet if one was committed;
4. restore the original fills and alphas listed in §1, and the original rectangular
   visual polygons the actors had before §4b;
5. restore `Door._refresh_visual()`'s gated dim by deleting its early return;
6. confirm `tools/art/warmth_check.py` still passes.

If step 4 is ever hard to perform because production drifted onto these colours, the
layer outlived its licence and that is the bug.
