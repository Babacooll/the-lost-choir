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

### 8. The gate

```
python3 tools/art/legibility_check.py          # the gate; exit 0 = pass
python3 tools/art/legibility_check.py --why    # the flat-fill impossibility bound
```

The checker mirrors the shader's cold-derive and re-derives every ratio in §4 from the
live `room.gd` ground colours, so the table above is checked rather than asserted. It
covers G1 (vs terrain solid), G2 (vs backdrop), G3 (fill vs its own contour) and G4
(mutual distinguishability), in the cold state and the warm one.

A passing gate is a floor, not a verdict. The human read — can a playtester who has never
seen the slice tell the player from a husk, and a gated door from an open one — is a
separate and non-negotiable check.

### 9. Deletion

This layer is done when `assets/art/` has real sprites. Deleting it is:

1. remove the placeholder script and every `role` declaration that feeds it;
2. remove `tools/art/legibility_check.py`;
3. remove this file;
4. restore the original fills and alphas listed in §1;
5. confirm `tools/art/warmth_check.py` still passes.

If step 4 is ever hard to perform because production drifted onto these colours, the
layer outlived its licence and that is the bug.
