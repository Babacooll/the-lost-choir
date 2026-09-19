# Vertical-slice art direction — "The Cold Amphitheater"

Owner: Art Director. Status: **slice-scoped**, not canonical.

This document establishes the minimum art direction the first vertical slice exercises, and
nothing more. It is deliberately **not** the art bible. Every rule below is written so it
composes upward into `docs/art/ART_BIBLE.md` when that document is written, rather than
pre-empting it: rules here constrain eight rooms, two enemies, one Verse-bearer and one
provisional protagonist read, and they claim authority over nothing outside that set.

It answers to `docs/creative-direction.md` (approved pillars) and
`docs/design/vertical-slice.md` (approved playable contract). Where those two speak, this
document translates rather than decides. Section 12 records every place it had to interpret.

**Slice-scoped means:** a rule here may be generalised into the bible later, contradicted by
the bible later, or thrown away with the slice. None of it is settled art direction, and
nothing here is a precedent that a future asset can cite as "already approved."

---

## 1. Technical frame

Fixed by `ARCHITECTURE.md` and §2 of the design spec. Restated because every asset decision
below depends on it.

| Property | Value |
|---|---|
| Tile | 16 × 16 px |
| Render scale | ×3, integer only — never a fractional zoom |
| Authoring tool | Aseprite (`.aseprite` is the source; `.png` is a build output) |
| Level authoring | LDtk, imported to Godot |
| Animation | Frame-based sprite sheets, no rigged deformation |
| Colour | Indexed to the slice palette (§3). No off-palette pixel ships. |
| Alpha | 1-bit. No partial alpha in sprite or tile art — soft light is the lighting layer's job, not the pixels' |
| Player collider | 18 w × 40 h px, origin at feet |

**Pixel grid law.** All sprite and tile art is authored on the 1:1 pixel grid and displayed at
×3. No rotation, no non-integer scaling, no sub-pixel sprite positioning in the art layer. A
sprite that needs to rotate is authored as discrete frames. This is not a style preference —
mixed-density pixels are the single most common way a painterly 2D game starts to look cheap.

### File layout and naming

```
art/
  sprites/
    listener/      listener_idle.aseprite, listener_idle.png, ...
    husks/         reed_husk_tell.aseprite, keening_husk_tell.aseprite, ...
    versebearer/   versebearer_cold.aseprite, versebearer_restore.aseprite, ...
    props/         membrane_slack.aseprite, bellframe.aseprite, ...
  tiles/           tileset_stone.aseprite, tileset_colonnade.aseprite, ...
  ui/              hp_mark.aseprite, breath_arc.aseprite
docs/art/
  vertical-slice-art-direction.md        <- this document
  palettes/lost-choir-slice.gpl          <- Aseprite palette, warm (source of truth)
  palettes/lost-choir-slice-cold.gpl     <- derived, do not hand-edit
  palettes/lost-choir-slice.json         <- machine-readable pairs + transform constants
tools/art/
  build_palette.py                       <- regenerates the two derived palette files
  warmth_check.py                        <- §8 numeric acceptance gate
```

Naming: `snake_case`, `<subject>_<state>[_<variant>].aseprite`. States use the vocabulary this
document defines (`cold`, `warm`, `idle`, `tell`, `attack`, `stagger`, `slack`, `taut`), not
free-form words, so an asset's state is greppable.

---

## 2. Shape grammar and silhouette law

The approved pillar is **Architecture of Resonance**: the world reads as an instrument, not a
hive. For the slice that resolves into four hard rules.

**R1 — Curvature before angle.** Every primary form is built from an arc whose centre lies
*inside* the form: bell curves, horn bells, larynx curvature, drum-skin discs, catenary sag.
Straight edges exist only where something was *cut* by a tool or *broken* — never as the
natural resting shape of a thing. A form whose dominant read is a straight line or a hard
corner is wrong by default and needs a cut or a fracture to justify itself.

**R2 — Three-mass rule.** Every character-scale silhouette resolves into exactly three legible
masses at a glance: a **chamber** (the resonating volume), a **frame** (what holds it), and an
**aperture** (where sound leaves). This is the grammar that makes the Listener, both husks and
the Verse-bearer read as one world. It is also what makes the two husks read as *one rule with
two values* rather than two unrelated monsters (§7) — the slice's H6 lives or dies here.

**R3 — Silhouette test.** Fill the sprite 100% black, view at ×1 (i.e. 1/3 of display size),
and it must still be identifiable as which entity it is. If two entities are confusable under
that test, the one with less claim to the shape changes. Run this before any interior detail is
painted; detail cannot rescue a silhouette.

**R4 — Detail lives in wear, not in line.** No crisp ink outline anywhere. Forms separate from
each other by **value step**, not by a drawn contour. The minimum legible separation between a
subject and what is behind it is **two palette steps of value** (e.g. `ST3` subject against
`ST1` ground). Interior detail is surface history — chips, oxidation crust, wax runs, hairline
cracks, polish worn through to bare metal — not hatching or panel lines.

### Forbidden motifs (slice-scoped, enforced at the critic gate)

Drawn from the approved direction's explicit exclusions, plus the failure modes this palette
and pipeline are most likely to drift into:

