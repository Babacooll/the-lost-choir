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
  debug overlay, CI skeleton) is in this repository.

## Running the project (Godot editor)

Requires [Godot 4.3](https://godotengine.org/download) (GDScript, no C# build needed).

1. Open Godot 4.3.
2. **Import** → select this repository's `project.godot`.
3. Press **F5** (or the Play button) to run. The main scene is
   `scenes/levels/Zone.tscn` — the seven-room zone graph (§6 of the design
   spec), authored in `assets/levels/the_lost_choir.ldtk` and built at
   runtime by `scripts/levels/room.gd`. It boots into R1, The Cold Step.
   `scenes/test_room.tscn` is still present for isolated player-movement
   exercises (§3.1) but is no longer the main scene.

Controls: `A`/`D` or `←`/`→` to move, `Space` to jump, `F3` to toggle the debug
overlay (off by default).

Running the CI-produced export build will be documented once the export pipeline lands
(see `.github/workflows/ci.yml` for the current smoke-build step).

## Repository layout

- `ARCHITECTURE.md` — canonical technical baseline.
- `docs/` — creative direction and design specs.
- `scenes/`, `scripts/` — Godot scenes and GDScript.
- `assets/art`, `assets/audio`, `assets/levels` — discipline-organized game assets.
- `fmod/` — FMOD Studio project (stub; wired in a later checkpoint).
- `tests/` — GUT test suite (`addons/gut`).
