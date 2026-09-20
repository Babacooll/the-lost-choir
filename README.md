# The Lost Choir

Project home for **The Lost Choir**, an original 2D Metroidvania.

Approved creative direction: `docs/creative-direction.md`.
Approved technical direction: `ARCHITECTURE.md`.

Slice-scoped art direction: `docs/art/vertical-slice-art-direction.md`.

Vertical-slice implementation is in progress; see `## Status` below for what's landed
so far and `## Running the project` for how to open it.

## Status

- Creative Discovery: Done — Creative Director GO persisted in `docs/creative-direction.md`
- Game Technical Discovery: Done — Technical Direction GO persisted in `ARCHITECTURE.md`
  (engine: Godot 4; audio runtime: FMOD Studio integration)
- Vertical-slice implementation: **feature-complete**, against
  `docs/design/vertical-slice.md`. Checkpoint 1 (project bootstrap, player movement,
  debug overlay, CI skeleton), checkpoint 2 (Strike, Answer, input buffering,
  scripted dummy tell emitter), checkpoint 3 (Reed Husk, Keening Husk, the shared
  tell contract's stagger/arbitration/compression rules), checkpoint 4 (the R6
  restoration encounter — §7's offer/response phrase, adaptive shortening/
  extension, narrative delivery, and the restoration flag flip), checkpoint 5
  (Sustain and Return — §4.1's breath-gated traversal verb with real membranes
  and bell-frames, and §4.2's Strike-becomes-Return combat payoff), checkpoint 6
  (the cold→warm visual transition, §8 / art doc §4), checkpoint 7 (real audio —
  Godot-native interim, see `## Audio` below), and the seven-room zone graph
  (§6, LDtk-into-Godot pipeline) are all in this repository, with a runnable
  macOS export (`## Running the macOS build`) and a full pass against §11's
  acceptance criteria.

## Running the project (Godot editor)

Requires [Godot 4.3](https://godotengine.org/download) (GDScript, no C# build needed).

1. Open Godot 4.3.
2. **Import** → select this repository's `project.godot`.
3. Press **F5** (or the Play button) to run. The main scene is
   `scenes/levels/Zone.tscn` — the seven-room zone graph (§6 of the design
   spec), authored in `assets/levels/the_lost_choir.ldtk` and built at
   runtime by `scripts/levels/room.gd`. It boots into R1, The Cold Step.

   `scenes/test_room.tscn` is no longer the main scene, but is still present
   and still the place to open directly (Godot editor → open the scene → F6,
   or set it as the run scene temporarily) for isolated combat testing: a flat
   platform, one gap, and one raised ledge to exercise player movement
   (§3.1), a scripted dummy tell emitter to exercise Answer (§3.3) against,
   and a Reed Husk and a Keening Husk (§5) to fight. It is not reachable from
   `Zone.tscn`'s default run.

Controls: `A`/`D` or `←`/`→` to move, `Space` to jump, `J` to Strike (or Return,
while holding a resolved note post-restoration — §4.2), `K` to Answer, `L` to
hold Sustain (post-restoration only — §4.1), `F3` to toggle the debug overlay
(off by default; plots the tell window — including the identifying-transient
marker — against your Answer presses). `T` additionally opens a manual tell
window on `test_room.tscn`'s dummy emitter — that scene only.

## Running the macOS build

The slice exports to a double-clickable `.app` — no editor required (§11 AC#13). Two ways to get one:

**Download a built artifact:** every CI run on `main` produces one — see `## CI-produced builds` below.

**Export it yourself**, from the Godot editor or the command line, once you have Godot 4.3+ and its
export templates installed ([godotengine.org/download](https://godotengine.org/download); the editor's
**Editor → Manage Export Templates** menu fetches them for you):

```sh
godot --headless --path . --export-debug "macOS" "build/macos/The Lost Choir.app"
```

Then launch it either way:

```sh
open "build/macos/The Lost Choir.app"
```

or double-click `The Lost Choir.app` in Finder. It boots straight into R1, The Cold Step, with the same
controls as the editor build (see `## Running the project` above) and the debug overlay off by default
(`F3` to toggle — §11 AC#12).

The export preset (`macOS` in `export_presets.cfg`) is unsigned/un-notarized — fine for local and CI
smoke builds; a distributable build would need Apple Developer signing, which is out of this slice's
scope. Gatekeeper will show an "unidentified developer" prompt on first launch; right‑click → **Open**
(or **System Settings → Privacy & Security → Open Anyway**) to run it once, same as any unsigned `.app`.

## CI-produced builds

`.github/workflows/ci.yml` runs on every push/PR to `main`:
- **Headless GUT tests** — the full suite under `tests/unit/`.
- **Export smoke build (Linux)** — a portability check, not a second supported platform (cut in §13);
  its artifact isn't meant to be played, just proof the project still exports cleanly outside macOS.

The macOS `.app` above is exported locally/on demand rather than as a third CI job — CI runners are
Linux, and cross-exporting a macOS bundle from there needs the same templates and still can't be
launched/smoke-tested on that runner, so the Linux job stays the CI-side portability check and the
macOS export is the one you run to actually play the build.

## Audio

The slice ships **Godot-native interim audio**, not the FMOD Studio via GDExtension integration
`ARCHITECTURE.md` names — FMOD's SDK is proprietary and account/license-gated, and this environment has
no way to obtain it (`fmod/` is still an empty stub). `scripts/audio/audio_director.gd` implements the
same contract (`docs/audio/fmod-implementation-contract.md`) — bus topology, ducking, parameter names,
scheduling discipline, save/load silence — against `AudioServer`/`AudioStreamPlayer` instead, so
swapping in real FMOD later is a backend change behind the same entry points, not a redesign. Documented
gap: Godot has no real-time pitch-preserving time-stretch, so the compressed-tell `TellLead` scaling here
uses playback-rate (a pitch side effect) rather than the pitch-preserving stretch the real contract calls
for.

## Repository layout

- `ARCHITECTURE.md` — canonical technical baseline.
- `docs/` — creative direction and design specs.
- `scenes/`, `scripts/` — Godot scenes and GDScript.
- `assets/art`, `assets/audio`, `assets/levels` — discipline-organized game assets.
- `fmod/` — FMOD Studio project (stub; not wired — see `## Audio` above).
- `tests/` — GUT test suite (`addons/gut`).
- `export_presets.cfg` — the `Linux Smoke Build` (CI) and `macOS` (playable) export presets.