- Insect anything: chitin, exoskeleton segmentation, mandibles, compound or bead eyes, wings,
  carapace sheen, thorax/abdomen division.
- Hollow Knight's specific language: the pale masked face, the two-horn head silhouette, cloak
  with a torn scalloped hem, ink-wash rendering, the black-void-with-white-eyes read.
- Crisp ink outlines, uniform 1-px contour lines, cel-shaded hard terminators.
- Skulls, ribcages read as ribcages, and generic bone-gothic ossuary dressing. Our creatures are
  *instruments that died*, not *bodies that died*. A rib-like form must first be a frame member.
- Literal readable sheet music, real clefs, real staves, real notation glyphs. Our etchings are
  calligraphic wave forms that *rhyme* with notation, and are never transcribable.
- Neon, magenta/cyan, chromatic aberration, lens flare, digital glitch, holographic UI.
- Any glow that is not sourced from a seam, a lit brass surface, or a named light in the scene.
- Filling empty space with decoration. §6 of the design spec: "No room may be decorated to look
  complete."

---

## 3. Palette

One palette, 32 colours, used by every asset in the slice. It is indexed, it is small on
purpose, and it is the reason eight rooms authored by different hands will still look like one
place.

The **warm column is the source of truth** — it is the true material colour of every surface.
The **cold column is derived, never authored** (§4). `tools/art/build_palette.py` regenerates
both `.gpl` files and the `.json`; hand-editing the derived files is how a slice ends up with a
transition that does not match its own shader.

ΔW below is the warmth delta `(R−B)/255` between the warm and cold value — it is how much of
the cold→warm lever each colour actually carries.

**Stone — amphitheatre travertine**

| id | role | warm | cold | ΔW |
|---|---|---|---|---|
| `ST0` | deepest crevice | `#3b2f28` | `#303237` | +0.102 |
| `ST1` | shadow | `#5a4638` | `#42454b` | +0.169 |
| `ST2` | body | `#806450` | `#5a5d65` | +0.231 |
| `ST3` | lit face | `#a8876b` | `#757982` | +0.290 |
| `ST4` | rim / chipped edge | `#cbae8c` | `#9097a2` | +0.318 |

**Wax-plaster (candle-wax cream)**

| id | role | warm | cold | ΔW |
|---|---|---|---|---|
| `WX0` | shadow | `#8d7a5e` | `#676d75` | +0.239 |
| `WX1` | body | `#bda880` | `#89919a` | +0.306 |
| `WX2` | lit | `#ded0a8` | `#a3b0bd` | +0.314 |
| `WX3` | highest value in the kit | `#f4ecd0` | `#b6c5d8` | +0.275 |

**Terracotta**

| id | role | warm | cold | ΔW |
|---|---|---|---|---|
| `TC0` | shadow | `#5c2b1f` | `#383337` | +0.235 |
| `TC1` | body | `#8c3f2a` | `#4f464a` | +0.365 |
| `TC2` | lit | `#b85a35` | `#675d60` | +0.486 |
| `TC3` | rim | `#d98149` | `#817a7c` | +0.545 |

**Bronze / verdigris**

| id | role | warm | cold | ΔW |
|---|---|---|---|---|
| `BZ0` | shadow | `#2f3a33` | `#30383e` | +0.039 |
| `BZ1` | body | `#4d6152` | `#49555d` | +0.059 |
| `BZ2` | verdigris bloom | `#6f8f74` | `#667781` | +0.086 |
| `BZ3` | verdigris lit crust | `#9dbfa2` | `#889daa` | +0.114 |

**Husk (frame and membrane)**

| id | role | warm | cold | ΔW |
|---|---|---|---|---|
| `HK0` | frame shadow | `#2b2621` | `#272a2f` | +0.071 |
| `HK1` | frame body | `#4f453a` | `#3f4349` | +0.122 |
| `HK2` | membrane dried | `#7c6d5a` | `#5d636b` | +0.188 |
| `HK3` | membrane lit / taut | `#b2a288` | `#838c98` | +0.247 |

**Void**

| id | role | warm | cold | ΔW |
|---|---|---|---|---|
| `VD0` | interior black | `#14161c` | `#1a1d23` | +0.004 |
| `VD1` | near-black | `#23262f` | `#252a32` | +0.004 |
| `VD2` | ambient floor | `#333a47` | `#323944` | −0.008 |

**Brass / gold — the "sound is alive" accent**

| id | role | warm | cold | ΔW |
|---|---|---|---|---|
| `BR0` | deep seat | `#4a3312` | `#2f2a20` | +0.161 |
| `BR1` | shadow | `#7d5a1d` | `#514936` | +0.271 |
| `BR2` | body | `#b98c2c` | `#7a7153` | +0.400 |
| `BR3` | lit face | `#e0b849` | `#999371` | +0.435 |
| `BR4` | specular — **legal only where `w > 0`** | `#ffe9a3` | `#b7b9aa` | +0.310 |

**Seam — emissive only, no cold counterpart**

| id | role | warm |
|---|---|---|
| `SM0` | outer bleed | `#ff9a3c` |
| `SM1` | body | `#ffc75e` |
| `SM2` | core | `#fff2c4` |

In the cold state the crack is not a dim seam — it is a **hole**, authored with `VD0`/`VD1`.
The seam colours do not exist until restoration. This is the difference between "the light is
turned down" and "there is no light yet," and it is the whole point of §7 of the design spec.

