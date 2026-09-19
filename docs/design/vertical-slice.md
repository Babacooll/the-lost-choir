# Vertical Slice Design Specification — "The Cold Amphitheater"

Owner: Game Designer. Status: **approved for production inside existing creative direction**
(`docs/creative-direction.md`) and technical direction (`ARCHITECTURE.md`). This document is the
authoritative playable-design contract for the first vertical slice. It does not create new
creative pillars; where it would, it defers (see §10).

The slice exists to answer one question: **does "restoring specific broken relationships" work as a
playable metroidvania loop?** It is deliberately small. Content beyond this document is out of scope.

---

## 1. Scope

One zone, eight rooms, one silenced Verse, two enemy types, one ability gate, one secret.

Target play length: **12–18 minutes** for a first-time player, including one or two failed
restoration attempts. Not a demo of breadth — a demo of whether the loop lands.

### Hypotheses under test

| # | Hypothesis | Falsified if |
|---|---|---|
| H1 | Movement without any Verse is already pleasant to hold | Players describe pre-Verse traversal as a chore to get through |
| H2 | Answering a voice reads as defense, not as a parry reskin | Players call it "parry" and ignore the audio, reading visuals only |
| H3 | The same verb serving defense *and* restoration makes restoration feel earned | Restoration reads as a QTE or as a boss fight |
| H4 | One traversal verb refolds the map enough to feel metroidvania | Players do not notice the world closed a loop |
| H5 | Cold→warm is felt as consequence, not as a graphics setting | Players don't mention the change unprompted |
| H6 | Register→timing mapping (percussive=short lead, keening=long lead) is learnable in one zone | Players never form the mapping; both enemies feel like one timing |
| H7 | A secret paying out *meaning* (not power) still motivates exploration | Players who find R8 report it as empty/unrewarding |

Every downstream discipline should be able to point at which hypothesis its work serves.

---

## 2. Units and conventions

- Tile = 16 px. Render scale ×3. All distances below are in world px unless stated.
- Player collider: 18 px wide × 40 px tall (2.5 tiles). Origin at feet.
- All timings in ms, measured at 60 Hz fixed tick. Times are **design contracts**, not suggestions;
  changing one requires a Design sign-off, not an engineering judgment call.

---

## 3. Starting kit (pre-Verse)

The protagonist begins able to move and to strike, but **not to sing**. This is the slice's opening
statement: before you have a Verse, you can only hit things.

### 3.1 Movement

| Property | Value |
|---|---|
| Run max speed | 170 px/s |
| Accel to max | 90 ms |
| Decel to rest | 70 ms |
| Jump apex height | 56 px (3.5 tiles) |
| Time to apex | 320 ms |
| Fall gravity multiplier | 1.7× rise gravity |
| Variable jump cut | releasing Jump before apex sets `vy *= 0.45` |
| Terminal fall speed | 520 px/s |
| Coyote time | 100 ms |
| Jump input buffer | 120 ms |
| Landing lag | none — full control on contact |
| Air control | 100% of ground accel |

Edge cases:
- Coyote time does **not** apply after an intentional jump (no double jump via coyote).
- Jump buffer consumes on the first frame ground contact is true, including on a moving platform.
- Ceiling bonk: `vy` zeroed, no horizontal penalty.
- Corner correction: a jump that clips a ceiling corner within 4 px is nudged horizontally rather
  than stopped. This is not optional — H1 depends on it.

### 3.2 Strike (baseline offense)

| Phase | Duration |
|---|---|
| Startup | 90 ms |
| Active | 70 ms |
| Recovery | 140 ms |

- Reach: 22 px forward from collider edge, 30 px tall hitbox.
- Damage: 1.
- Cancellable into Jump from the first recovery frame; **not** cancellable during startup.
- Input buffered 120 ms.
- No combo string in the slice. One strike, held rhythm. Intentional: the player's un-Versed body is
  monotonous, and the Verse is what introduces musical variation.

