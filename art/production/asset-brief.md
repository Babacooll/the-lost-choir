# Vertical-slice production batch — asset brief

Constraint set: `docs/art/vertical-slice-art-direction.md` (slice-scoped, not the art bible).
Palette: `docs/art/palettes/lost-choir-slice.gpl` (warm column is source of truth; cold is a
derived transform per §4.1, never hand-authored).

This batch covers priority items 1–4 of §13's production table. All are **supporting** assets
under the Art Director's slice-scoped direction (not hero-gated) — the Art Director has already
resolved the identity questions that would require an owner gate (Verse-bearer species/history is
explicitly deferred per §12.4; the Listener, which *would* be hero-gated, is not in this batch).

## Shared technical needs (all four assets)

- Camera: static, orthogonal, 2D side-view, integer ×3 display scale, authored at 1:1.
- Palette: strictly the 32 colours in `lost-choir-slice.gpl`. No off-palette pixel.
- Alpha: 1-bit only (fully opaque or fully transparent per pixel), no soft edges, no AA glow.
- Edges: no ink outline. Forms separate by ≥2 palette-value steps, never a drawn contour.
- Silhouette: three-mass grammar (chamber / frame / aperture), curvature before angle.
- Brass/seam discipline: `BR4` and `SM0–2` are emissive-only — forbidden in any cold-state
  asset. Brass ≤4% of pixels of any authored screen.
- Forbidden: insect anatomy, Hollow Knight visual language, skull/ribcage-as-bone reads,
  literal music notation, neon/glitch/lens-flare, unsourced glow, decorative filler.

## Capability boundary — read before the per-asset briefs

The image-generation provider available in this workspace (Gemini `gemini-3-pro-image`, aka
Nano Banana Pro) produces painterly raster concept art. It cannot be instructed to emit
pixel-perfect, hand-indexed 32-colour art with exact 1-bit alpha, exact canvas pixel dimensions,
a 47-tile autotile blob set with correct adjacency logic, or an exact frame-accurate animation
sequence matching a millisecond timing contract. Those are Aseprite-authoring tasks, not
prompting tasks.

So for each of the four assets below, this batch produces **identity/material/silhouette
concept renders** — the thing a generative model can actually do well and that the critic gate
can usefully judge for identity, silhouette and material language — and explicitly hands off
the indexed-pixel, frame-accurate, tile-adjacency production work to Aseprite authoring (by a
human pixel artist or a dedicated pixel-art tool) using these concepts as the approved reference.
This is named per asset in `handoff-manifest.md`, not discovered silently at the end.

---

## Asset 1 — Verse-bearer (hero-scale prop, supporting authority)

- Type: `prop` (large, scene-anchor). Authority: supporting (identity is explicitly deferred,
  §12.4 — "not decided here: ... the Verse-bearer's species or history").
- Canvas: 64×72 px, seated, amphitheatre focus.
- States needed: cold (matte/cracked/silent-grey) and restored (gold-seam, etched).
- Three-mass read: chamber = great bell-chamber body; frame = stone frame partly fused with the
  amphitheatre; aperture = the closed/opened aperture at the crack.
- Cold palette: `ST1`/`ST2` body, `WX0` dust, `BZ0`/`BZ1` fittings, `HK2` collapsed membrane over
  the aperture, crack = `VD0` (a hole, not a dim light). No `BR4`, no `SM*`.
- Restored palette: crack path fills `SM1` body / `SM2` core, `SM0` only as outer bleed — never
  `SM0` alone. Brass fittings within 48px light first (`BR2`/`BR3`, `BR4` only where lit).
  Calligraphic etchings: 3 primary + ≤5 secondary strokes, variable weight (thin→2px crest→thin),
  confined to the bearer and ~48px of surrounding stone. Must not resemble staves/clefs/notation.
- Invariant across both states: **the crack is one continuous path**, same geometry cold and
  restored — it is the thing that becomes the light source, so it cannot move, branch
  differently, or change length between states.
- Restoration transition (§8 timeline) is a *sequence*, not a single extra pose: t=0 crack interior
  flashes to `SM2` in one frame (no fade-in); 0–400ms seam brightens + near brass lights first;
  0–2500ms warmth wavefront; 120–2500ms etchings draw on; 2500–3200ms settle to slow seam breath.
  No burst, no shockwave, no flash, no particle bloom, no star-wipe — "a light coming on in a
  room," not a boss dying.