### Usage rules

- **Brass budget.** Brass occupies **≤ 4% of the pixels** of any authored screen. It is the
  accent that means *sound is alive*; at 10% it means nothing. `warmth_check.py` enforces the
  ceiling from the cold-state side (≤ 6% of pixels above the chroma floor, and that share must
  be brass).
- **`BR4` and `SM0–2` are emissive colours.** They may not appear in a cold-state authored
  asset at all. An artist who needs a bright accent in the cold state has misread the brief.
- **`WX3` is the value ceiling.** Nothing non-emissive goes brighter. It exists to make the one
  or two chipped plaster edges per room sing; used as a fill it flattens the whole kit.
- **No ramp jumping.** Shade within a family (`ST0→ST1→ST2`). Crossing families mid-ramp
  (`ST2→WX2`) is how a 32-colour palette turns into mud. Two families meet at a *material
  boundary*, not inside a gradient.
- **Terracotta is the cold→warm workhorse.** It carries the largest ΔW of any non-metal
  (+0.365 to +0.545). Rooms that must sell the transition — R6 and R4 per acceptance criterion
  10 — need a meaningful terracotta area in frame, not just stone.
- **Verdigris carries almost none** (+0.04 to +0.11). Use it for texture and age, never as the
  thing a room relies on to prove it changed.

---

## 4. Cold → warm: the observable contract, made buildable

§8 of the design spec fixes the *contract*. This section fixes the *implementation rule* so
that art, shader and acceptance test cannot disagree.

### 4.1 Author once, derive the cold

**Assets are authored warm.** There is no cold tileset and no cold sprite set. The cold state is
produced at runtime by a transform over the warm albedo, and the palette's cold column is the
exact result of that transform, published so the artist can see what their asset will look like
in the cold half of the game.

The transform, in **sRGB 8-bit space** (not linear — what Aseprite shows the artist must be what
the game shows the player):

```
L        = 0.2126·R + 0.7152·G + 0.0722·B          # luma
desat    = lerp(c, L, s)                           # s = 0.72 default, 0.55 for brass
tinted   = desat * T                               # T = (0.88, 0.96, 1.08) default
                                                   #   = (0.92, 0.97, 1.03) for brass
cold     = lerp(tinted, #39424f, 0.18)             # everything except brass
cold     = tinted * 0.82                           # brass only: unlit, not repainted
```

Constants live in `docs/art/palettes/lost-choir-slice.json` and are read by the build script.
They are art-direction contracts: changing one is an art-direction change and needs this
document updated, not a shader tweak.

Brass takes a different path on purpose, and that difference *is* the "dormant metal" rule:

- It keeps **45% of its chroma** where everything else keeps 28%, so it stays visibly *metal*
  among grey stone rather than becoming more grey stone.
- It skips the pull toward the cold mid, so it keeps its **full value structure**. Cold brass
  spans luma 0.17 → 0.72; the cold stone around it spans 0.20 → 0.59. Metal reads as metal
  because of its value range, not because of its hue — that range is what survives the cold.
- It is scaled to 82% value: **unlit**. Zero `Light2D` contribution, zero bloom, no specular
  frame, no `BR4` pixel anywhere.

Which gives the one-line rule: **in the cold state the world's warmth lives in *reflectance*
only; not one pixel of it is *emitted*.** Dormant metal, not absent metal.

### 4.2 The warmth field

A single scalar `w ∈ [0,1]` per pixel drives everything: `rendered = lerp(cold(albedo),
albedo, w)`, brass emission `= w`, seam colours visible only where `w > 0`.

| Property | Value |
|---|---|
| Origin | the Verse-bearer's seam (a point, not the room centre) |
| Propagation speed | 300 px/s (design spec §7) |
| Full duration | 2500 ms (design spec §7) |
| Wavefront band | 24 px wide leading edge |
| Band overshoot | `w` peaks at **1.15** in the band, settling to 1.0 over 400 ms behind it |
| Band effect on brass | overshoot applies to **emission only**; albedo clamps at 1.0 |
| Easing | linear in *distance* (it is a wave, not a fade). No ease-in/ease-out on the radius. |
| Occlusion | none — warmth passes through geometry. It is sound, not light. |

The overshoot band is the single most important detail here. A plain crossfade over a whole
room reads as a graphics setting — exactly the H5 failure the design spec names. A 24 px band
that travels outward and makes each brass fitting **glint as it passes** reads as something
moving through the room. It is also what makes the change visible in "a single unbroken shot
without a cut or fade": the shot has a subject that moves.

### 4.3 Authored-warm rooms

R7 and R8 are authored warm-on-first-sight (design spec §6). They are not a separate art set —
they are the same warm assets with `w = 1` pinned. R1, R2, R4, R5 and R6 carry `w` from the
restoration flag.

### 4.4 Acceptance

`python3 tools/art/warmth_check.py cold.png warm.png` on a same-camera pair. Thresholds:

