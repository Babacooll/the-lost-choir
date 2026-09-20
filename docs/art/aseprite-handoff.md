# Aseprite handoff — what a human artist needs to finish the slice's art

Owner: Art Director. Status: **the asset track's reachable end in this environment.**

The art direction in `docs/art/vertical-slice-art-direction.md` is merged and is the contract
everything downstream built against — engineering verified the cold→warm transition numerically
against its §4 constants, brass's separate path included. What is *not* done is the pixel art
itself, and it cannot be done here. This document says precisely what remains, so the work can be
picked up without re-deriving any of it.

## The constraint, stated once

This workspace has a text-to-image provider and no pixel-art pipeline. Generated images can
establish identity, material and silhouette; they cannot emit 32-colour-indexed sprites at exact
canvas sizes, 1-bit alpha, 47-tile autotile sets with correct adjacency, or frame sequences that
hit the millisecond contracts in §11.1. That is a tooling boundary, not a work-rate problem: more
rounds inside this environment produce better *references* and never produce a shippable sprite.
It is unblocked by one person with Aseprite, not by another prompt.

Scale of what is left: **~100 sprite frames and ~275 tiles**, against a fixed 32-colour palette
and a written spec. For an experienced pixel artist that is on the order of **one to two weeks**
— tilesets ~2–3 days, characters and props ~3–4 days. Treat that as an estimate with its basis
shown, not a quote.

## What is already finished and should not be redone

| Artefact | Where | Status |
|---|---|---|
| Slice art direction | `docs/art/vertical-slice-art-direction.md` | Merged. The contract. |
| Palette, 32 colours | `docs/art/palettes/lost-choir-slice.gpl` | Load into Aseprite as an indexed palette. Warm is the source of truth. |
| Derived cold palette | `docs/art/palettes/lost-choir-slice-cold.gpl` | Generated — never hand-edit. Shows what an asset looks like at `w = 0`. |
| Cold transform constants | `docs/art/palettes/lost-choir-slice.json` | Already implemented in-engine. |
| `build_palette.py` | `tools/art/` | Regenerates the derived files after any warm-palette edit. |
| `warmth_check.py` | `tools/art/` | §8's numeric gate. Stdlib only. Run it on a same-camera before/after pair. |

## How much to trust the concept references

Round-2 candidates are on `agent/asset-artist/3d1472635e40` under `art/production/`, with
`handoff-manifest.md` and `handoff-manifest-round2.md` recording every rejected pass and why.
That provenance is worth reading before starting — several corrections are only legible as the
difference between two passes.

They are **Art-Director-reviewed but not Visual-Identity-Critic-validated.** The round-1 batch
went through the full critic gate; round 2 did not. Trust them for material language, value
structure and colour, and treat their geometry as a proposal:

| Reference | Trust | Caveat |
|---|---|---|
| `bell-frame/bellframe-high-v3.jpg` | High | Passes black-fill at 40 × 48. Tuned-tube body, stone rail, warm `BR2`/`BR3`. |
| `tileset-stone/tileset-stone-v3.jpg` | High | Field re-biased to the `ST3`/`ST4` floor. Joints read slightly bolder than pure value-step in places — tighten while authoring. |
| `tileset-terracotta/tileset-terracotta-v2.jpg` | High | Full `TC0`–`TC3` range, irregular tile sizes. |
| `membrane/membrane-slack-v3.jpg` | Medium | Material handling and the off-centre asymmetric sag are right. Rendered as a true circle; the shipping canvas is a 64 × 20 ellipse — see §9.1, the canvas is correct and is not a squashed circle. |
| `verse-bearer/versebearer-dormant-v4.jpg` | Material only | **Its silhouette fails, and the spec is why.** See below. Fittings, fracture lip, aperture treatment and posterised value steps are all correct and worth copying. |
| `verse-bearer/versebearer-restored-v3.jpg` | Material only | Same. Etching density and seam treatment are right. |

### The Verse-bearer silhouette — a spec defect, not a generation limit

