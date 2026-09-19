# Audio Bible — slice-scoped

Owner: Audio Director. Scope: **the first vertical slice only** (`docs/design/vertical-slice.md`,
"The Cold Amphitheater"). Written against approved creative direction
(`docs/creative-direction.md`) and technical direction (`ARCHITECTURE.md`).

This is not the audio bible for the whole game. It is the part the slice exercises, written so it
**composes into** the full bible later rather than pre-empting it. Every rule below is either
(a) derived from already-approved direction, or (b) marked **[PROVISIONAL]** and carrying a note
about what would make it canon.

Audio in this slice is not dressing. The defensive verb times against a sound, and progression is
carried by the music's state. Two systems in this game are made of audio; if the audio is wrong,
they do not exist.

---

## 0. Canon status, and why nothing here fires a Creative Checkpoint yet

Establishing the game's signature leitmotif is a Creative Checkpoint trigger in the normal case.
It is not being treated as one here, deliberately, for the same reason and by the same precedent
the design spec uses for protagonist identity (§10 of the slice spec):

- The Creative Director's standing instruction on the parent issue is explicit — *"Do not wait for
  my approval & start defining & delivering on your own. Don't come back to me before a first
  playable version."* A blocking checkpoint now is the one outcome that instruction rules out.
- The material below is therefore **slice-provisional and explicitly non-canonical**. The slice
  ships it so the loop can be played and judged; it does not make it the game's identity.
- The **post-play checkpoint** is where it becomes canon or gets replaced. §11 lists exactly what
  needs a decision, so the question arrives with a playable answer attached rather than as an
  abstract one. A phrase you have heard land is a far better checkpoint than a phrase described
  in prose.

Nothing here closes the register taxonomy, the "why this Verse went quiet" categories, or the
third Verse's interval. Those stay open.

---

## 1. Capability honesty

**No vocal-synthesis, sample-library, recording, or generative-audio capability is available in
this toolchain.** Everything in `audio/reference/` is deterministic additive/subtractive synthesis
written for this project (`tools/audio/synth_slice_audio.py`).

What that means concretely:

- These are **reference/temp-track** assets. They encode the *timing, spectral and level contract*
  exactly, and they are good enough to playtest H2, H3 and H6 against. They are **not** final vocal
  performances and must not be described as such to a playtester or in a release.
- Sung material is a synthetic approximation of a voice. It carries the right pitch set, the right
  contour, the right formant region and the right articulation timing. It does not carry a singer.
- They are a **strict upgrade on engineering's placeholders** and should be dropped in now, not at
  polish — because half of what the playtest measures is whether these timings are readable, and
  placeholder beeps cannot answer that.
- Replacement path when a voice capability exists: re-record against §2–§6, keep every timing and
  level number, re-run the measurement harness, diff the numbers.

**Provenance / licensing:** no third-party audio, no samples, no model output, no recorded
performance. Fully original and deterministic — a fixed RNG seed means re-running the script
reproduces every byte. Settings are the script itself; it is the provenance record.

---

## 2. Pitch material — the Unfinished Phrase

Reference: `audio/reference/leitmotif_01_cold_acappella.wav`, `_02_warm_grounded.wav`,
`_03_AB_proof.wav`.

### The phrase

Free time, unmetered, near a cappella. One voice in the alto region plus one much quieter shadow
voice on two notes only.

| # | pitch | Hz | onset (s) | length (s) |
|---|---|---|---|---|
| 1 | A4 | 440.00 | 0.00 | 0.90 |
| 2 | D5 | 587.33 | 0.95 | 0.80 |
| 3 | C5 | 523.25 | 1.85 | 0.85 |
| 4 | A4 | 440.00 | 2.80 | 0.80 |
| 5 | G4 | 391.99 | 3.70 | 0.95 |
| 6 | A4 | 440.00 | 4.75 | held 2.60, decays to nothing |

Shadow voice (quartal, −22 dB): A4 under note 2, G4 under note 3.

### What is missing, and why it is the whole design

Pitch set: **{G4, A4, C5, D5}**. Two things are deliberately absent:

- **No root.** Nothing grounds these pitches. The ear cannot decide what key it is in — the same
  four notes read plausibly as two different tonalities and refuse to settle. This is what
  "unfinished" means here: not sad, not sparse — *ungrounded*.