| Check | Threshold | Serves |
|---|---|---|
| Cold mean warmth `(R−B)/255` | ≤ +0.02 | "no warm accent above the ambient floor" |
| Cold share of pixels above the chroma floor (0.06) | ≤ 6% | brass budget, dormant not blazing |
| Same share, lower bound | > 0.1% | **dormant metal, not absent metal** |
| Δ mean warmth, cold → warm | ≥ +0.12 | the side-by-side is unmistakable |
| Δ value contrast (stdev of luma) | ≥ +0.02 | "measurable rise in warmth *and contrast*" |

The palette as specified scores Δ mean warmth **+0.188** and Δ contrast **+0.052** on a
representative material mix — roughly 1.5× and 2.5× the minimums, so a room has room to be
composed badly and still pass. That headroom is deliberate: the gate is a floor, not a target.

**The numeric gate does not replace the human read.** §8's actual acceptance is "unmistakable to
someone who has not played." Both gates are required; the script exists so the human gate is
never the first time we find out.

---

## 5. Light, value and edge

- **Cold light sources are cold and low-contrast** (design spec §8). Cold-state key light tints
  toward `#39424f`; the cold column's value spread is compressed ~23% against the warm column,
  which is where the low contrast comes from. Do not add it twice in the shader.
- **Warm light is sourced.** After restoration, light comes from the seam, from lit brass, and
  from named scene lights — never from a global brightness lift.
- **Ambient occlusion is painted, not lit.** Contact shadows are authored into the tiles as
  `ST0`/`VD1` at the tile join. The lighting layer does not do contact shadow at this scale.
- **Edges.** §2 R4: value step, not contour. Where a silhouette would otherwise be lost against
  a same-value ground, fix the *composition* (move the prop, change the ground tile) before
  reaching for a rim light. Rim light in the cold state is forbidden outright — it is warmth the
  cold state is not allowed to have.
- **Dithering** is permitted only as *material texture* (oxidation crust, weathered plaster,
  dried membrane), never as a gradient between two ramp values. Checkerboard gradient dithering
  reads as a different game's style and is out.

---

## 6. The Listener — provisional, non-canonical

**Protagonist identity is an open creative gate** (`docs/creative-direction.md`;
`docs/design/vertical-slice.md` §10). It is not resolved here, and this section is built so that
it *cannot* be resolved here by accident.

**I did not need to make the identity call to produce a readable silhouette, so I have not made
it, and no Creative Checkpoint is raised.** The reasoning matters, because "provisional" is easy
to claim and easy to violate: identity in a 2D silhouette is carried almost entirely by *face,
species markers and costume signifiers*. Readability is carried by *mass, proportion and
motion*. Those are separable. The rules below take all the readability from the second set and
spend none of the first.

### Anti-canonisation rules — each of these is a rejection criterion at the critic gate

| Rule | Why |
|---|---|
| **No face read.** No eyes, mouth, nose, brow, muzzle or mask-face. The head mass is a smooth hooded volume whose front is in shadow at every angle. | A face is an identity. There is no such thing as a provisional face. |
| **No species read.** No visible hands with a countable number of fingers, no ears, no tail, no hair, no hooves, no digitigrade leg. Limb terminals are wrapped or tapered. | Countable anatomy is a species claim. |
| **No costume signifiers.** No insignia, no belt, no pouches, no weapon sheath, no jewellery, no clasp with a shape anyone could read as a faction mark. | Every one of these is a lore assertion a future writer would be stuck with. |
| **No gender read.** Silhouette carries no chest, waist or hip shaping; the body is a single tapering column under a wrap. | Same reason. |
| **No scale anchor beyond the collider.** Nothing implies "child" or "giant" — proportions sit at a neutral 6-head figure. | Age is identity too. |
| **The seam is on the equipment, not the body.** The restored gold seam runs on the chest wrap, not on skin or shell. | A seam on a *body* asserts what the body is made of. |

### What the Listener *is*, visually

A vertical, under-determined figure — a **wrapped column** — that reads as "someone listening"
by posture alone.

| Property | Value |
|---|---|
| Sprite canvas | 32 × 48 px (collider 18 × 40, origin at feet) |
| Proportion | ~6 heads; head mass 8 px, shoulders 16 px wide, hem 14 px |
| Silhouette read | one continuous tapering column, hood → shoulders → wrap → hem; no limb reads in idle |
| Three-mass (§2 R2) | **chamber** = the wrapped torso; **frame** = the shoulder yoke; **aperture** = the chest seam (dark crack cold / gold warm) |
| Palette | `HK1` wrap body, `HK0` shadow, `WX0`/`WX1` cloth lights, `ST4` on the yoke only. **No brass until the Verse is restored.** |
| Cold posture | head tilted 1 px toward the listening side, shoulders slightly forward — leaning in |
| Warm posture | shoulders open 1 px, head level. Same figure, having heard something. |

The posture pair is the whole characterisation budget. "Someone who leans in to listen" is an
*attitude*, not an identity — it survives any later answer to who they are.

### If this is wrong

If the Creative Director or Game Designer reads the wrapped-column as already canonising
something, the correct response is to raise a Creative Checkpoint and stop, **not** to adjust
the silhouette until it feels safe. Recorded in §12.

---

## 7. The husks — one rule, two values

Both are "husks of sound": instrument anatomy, not bodies. **H6 tests whether a player forms one
mental model across both**, so they are authored from a single kit with a single differing axis.

### 7.1 The shared kit

Both husks are built from the same three masses (§2 R2), in the same order, with the same
materials:

