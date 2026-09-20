# FMOD implementation contract — vertical slice

Owner: Audio Director. Consumer: Engineering Lead and builders.
Companion to `docs/audio/AUDIO_BIBLE.md`; runtime fixed by `ARCHITECTURE.md`
(FMOD Studio via GDExtension; Godot native buses only for trivial UI one-shots).

**Every rule here is implementable and testable against placeholder audio.** Nothing below waits
on final material — that is the point of writing it now. Wire the bus topology, the parameters,
the scheduling discipline and the save behaviour against beeps, and swapping in
`audio/reference/*.wav` becomes a content change rather than a systems change.

---

## 1. Bus topology

```
MASTER
├── TELL     dedicated, DRY. no reverb send, no spatial send, never ducked, never limited.
├── VOICE    the bearer, the leitmotif, the choir.        → amphitheater reverb
├── VERSE    Sustain, Return, seam sounds.                → room reverb, high send
├── AMB      ambience beds and one-shot sources.          → room reverb
└── SFX      footsteps, impacts, flavor vocalization.     → room reverb
UI            Godot native buses (per ARCHITECTURE.md), not FMOD.
```

**TELL is inviolable.** No effect of any kind on this bus. No reverb, no delay, no spatialization,
no bus compression, no limiter. It is the only signal path in the game with no room on it, and that
absence is itself the cue: a dry sound in a reverberant world is a sound that is *about to happen
to you*. It also happens to be what makes tells legible in a dense mix.

Do not put a limiter on TELL "for safety." The Reed's identity is 2 ms of transient; a limiter eats
exactly that.

## 2. Ducking

Any open tell ducks `AMB`, `SFX`, `VOICE` and `VERSE`:

| | |
|---|---|
| Depth | −6 dB |
| Attack | 40 ms |
| Release | 250 ms |
| Duration | tell onset → attack resolution (the full window) |
| Sidechain source | TELL bus |

TELL is never itself a duck target, including by another tell.

## 3. Levels

| bus | target |
|---|---|
| TELL | tells at **−23 LUFS short-term over their first 160 ms** (see bible §4.4) |
| TELL peak headroom | **≥11 dB above target** — the Reed peaks at −3 dBFS at −23 LUFS |
| AMB cold | **−46 LUFS** integrated |
| AMB warm | **−28 LUFS** integrated |

**Acceptance test (§5.4 of the slice spec made falsifiable):** with maximum simultaneous world
activity — both enemies active, player sustaining, ambience at warm level — a tell's **first 160 ms
must measure ≥12 LU above the sum of everything else** at the listener. If it does not, the build
fails. This is a bug report, not a mix note.

**Do not normalize per asset or per room.** See bible §6 — this single mistake silently converts an
18 LU restoration event into a 2 LU one, and then H5 fails in playtest with no traceable cause
because every asset measures correctly in isolation.

## 4. Parameters

| parameter | scope | range | drives |
|---|---|---|---|
| `VerseLowDroneRestored` | global, **saved** | 0 / 1 | leitmotif grounding layer; warm ambience; Sustain and Return availability |
| `PaletteWarmth` | per-room | 0 → 1, **duration derived, not fixed** (see §4.0) | ambience crossfade, reverb character; shares the art lerp (spec §8) |
| `TellLead` | per-event instance | 420–800 ms | **stretches the tell gesture to fill its lead** |
| `TellRepeat` | per-encounter | 0 / 1 | selects the compressed lead (bible §10.2) |
| `BreathRemaining` | global | 1 → 0 | drone tremor and thinning in the last 600 ms |
| `EncounterPhraseLength` | R6 | 1–5 | how many notes the bearer offers |
| `EncounterNoteIndex` | R6 | 1–5 | which note is sounding |

### 4.0 `PaletteWarmth` has no authored duration

**Do not build this ramp to a fixed length.** Spec §8 fixes the *speed* of the cold→warm spread —
300 px/s from the room's warmth origin, linear in distance — and lets the duration fall out of it.
An earlier revision of this row said "0 → 1 over 2500 ms"; §8 no longer contains that number, and
the shipped visual lerp is roughly twice as fast, so building to 2500 ms would have desynchronised
the ambience from the picture it exists to sit inside.

Drive the parameter from the same field the visuals read — `scripts/state/warmth_field.gd`, one
global elapsed clock shared by every room — sampled at the listener, per audio frame:

- each point warms at `distance ÷ 300 px/s` after restoration begins;
- a 24 px leading band sweeps that point (80 ms at the fixed speed), then a 400 ms settle;
- in R6, where restoration actually fires, the far corner lands at **~1.3 s** total;
- §8's floor: the farthest point of that room must warm **at least 700 ms** after the origin. If a
  future re-author breaks that, the room moves — the speed does not.

Two audio-side rules on top of the shared field:

- **Clamp to 1.0.** The visual field overshoots to 1.15 before settling; that bloom is a picture
  effect. An ambience crossfade or reverb send that overshoots reads as a level error, not as
  warmth.
- **Smooth in FMOD, don't re-time.** Any parameter seek speed you set is anti-zipper smoothing
  only, and must stay well under the 80 ms band sweep — it is not a second, slower ramp layered on
  the derived one.

### 4.1 `TellLead` is the one that matters

**Tells must time-stretch to their lead. They are not fixed-length files.**

Failure mode if implemented as a fixed file plus padding or truncation:

- Truncated: the Reed's accelerando is cut mid-gesture, so its landing point no longer coincides
  with the attack. The sound tells the player the attack arrives later than it does.
- Padded: dead air appears between the identity and the attack, which destroys the "lead time is
  audible as travel" rule (bible §4.1) — the rule H6 actually depends on.

Either way the *compressed* tell lies to the player, and after the second tell in an encounter
every tell is compressed. This is the most consequential line in this document.

Concretely: the Reed's rattle rate schedule and the Keen's pitch ramp are both functions of the
total lead. Drive them from `TellLead`; do not author one file per value. The reference renders at
520/458 and 700/616 exist so you can verify the endpoints, not so you can ship four files.

## 5. Scheduling

**The game clock owns the window. FMOD owns the sound.**

- The gameplay tell window opens on the fixed 60 Hz tick, driven by game time.
- The tell audio is scheduled (`setDelay` against the DSP clock) so that its **first transient lands
  at window-open ±10 ms**.
- Audio latency, device buffer size, and output device changes must **never** move the gameplay
  window.

The debug overlay (spec §9, §11.3) draws the tell window against actual input press. If the window
is driven by audio callbacks, that overlay will show real drift on some devices and the team will
spend days chasing a tuning problem that is a scheduling bug.

Per `ARCHITECTURE.md` this is precisely why FMOD is in the stack: pre-scheduled, sample-accurate
triggering rather than fire-and-forget playback.

## 6. The leitmotif is zone-scoped, not room-scoped

Slice spec acceptance criterion §11.11.

- The leitmotif and the drone bed are **zone-scoped FMOD event instances**. They are created on
  zone entry and **must not stop, restart, or retrigger at a room transition**.
- Only ambience *layers* crossfade at a door: 400 ms, equal-power.
- A music bed that restarts at a door turns cumulative world state back into a loop, which is the
  one thing the creative direction is explicit about not doing.

**Test:** restore the Verse in R6, walk R6 → R5 → R4, and confirm the grounding interval is
continuous and phase-continuous across both transitions — not re-faded, not restarted.

## 7. Save / load

- `VerseLowDroneRestored` is the save flag (Godot `Resource` save per `ARCHITECTURE.md`); FMOD's
  parameter is set **from** it on load.
- **On loading a restored save, the world starts warm, silently.** The grounding layer is at full
  state before the first frame renders. No fade-in, no re-swell, no replay of the restoration.
- Restoration is a one-time *event*. The save reproduces a **state**, not the event.

**Test:** restore, save, quit, load. The interval is present from frame one and the player never
hears it arrive a second time.

## 8. R6 encounter

- Phrase length comes from `EncounterPhraseLength` and always grows **from the head** — 1 note is
  `[A4]`, 2 is `[A4 D5]`, and so on (bible §5.3). Never from the tail, never a different subset.
- The bearer's notes route to `VOICE` (wet), **not** to TELL — even though they are mechanically
  tells. This is deliberate: the wet/dry split is what distinguishes an offer from an attack when
  the lead time is identical (bible §5.1).
  *Note the consequence:* the bearer's notes are therefore **not** protected by the TELL bus's
  no-duck rule, so verify their audibility against warm ambience explicitly. This is the one place
  the dry-channel guarantee does not apply and it needs its own check.
- A successful Answer **overlaps** the bearer's note consonantly; it does not cut it off (bible §5.2).
- On completion: the drone enters under the held note. **No sting event exists in the project.**
  Do not author one "for now" — temporary stings become permanent.
- The 1400 ms post-miss silence is **empty**. No event fires in it at all (bible §5.5).