### 3.3 Answer (the defensive tell/response verb — the slice's core mechanic)

Answer is not a parry. It is answering a voice. Mechanically it resolves an enemy's *note* before
that note becomes an attack.

| Property | Value |
|---|---|
| Startup | 0 ms (read on press) |
| Active "answer pose" | 180 ms |
| Recovery on whiff | 220 ms |
| Recovery on success | 0 ms |
| Pre-window input buffer | 120 ms (a press up to 120 ms *before* tell onset still counts) |
| Cooldown | none — but whiff recovery is the real cost |

**Success condition:** an Answer press lands inside an enemy's open tell window (§5).

**On success:** the incoming attack is unmade (no damage, no hitbox spawns), the enemy staggers for
900 ms, and the player holds a *resolved note* for 1200 ms (see §4.2). Audio: the enemy's tell
resolves rather than cuts off — it completes to its interval.

**On failure (whiff or no press):** the attack resolves normally. 1 damage, 180 px knockback,
400 ms hitstun, 600 ms invulnerability.

Design intent: whiffing costs 220 ms of recovery, which is long enough to be punished by a second
enemy but never long enough to feel like a death sentence. Mashing Answer is a losing strategy
against a 520 ms tell but is not instantly fatal — it degrades, it does not cliff.

### 3.4 Health and failure

- Player HP: 5. Enemy contact and attacks deal 1.
- No healing item in the slice. HP refills fully at the Verse-bearer and at zone entry.
- Death → respawn at zone entry (R1) or at the amphitheater rim (R6) once reached. Nothing is lost;
  enemies respawn. **Failure delays progress, it does not punish it** — this is a direction-level
  rule, not a difficulty preference.

---

## 4. The Verse: Low Drone