Two asset passes failed the black-fill test at 64 × 72 and the artist reported it as a probable
generator limit. It was not. §8 named the bearer's third mass as an aperture cut into the chamber
wall, while §2 R3 says a mass existing only inside the outer contour is not a mass R2 counts. The
test could not be passed as written, by any tool or any hand.

Corrected in §2 R2 and §8, and this is the geometry to author against:

- The three masses are **chamber** (the bell body), **frame ribs**, and **mouth** (the flared
  lower lip). The slot in the chamber wall is the *wound*, not the aperture — a bell's aperture
  is its mouth, which is where sound leaves and which exists in the outline.
- **The ribs protrude past the chamber's widest point**, with real negative space between rib and
  chamber. A rib that is contour-continuous with the chamber is a colour boundary, not a mass.
- **The mouth stands clear of the ground on those ribs.** The gap beneath the lip is what makes
  the third mass legible.

Build the black fill first, at 64 × 72, before any interior detail. If three masses are not
countable there, nothing painted afterwards will rescue it.

## The work, in the order to do it

Priority is what the slice cannot be evaluated without. Every row cites the section that governs
it; none of the rules are repeated here, on purpose — the document is the contract.

| # | Asset | Canvas | States / frames | Governed by |
|---|---|---|---|---|
| 1 | Verse-bearer | 64 × 72 | dormant; restored; restoration sequence per §8's timeline | §8, §2 R2 |
| 2 | Tileset `stone` | 16 px | 47-tile blob + the R6 niche the bearer sits in | §10 |
| 3 | Tileset `terracotta` | 16 px | 47-tile blob | §10 |
| 4 | Membrane | 64 × 20 | slack, tremble ×3, ramp-in ×3, taut, ramp-out ×2 | §9.1 |
| 5 | Bell-frame | 40 × 48 | high, travel ×12, low, swing ×2 | §9.2 |
| 6 | Reed Husk | 34 × 26 | idle ×4, tell, attack ×3, stagger ×2, death ×5 | §7 |
| 7 | Keening Husk | 22 × 52 | same set, + projectile 6 × 3 | §7 |
| 8 | The Listener | 32 × 48 | idle ×4, run ×8, jump set, strike ×5, answer, sustain, return | §6, §11.1 |
| 9 | Tilesets `plaster`, `colonnade`, `bronze` | 16 px | 47-tile blob each | §10 |
| 10 | Diegetic UI | — | HP mark ×2, breath arc | §11.3 |
| 11 | Decoration + parallax | — | ~40 tiles, 2 layers | §10 |

Rows 6–8 have **no concept reference at all** — they were never reached. They are specified in
words only, which is sufficient: §7.2's table fixes both husks' proportions and apertures, and §6
fixes the Listener's proportions and its anti-canonisation rules. Row 8 in particular must not be
improvised: the Listener is deliberately provisional, and §6's constraints are rejection criteria,
not suggestions.

## Checks to run before calling any asset done

1. Indexed to `lost-choir-slice.gpl`, 1-bit alpha, exact canvas size (§1).
2. Black fill at shipping size — three masses countable, entity identifiable (§2 R2, R3).
3. Two palette steps of separation from its intended background, **measured after the cold
   derive** (§2 R4, §10). The cold transform compresses the ramp from a 0.126 mean step to 0.098;
   an asset that clears warm and fails cold has not passed.
4. Nothing from §2's forbidden-motif list — faces especially, which is the one that arrives by
   accident.
5. Brass within §3's budget: a screen measure at `w = 0`, not per-asset. The restored Verse-bearer
   is exempt; it is the light source.
6. No `BR4` or `SM*` in any dormant-state asset.
7. For the husks: someone who has not read the document can state "short aperture = short lead,
   long aperture = long lead" from the two silhouettes alone (§7.2).
8. Frame counts match §11.1, which derives them from the playable contract's millisecond timings.

## Gate

Unchanged: artist produces → Art Director → Visual Identity Critic → integration. §14 sets what a
candidate must be to be reviewable at all, and it applies to hand-authored work too — a submission
without its shipping-size and black-fill panels cannot be reviewed against §2 R3.