- **No third.** There is no F♮ and no F♯, so the phrase makes **no emotional verdict**. Major or
  minor is undeclared. This is deliberate and it is load-bearing narratively: the slice may seed
  doubt about the choir, it must not reveal. A phrase that has already decided whether this is a
  tragedy has revealed.

Forbidden: adding any pitch outside this set to the cold-state phrase, for any reason, including
"it sounded thin." It is supposed to sound like something is missing. Something is missing.

### The one interval restoration adds

**D2 (73.42 Hz) — the root, a perfect fifth below the phrase's floor note A.**

Not one more layer. The note that **re-reads every note above it**. The upper voices do not change
by one sample — the A/B proof file renders both takes from the same buffer at the same fader gain,
so the difference is the interval and nothing else. When the root arrives, the ambiguity resolves,
the phrase acquires a key, and the held A4 that has been hanging since the opening room becomes a
fifth instead of a question.

Measured on the rendered reference:

| | cold | warm | delta |
|---|---|---|---|
| Integrated loudness (LUFS) | −29.5 | −29.6 | **−0.1** |
| Energy 30–200 Hz (dB) | −48.0 | +3.4 | **+51.4** |

Read that carefully, because it is the single most important production fact in this document:
**the restoration is invisible to a loudness meter and unmistakable to an ear.** It is not louder.
It is not brighter. It is not more. It is *grounded*. K-weighting attenuates 73 Hz so heavily that
the meter barely moves, while the 30–200 Hz band — which was empty, genuinely empty, because the
cold phrase has no energy down there at all — gains 51 dB.

Consequence for QA: **do not verify restoration with a level meter.** Verify it by ear, and verify
the low-band energy. A tester who reports "nothing happened" while watching a meter has tested
nothing.

### Reserved, NOT decided here

The **third** — whether this choir is finally major or minor — is reserved for a later Verse.
Do not resolve it in the slice, in any asset, in any variant. It is the phrase's last open
question and it is worth more unresolved.

---

## 3. The low drone register — the Verse's voice

Reference: `verse_sustain_loopbody_3s.wav`, `verse_sustain_breath_end.wav`, `verse_return_seam.wav`.

Fundamental **D2 = 73.42 Hz**.

**The small-speaker rule.** D2's fundamental is close to inaudible on a laptop, a phone or a cheap
TV. The perceived low must therefore live in **harmonics 2–5** (146.8 / 220.2 / 293.7 / 367.1 Hz)
and in a throat formant around 430–560 Hz — the fundamental is held back to ~35% and is a
*reinforcement*, not the sound. Test: if the drone disappears on a phone speaker, it is not the low
register, it is a sub-bass effect, and it has failed. The Verse the player restored must still be
there on bad speakers or the progression system is invisible to half the audience.

**The drone is a person, not a texture.** Three rules, all mandatory:

1. **Slow pitch drift** — ±5 cents at ~0.23 Hz. A perfectly stable pitch reads as an oscillator.
2. **A moving formant** — the upper formant sweeps 430↔560 Hz at ~0.17 Hz over a fixed low. This is
   the property borrowed from throat-singing technique (see §9): one throat producing a stable
   fundamental and a *separate moving* upper voice. It is what makes a drone read as alive rather
   than as a synth pad.
3. **Breath** — a band of air around 900 Hz, amplitude-modulated. Someone is doing this with a body.

**Forbidden:** a sine sub, a sawtooth pad, an "ominous drone" preset, anything that holds still.

### Sustain (the traversal verb)

The 180 ms ramp-in is a **gameplay gate** (§4.1 of the slice spec) — for 180 ms nothing in the
world responds. An invisible gate is an unfair gate, so it must be **audible**:

- 0 → 180 ms: the drone swells from nothing (curve `(t/0.18)^1.4`). Nothing else.
- **At exactly 180 ms**: a quiet bowed-metal partial enters (D4 + A4 + D5, 45 ms attack, −14 dB).
  This is the player's only cue that the world effect armed. It is not decoration; it is the
  readout for a rule the player otherwise has to infer from failure.
- Movement while sustaining is ×0.85 — the mix does **not** duck footsteps to compensate. The
  player should hear that they are doing something effortful.

