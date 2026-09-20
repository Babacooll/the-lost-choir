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
- Vertical-slice implementation: in progress, against
  `docs/design/vertical-slice.md`. Checkpoint 1 (project bootstrap, player movement,
  debug overlay, CI skeleton), checkpoint 2 (Strike, Answer, input buffering,
  scripted dummy tell emitter), checkpoint 3 (Reed Husk, Keening Husk, the shared
  tell contract's stagger/arbitration/compression rules), checkpoint 4 (the R6
  restoration encounter — §7's offer/response phrase, adaptive shortening/
  extension, narrative delivery, and the restoration flag flip), and the
  seven-room zone graph (§6, LDtk-into-Godot pipeline) are in this repository.

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

Controls: `A`/`D` or `←`/`→` to move, `Space` to jump, `J` to Strike, `K` to
Answer, `F3` to toggle the debug overlay (off by default; plots the tell
window — including the identifying-transient marker — against your Answer
presses). `T` additionally opens a manual tell window on `test_room.tscn`'s
dummy emitter — that scene only.

Running the CI-produced export build will be documented once the export pipeline lands
(see `.github/workflows/ci.yml` for the current smoke-build step).

## Repository layout

- `ARCHITECTURE.md` — canonical technical baseline.
- `docs/` — creative direction and design specs.
- `scenes/`, `scripts/` — Godot scenes and GDScript.
- `assets/art`, `assets/audio`, `assets/levels` — discipline-organized game assets.
- `fmod/` — FMOD Studio project (stub; wired in a later checkpoint).
- `tests/` — GUT test suite (`addons/gut`).
