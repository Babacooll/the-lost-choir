# Vertical-slice production batch — handoff manifest

Batch: §13 priority items 1–4 (Verse-bearer, tileset `stone`+`terracotta`, membrane, bell-frame).
Constraint set: `docs/art/vertical-slice-art-direction.md`. Brief: `art/production/asset-brief.md`.
Status: **review candidates for the Visual Identity Critic, not production-final.**

## Capability boundary (read this first)

Provider used: Gemini `gemini-3-pro-image` (Nano Banana Pro), `GEMINI_API_KEY` present.
`IDEOGRAM_API_KEY` is absent workspace-wide — not relevant to this batch (no transparency
requirement; all four assets are 1-bit-alpha sprites/tiles composited by the engine, not
alpha cut-outs).

**What this batch is:** identity, material-language and silhouette concept renders, generated
and iterated against the art direction doc's hard constraints (three-mass grammar, no-outline
rule, brass/emissive discipline, forbidden motifs).

**What this batch is not:** production-ready indexed pixel art. Gemini cannot be prompted into
emitting pixel-perfect 32-colour-indexed art, exact 1-bit alpha, exact 16px/64×72px/etc. canvas
dimensions, a 47-tile autotile blob set with correct adjacency, or frame-accurate animation
sequences matching the §11.1 millisecond contracts. That is Aseprite-authoring work. Each
section below names the concrete Aseprite handoff task the concept unlocks.

## 1. Verse-bearer

- Approved: `verse-bearer/versebearer-cold-v2.jpg` (cold state), `verse-bearer/versebearer-restored-v2.jpg` (restored state).
- Rejected, kept for provenance: `versebearer-cold-candidate.jpg` (isometric perspective + crisp
  ink outlines — both hard-constraint violations), `versebearer-restored.jpg` (etching density
  read as decorative filigree, explicitly the "different, wrong idea" §8 warns against; whole
  chamber over-brightened past the reflectance-only intent).