- **Chamber** — a cracked resonating body. `HK1` frame, `HK2` dried membrane stretched over it,
  `BZ1`/`BZ2` oxidised fittings at the joins, one hairline `VD1` crack that never closes.
- **Frame** — bone-like *frame members*, read as an instrument's struts, never as a skeleton.
  `HK0`/`HK1`.
- **Aperture** — where the voice leaves. This is the differing axis.

Shared rules: no eyes anywhere; no head as a separate mass (the aperture *is* the head); brass
fittings are dormant in the cold state like everything else; both carry exactly one visible
crack, because a husk is a thing that broke.

### 7.2 The differing axis — register is a shape

| | **Reed Husk** (percussive/throat, melee, 520 ms lead) | **Keening Husk** (keening, ranged, 700 ms lead) |
|---|---|---|
| Aperture | **split reed** — a short, wide, doubled flap, 10 px across, 4 px deep | **drawn pipe throat** — a long, narrow tube, 5 px across, 22 px tall, flaring to a small bell |
| Proportion | wide and low: 34 × 26 px, chamber below the aperture | tall and narrow: 22 × 52 px, chamber below a long throat |
| Stance | low-slung, four short frame members, walks at 60 px/s | rooted: frame members fuse into a base that meets the floor as one mass; it does not walk |
| Dominant curve | a squat, taut arc — a struck drum | a long, thin, rising arc — a drawn breath |
| Membrane | broad, slack, visibly struck (wear ring at the centre) | narrow, over-tight, visibly split at the throat join |
| Silhouette ratio | ≈ 1.3 : 1 wide | ≈ 1 : 2.4 tall |

Read as one sentence: **short aperture = short note = short lead; long aperture = long note =
long lead.** The player does not need to be told this; the shape is the timing. That sentence is
the art contribution to H6, and it is the thing the critic gate should test hardest — if a
reviewer cannot state that rule after looking at both silhouettes for five seconds, the pair has
failed regardless of how good either sprite is.

### 7.3 The tell visual — "the shape says *who*, the sound says *when*"

This is the most constrained rule in the document, and the reason is H2: the hypothesis is
falsified if "players call it a parry and ignore the audio, reading visuals only." An art
department can fail that hypothesis single-handedly by drawing a good wind-up.

**Permitted during a tell:**
- The aperture **opens** — a hard state change on the first frame of the tell, held flat for the
  entire window. Reed: the reed flaps part. Keening: the throat bell irises open.
- A pale breath vapour (`HK3`, 1-bit, 2-frame loop) drifts from the aperture at constant
  density for the whole window.
- The chamber's crack widens by 1 px and stays there.

**Forbidden during a tell:**
- Any animation whose *progress* encodes time-to-resolution: no growing charge, no filling
  meter, no arm drawing back, no brightening ramp, no scaling ring, no colour shift over the
  window. A player must not be able to frame-count the release off the sprite.
- Any tell VFX outside the enemy's own silhouette plus 8 px.
- Any use of seam or brass emissive colour. Husks are silent things; they have no seam.

The tell visual therefore carries **identity and state** ("this one, and it is speaking now")
and deliberately carries **no timing information**. Timing is Audio's, per the dedicated dry
channel in design spec §5. The two enemies' visuals differ by *shape*, not by *tempo* — the
tempo difference lives in the sound, and the shape tells you which sound to expect.

Consequence, stated plainly so it is a decision and not an oversight: **a player with the sound
off cannot beat this slice reliably.** That is the intended design, it is what H2 measures, and
the debug overlay (design spec §9) is the accessibility answer during development. A permanent
accessibility affordance is a real question and belongs on the post-play list, not in this
slice's art rules — flagged in §12.

### 7.4 States and frames

| State | Frames | Notes |
|---|---|---|
| Idle | 4 @ 200 ms | breathing sag of the membrane, 1 px |
| Tell | 1 (held) + 2-frame vapour loop | hard onset per §7.3 |
| Attack | 3 @ 60 ms | Reed: lunge. Keening: the throat *un-clenches* — the projectile is a released note |
| Stagger | 2 @ 150 ms | 900 ms window (1600 ms on Return); membrane goes fully slack |
| Death | 5 @ 90 ms | the chamber **collapses inward** and goes quiet. No gibs, no burst, no soul-wisp. A husk ending is a sound stopping. |

---

## 8. The Verse-bearer

The slice's thesis in one asset. 64 × 72 px, seated in the amphitheatre's focus.

**Cold state.** Matte, cracked, silent-grey. Built from the shared three-mass grammar at a
larger scale: a great bell-chamber body, a stone frame that has partly become the amphitheatre
around it, a closed aperture. Palette: `ST1`/`ST2` body with `WX0` dust, `BZ0`/`BZ1` fittings,
`HK2` collapsed membrane across the aperture. Its brass fittings follow the dormant-metal rule —
visibly metal, visibly unlit. The crack is `VD0`: a hole, not a dim light.

**The crack geometry is authored once, as a single continuous path**, from the lower chamber up
across the aperture and over the shoulder of the bell. It is the same path in both states — this
is the load-bearing idea: *the crack becomes the light source*. It must not move, branch
differently, or gain length between states, because the emotional claim is that the wound and
the voice are the same thing.