**The seam is a driver, not a speaker.** Sustain excites the room; it does not play a sound at it.
Practically: the Sustain bus feeds the room reverb at a *higher* send than anything else in the
game, and the dry component is small. The player is making the architecture resonate.

### Breath exhaustion

The diegetic UI budget (§9) gives breath a single small arc visible only while sustaining, so
**audio carries the warning**. In the last 600 ms: tremor onset ramping 5 → 13 Hz, amplitude
thinning to 65%. A voice running out of air, not a beeping meter. Then the 120 ms ramp-out.

A player mid-jump is looking at the platform, not at an arc near their feet. They will hear this.

### Return

The enemy's own note released back out of the seam. It must carry **the enemy's register inside the
Verse's body** — the reed band (≈520 Hz, −9 dB) is mixed into the D2 body and the seam transient.
The point of Return is that it is *their* sound coming back, not a new weapon you acquired. If it
sounds like a generic power attack, the mechanic's meaning is gone and H3 is untestable.

---

## 4. Tell sounds — the dedicated dry channel

Reference: `tell_reed_husk_*.wav`, `tell_keening_husk_*.wav`, `h6_AB_reed_vs_keening.wav`.

Slice spec §5.4: *an enemy whose tell is inaudible under the mix is a bug, not a tuning
preference.* This section turns that into numbers that can fail a build.

### 4.1 The one rule, two values (this is H6)

Both tells are **one gesture**: *a voice announces itself, then travels toward you.*

- Reed Husk: **low, dry, short travel.**
- Keening Husk: **high, thin, long travel.**

The critical production rule, and the thing that decides whether H6 survives:

> **Lead time must be audible as the distance the sound travels — never as dead air.**

A 700 ms tell that is a 160 ms identity followed by 540 ms of nothing does not teach a player that
this enemy is slower. It teaches them that this enemy has a pause in it. The gesture must *occupy*
its lead: the Reed's rattle accelerates across the whole window, the Keen's pitch rises across the
whole window. A player who has never seen a number must be able to say "that one takes longer,"
because the sound is longer, not because the wait is longer.

This is also why tells **must time-stretch to their lead** rather than being fixed-length files —
see §7, it has a real failure mode.

### 4.2 Reed Husk — percussive / throat, 520 ms lead

| | |
|---|---|
| **Identity** | a **DOUBLE KNOCK** — split-reed crack at **0 ms** and again at **95 ms** |
| Register | throat formant ≈520 Hz, lowpassed at 1300 Hz (2-pole) |
| 160 ms → attack | dry throat rattle, **accelerating 9 → 23 Hz**, band sweeping 240 → 500 Hz |
| Answered | the note is **not cut off** — it *completes to its interval*, resolving up to A3 |
| Unanswered | the rattle is cut off by the lunge: a hard stop, no completion |

The doubleness is the identity. It is cheap, it is unmistakable, it survives any mix and any
speaker, and it is complete at 95 ms with 65 ms of budget to spare.

Nothing in this cue exists below 170 Hz. **The low register belongs to the Verse** — an enemy that
occupies it would blur the one sound in the game that means "you restored something."

### 4.3 Keening Husk — keening / high, 700 ms lead

| | |
|---|---|
| **Identity** | hard glottal onset, then an upward **PITCH BREAK** of a minor 7th, A4 → G5 |
| Attack | **≤15 ms, never a fade-in** (see the warning below) |
| Contour | A4 held 35 ms → fast kinked glide → G5, then slow rise to Bb5 across the lead |
| Vibrato | rate rises 4.5 → 7.5 Hz across the lead; the cue **thins** (−32%), never swells |
| Answered | resolves back down to A4 and completes |
| Unanswered | the projectile spawns |

The **kink** is the identity — a break, not a smooth portamento. A smooth glide reads as generic;
a break reads as a specific throat doing a specific thing, and it is the opposite gesture from the
Reed's double-knock. Two creatures, two opposite motions, one grammar.

> **Warning, and it constrains the sound design permanently:** the 160 ms transient budget and this
> gesture are only compatible because the attack is ≤15 ms. Give this cue a 60 ms swell — the
> instinctive choice for a keening voice, and what a singer would naturally do — and the identity
> lands past 160 ms and the contract breaks. **The keening tell may never fade in.** This is the
> single most fragile rule in this document and it is the one most likely to be broken by someone
> trying to make it sound nicer.

