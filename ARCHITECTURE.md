# Architecture — The Lost Choir

This document is the canonical technical baseline for The Lost Choir. It records what has
been decided, why, and what remains open. Update it through Technical Discovery or a
subsequent Technical Direction decision, not through routine production edits.

The Lost Choir is an original 2D Metroidvania. Its approved creative pillars are recorded
in `docs/creative-direction.md`; this document exists because those pillars carry real
technical consequences — the game's core combat mechanic and its progression system are
both audio-driven, not audio-decorated.

## Status

Game Technical Discovery approved by the workspace owner (Creative Director) on
2026-09-19 (GO on the Technical Direction Ready checkpoint presented on
[MICH-571](mention://issue/01a0bb4e-be3f-7414-9896-2898994de391)). This repository still
contains no game code — that begins with a vertical-slice scope decision, owned by the
appropriate Game Development authorities, not by this document.

## Why these decisions, not genre defaults

Two properties of the approved creative direction drive engine and audio choices away from
generic 2D-platformer defaults:

- **Audio is a combat mechanic.** The defensive tool times against an enemy's own
  vocal/sonic tell: ~450–600ms lead time for standard enemies (up to ~700–800ms for
  elites/bosses), with the identifying transient front-loaded in the first ~150–200ms, on a
  dry tell channel kept separate from ambience. That needs sample-accurate, pre-scheduled
  audio triggering, not fire-and-forget playback.
- **Music is cumulative world state, not a loop.** The leitmotif is one incomplete choral
  phrase that gains a voice/interval per restored Verse; biome/faction motifs are partial
  variants of that same phrase. That is vertical-layering adaptive music driven by
  persistent save state, not a playlist.

No multiplayer, online services, leaderboards, or cloud sync appear anywhere in the
approved creative direction or its discovery history — checked, not assumed. Networking is
treated as out of scope until Product/Creative direction says otherwise.

## Engine and audio runtime

| decision | choice | status |
|---|---|---|
| Engine | Godot 4, GDScript for gameplay logic | Approved (Technical Direction GO, 2026-09-19) |
| Audio middleware | FMOD Studio integration (GDExtension, e.g. `fmod-gdextension`) as the runtime for combat-tell scheduling and adaptive/leitmotif music; Godot's native audio buses handle only trivial one-shot UI sound | Approved (Technical Direction GO, 2026-09-19) |

Alternatives considered and rejected: Unity (larger ecosystem but runtime-fee history and
no 2D-specific advantage here), GameMaker (fastest 2D iteration but weaker shader/audio
control for the seam-glow and layered-mix requirements below), Unreal (2D is a poor fit).
For audio, a custom scheduled-playback and layering system built directly on Godot's
buses was considered and rejected: it would require solving scheduling and vertical
layering from scratch before combat timing could be tuned at all, with no track record on
this exact pattern, against FMOD's built-in quantized event playback and
parameter-driven layering designed for this.

These two are the project's foundational, expensive-to-reverse choices and are the only
ones that required explicit Technical Direction GO — nothing else below deviates from a
workspace standard or is comparably hard to reverse.

## System components

| concern | direction | rationale |
|---|---|---|
| Rendering/camera | Godot 2D renderer; `Light2D` / normal maps for the per-Verse seam-glow and cold→warm palette shift; per-region camera bounds | Palette temperature is the creative direction's primary storytelling lever — needs first-class 2D lighting, not sprite swaps |
| World/scene organization | Godot scene tree, one scene per room, ability-gated connections between rooms | Standard interconnected-metroidvania graph; no ECS needed at this scale |
| Physics/collision | Godot built-in 2D physics (`CharacterBody2D`, `TileMap` collision) | Standard, no unusual physics requirement in the creative direction |
| Input | Godot `InputMap` plus a thin input-buffering layer (buffer/coyote-time windows) | Combat tell/response windows are narrow (450–800ms) and load-bearing; naive input polling risks missed reads that read as unfair rather than a design signal |
| Gameplay/ability architecture | Verse-gated ability unlocks as a small state machine plus per-room gate flags; the same restoration flags drive rendering (seam-glow) and FMOD parameters (leitmotif layer) | One state model feeds traversal gating, visuals, and music — mirrors the creative direction's explicit cross-discipline convergence |
| Animation | Frame-based sprite animation (Aseprite → Godot import) | Art direction reads as painted 2D frames ("detail lives in surface wear, not linework density"), not rigged deformation; revisit per-creature only if a specific case needs procedural skeletal motion |
| Save/progression | Godot `Resource`-based save file: ability flags, per-Verse restoration state, world position | Small, flat state; no external database needed |
| Level/world authoring | LDtk (external, free, metroidvania-oriented) imported into Godot | Purpose-built for interconnected room/world-graph authoring rather than hand-building the graph in-editor |
| Dev/debug tooling | In-game debug overlay visualizing the combat tell/response window against actual input | The tell window is narrow and central to whether combat feels fair; needs instrumentation from the start, not after tuning problems appear |
| Performance/memory budgets | Deferred | No content yet to budget against; revisit at first vertical slice |
| Build/export | Godot export templates, PC first (Windows/macOS/Linux) | No platform requirement beyond this surfaced anywhere in the creative direction |
| Repository structure | Single Godot project repo; `docs/` for creative and technical direction; assets organized by discipline (art/audio/levels); FMOD project as a subfolder with its own build step | Keeps discipline ownership (Art/Narrative/Audio bibles, Engineering direction) visible at the top level |

## CI/CD and release path

**CI:** GitHub Actions, in this repository — conforms to the workspace technical standard
(`docs/technical-standards.md`, CI/release automation: `standard`). Headless Godot script
tests (GUT) and an export smoke build, wired once there is gameplay code to test; nothing
to configure yet at this stage.

**Release path: explicitly deferred.** No deployable artifact exists yet — there is no
vertical slice. Trigger: the first vertical-slice milestone, at which point the Engineering
Lead decides distribution (e.g. itch.io or Steam build automation) as its own Technical
Direction call.

## Conformance to the workspace technical standard

`docs/technical-standards.md` (workspace `04bf8515-48ab-4102-a8bb-a732d3c07108`) declares
defaults for backend, mobile, web, hosting, database, and CI/release automation — all
SaaS/mobile-shaped. None of it addresses game engine, game audio middleware, game
asset/animation pipelines, or game distribution, so none of those component classes are a
deviation from anything declared; they are new decisions this project is making for
itself. The one entry that transfers is CI/release automation (GitHub Actions), which this
project conforms to.

## Open / deferred

- Performance and memory budgets — deferred to first vertical slice.
- Distribution/release automation — deferred to first vertical-slice milestone.
- Protagonist identity and the exact taxonomy of "why this Verse went quiet" — these are
  Creative, not Engineering, decisions (see `docs/creative-direction.md`), and may still
  have technical implications (e.g. on save-state shape) once resolved.