- Rejected traits: anything readable as a boss-death effect, readable notation, a face on the
  bearer (identity is not being resolved), any brass/seam colour in the cold render.

## Asset 2 — Tilesets `stone` + `terracotta`

- Type: `texture` / tileset. Authority: supporting, fully rule-bound (§10 table).
- Tile size: 16×16 px base unit; a full family is a 47-tile blob autotile (all inner/outer
  corner and edge combinations for a single material against itself).
- `stone` (amphitheatre travertine): `ST0` deepest crevice → `ST4` rim/chipped edge. Everywhere;
  the base material. Contact shadows painted as `ST0`/`VD1` at tile joins (no separate AO pass).
- `terracotta` (fired tile facing, seating risers): `TC0` shadow → `TC3` rim. This family carries
  the largest non-metal ΔW (+0.365 to +0.545) — it is the cold→warm workhorse, so rooms R3/R4/R6
  need a real terracotta area in frame, not just stone dressing.
- Shared rules: curvature before angle on any tile edge that is a natural material boundary
  (straight only where visibly cut/broken); no ramp-jumping between families mid-gradient; no
  crisp mortar-line grid — joints read as value steps, not drawn lines.
- What this batch can produce: one representative concept panel per family showing the value
  ramp, material language, and a small composed patch (a few tiles' worth) at legible density —
  not the full 47-tile autotile logic, which is a tile-adjacency authoring task (handoff).

## Asset 3 — Membrane (slack drum-skin disc)

- Type: `prop`, interactive affordance. Authority: supporting, rule-bound (§9.1).
- Canvas: 64×20 px (hoop 64px across).
- States: slack (default, catenary sag 5px deep, `HK2` skin / `HK0` in the sag / `BZ0`-`BZ1`
  hoop) and taut (sustaining, flat 1px crown, `HK3` skin / `BZ2` hoop / `ST4` hoop specular).
- Diegetic affordance cues, all present before the player owns Sustain, none of them an icon:
  1. Hoop is visibly a tension mechanism — lugs + tensioning collar, worn bright (`ST4` on `BZ1`)
     at contact points.
  2. Sympathetic tremble: within range and not sustaining, 1px/3-frame low-amplitude tremble on
     a 900ms cycle.
  3. Dust film (`WX0`) on the slack skin, disturbed by the tremble, absent when taut.
- Frame contract (§11.1/§9.1 combined): slack, tremble ×3, ramp-in ×3 (180ms), taut, ramp-out ×2
  (120ms) — ramp-out drops the skin one frame ahead of anything falling from it.
- Rejected traits: any glyph/icon/outline-pulse affordance; a hoop that reads as decorative
  rather than mechanical; dust that persists into the taut state.

## Asset 4 — Bell-frame

- Type: `prop`, interactive affordance. Authority: supporting, rule-bound (§9.2).
- Canvas: 40×48 px.
- States: high (default, suspended from a guide rail) and low (bottom of travel, sustaining).
- Palette: `BR1`/`BR2` bell in the high/cold-dormant state; `BR2`/`BR3` (and `BR4` only where
  `w > 0`) once warm/lit. `BZ1` yoke, `ST2` rail.
- Diegetic affordance cues:
  1. Travel path worn into the wall — polished band on the guide rail along the exact travel
     distance, plus a chalk-pale `WX1` wear ring at the low position.
  2. It is the *only* brass mass in its room context (R4) — dormant brass in a grey room already
     reads as "this matters"; this asset spends the room's entire 4% brass budget.
  3. Hangs slightly off-plumb, 1px swing on a 2.2s cycle — a suspended thing that visibly moves.
- Frame contract: high, travel ×12 (descent, eased out at bottom), low, swing ×2. Descent carries
  ease-out timing; rise on ramp-out compresses the yoke 1px on first contact before travel.
- Rejected traits: a bell rendered as a generic fantasy prop with no visible suspension mechanism;
  brass brighter/more saturated than the dormant-metal rule allows in the high/cold state.

## What must remain invariant across iterations (all four)

- Palette indices used, not just "colours that look close."
- Three-mass read per asset.
- The Verse-bearer's single crack path geometry, once drawn, across every state/frame.
- No emissive colour (`BR4`, `SM0–2`) outside a `w > 0` context.
