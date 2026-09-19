# The Lost Choir

Project home for **The Lost Choir**, an original 2D Metroidvania.

Approved creative direction: `docs/creative-direction.md`.
Approved technical direction: `ARCHITECTURE.md`.

Vertical-slice implementation is in progress; see `## Status` below for what's landed
so far and `## Running the project` for how to open it.

## Status

- Creative Discovery: Done — Creative Director GO persisted in `docs/creative-direction.md`
- Game Technical Discovery: Done — Technical Direction GO persisted in `ARCHITECTURE.md`
  (engine: Godot 4; audio runtime: FMOD Studio integration)
- Vertical-slice implementation: in progress, against
  `docs/design/vertical-slice.md`. Checkpoint 1 (project bootstrap, player movement,
  debug overlay, CI skeleton) and checkpoint 2 (Strike, Answer, input buffering,
  scripted dummy tell emitter) are in this repository.

## Running the project (Godot editor)

Requires [Godot 4.3](https://godotengine.org/download) (GDScript, no C# build needed).

1. Open Godot 4.3.
2. **Import** → select this repository's `project.godot`.
3. Press **F5** (or the Play button) to run. The main scene is
   `scenes/test_room.tscn` — a flat platform, one gap, and one raised ledge to
   exercise player movement (§3.1 of the design spec), plus a scripted dummy
   tell emitter to exercise Answer (§3.3) against.

Controls: `A`/`D` or `←`/`→` to move, `Space` to jump, `J` to Strike, `K` to
Answer, `T` to manually open a tell window on the dummy emitter, `F3` to
toggle the debug overlay (off by default; plots the tell window against your
Answer presses).

Running the CI-produced export build will be documented once the export pipeline lands
(see `.github/workflows/ci.yml` for the current smoke-build step).

## Repository layout

- `ARCHITECTURE.md` — canonical technical baseline.
- `docs/` — creative direction and design specs.
- `scenes/`, `scripts/` — Godot scenes and GDScript.
- `assets/art`, `assets/audio`, `assets/levels` — discipline-organized game assets.
- `fmod/` — FMOD Studio project (stub; wired in a later checkpoint).
- `tests/` — GUT test suite (`addons/gut`).
