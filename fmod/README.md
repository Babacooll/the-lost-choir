# FMOD project (stub) — still a stub, by necessity, not by omission

Placeholder for the FMOD Studio project and the `fmod-gdextension` runtime integration
decided in `ARCHITECTURE.md`. This subfolder exists so the repo layout is stable from
checkpoint 1 onward.

**Checkpoint 8 investigated whether the real FMOD SDK is obtainable in this environment
and confirmed it is not:** FMOD's SDK is proprietary and requires an authenticated
FMOD account/license to download; this runtime has no such credentials, no vendored
`fmod-gdextension` binaries, and no way to accept FMOD's EULA. This folder therefore
stays an empty stub — nothing here should be treated as evidence FMOD was integrated.

The full `docs/audio/fmod-implementation-contract.md` contract (bus topology, ducking,
parameters, scheduling discipline, save/load silence) is implemented instead against
Godot's native `AudioServer`/`AudioStreamPlayer` in `scripts/audio/audio_director.gd`,
as an **interim substitution**, not a silent deviation from `ARCHITECTURE.md`'s FMOD
decision. Parameter names and semantics mirror the contract exactly (`VerseLowDroneRestored`,
`PaletteWarmth`, `TellLead`, etc.) so that wiring the real FMOD Studio project into this
folder later is a backend swap behind those same entry points, not a redesign.

Known gaps the swap will need to close, documented in `audio_director.gd`'s header:
- Godot has no real-time pitch-preserving time-stretch; `TellLead` scaling uses
  playback-rate (`pitch_scale`), which shifts pitch as a side effect.
- Tell scheduling calls `play()` synchronously on the game-clock tick a tell window
  opens, rather than FMOD's `setDelay`-against-the-DSP-clock sample-accurate scheduling.