**Restored state.** The path fills `SM1` with an `SM2` core and an `SM0` outer bleed, becomes a
`Light2D` source, and the calligraphic wave etchings spread outward from it.

### Etching vocabulary

- **What they are:** continuous calligraphic strokes with variable weight — thin at the entry,
  swelling to 2 px at the crest, thin at the exit. Wave forms that *rhyme* with notation.
- **What they are not:** notation. No staves, no clefs, no noteheads, nothing transcribable
  (§2 forbidden motifs). A musician must not be able to read them.
- **How they grow:** along authored spline paths, drawn on progressively, at **40 px/s**, so the
  full extent lands inside R6's 2500 ms room lerp and the etchings and the room warm *together*.
- **Where they stop:** on the bearer and on the stone within ~48 px of it. They do not crawl
  across the whole room — their edge is the evidence that the warmth has a source.
- **Colour:** `SM1` body, `SM2` only in the crack core, never `SM0` alone.
- **Density:** 3 primary strokes and up to 5 secondary. More reads as decorative filigree, which
  is a different, wrong idea.

### Restoration timeline (art half)

| t (ms) | Event |
|---|---|
| 0 | Last note answered. The crack's `VD0` interior goes to `SM2` along its whole length in one frame — no fade-in |
| 0–400 | Seam brightens to full; `Light2D` ramps in; brass **within 48 px** lights first |
| 0–2500 | Warmth wavefront travels at 300 px/s from the seam (§4.2) |
| 120–2500 | Etchings draw on at 40 px/s |
| 2500–3200 | Settle: overshoot band resolves, seam drops to a slow ±6% value breath (1 cycle / 2.4 s) |

**No fanfare.** No burst, no shockwave ring, no screen flash, no particle bloom, no star-wipe.
Design spec §7: the encounter must land on *agreement*, not victory. The art of restoration is a
light coming on in a room, not an explosion. If it reads as a boss dying, it is wrong even if
every pixel is beautiful.

---

## 9. Affordances — showing the lock before the key

R4 must let a player read **"this responds to a held low note"** before they own Sustain
(design spec §6). Affordance is the slice's hardest art problem, because the honest failure mode
is not ugliness — it is a player who walks past the membrane without registering it as a thing.

The rule: **affordance is carried by material state plus sympathetic response, never by a
symbol.** No icons, no glyph hints, no outline pulse, no "?" marker. The world shows that it
*can* move and that it *already answers sound*; the player supplies the rest.

### 9.1 Membrane (slack drum-skin disc)

| | Slack (default) | Taut (sustaining) |
|---|---|---|
| Form | catenary sag, 5 px deep at centre, across a `BZ1` bronze hoop | flat, 1 px crown, hoop rim visibly loaded |
| Palette | `HK2` skin, `HK0` in the sag, `BZ0`/`BZ1` hoop | `HK3` skin, `BZ2` hoop, `ST4` hoop specular |
| Size | 64 × 20 px (hoop 64 px across) | same footprint, skin raised to the hoop plane |
| Read | "a drum nobody has tightened" | "a floor" |

Three affordance cues, all diegetic, all present before the player owns Sustain:

1. **The hoop is a tension mechanism, visibly.** Lugs and a tensioning collar around the rim,
   worn bright at the contact points (`ST4` on `BZ1`) — evidence this has been tightened many
   times. A mechanism that shows wear shows that it moves.
2. **Sympathetic tremble.** Within 140 px of the player and *not* sustaining, the skin carries a
   1 px, 3-frame, low-amplitude tremble on a 900 ms cycle. It is already answering the world's
   ambient low end — faintly, insufficiently. This is the sentence "a held low note does
   something here" spoken in motion instead of in UI.
3. **Dust.** A thin `WX0` dust film on the slack skin, which the tremble disturbs and which is
   *gone* in the taut state. Dust is how a player reads "untouched, but touchable."

Ramp-in (180 ms) and ramp-out (120 ms) are authored as 3-frame and 2-frame transitions. On
ramp-out anything standing on the membrane falls (design spec §4.1) — the skin drops *first*,
one frame ahead of the player's fall, so the cause is visible.

### 9.2 Bell-frame (suspended, descends while sustaining)

| | High (default) | Low (sustaining) |
|---|---|---|
| Form | a bell mouth-down in a `BZ1` yoke, suspended from a guide rail | same, at the bottom of its travel |
| Palette | `BR1`/`BR2` bell (dormant cold), `BZ1` yoke, `ST2` rail | `BR2`/`BR3` bell, `BR4` only if `w > 0` |
| Size | 40 × 48 px |  |

Affordance cues:

1. **The travel path is worn into the wall.** A polished band on the guide rail along the exact
   travel distance, plus a chalk-pale `WX1` wear ring on the stone at the low position. The
   player can see where this thing goes before they can make it go there.
2. **It is the only brass mass in R4.** Dormant brass in a grey room is already the game's "this
   matters" signal (§3 brass budget); R4 spends its entire 4% on the bell-frames.
3. **It hangs slightly off-plumb** and swings 1 px on a 2.2 s cycle. A suspended thing that
   moves is a thing that can be moved.

Descent: 12 frames over the ramp-in, eased out at the bottom. Rise on ramp-out carries the
player (design spec §4.1) — the bell must read as *lifting* them, so the yoke compresses 1 px on
first contact before travel begins.