### 4.4 Level: match by loudness, never by peak

At identical peak levels the Reed measured **14 dB quieter in RMS** than the Keen — a percussive
double-knock and a sustained tone are not equally audible at matched peaks. Peak-matching them
would ship one enemy whose tell is reliably harder to hear. That is §5.4's "bug."

**Rule: tells are level-matched on short-term K-weighted loudness over their first 160 ms.**

| cue | first-160 ms | peak |
|---|---|---|
| Reed 520 ms | −23.0 LUFS | −3.0 dBFS |
| Keening 700 ms | −23.0 LUFS | −14.1 dBFS |
| Reed 458 ms (compressed) | −23.0 LUFS | −3.0 dBFS |
| Keening 616 ms (compressed) | −23.0 LUFS | −13.8 dBFS |

**The TELL bus therefore needs 11 dB of peak headroom above its loudness target.** Do not limit or
compress the bus to reclaim it — clipping the Reed's knock destroys exactly the 2 ms that carries
its identity.

### 4.5 Spectral separation

Slice spec §5.5 staggers tell onsets, but two tell windows can still be open at once (see §10.4).
When they are, they must be separable by ear. Measured share of energy below 700 Hz:

| cue | <700 Hz | >700 Hz |
|---|---|---|
| Reed Husk | **0.543** | 0.429 |
| Keening Husk | **0.008** | 0.986 |

The Keening Husk puts eight-tenths of one percent of its energy in the Reed's region. They cannot
be confused. Any future enemy added to this zone must be checked against this table before it
ships — the third tell is where this kind of design usually quietly breaks.

### 4.6 Measured transient compliance

| cue | identity lands at | budget | pass |
|---|---|---|---|
| Reed 520 ms | 1.0 ms + **95.6 ms** (double knock) | 160 ms | ✅ |
| Keening 700 ms | **72.0 ms** (f0 reaches G5) | 160 ms | ✅ |
| Reed 458 ms | 1.0 ms + 95.6 ms | 160 ms | ✅ |
| Keening 616 ms | 72.0 ms | 160 ms | ✅ |

Regenerate with `python3 tools/audio/synth_slice_audio.py`; numbers land in
`audio/reference/MEASUREMENTS.json`. This is a regression test, not a one-off report — run it
whenever a tell changes.

---

## 5. The R6 restoration phrase

Reference: `r6_offer_3note.wav`, `r6_offer_5note.wav`, `r6_restoration_complete.wav`.

The bearer's notes are drawn from **the Unfinished Phrase itself** — this is where the phrase comes
from, so biome and faction variants later are variants *of this*, not new themes.

| note | pitch | onset |
|---|---|---|
| 1 | A4 | 0 ms |
| 2 | D5 | 1100 ms |
| 3 | C5 | 2200 ms |
| 4 | G4 | 3300 ms |
| 5 | A4 (held) | 4400 ms |

Each note is a tell with a 700 ms lead, per spec §7.1.

### 5.1 How an offer differs from an attack when the timing is identical

The bearer uses **the same 700 ms lead as the Keening Husk**. The timing therefore carries *none*
of the distinction — timbre and shape carry all of it:

| | enemy tell | bearer note |
|---|---|---|
| space | **dry** (no reverb, by contract) | **wet** — sung into the amphitheater, 2.6 s tail |
| width | narrow | wide |
| contour | **rises** | **falls and settles** (−26 cents over 450 ms) |
| body | thins toward the attack | holds, open |
| attack | ≤15 ms, hard | 30 ms, breathed |
| ending | runs straight into the attack | ends into its tail and **leaves a gap** |

The last row is the real one. **An enemy tell never leaves space. The bearer always does.** The
silence after each note has shape — it is the sound of someone waiting for you. That is what makes
the encounter read as a conversation rather than a pattern, and it is the whole reason the same
verb can mean "defend" in R5 and "agree" in R6.

### 5.2 Answering joins; it does not cancel

In combat, a successful Answer **unmakes** the enemy's note. In R6, a successful Answer **sounds
with** the bearer's note — consonant, at the fifth or the octave, overlapping rather than replacing.

Same verb, opposite valence. This is the H3 payload, and it is an audio decision: if the player's
answer in R6 cuts the bearer off the way it cuts an enemy off, the encounter is a boss fight no
matter what the design document says.

