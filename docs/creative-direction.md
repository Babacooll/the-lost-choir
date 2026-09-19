## Approved creative direction

Approved by the Creative Director on 2026-09-19 (GO on the Creative Checkpoint presented on [MICH-570](mention://issue/01a0bb4e-8b27-78fb-b689-5606264fd9b2)). This document is the canonical source for the game's foundational creative pillars — update it only through a new Creative Checkpoint, not by routine production edits.

The Lost Choir is an original 2D Metroidvania. Hollow Knight is a reference for format and quality ambition only — the direction below is deliberately built away from its silhouette language, insect motifs, ink-wash rendering, and lore structure.

### Intent

A metroidvania about restoring specific broken relationships, not collecting power. Every ability the player gains is legible simultaneously as a traversal verb, a combat tool, a piece of world history, a visual scar-turned-light, and an audible voice rejoining a structure. The player should feel like they are making the world audible and warm again, one specific old wound at a time — not defeating a villain or filling a meter.

### Core loop (Game Design)

Explore → find a silenced Verse → restore it via a call-and-response skill-check encounter (failure delays progress, it does not punish) → gain one permanent traversal verb and one combat tool. Movement and abilities grow in *shape*, not count — each restored Verse adds one distinct movement verb and one distinct combat tool, never an interchangeable stat upgrade.

Combat is close-to-mid range with readable telegraphs. The defensive tool is timed against an enemy's own vocal/sonic tell, not a generic parry window. Joint Design/Audio tuning contract (discovery-stage, to be refined during vertical slice): tell lead time ~450–600ms for standard enemies (up to ~700–800ms for elites/bosses, compressing on repeat exposure within an encounter); the identifying transient front-loaded in the first ~150–200ms of the tell; the defensive window open for the full telegraph, from tell onset to attack resolution. Every enemy with this tell must have a dry, uncluttered acoustic read reserved exclusively for tells — never shared with ambient or flavor vocal sound.

### World premise and emotional thesis (Narrative)

The world was held together — geography, weather, the boundary between regions — by a standing choir of voices, each Verse a distinct part of one continuous piece. It stopped through a collective failure of nerve or consensus, not a single villain or cataclysm; the silence itself is what is slowly rotting the world. Each silenced Verse has its own specific reason for going quiet, rather than one shared lore-dump explaining all of them at once.

Restoring a Verse is not "gaining power" or "healing the world" in the abstract — it is the protagonist learning to hold one specific voice's unresolved reason for going silent, and choosing to sing it again anyway. The restoration encounter should land on agreement to continue, not victory over an obstacle.

The protagonist starts believing the choir was silenced by something external; evidence across regions should let players revise that toward "the choir silenced itself," earned through discovery rather than a single expository reveal.

**Open, not yet approved:** the protagonist's specific identity/relationship to the choir, and the exact number of "why this Verse went quiet" categories needed for the roster to feel systemic. These require their own follow-up approval before they're treated as canonical (protagonist identity is a creative gate in its own right).

### Visual language — "Architecture of Resonance" (Art)

The world reads as an instrument, not a hive: amphitheaters, bell-frames, pipe-organ colonnades, throat-shaped chambers, string/membrane structures, carved sheet-music reliefs weathered into stone. Silhouette grammar is rounded and resonant — bell curves, horn bells, larynx curvature, drum-skin discs — never angular, segmented, chitinous, or insectoid.

Palette is warm and material: ochre, terracotta, aged bronze/verdigris, candle-wax cream, with brass/gold as the "sound is alive" accent. Silence reads cold and matte; restored sound reads warm and lit — palette temperature is the primary storytelling lever. Edges are painterly and textured (worn stone, cracked wax, oxidized metal), not crisp ink outlines; detail lives in surface wear, not linework density.

Creatures are "husks of sound" built from instrument anatomy — cracked resonating-chamber torsos, pipe-limbs, string-tendons, drum-skin membranes over bone-like frames, mouths as broken bells or split reeds. No wings, exoskeleton segmentation, or insect eyes.

Restoring a Verse is a material transformation, not a UI flourish: before restoration a Verse-bearer is matte, cracked, silent-grey; on restoration the crack itself becomes the light source — a warm gold repaired seam with calligraphic, near-musical-notation wave etchings spreading from it. The player's traversal/combat use of a restored Verse visibly emanates from that seam.

### Sonic identity (Audio)

The choir is a broken ensemble of identifiable individual voices, not ambient texture. Forbidden by default: a generic "sad choir pad" used as atmospheric wallpaper, reusing the same vocal register for both combat tells and ambience, and orchestral swell as the only payoff for ability unlocks.

Each Verse fragment corresponds to one distinct vocal register/technique (e.g. a low drone voice, a percussive/rhythmic voice, a keening high voice, a spoken/whispered voice), mirroring the "grows in shape, not number" principle from Design. Instrumentation stays sparse and grounded (bowed/struck resonant objects, non-orchestral drones) so voice remains the foreground signature.

Leitmotif approach: a single unfinished choral phrase, incomplete and missing intervals, established near a cappella in the opening minutes. Each restored Verse completes one more interval/voice of that phrase in the world's ambient mix — progression is audibly cumulative. Biome/faction motifs are corrupted or partial variants of fragments of that same phrase, not independent themes. Silence is a primary instrument: un-restored areas default toward near-silence or single-source ambience so each restoration is a genuine dynamic-range event.

Register-to-combat mapping proposal (pending joint tuning pass): percussive/throat-voice tells read as short-lead melee bursts; keening-voice tells read as longer-lead ranged/AoE — one mental model spans both narrative meaning and combat timing.

### Cross-discipline convergence

These four pillars were built to interlock, not stand independently: Art's crack-seam visual is designed to sync to Audio's per-Verse interval and to Narrative's micro-mystery; Audio's four vocal registers are proposed to map onto Design's movement-verb/combat-telegraph differentiation and onto Narrative's "why this voice went quiet" categories; Design and Audio share a draft joint tuning contract for the sound-cue combat mechanic.

### What this unlocks

Game Technical Discovery ([MICH-571](mention://issue/01a0bb4e-be3f-7414-9896-2898994de391)) is now eligible for promotion. Art, Narrative, and Audio begin codifying their canonical bibles against this direction. Design begins the joint tuning pass with Audio on combat telegraph timing.