---

## 10. Tileset — the eight rooms

One tileset family per material, 16 px, 47-tile blob autotile per family, authored in Aseprite
and wired in LDtk. A room is composed from families; it does not get bespoke tiles.

| Family | Palette | Where |
|---|---|---|
| `stone` — amphitheatre travertine | `ST0–ST4` | everywhere; the base material |
| `plaster` — cracked wax-plaster facing | `WX0–WX3` + `ST1` substrate | R2, R6, R7 |
| `colonnade` — pipe-organ columns, fluted, hollow | `ST2–ST4`, `BZ1` collars, `BR1` dormant mouth-holes | R5 |
| `terracotta` — fired tile facing, seating risers | `TC0–TC3` | R3, R4, R6 (the transition workhorse) |
| `bronze` — fittings, rails, hoops, grilles | `BZ0–BZ3` | trim across all rooms |

Budget: **5 families × 47 tiles = 235 base tiles**, plus ~40 decoration tiles and 2 parallax
backdrop layers. Anything above that is scope the slice did not ask for.

### What each room's art must do

Per design spec §6, every screen serves a row of the design table. Art's job per room:

| Room | The art's job | Must NOT |
|---|---|---|
| **R1 — The Cold Step** | Sell cold and near-silence. Widest empty value range, lowest detail density in the slice. One dormant brass fitting in frame so the player has seen the material before it ever lights. | Be interesting. R1's emptiness is the baseline the whole game is measured against. |
| **R2 — Reed Gallery** | The passive cracked husk must read as *the same kind of thing* as R3's Reed Husk, at rest. Same kit, same materials, collapsed posture. | Make it look dead-different. It is the same creature, not a corpse prop. |
| **R3 — The First Answer** | Flat, wide, uncluttered floor. The Reed Husk must be the only high-contrast element on screen. | Put any other readable shape in frame. Answer is taught here or nowhere. |
| **R4 — Membrane Hall** | Two legibility jobs: the membranes read as tensionable (§9.1), and the **unreachable upper ledge must be visibly a destination** — lit differently, a fragment of warm-authored geometry visible through the gap. Barred shortcut door to R7 readable as a door from this side. | Let the ledge read as background. H4 depends on the player *remembering* it. |
| **R5 — The Colonnade** | Verticality and exposure. Column mouths are dormant brass. Sight lines up the climb must let the Keening Husk's tall silhouette be read from below before it is in range. | Hide the Keening Husk behind foreground. Exposure is the point; ambush is not. |
| **R6 — The Cold Amphitheater** | The slice's money shot, twice. Must pass §4.4 both states. Composition places the seam so its wavefront crosses terracotta seating and at least three brass fittings on its way out. | Read as a boss arena. No arena ring, no gate, no skull motifs, no raised platform. |
| **R7 — The Warm Return** | Authored warm, and must be *recognisably the same stone* as R1/R4 — same tiles, `w = 1`. Recognition is the entire room. | Introduce any new material family. If it looks like a new place, R7 has failed. |
| **R8 — The Cracked Bell** | One image worth the breath-tight route. A great cracked bell, warm-authored, with etchings that stop mid-stroke. Narrative fragment only. | Contain anything that reads as a pickup, upgrade or collectible. H7 depends on the payout being meaning. |

---

## 11. Animation, VFX and diegetic UI

### 11.1 Animation language

Timings are *contracts from the design spec*, not animation preferences. Frame counts derive
from them at 60 Hz.

| Action | Contract | Frames |
|---|---|---|
| Run | 170 px/s, 90 ms accel | 8 @ 100 ms, 2-frame lean-in on accel |
| Jump | 320 ms to apex, 1.7× fall gravity | 1 launch, 1 rise, 2 apex hang, 1 fall, 2 land — **no landing lag pose**, full control on contact (design spec §3.1) |
| Strike | 90/70/140 ms | 2 startup, 1 active, 2 recovery |
| Answer | 0 ms startup, 180 ms pose | **1 frame, on press** — the pose reads instantly or the 0 ms startup is a lie |
| Answer success | enemy staggers 900 ms | seam-side flare on the Listener, 3 frames; no hitstop beyond 2 frames |
| Return | 120 ms startup, 3× damage | 2 startup, 2 active — the released note travels *from the seam*, visibly |
| Sustain | 180 ms ramp-in | 3-frame ramp, then a 2-frame loop held for the duration |

**The Listener's motion is where "someone listening" lives.** Weight settles into the ground on
landing; the hood leads a turn by one frame; the body is quiet when the player is quiet.

### 11.2 VFX language

Every effect answers to one rule: **an effect is either air moving or a seam speaking. Nothing
else emits.**

| Effect | Form |
|---|---|
| Husk breath (tell) | pale `HK3` vapour, 1-bit, constant density, 2-frame loop |
| Sustain (the drone) | concentric arcs from the Listener's seam, 1 px, `SM1` at 40% coverage, expanding at 300 px/s to match the warmth wavefront's language — the same visual grammar as the restoration, at a smaller scale. This is what makes Sustain read as *the Verse*, not as a jump button. |
| Return | a single arc released from the seam toward the target, 3 frames, `SM1`→`SM2` |
| Keening projectile | a thin 6 × 3 px `HK3` lens, no trail, no glow. It is a note, not a bullet. |
| Impact | 3-frame `WX2` chip-spray, no ring, no flash |
| Restoration | §8 timeline. No burst. |