- Self-check against §13 checklist:
  1. Not yet indexed/canvas-correct — Aseprite task (below).
  2. Silhouette test: three masses (arch frame, bell chamber, closed/open aperture) read at a
     glance in both states — passes by inspection; re-run properly once indexed at 64×72.
  3. Three-mass read: yes, nameable (frame / chamber / aperture).
  4. Value separation: chamber vs frame is a clear value step in both renders.
  5. Forbidden motifs: no face, no readable notation (etchings are unstructured flowing lines,
     not staves), no outline, no insect/skull read.
  6. Brass/emissive budget: cold render has zero `BR4`/`SM*`-equivalent color; restored render
     confines glow to the crack, ~5 etch strokes, and two fitting patches — approximates the
     "3 primary + ≤5 secondary" cap and the "stops within ~48px of the bearer" rule.
  7. Cold-state legibility: this asset is authored-then-approved as *two separately generated
     states*, not a derived transform — flagged as an open question in §3 below, not silently
     resolved.
  8. N/A (not a husk).
  9. N/A (no frame-count contract for this asset; the restoration *sequence* timing in §8's
     table is not represented by a single static image — see Aseprite task.
- **Aseprite task:** re-author both states by hand at 64×72, indexed to the 32-colour palette,
  1-bit alpha, using these renders as the approved reference for chamber/frame/aperture shape,
  crack path, and etching placement. Then hand-key the restoration sequence per §8's timeline
  table (t=0 flash, 0–400ms brass light-first, 120–2500ms etch draw-on, 2500–3200ms settle) as a
  discrete frame sequence — this is a new authoring task the concept renders do not cover.

## 2. Tilesets `stone` + `terracotta`

- Approved: `tileset-stone/tileset-stone-concept-v2.jpg`, `tileset-terracotta/tileset-terracotta-concept.jpg`.
- Rejected, kept for provenance: `tileset-stone/tileset-stone-concept.jpg` (crisp ink outline
  around every block — direct §2 R4 violation).
- Self-check:
  - Palette/value ramp: stone concept reads as `ST0–ST4` family: deep crevice, shadow, body, lit
    face, sparse rim highlight, matches the doc's 5-step ramp. Terracotta reads as `TC0–TC3`
    (4-step, warmer/more saturated red-orange, correctly distinct from stone).
  - No-outline rule: stone v2 passes — joints are value-step, no ink line. **Terracotta has a
    visibly more defined grout line than the stone concept — flagged, not silently accepted.**
    It's closer to a "soft dark seam" than a hard black contour, but it's borderline against §2
    R4 and should be tightened during Aseprite authoring rather than treated as approved as-is.
  - Detail as wear, not line: hairline cracks and mottling read as soft value marks in both,
    correct.
  - Curvature before angle: both are cut masonry/fired tile — straight edges are correct here
    per §2 R1 ("straight edges exist only where something was cut... never as the natural
    resting shape" — quarried/fired material is legitimately cut).
- **This is not a 47-tile autotile set.** Each concept is one representative composed patch
  showing material language and value ramp — not tile-adjacency logic (inner/outer corners,
  edges, etc.). **Aseprite task:** build the actual 47-blob set per family at 16×16px using
  these concepts as the material/value reference; tighten the terracotta grout treatment to
  match the stone concept's value-step (no-line) joint during that pass.

## 3. Membrane

- Approved: `membrane/membrane-slack-v2.jpg` (slack/default state).
- Rejected, kept for provenance: `membrane/membrane-slack.jpg` (sag rendered as a deep
  funnel/near-black void — reads as a hole, not "a drum nobody has tightened," and risked
  colliding with the void/hole visual language reserved for the Verse-bearer's crack; also had
  harder rim/lug outlines than the corrected pass).
- Self-check: hoop reads as a tension mechanism (lugs + worn contact-polish spots), dull
  oxidized bronze-green (no brass/gold), dusty tan skin with visible dust specks, shallow
  catenary sag reading as slack-not-hollow. No icon/glyph affordance — cues are all material/
  motion per §9.1's diegetic-only rule.
- **Not generated:** the taut state, the tremble cycle (3 frames), ramp-in (3 frames), ramp-out
  (2 frames). A generative image model cannot produce a coherent in-between animation sequence
  from a single static concept. **Aseprite task:** author all seven states/frames by hand at
  64×20, indexed, using the slack concept as the material/proportion reference; the taut state
  keys off the doc's `HK3`/`BZ2`/`ST4` values directly (§9.1 table) rather than needing a
  separate generated concept.

## 4. Bell-frame

- Approved: `bell-frame/bellframe-high-v2.jpg` (high/default state).
- Rejected, kept for provenance: `bell-frame/bellframe-high.jpg` (bell rendered in bright
  saturated lit gold — direct violation of the dormant-metal rule for a cold/high default state,
  which must stay in the `BR1`/`BR2` dull range with no `BR4`; also had stray prong shapes above
  the yoke not called for anywhere in the brief).
- Self-check: three masses read (bell / yoke / rail), bell is muted dormant brass in the
  approved version, worn travel-band on the rail present (though could be tightened further —
  still reads slightly wide relative to "one-sixth of rail width" spec), off-plumb tilt present,
  no chain (rigid yoke-on-rail per brief). Brass is the only metal-accent color in the image,
  consistent with "only brass mass in R4" rule (that rule is about the *room*, not this image in
  isolation, but the asset doesn't contradict it).
- **Not generated:** the low/sustaining state, travel ×12 frames, swing ×2 frames. **Aseprite
  task:** author all state/frames by hand at 40×48; low state keys `BR2`/`BR3` (and `BR4` only
  where `w > 0`, i.e. never in this concept's cold/high context) per the §9.2 table.

## Open questions for the Art Director (do not silently resolve)

1. **Verse-bearer cold/warm as two separately generated images, not a derived transform.**
   §4.1 states cold is *always* a derived transform over a warm original, never separately
   authored — that's a hard rule for ordinary sprites/tiles. The Verse-bearer's cold and
   restored states are visually and materially different enough (closed vs. lit aperture, dust
   vs. glow, dormant vs. lit fittings) that it's unclear whether §4.1 is meant to apply to it
   literally, or whether the restored state is instead "warm" and the *cold* state generated
   here is what the runtime transform should derive from — i.e. is `versebearer-cold-v2.jpg`
   the §4.1 input, and does applying the transform to it need to reproduce something close to
   the *shape* of `versebearer-restored-v2.jpg` (minus the emissive elements, which §4.1 says a
   derived cold state never gets)? Recommend the Aseprite artist author only the warm
   (restored-adjacent, non-emissive) version as the §4.1 source and derive cold mechanically,
   rather than hand-authoring both — but that's a production-process call, not this batch's to
   make unilaterally, so flagging rather than deciding.
2. **Terracotta tileset grout line** is borderline against the no-outline rule — noted above,
   recommend tightening in the Aseprite pass rather than re-running generation.
3. **Bell-frame worn travel-band width** reads a little wider than the "one-sixth of rail width"
   spec — minor, worth a look in the Aseprite pass, not worth another generation cycle.

None of the four assets turned out to be impossible under the brief — no constraint is flagged
as contradictory or unworkable. All four just require Aseprite hand-authoring beyond what image
generation can produce, per the capability boundary above.
