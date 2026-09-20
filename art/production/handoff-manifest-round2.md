# Batch 1 — round 2 (post-adjudication corrections)

Responds to the Art Director's adjudication of the Visual Identity Critic's CHANGES_REQUESTED.
Constraint set: `docs/art/vertical-slice-art-direction.md` as corrected (§4.1b, §8, §9.1, §9.2,
§10, §13, new §14). One render language used across this whole round: flat posterized value
steps, orthogonal, no staging, authored warm — per §14.

## Verse-bearer

- Dormant: `verse-bearer/versebearer-dormant-v4.jpg` (+ `-sheet.jpg` with shipping-size and
  black-fill panels). Restored: `verse-bearer/versebearer-restored-v3.jpg` (+ `-sheet.jpg`).
- Fixed: no arch/loop/handle/bail anywhere in the sprite (two prior attempts still fused one in —
  `versebearer-cold-candidate.jpg` had the full arch, this round's first pass
  (`versebearer-dormant-v3.jpg`, kept for provenance, not promoted) still had a suspension loop
  fused to the chamber shoulders — same defect in a new shape); aperture is a hard-edged
  off-center slot with no lid/brow/crescent; fittings are formed hardware (band, hex-bolt, plate)
  in flat muted `BR1`/`BR2` only, zero green anywhere; crack now carries a bright `ST4`-equivalent
  fracture lip so it's legible dormant, not just once lit; etchings sparse (~5 lines) with most of
  the chamber bare.
- **Not fixed, and I want to be explicit about it rather than call this done: the three-mass
  silhouette test still fails at 64×72 black-fill** (see the sheet's third panel). Removing the
  arch fixed the *architecture* fusion the critic flagged, but the frame-rib mass I added at the
  base is still contour-continuous with the chamber — nothing separates them in outline, so the
  black fill reads as one blob with a small interior notch (the aperture), not three legible
  masses. I ran this correction twice (`-v3` then `-v4`) and the generator keeps defaulting to a
  single fused contour no matter how I describe the ribs as a separate mass — this looks like a
  real limit on how much silhouette topology I can direct through prompting alone, not something
  a third prompt attempt is likely to fix. My recommendation for the Aseprite pass: make the rib
  mass extend *past* the chamber's outer edge (protrude beyond the bell curve on at least one
  side) so the black-fill test has an actual gap between chamber and frame, rather than trying to
  separate them by color alone the way this concept does. Flagging this now rather than
  presenting the sheet as passing when the panel it carries shows it doesn't.

## Terracotta

- `tileset-terracotta/tileset-terracotta-v2.jpg`. Full `TC0`–`TC3` range now visibly in use
  (dark shadow tiles and bright rim tiles both present, not clustered at two mid-tones), irregular
  tile sizes, thin joint gap rather than a bold grout line.

## Stone

- `tileset-stone/tileset-stone-v3.jpg`. Field re-biased toward the pale `ST3`/`ST4` range per
  §10's derived floor. Joint gap is thinner than the batch-1 version but still reads a little
  bolder than a pure value-step in a couple of places — worth tightening in the Aseprite pass,
  not worth a third generation cycle over.

## Membrane

- `membrane/membrane-slack-v3.jpg` (+ `-sheet.jpg`). Flat orthogonal (a true circle, not the
  three-quarter ellipse the critic rejected), no cast shadow/floor/backdrop, sag is off-centre
  and asymmetric (an irregular lopsided pool, not a concentric basin).
- **Open question, not silently resolved: canvas-aspect mismatch.** §9.1 still specifies
  `64 × 20 px` — a 3.2:1 wide shape — but "flat orthogonal, no three-quarter" pushed me toward a
  true 1:1 circle, which doesn't fit that canvas at all without either cropping most of the disc
  off or squashing it. I generated the true circle because that's the most literal reading of
  "kill the three-quarter view," but I'm not confident that's what was meant, since the original
  64×20 spec was written *before* this correction and hasn't changed. Two readings I can see,
  and I didn't pick one: (a) the membrane is meant to be seen edge-on/low-angle as a shallow wide
  basin (closer to the old proportions, wrong projection), or (b) the 64×20 canvas itself needs
  revisiting now that the projection is corrected. I'd rather ask than guess a third time in two
  different directions. The hoop/sag/dust material treatment in this candidate carries over
  either way once that's settled.
- Minor: hoop color reads a bit more saturated/light green than `BZ1`-dominant — worth a value
  pass in Aseprite, not a re-generation.

## Bell-frame

- `bell-frame/bellframe-high-v3.jpg` (+ `-sheet.jpg`). Rebuilt as 4–5 tuned bronze tubes of
  stepped length in a yoke — no bell curve, no cast bell mouth anywhere. Rail reads as stone
  (`ST2`/`ST3`, no wood grain). Both tubes and yoke authored in the warm `BR2`/`BR3` range per
  §9.2's correction (no pre-baked-cold darkening this time). **Passes the black-fill silhouette
  test at 40×48 cleanly** — two legible masses (tube cluster, rail) survive shipping size, unlike
  the Verse-bearer above.

## What I'm not claiming

Provenance for every rejected intermediate pass is kept alongside the approved files, per the
standard the critic asked to keep. Nothing in this round is final production art — per §14 these
are still concept references for the Aseprite pass, now built to the corrected constraint set and
carrying the shipping-size/black-fill proof panels §14 requires. The Verse-bearer's silhouette
panel is included specifically because it does *not* pass — that's the finding, not a defect to
paper over before sending it back.