Forbidden: screen shake above 2 px, chromatic aberration, additive particle bloom, slow-motion,
white flash, damage numbers.

### 11.3 Diegetic UI art

Design spec §9 sets the budget; this fixes its look.

- **HP — 5 discrete marks, intact/cracked.** Drawn as 5 small bell-mouth forms, `BZ2` intact,
  `HK0` with a `VD1` fracture when lost. Cracked, never absent: the mark stays, the sound stops.
- **Breath arc** — a single `SM1` arc at the Listener's chest seam, visible only while sustaining
  or refilling, depleting by *arc length*, not by fill.
- **Resolved note (1200 ms Return window)** — the seam brightens `SM1`→`SM2` and holds. No icon,
  no timer, no number. The brightening must be visible against a warm background too; verify in
  R7, not only in a cold room.
- **No minimap** (design spec §9). No ability icons. No pickup toast.

---

## 12. Interpretations, and what this document does not decide

Recorded so the Game Designer and Creative Director can correct them cheaply.

1. **"No warm accent above the ambient floor" vs. "gold present but unlit"** (design spec §8) —
   these two sentences constrain each other. I read the first as governing *emission* and the
   second as governing *reflectance*: in the cold state gold may sit above the chroma floor as a
   surface, but must emit nothing. `warmth_check.py` enforces exactly that reading (≤ 6% of
   pixels above the floor, and > 0.1% required, so absent metal fails too). **If the intent was
   that gold must also sit below the chroma floor, the gate's upper bound drops to ~1% and the
   dormant-metal read goes with it — tell me and I will re-derive the brass transform.**
2. **The Listener's identity is not resolved and no Creative Checkpoint is raised.** §6 states
   why the readability problem was separable from the identity problem. If that separation does
   not hold for the Creative Director, this becomes a Checkpoint, not an art revision.
3. **Sound-off play is not viable in this slice, by design** (§7.3). A permanent accessibility
   affordance for the tell is a real question deferred to the post-play list; adding a timing
   readout now would pre-falsify H2.
4. **Not decided here:** the full art bible, any biome outside this zone, the Verse-bearer's
   species or history, husk variants beyond these two, a second Verse's seam colour, character
   portraits, key art, logo, or anything about the game's second zone.
5. **Open dependency:** the etching spline paths (§8) should ideally rhyme with the shape of
   Audio's unfinished leitmotif phrase. That is a nice-to-have cross-discipline alignment, not a
   blocker — the etchings ship without it if Audio's phrase is not fixed in time.

---

## 13. Production brief and gate

Asset production is the Asset Artist's. Independent review is the Visual Identity Critic's. This
document is the constraint set both work against.

Priority is ordered by what the slice cannot be evaluated without.

| # | Asset | Size | States / frames | Serves |
|---|---|---|---|---|
| 1 | Verse-bearer | 64 × 72 | cold; restored; restoration sequence per §8 | H3, H5, acceptance 10 |
| 2 | Tileset `stone` + `terracotta` | 16 px | 47-blob each | all rooms, §4.4 gate |
| 3 | Membrane | 64 × 20 | slack, tremble ×3, ramp-in ×3, taut, ramp-out ×2 | H4, design §4.1 |
| 4 | Bell-frame | 40 × 48 | high, travel ×12, low, swing ×2 | H4, design §4.1 |
| 5 | Reed Husk | 34 × 26 | idle ×4, tell, attack ×3, stagger ×2, death ×5 | H2, H6 |
| 6 | Keening Husk | 22 × 52 | same set + projectile | H2, H6 |
| 7 | The Listener | 32 × 48 | idle ×4, run ×8, jump set, strike ×5, answer, sustain, return | H1 |
| 8 | Tileset `plaster`, `colonnade`, `bronze` | 16 px | 47-blob each | R2, R5, R6, R7 |
| 9 | Diegetic UI | — | HP ×2, breath arc | design §9 |
| 10 | Decoration + parallax | — | ~40 tiles, 2 layers | room composition |

**Gate order:** Asset Artist produces → returns to Art Director → Art Director routes to Visual
Identity Critic → critic passes or returns findings → integration. Placeholder art is already
unblocking engineering (design spec §12), so the critic gate is not to be shortened to save
time.

**Per-asset acceptance** (the critic gate's checklist):

1. On palette, indexed, 1-bit alpha, correct canvas size.
2. Passes the §2 R3 silhouette test at ×1, black fill.
3. Three-mass read (§2 R2) is identifiable and nameable.
4. Two-palette-step value separation from its intended background (§2 R4).
5. Violates nothing in §2's forbidden-motif list.
6. Brass ≤ 4% of pixels; no `BR4` or `SM*` in a cold-state asset.
7. Cold state, when derived by the §4.1 transform, still reads correctly — check it, do not
   assume it.
8. For the husks: a reviewer who has not read this document can state the "short aperture =
   short lead, long aperture = long lead" rule from the two silhouettes alone (§7.2).
9. For anything on a design-spec timing: frame count matches the contract in §11.1.