## 9. Sustain

- 180 ms ramp-in: drone swells from zero; the "engage" partial fires at **exactly 180 ms**, which is
  the same tick the world effect arms. These must not drift apart — the partial is the player's
  only readout for an otherwise invisible gate.
- `BreathRemaining` drives tremor and thinning over the last 600 ms.
- 120 ms ramp-out on release, matching the world-effect release.
- High reverb send: Sustain excites the room (bible §3).

## 10. Asset inventory

`audio/reference/` — 48 kHz / 16-bit / stereo. Regenerate with
`python3 tools/audio/synth_slice_audio.py` (numpy only). Measurements land in
`audio/reference/MEASUREMENTS.json` and should be treated as a regression test.

| file | use |
|---|---|
| `leitmotif_01_cold_acappella.wav` | cold-state phrase, R1/R2 |
| `leitmotif_02_warm_grounded.wav` | restored phrase (same upper voices + root) |
| `leitmotif_03_AB_proof.wav` | the A/B — for review and for the checkpoint, not for the build |
| `tell_reed_husk_520ms.wav` | Reed tell, base lead |
| `tell_reed_husk_458ms_compressed.wav` | Reed tell, repeat-compressed |
| `tell_reed_husk_520ms_answered.wav` | Reed tell resolving to its interval on a successful Answer |
| `tell_keening_husk_700ms.wav` | Keening tell, base lead |
| `tell_keening_husk_616ms_compressed.wav` | Keening tell, repeat-compressed |
| `tell_keening_husk_700ms_answered.wav` | Keening tell resolving on a successful Answer |
| `h6_AB_reed_vs_keening.wav` | H6 listening test — all four tells back to back |
| `verse_sustain_loopbody_3s.wav` | Sustain, incl. the 180 ms ramp and engage partial |
| `verse_sustain_breath_end.wav` | breath exhaustion tremor + ramp-out |
| `verse_return_seam.wav` | Return |
| `r6_offer_3note.wav` | bearer's first offer |
| `r6_offer_5note.wav` | bearer's full phrase |
| `r6_restoration_complete.wav` | completion + the drone arriving (no sting) |
| `amb_cold_near_silence_30s.wav` | cold ambience, **seamless loop**, −46 LUFS |
| `amb_warm_restored_30s.wav` | warm ambience, **seamless loop**, −28 LUFS |

Status: reference / temp-track, not final vocal performances — see bible §1. They are a strict
upgrade on placeholder beeps and should be integrated now, because half of what the playtest
measures is whether these timings and levels are readable.

## 11. Build acceptance checklist

Maps to the slice spec's acceptance criteria.

- [ ] TELL bus carries no effect of any kind, and is never ducked or limited.
- [ ] A tell's first 160 ms measures ≥12 LU above everything else at maximum world activity.
- [ ] Both tells measure −23 LUFS over their first 160 ms; TELL has ≥11 dB peak headroom.
- [ ] Tell audio transient lands at gameplay window-open ±10 ms, on every supported device.
- [ ] The gameplay window is driven by game time, not by audio callbacks.
- [ ] Compressed tells (458 / 616 ms) stretch the gesture — not truncated, not padded.
- [ ] Debug overlay shows tell window vs. input press; window matches §5 within ±16 ms.
- [ ] Cold ambience −46 LUFS, warm −28 LUFS, and **no asset is individually normalized**.
- [ ] Leitmotif is continuous across R6 → R5 → R4 with no restart or re-fade.
- [ ] Loading a restored save starts warm with the interval already present — no fade-in.
- [ ] R6 phrase grows from the head at every length from 1 to 5.
- [ ] R6 completion is not louder than the offer, by peak or integrated.
- [ ] No sting event exists in the FMOD project.
- [ ] Nothing plays during the 1400 ms post-miss silence.
- [ ] The Sustain engage partial fires on the same tick the world effect arms.

## 12. Open — needs a Design decision before it gets decided implicitly

Both are raised in full in bible §10; repeated here because Engineering will hit them first.

1. **Repeat compression: single-step or iterative?** Single-step gives 458 / 616 ms and the 420 ms
   floor is unreachable. Iterative (0.88ⁿ) makes the floor load-bearing by the 4th tell. Reference
   audio currently covers single-step.
2. **Two open tell windows: which does an Answer resolve?** Legal in R5 under §5.5. Audio's
   recommendation is *the tell whose attack lands soonest*. Needs to be written down rather than
   falling out of an array order.