### 5.3 The phrase grows from its head, never its tail

Adaptive shortening (spec §7.4) and extension (§7.5) both operate on the **head**:

| length | notes |
|---|---|
| 1 | A4 |
| 2 | A4 D5 |
| 3 | A4 D5 C5 |
| 4 | A4 D5 C5 G4 |
| 5 | A4 D5 C5 G4 A4 |

The player hears the same beginning every single time, which is how they learn it. Growing from the
tail — or re-offering a different subset — would mean a struggling player hears a *different* phrase
each attempt, which is the opposite of meeting them. This is an engineering contract, not a
preference; see §7.

### 5.4 Restoration: the floor arrives, and that is all

On the 5th note, D2 enters **underneath the held A4**. A bare perfect fifth — the most consonant
interval there is. Open, wide, no third, no verdict.

**No victory sting. No fanfare. No cymbal, riser, choir swell, bloom, or bright new layer.** The
only new sound is the drone, and it enters on a 1.25 s breath envelope — it *arrives*, it does not
hit.

This is testable, and it is tested:

| | LUFS |
|---|---|
| `r6_offer_5note` | −20.8 |
| `r6_restoration_complete` | **−21.6** |

**The restored take is 0.8 LU quieter than the offer it completes.** The event is felt as *depth*,
not as volume.

> **Rule: post-restoration peak and integrated loudness must not exceed pre-restoration.**
> Any build where the restoration is louder has turned agreement into victory. Asserted in
> `MEASUREMENTS.json` as `r6_no_victory_sting`.

### 5.5 The 1400 ms silence after a miss

Spec §7.3: on a missed note the phrase stops and there is a 1400 ms silence before the re-offer.

**That silence is a scored event — treat it as material, not as absence.** Nothing plays in it.
Not a "miss" sound, not a soft negative cue, not a reverb swell, not a sympathetic hum. The phrase
falls apart and the room is left holding it.

This is the one moment in the slice where the direction's "silence is a primary instrument" line
has to actually be true. A designer's instinct here is to fill it with feedback so failure reads as
acknowledged. Don't. The unacknowledged silence *is* the feedback, and it is the sting the spec
says failure should have — "the sting of a phrase falling apart," costing nothing but time.

---

## 6. Ambience and the dynamic-range contract

Reference: `amb_cold_near_silence_30s.wav`, `amb_warm_restored_30s.wav` (both seamless loops).

| state | target | measured |
|---|---|---|
| Cold | −46 LUFS | **−46.0** |
| Warm | −28 LUFS | **−28.0** |
| **Restoration event** | ≥15 LU | **18.0 LU** |

### Cold

**Single-source ambience only. No pad. No bed. No drone. No music.**

Room air (lowpassed at 190 Hz, plus a whisper of high air), and *intermittent single sources*
8–20 s apart: a distant drip, stone settling, wind through a broken pipe. That is the entire
content of a cold room. The player should occasionally wonder whether the audio is working.

The Unfinished Phrase appears in R1/R2 a cappella, very quiet, **once**, and then not again for
40–90 s. It must feel half-heard — something you are not sure you heard, that you cannot ask to
repeat. If a tester can hum it after R1, it is mixed too loud.

### Warm

The drone bed sits under everything, zone-wide. The phrase recurs more often and more fully.
Ambience rises 18 LU.

### The rule that protects all of this

> **No per-asset or per-room loudness normalization. The mix is authored across the zone.**

This is the standard way this design dies in implementation. Somebody notices R1 is "too quiet,"
normalizes it to a comfortable level, and the 18 LU event silently becomes a 2 LU event —
and then H5 fails in playtest for a reason nobody can find, because every individual asset
measures fine. The gap between −46 and −28 **is** the restoration. Protect the quiet end of it
as carefully as the loud end.

Corollary: never trim the cold rooms up. If cold is uncomfortably quiet, that is the design
working. The only legitimate global adjustment is moving both ends together.

---

## 7. FMOD implementation contract

Full contract, with acceptance tests and parameter tables, is in
**`docs/audio/fmod-implementation-contract.md`**. It is written to be actionable against
placeholder audio, so Engineering is not blocked on final material — every rule there can be
implemented and tested before a single final asset exists.

The three that will bite hardest if missed:

1. **Tells time-stretch to their lead; they are not fixed-length files.** Repeat compression
   (520→458, 700→616) must stretch the gesture, not truncate it or pad it. A truncated tell means
   the accelerando's landing point lies to the player, and the compressed encounter — which is
   every encounter after the second tell — teaches the wrong timing.
2. **The game clock owns the window; FMOD owns the sound.** Audio latency must never move the
   gameplay tell window, or the debug overlay (spec §9, §11.3) shows a mismatch that is real.
   Schedule the sound so its transient lands at window-open ±10 ms; open the window on the tick.
3. **Loading a restored save starts warm, silently.** No fade-in of the restored interval on load,
   or the player hears the world re-restore itself every time they load. Restoration is a one-time
   event; the save flag reproduces a *state*, not a replay. (Spec §11.11.)

---

## 8. Forbidden

From approved direction:

- A generic "sad choir pad" used as atmospheric wallpaper.
- The same vocal register for combat tells and for ambience.
- An orchestral swell as the payoff for an ability unlock.
- Imitating a living composer, or reproducing another game's signature musical identity.

Added by this document, slice-scoped:

- Any reverb, send, or spatialization on the TELL bus.
- Any tell whose identity is not complete by 160 ms.
- A fade-in on the keening tell (§4.3).
- Any enemy sound below 170 Hz — the low register belongs to the Verse.
- Level-matching tells by peak instead of by first-160 ms loudness.
- Any victory sting, riser, bloom or bright layer at R6 completion.
- Any sound at all inside the 1400 ms post-miss silence.
- Per-asset or per-room loudness normalization.
- Music beds that stop and restart at a room transition.
- A fade-in of the restored interval on save load.
- Adding pitches outside {G4, A4, C5, D5} to the cold-state phrase.
- Resolving the third (F♮ / F♯) anywhere in the slice.

---

## 9. References — translated into properties, not names

Every reference below is cited for **one specific transferable property**. None is cited as a style
to imitate, and none of this material's repertoire, language, or signature is being reproduced.

| reference | the property taken | explicitly NOT taken |
|---|---|---|
| Sardinian *canto a tenore*, the `bassu` role | a bass voice can be a drone **and** a rhythm at once, and an ensemble can read as identifiable individuals rather than as a pad | the repertoire, the language, the vocal style, the cultural signature |
| Tuvan throat technique (`kargyraa` family) | one throat can hold a stable fundamental while a **separate upper formant moves** — this is what makes §3's drone read as alive rather than synthetic | the timbre itself, the idiom, any attempt to sound "Tuvan" |
| Corsican *paghjella*, the *terza* entry | a third voice entering **re-reads** the two already sounding — the model for §2's grounding interval | the modal language, the repertoire |
| Struck-resonant-body decay (bells, tam-tams) | decay exceeds attack by orders of magnitude; a room's tail is how it tells you its size — which is why the dry tell channel is the only thing in the game without one | any specific instrument's recorded character |
| Room-as-instrument process work (Lucier and after) | a space can be made audible by **exciting** it — the model for "the seam is a driver, not a speaker" | the compositions, the process as an aesthetic |

The test for whether a reference is being used correctly: could you implement the property without
having heard the reference? If yes, it is a property. If no, it is an imitation.

---

## 10. Findings for Game Design — my side of the joint tuning pass

The slice spec asked for these to come back rather than be absorbed silently. Four did.

### 10.1 H6's register→timing mapping survives contact with real sound — with one hard constraint

**Verdict: the mapping holds. 520 ms / 700 ms both work. Do not change the numbers.**

The constraint is on me, not on Design: the keening tell's identity fits inside 160 ms **only**
because its attack is ≤15 ms. Measured at 72 ms, so there is real margin — but that margin exists
only under a no-fade-in rule, which is now §4.3 and is in the forbidden list. Recorded here so that
if a future keening-register enemy misses its transient budget, the cause is known immediately
rather than rediscovered as a tuning mystery.

The thing that actually decides H6 is not the two numbers. It is the rule in §4.1: **lead time has
to be audible as travel, not as waiting.** If playtesters fail to form the mapping, check that
before you consider changing 520/700 — the likely failure is a tell with dead air in it, not a tell
with the wrong duration.

### 10.2 The repeat-compression floor never engages at slice values — confirm it is a safety net