The slice restores exactly one Verse — the **low drone voice** (Audio's first register). It grants
one traversal verb and one combat tool, per the "grows in shape, not count" rule.

### 4.1 Sustain (traversal verb)

Hold to emit a held low drone from the restored seam.

| Property | Value |
|---|---|
| Input | hold (dedicated button) |
| Ramp-in | 180 ms before any world effect applies |
| Breath meter | 3000 ms at full |
| Refill rate | 1.5× drain (i.e. full refill in 2000 ms) |
| Refill delay | 500 ms after release |
| Movement while sustaining | run speed ×0.85; jump unaffected |
| Ramp-out | world effects release 120 ms after input release |

**World effects while sustaining:**
- **Membranes** (slack drum-skin discs) tauten into solid one-way-up platforms within 140 px of the
  player. They go slack on ramp-out — anything standing on one falls.
- **Bell-frames** (suspended) descend to their low position within 140 px, becoming reachable
  platforms; they rise again on ramp-out, carrying the player up with them if stood on.

Edge cases:
- Ramp-in exists so Sustain cannot be tapped to flicker platforms. Flicker-routing is a *later*
  game's advanced tech, not a slice mechanic.
- A membrane going slack while the player stands on it drops the player; it does not kill.
- Breath exhausting mid-traversal forces the ramp-out. This is the intended failure and the source
  of the slice's routing tension: **Sustain turns platforming into a breath-budget problem.**

### 4.2 Return (combat tool)

Return does not add a button. It adds a *meaning* to a button the player already owns.

- While holding a resolved note (1200 ms after a successful Answer), **Strike** becomes **Return**:
  the enemy's own note is released back at it.
- Startup 120 ms. Damage 3× Strike. Stagger 1600 ms.
- Visually and audibly it emanates from the gold seam (Art/Audio contract).
- If the 1200 ms lapses unspent, the note fades — no penalty, just a missed beat.

Design intent (serves H3): pre-Verse, a successful Answer only negates. Post-Verse, the same success
becomes a resource. Combat does not get a new toy — it gets deeper on inputs the player has already
mastered. Restoring a Verse should feel like *understanding more*, not *carrying more*.

---

## 5. Enemies and the tell contract

Both enemies are "husks of sound" per the art direction. Both obey the joint Design/Audio tuning
contract, which this document now makes concrete for the slice.

### Shared tell rules

1. Tell window opens at tell onset and remains open until attack resolution. The Answer window **is**
   the telegraph — there is no separate narrow sub-window.
2. The identifying transient — the part that tells you *which* attack this is — lands in the first
   **160 ms** of the tell.
3. Repeat compression: the 3rd and subsequent tell within one uninterrupted encounter compresses to
   **88%** of base lead time, floor 420 ms. Resets after 6 s out of combat.
4. The tell plays on a **dedicated dry channel**, never shared with ambience or flavor vocalization.
   An enemy whose tell is inaudible under the mix is a bug, not a tuning preference.
5. No enemy may begin a tell while another enemy's tell is open *and* within 200 ms of its onset —
   tells stagger so two open windows are always distinguishable. (Slice-wide encounter rule.)

### 5.1 Reed Husk — percussive / throat register, melee

| Property | Value |
|---|---|
| Tell lead | 520 ms |
| Attack | forward lunge, 40 px reach, 1 damage |
| HP | 3 (1 Strike = 1; 1 Return = 3) |
| Post-attack recovery | 700 ms |
| Aggro range | 220 px |
| Movement | walks at 60 px/s, does not jump |

Reads as: short, dry, percussive. Close. Answer early-ish.

### 5.2 Keening Husk — keening / high register, ranged

| Property | Value |
|---|---|
| Tell lead | 700 ms |
| Attack | projectile at 240 px/s, 1 damage, travels until wall |
| HP | 4 |
| Post-attack recovery | 900 ms |
| Aggro range | 380 px |
| Movement | stationary; pivots to face |

Reads as: long, thin, rising. Far. Answer late.

**H6 depends entirely on these two feeling like one rule with two values, not two unrelated fights.**
A successful Answer on the Keening Husk unmakes the projectile before it spawns — the player must
answer the *voice*, not dodge the projectile. If players dodge instead of answer, H2 and H6 are both
in trouble and that is a finding worth having.

---

## 6. Zone layout — eight rooms

Authored in LDtk per `ARCHITECTURE.md`. Camera: per-room bounds, no scrolling across doors.

```
                    [R8] secret
                      |
   [R1]--[R2]--[R3]--[R4]--[R5]--[R6]
     \                 |          /
      \______[R7]______|_________/   (opens only after the Verse)
```

| Room | Player intent | Teaches / tests | Gate |
|---|---|---|---|
| **R1 — The Cold Step** | "Where am I, and does moving feel good?" | Run, jump, coyote, corner correction. Near-silent ambience. No enemy. | — |
| **R2 — Reed Gallery** | "What can I do to the world?" | Strike, on a passive cracked husk that does not fight back. | — |
| **R3 — The First Answer** | "Something is speaking at me." | One Reed Husk, isolated, wide floor, no pit. Answer taught here or nowhere. | — |
| **R4 — Membrane Hall** | "I can see where I can't go." | Slack membranes; a visibly unreachable upper ledge leading to R5's high route and to R8. A shortcut door to R7, barred from this side. | Sustain (visible, unusable) |
| **R5 — The Colonnade** | "This is harder and I'm exposed." | Vertical pipe-organ climb. One Reed Husk on a mid-ledge, one Keening Husk above it. Falling costs progress, not life. | — |
| **R6 — The Cold Amphitheater** | "Someone is here, and they stopped." | The Verse-bearer. The restoration encounter (§7). | — |
| **R7 — The Warm Return** | "Oh — I've been here." | Sustain-gated membrane route; opens the shortcut door back into R4 and the drop to R1. Closes the loop. | Sustain (required) |
| **R8 — The Cracked Bell** | "I wonder." | Optional. Reached from R4's high ledge using Sustain + a breath-tight route. Contains a narrative fragment only — **no ability, no upgrade, no collectible counter.** | Sustain + execution |

### Critical path
R1 → R2 → R3 → R4 → R5 → R6 → *(restoration)* → R7 → R4/R1.

### Optional path
R4 high ledge → R8. Requires Sustain, so it is only available on the return leg — the player must
*remember* the ledge they could not reach. That memory is H4's actual test.

### Teaching beats
Each mechanic is introduced in a room where failing it costs nothing, then immediately reused in a
room where it costs something. Strike: taught R2 (no stakes) → used R3 (stakes). Answer: taught R3
(flat floor) → used R5 (height, two enemies). Sustain: taught R6 exit (flat) → used R7 (breath
budget) → mastered R8 (breath-tight).

**No room may be decorated to look complete.** Every screen in this slice must serve a row of this
table. If a space serves none, cut it.

---

## 7. The restoration encounter (R6)

This is the slice's thesis. It is **not** a boss fight. It must not read as one.

### Structure

The Verse-bearer — matte, cracked, silent-grey, seated in the amphitheater's focus — offers a phrase.
The player answers it. The same Answer verb used in combat, now used to agree rather than to defend.

1. **Offer.** The bearer sings a phrase of **3 notes**, each note a tell with a 700 ms lead (keening
   pacing — generous, this is not a reflex test).
2. **Response.** The player must Answer each note inside its window. Notes are spaced 1100 ms apart.
3. **On a missed note:** the phrase stops. A 1400 ms silence. The bearer re-offers **from the start**.
4. **Adaptive shortening:** after two consecutive failed attempts, the phrase drops to 2 notes. After
   four, to 1. It never drops below 1. The game meets the player; it does not gate them out.
5. **On completing the phrase:** the phrase extends — attempt 2 is 4 notes, attempt 3 is 5 notes.
   Completing **5 consecutive notes** restores the Verse.
6. **No damage. No HP. No fail state. No timer.** Failure costs only time and the sting of a phrase
   falling apart.

### Narrative delivery
The bearer's reason for going silent is delivered **in the gaps between notes** — one short line per
gap, so the player learns why this voice stopped *while* they are learning its phrase. No cutscene,
no log, no expository wall. (Content owned by Narrative Designer; this spec fixes the delivery slot
and the budget: **≤12 words per gap, 4 gaps maximum**.)

### On restoration
- The crack becomes the light source: a warm gold seam with calligraphic wave etchings spreading from
  it (Art contract).
- The ambient mix gains one interval of the leitmotif — permanently, zone-wide (Audio contract).
- R6's palette temperature lerps cold→warm over **2500 ms**, starting at the seam and propagating
  outward at roughly 300 px/s.
- On subsequent entry, R5, R4, R2 and R1 are warm. R7 and R8 are authored warm-on-first-sight.
- Sustain and Return become available immediately, in R6, before the player leaves. The player must
  be able to try the new verb in the room where they earned it.

**The encounter must land on agreement, not victory.** No health bar, no damage numbers, no "defeated"
state, no fanfare sting. If a playtester describes R6 as "the boss," the encounter has failed its
intent and that is a Design finding, not a tuning one.

---

## 8. Cold → warm: observable contract

Palette temperature is the primary storytelling lever, so it gets a testable definition rather than an
adjective.

| State | Requirement |
|---|---|
| Cold (pre-restoration) | Matte surfaces, no warm accent above the ambient floor, light sources cold and low-contrast. Gold/brass accents present but **unlit** — visibly dormant metal, not absent. |
| Transition | 2500 ms lerp, seam-origin, ~300 px/s propagation. Must be visible in a single unbroken shot without a cut or fade. |
| Warm (post-restoration) | Brass/gold accents lit as the "sound is alive" accent; measurable rise in scene warmth and contrast. |

Acceptance: a side-by-side screenshot of any restored room before and after must be unmistakably
different **to someone who has not played the game**. If it needs explaining, it is not a lever.

---

## 9. Diegetic UI budget

- HP: 5 discrete marks, rendered as intact/cracked, not as a bar.
- Breath: a single arc near the player's seam, visible **only while sustaining or refilling**.
- Resolved note (the 1200 ms Return window): the seam brightens. No icon, no timer, no number.
- No minimap in the slice. H4 must be tested against the player's actual memory of space. A minimap
  would answer H4 for them and invalidate the result.
- Debug overlay (per `ARCHITECTURE.md`): tell window vs. actual input press, toggleable, off by
  default in the delivered build. This is required from the first playable, not retrofitted.

---

## 10. Deferred — explicitly not decided here

- **Protagonist identity** remains open per `docs/creative-direction.md` and is **not** resolved by
  this spec. The slice uses **"the Listener"** as a provisional working handle: under-determined
  silhouette, no face read, no species read, no dialogue, no asserted backstory. Nothing in this
  slice canonizes it. Rationale: the slice's hypotheses concern what the protagonist *does*, not who
  they are — none of H1–H7 moves if the identity changes later. Resolving it would require a Creative
  Checkpoint and would block delivery of the first playable, which the Creative Director explicitly
  asked not to happen. It goes on the post-play question list instead.
- The full "why this Verse went quiet" taxonomy. The slice ships exactly one instance of one reason;
  it does not generalize the category system.
- Any second Verse, second zone, boss, economy, or map screen.

---

## 11. Acceptance criteria

The slice is ready for human evaluation when **all** of the following are observably true in a built,
runnable artifact:

1. A player can start the build and reach R6 using only in-game teaching — no external instructions
   beyond controls.
2. Movement matches §3.1 within ±16 ms / ±4 px, verified against the debug overlay.
3. Answer succeeds against both enemy types when pressed inside the tell window, and the debug overlay
   demonstrates the window matches §5 within ±16 ms.
4. A successful Answer on a Keening Husk prevents the projectile from spawning at all.
5. The restoration encounter completes, adapts on repeated failure per §7.4, and cannot damage or kill
   the player under any input.
6. After restoration, Sustain and Return are usable in R6 before leaving.
7. Sustain tautens membranes and lowers bell-frames per §4.1, and breath exhaustion forces ramp-out.
8. R7 is impassable before restoration and passable after; its shortcut door opens a real loop back to
   R4 and R1.
9. R8 is reachable only with Sustain and contains a narrative fragment and nothing else.
10. Cold→warm meets §8's side-by-side test for at least R6 and R4.
11. The leitmotif ambient mix gains one interval at restoration and retains it across a room
    transition and a save/load.
12. The debug overlay ships in the build, toggleable, default off.
13. The build runs on macOS and one other desktop platform, launched from a single documented command
    or double-click.

---

## 12. Dependencies

| Discipline | Needed for the slice |
|---|---|
| **Art** | Slice-scoped art rules; Listener silhouette (provisional); Reed Husk + Keening Husk; Verse-bearer matte→seam states; membrane and bell-frame readable affordances; cold/warm palette pair; the 8 rooms' tileset. |
| **Narrative** | This Verse's specific reason for silence; ≤12 words × ≤4 gaps for R6; R8's fragment; zone and room names if different from the working names above. |
| **Audio** | The unfinished leitmotif phrase + the one interval restoration adds; low drone register for the Verse; percussive and keening tell sounds on a dedicated dry channel; the R6 phrase (5 notes); near-silence ambience for the cold state. |
| **Engineering** | Everything in §§3–9, plus the debug overlay, save/load of the restoration flag, and a runnable export. |

Placeholder art and audio are acceptable for engineering to begin immediately and are expected to be
replaced by discipline deliverables before playtest. **Engineering must not wait on final assets.**