Reading §5.3 as a single 88% step: Reed 520 → **458 ms**, Keening 700 → **616 ms**. Both are well
above the 420 ms floor, so **the floor is unreachable in this slice.**

Either reading is fine, I just need to know which, because it changes what I build:

- **(a) safety net for future enemies** — nothing to do, I'll note it as intentionally inert.
- **(b) compression was meant to be iterative** (0.88ⁿ, so Reed 520→458→403→**420 floor** by the
  4th tell) — then the floor is load-bearing and I need to build Reed tells that still read at
  420 ms. That is tight but achievable: the double-knock ends at 95 ms, leaving 325 ms of
  accelerando, which is enough for the gesture to still read as travel.

I've built for (a) and rendered the single-step values. If it's (b), say so and I'll render the
420 ms floor case — it's a re-run of the script, not a redesign.

### 10.3 The R6 narrative gap is ~400 ms, and 12 words cannot be read in 400 ms

Notes are 1100 ms apart with a 700 ms lead, which leaves roughly **400 ms** of gap. Narrative's
budget (§7) is ≤12 words per gap. At normal reading speed 12 words needs ~3.5 s. The two numbers
are not compatible as literally written, and this lands on Narrative as much as on us.

This is not a "make the gaps longer" request — 1100 ms spacing is load-bearing for the phrase
reading as a phrase, and stretching it would make the offer drag.

**My recommendation:** the line *lands* in the gap and *persists* across the following note,
fading as that note's tail decays — roughly 1500 ms of on-screen life. The player reads it while
the next note sounds, which is exactly the "learning why while learning the phrase" intent, and
arguably better than reading it in silence.

Audio's side either way: the bearer's tail is authored to fall below the ambience floor within
~350 ms of the note ending, so the gap reads as *waiting* and the text has somewhere quiet to sit.
That is already how the reference renders. Both resolutions work against what I've built — I just
need to know which one Narrative is writing to. Flagging rather than choosing, since the word
budget is theirs.

### 10.4 Two tell windows can be open at once, and §3.3 doesn't say which one an Answer resolves

§5.5 blocks a tell from starting within 200 ms of another's onset — but it does not prevent overlap
beyond that. In R5 (one Reed, one Keening) a Reed tell starting 250 ms into a Keening's 700 ms
window is legal, and both windows are then open with one Answer button between them.

**Recommendation: resolve to the tell whose attack lands soonest**, and give the unanswered tell no
penalty. Rationale is partly mine: urgency is what the mix makes salient anyway, so resolving to
the most imminent attack matches what the player's ear is already telling them, and resolving to
anything else will feel like the game ignored their input. The alternative — resolving to the most
recent onset — would sometimes answer the *further* enemy while the nearer one lands, which reads
as a bug in a game about listening.

Audio supports either choice: §4.5's measured separation (0.8% vs 54.3% below 700 Hz) means the two
open tells are never spectrally confusable. But the resolution rule is Design's call and it needs to
be written down before Engineering picks one implicitly — this is the kind of thing that gets
decided by whichever array index happens to come first.

---

## 11. For the post-play Creative Checkpoint

Everything in §0 that is provisional, with a playable answer attached rather than a prose pitch:

1. **Is the Unfinished Phrase the game's signature?** The A/B file is the whole pitch: listen to
   `leitmotif_03_AB_proof.wav` and the question answers itself in 22 seconds.
2. **Is "the missing interval is the root" the right mechanic** for cumulative music, as against
   adding a voice, a harmony, or a countermelody per Verse? This choice determines every future
   Verse's payoff and is genuinely expensive to reverse once players have learned it.
3. **Should the third stay unresolved** across the whole first region, as §2 reserves it?
4. **Does restoration-as-depth rather than as-volume land**, or does it read as anticlimax to
   someone who has just spent 15 minutes earning it? §5.4 is a deliberate bet against the instinct
   to reward. Playtest is the only way to settle it.
5. **Does the low drone survive the player's actual speakers?** §3's small-speaker rule is the
   mitigation; the playtest should include at least one laptop-speaker session, because the whole
   progression system is inaudible if it fails.
6. The voice itself is a synthetic approximation (§1). Whether the sonic identity is *right* can be
   judged from these files; whether it is *good* cannot be judged until a voice exists.
