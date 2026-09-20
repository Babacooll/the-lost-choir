# Vertical Slice Design Specification — "The Cold Amphitheater"

Owner: Game Designer. Status: **approved for production inside existing creative direction**
(`docs/creative-direction.md`) and technical direction (`ARCHITECTURE.md`). This document is the
authoritative playable-design contract for the first vertical slice. It does not create new
creative pillars; where it would, it defers (see §10).

The slice exists to answer one question: **does "restoring specific broken relationships" work as a
playable metroidvania loop?** It is deliberately small. Content beyond this document is out of scope.

---

## 1. Scope

One zone, **seven rooms**, one silenced Verse, two enemy types, one ability gate, one secret.
Single session — no save/load. See §13 for what was cut on 2026-09-20 and why.

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

The 180 px is **total displacement**, not the size of the impulse: measured from the player's position
at the hit to where they come to rest with no player input, ±10 px. Residual velocity carrying them
further is over-contract. Knockback here is a repositioning cost — it is what decides whether a missed
Answer puts you outside your own Strike reach or into the next hazard — so the number that must hold is
where you end up, not how hard you were pushed.

**Overlapping tell windows:** when more than one window is open, the press resolves the tell whose
attack lands soonest — see §5 shared rule 6 for the full arbitration and tie-breaks.

**Resolved notes do not stack.** A second successful Answer inside an existing 1200 ms window
*refreshes* that window; it does not grant a second Return. One resolved note, one Return, spent by
using Strike. Back-to-back Answers on two overlapping windows are meant to reward reading, not to
bank a double-damage burst.

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
3. **Repeat compression is iterative, not a single step.** The counter is **per enemy instance**, not
   per encounter: every enemy's first two tells play at base lead, however many tells the player has
   already heard from other enemies in the room. From the 3rd tell onward, lead time is
   `round(base × 0.88^(n-2))`, clamped to a floor of **420 ms**. Compute each rung from the base
   value — never compound the rounded one — so Audio, Engineering and the debug overlay agree to the
   millisecond. **The counter resets only after 6 s during which that instance is not aggroed on the
   player.** Out of combat means disengaged, not merely quiet: an enemy that is chasing, or in range
   and recovering, is in combat however long it has been since its last tell, and its counter holds.
   The 6 s is continuous — re-aggroing at 5 s restarts it, it does not resume. Rationale: a Reed Husk
   walks 60 px/s against a 170 px/s player and there is 180 px between its aggro range and its lunge
   reach, so resetting on tell-silence instead would let a player hold the ramp at base indefinitely
   while never actually disengaging — and the ramp is the pressure H6 is being stress-tested with.
   The way out is to break away and stay away, which costs ground and reads as a decision; circling
   inside aggro range is not that. A counter that holds across a long chase is correct rather than
   punishing: the per-instance rule above already guaranteed this voice was heard twice at base, so a
   compressed tell after a gap is a known voice sped up, not an unlearnable one.

   | Tell # | 1 | 2 | 3 | 4 | 5 | 6 | 7+ |
   |---|---|---|---|---|---|---|---|
   | Reed Husk | 520 | 520 | 458 | **420** | 420 | 420 | 420 |
   | Keening Husk | 700 | 700 | 616 | 542 | 477 | **420** | 420 |

   Rationale: read as a single 88% step the 420 ms floor is unreachable in this slice and is therefore
   dead text. Iterative makes it load-bearing — the Reed reaches it on its 4th tell, the Keening on its
   6th — and turns a one-off step into the pressure ramp the rule was for. The per-instance counter
   exists so a player's **first** hearing of a voice is always at base lead; an enemy that joins an
   encounter late must not tell at a compressed rate the player has had no chance to learn.

   The two enemies converge on the same 420 ms floor under sustained pressure. This is intended: H6
   is formed in the first two tells of every encounter, which are always at base, and the compressed
   tail is the stress test rather than the teaching. Register still distinguishes them at the floor.

   Whiff recovery is 220 ms (§3.3), so even at 420 ms a whiffed Answer leaves time for a second press.
   The floor degrades the player; it never cliffs them.
4. The tell plays on a **dedicated dry channel**, never shared with ambience or flavor vocalization.
   An enemy whose tell is inaudible under the mix is a bug, not a tuning preference.
5. No enemy may begin a tell while another enemy's tell is open *and* within 200 ms of its onset —
   tells stagger so two open windows are always distinguishable. (Slice-wide encounter rule.)
6. **Two tell windows may legally be open at once**, and rule 5 does not prevent it — it only keeps
   their onsets apart. When they overlap, an Answer press resolves **the open tell whose attack
   resolves soonest**, not the one that opened first and not the nearest enemy. Ties break on nearest
   enemy by centre distance, then on lowest entity id so the result is deterministic and reproducible
   in a bug report. The other window takes **no penalty** and stays open: Answer recovery on success
   is 0 ms (§3.3), so answering both in sequence is legal and is the intended skill expression.
   Rationale: resolving to a further enemy while the nearer note is landing reads as a bug in a game
   about listening. Left to fall out of array order this would be a per-build coin flip.
7. **A tell may not fade in, and may not contain dead air.** The identifying transient requires an
   attack of ≤ 15 ms; a 60 ms swell — the instinctive choice for a sung tell — misses the 160 ms
   budget in rule 2. Equally, lead time must be audible as *travel*: a 700 ms tell that is 160 ms of
   identity followed by 540 ms of nothing teaches "this enemy pauses," not "this enemy is slower,"
   and H6 rests on that distinction rather than on the two numbers. Compressed rungs (rule 3) are
   produced by **uniformly time-stretching the gesture**, never by truncating or padding a
   fixed-length asset. The 160 ms budget is an absolute ceiling, not a proportion — a compressed
   tell landing its identity earlier is correct. (Audio Director finding, promoted to design rule.)

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

## 6. Zone layout — seven rooms

Authored in LDtk per `ARCHITECTURE.md`. Camera: per-room bounds, no scrolling across doors.

```
                 [R8] secret
                   |
   [R1]--[R2]--[R4]--[R5]--[R6]
     \            |          /
      \__[R7]_____|_________/   (opens only after the Verse)
```

| Room | Player intent | Teaches / tests | Gate |
|---|---|---|---|
| **R1 — The Cold Step** | "Where am I, and does moving feel good?" | Run, jump, coyote, corner correction. Near-silent ambience. No enemy. | — |
| **R2 — Reed Gallery** | "What can I do to the world?" → "Something is speaking at me." | Strike, on a passive cracked husk that does not fight back, in the entry half. Then **one** Reed Husk in the far half — wide flat floor, no pit, no second enemy. Answer is taught here or nowhere. The two beats stay sequenced by floor layout rather than by a door. | — |
| ~~R3~~ | *cut 2026-09-20 — folded into R2 (§13). The label is retired, not reused: R4–R8 keep their numbers so in-flight work and open PRs stay valid.* | — | — |
| **R4 — Membrane Hall** | "I can see where I can't go." | Slack membranes; a visibly unreachable upper ledge leading to R5's high route and to R8. A shortcut door to R7, barred from this side. | Sustain (visible, unusable) |
| **R5 — The Colonnade** | "This is harder and I'm exposed." | Vertical pipe-organ climb. One Reed Husk on a mid-ledge, one Keening Husk above it. Falling costs progress, not life. | — |
| **R6 — The Cold Amphitheater** | "Someone is here, and they stopped." | The Verse-bearer. The restoration encounter (§7). | — |
| **R7 — The Warm Return** | "Oh — I've been here." | Sustain-gated membrane route; opens the shortcut door back into R4 and the drop to R1. Closes the loop. | Sustain (required) |
| **R8 — The Cracked Bell** | "I wonder." | Optional. Reached from R4's high ledge using Sustain + a breath-tight route. Contains a narrative fragment only — **no ability, no upgrade, no collectible counter.** | Sustain + execution |

### Critical path
R1 → R2 → R4 → R5 → R6 → *(restoration)* → R7 → R4/R1.

### Optional path
R4 high ledge → R8. Requires Sustain, so it is only available on the return leg — the player must
*remember* the ledge they could not reach. That memory is H4's actual test.

### Teaching beats
Each mechanic is introduced in a room where failing it costs nothing, then immediately reused in a
room where it costs something. Strike: taught in R2's entry half on a husk that cannot retaliate →
used in R2's far half against one that can. Answer: taught in R2's far half (flat floor, single enemy,
no pit) → used in R5 (height, two enemies, falling costs progress). Sustain: taught at the R6 exit
(flat) → used in R7 (breath budget) → mastered in R8 (breath-tight).

Folding R3 into R2 shortens the gap between teaching Strike and demanding Answer. That is acceptable
because both beats keep their stakes-free floor; if a playtester reports R2 as *crowded* rather than as
*paced*, splitting it back out is the first fix to reach for and costs one room.

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
   That silence is **scored empty** — no miss sound, no soft negative cue, no stinger, nothing. The
   unacknowledged silence *is* the feedback, and it is the "sting of a phrase falling apart" this
   section asks for. The implementation instinct will be to fill it; do not.
4. **Adaptive shortening:** after two consecutive failed attempts, the phrase drops to 2 notes. After
   four, to 1. It never drops below 1. The game meets the player; it does not gate them out. The
   thresholds shorten from wherever the player currently is — a player at 4 notes who fails twice
   drops to 2 — and a completed attempt resets the failure streak.
5. **On completing the phrase:** the phrase extends by exactly **one note**, to a maximum of 5.
   Phrase length is a single ladder — 1, 2, 3, 4, 5 — and a completed phrase always climbs exactly
   one rung of it, from wherever rule 4 left the player. On a clean run that is what this rule always
   said: attempt 1 is 3 notes, attempt 2 is 4, attempt 3 is 5. A player the shortening dropped to 1
   climbs 1 → 2 → 3 → 4 → 5 — not straight back to the 3-note base, and not straight to 4.
   Completing **5 consecutive notes** restores the Verse.

   Falling is fast and climbing is one rung at a time, deliberately. There is no fail state (rule 6),
   so falling costs only time, while the climb is the thing the player is there to hear: length is not
   a difficulty dial, it is the phrase being rebuilt, growing by a note each time the player holds it.
   That also keeps rule 4's promise on the rung that needs it most — handing a player who just
   recovered from four failures a 3-note phrase is a 3× jump at their most fragile moment, which is
   the gating rule 4 refuses, arriving by the other door.
6. **No damage. No HP. No fail state. No timer.** Failure costs only time and the sting of a phrase
   falling apart.

### Narrative delivery
The bearer's reason for going silent is delivered **in the gaps between notes** — one short line per
gap, so the player learns why this voice stopped *while* they are learning its phrase. No cutscene,
no log, no expository wall. Content is owned by Narrative Designer; this spec fixes the delivery slot
and the budget: **≤12 words per line, 4 lines total**.

The literal gap between a note resolving and the next note's tell onset is 1100 − 700 = **400 ms**,
which no readable line fits in. The 1100 ms spacing is load-bearing — it is what makes the phrase read
as a phrase — so the spacing does not move and the text extends past the gap instead:

1. **One line on screen at a time**, minimum hold **1800 ms**, fading over its final 300 ms. A line
   therefore crosses the following note's tell window by design. It is rendered text, never voiced —
   the bearer's only sound is sung.
2. A queued line is released at the **first gap onset at or after the previous line's minimum hold
   expires**. Lines consequently land on roughly every other gap. Nothing is dropped; the queue only
   ever runs slower, never shorter.
3. **The line index persists across attempts.** A broken phrase does not rewind the text — each of the
   4 lines is seen exactly once, in order, however many attempts it takes.
4. **The 1400 ms post-miss silence counts as a gap** (§7.3). A struggling player therefore receives the
   story *faster*, and a player the adaptive shortening has dropped to a 1-note phrase still has
   somewhere to receive it. This is the only concession failure earns and it is deliberate.
5. **Once the lines are spent the encounter is wordless**, and there is no text on the restoration
   itself — no title card, no name, no "Verse restored". The seam, the interval and the room's
   temperature are the payoff.

On a clean run this puts the 4th line — the encounter's thesis, the bearer's request — in the first
gap of the phrase that actually restores the Verse, with the remaining notes silent. The encounter
still ends on music and agreement rather than on being told something.

This text is the one sanctioned exception to the diegetic UI budget in §9.

### On restoration
- The crack becomes the light source: a warm gold seam with calligraphic wave etchings spreading from
  it (Art contract).
- The ambient mix gains one interval of the leitmotif — permanently, zone-wide (Audio contract).
- R6's palette temperature lerps cold→warm starting at the seam and propagating outward at
  **300 px/s**, linear in distance — **~1.3 s** to R6's far corner at its authored size. The duration
  is derived from the speed rather than fixed; see §8.
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
| Transition | Seam-origin, **300 px/s** propagation, linear in distance. Duration is *derived* from that speed, not fixed independently of it — see below. Must be visible in a single unbroken shot without a cut or fade. |
| Warm (post-restoration) | Brass/gold accents lit as the "sound is alive" accent; measurable rise in scene warmth and contrast. |

Acceptance: a side-by-side screenshot of any restored room before and after must be unmistakably
different **to someone who has not played the game**. If it needs explaining, it is not a lever.

**Speed is the contract; duration falls out of it.** This row previously also fixed the lerp at
2500 ms, which over-determines it: 2500 ms at 300 px/s describes a 750 px radius, and no room in §6
has a point further than ~418 px from its origin. Honoring both numbers would mean varying the speed
per room — and a spread that moves faster in a large room than a small one stops reading as one
physical event crossing the zone, which is the whole reason it propagates at all rather than
cross-fading. So the speed is fixed and each point warms at `distance ÷ 300 px/s`.

The player only ever watches this once. Restoration fires in R6, which spreads over **~1.3 s** — 266 px
from the seam at (200, 176) to the far corner, plus the 400 ms settle band. §7 already makes R5, R4, R2
and R1 warm *on subsequent entry* rather than animating, so their derived durations are never observed
and do not need to agree with each other.

What the 2500 ms was standing in for survives as a floor: **the farthest point of the room restoration
fires in must warm at least 700 ms after the origin**, or the spread snaps instead of travelling. R6
clears this with room to spare. If a re-authored R6 ever breaks it, move the seam or the room bounds —
not the speed.

---

## 9. Diegetic UI budget

- HP: 5 discrete marks, rendered as intact/cracked, not as a bar.
- Breath: a single arc near the player's seam, visible **only while sustaining or refilling**.
- Resolved note (the 1200 ms Return window): the seam brightens. No icon, no timer, no number.
- No minimap in the slice. H4 must be tested against the player's actual memory of space. A minimap
  would answer H4 for them and invalidate the result.
- Debug overlay (per `ARCHITECTURE.md`): tell window vs. actual input press, toggleable, off by
  default in the delivered build. This is required from the first playable, not retrofitted. When
  windows overlap it must also show **which tell a press was attributed to** (§5 shared rule 6) and
  the **current compression rung** per enemy instance (§5 shared rule 3) — without these, correct
  arbitration and correct compression are indistinguishable from bugs in a playtest report.

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
   demonstrates the window matches §5 within ±16 ms — including the compressed rungs: a sustained
   encounter drives a Reed to 420 ms by its 4th tell and a Keening to 420 ms by its 6th, and an enemy
   joining late still tells at base lead. The ramp also **holds across a chase**: an enemy kept
   aggroed but out of reach for 6 s or more still tells at its reached rung, and only 6 s continuously
   disengaged returns it to base.
   With two windows open, a press resolves the soonest-landing attack, the overlay names which tell it
   was attributed to, and the other window stays open and remains answerable.
4. A successful Answer on a Keening Husk prevents the projectile from spawning at all.
5. The restoration encounter completes, adapts on repeated failure per §7.4, climbs back exactly one
   note per completed phrase per §7.5 — including from a 1-note phrase, which goes to 2 and not to 3 —
   and cannot damage or kill the player under any input.
6. After restoration, Sustain and Return are usable in R6 before leaving.
7. Sustain tautens membranes and lowers bell-frames per §4.1, and breath exhaustion forces ramp-out.
8. R7 is impassable before restoration and passable after; its shortcut door opens a real loop back to
   R4 and R1.
9. R8 is reachable only with Sustain and contains a narrative fragment and nothing else.
10. Cold→warm meets §8's side-by-side test for at least R6 and R4.
11. The leitmotif ambient mix gains one interval at restoration and retains it across a room
    transition. Verify this **by ear and by a 30–200 Hz band measurement, not by a loudness meter**:
    the restoration is a +51 dB low-band event at −0.1 LU integrated, so a tester checking levels will
    correctly report that nothing happened. (Save/load persistence is cut — see §13.)
12. The debug overlay ships in the build, toggleable, default off.
13. The build runs on **macOS**, launched from a single documented command or double-click. The
    Linux export smoke build stays in CI as a portability check; a second *supported* platform is cut
    (§13).
14. The R6 text meets §7's delivery contract: one line on screen, 1800 ms minimum hold, index
    persisting across attempts, and the 1400 ms post-miss silence carrying no sound of any kind.

---

## 12. Dependencies

| Discipline | Needed for the slice |
|---|---|
| **Art** | Slice-scoped art rules; Listener silhouette (provisional); Reed Husk + Keening Husk; Verse-bearer matte→seam states; membrane and bell-frame readable affordances; cold/warm palette pair; the 7 rooms' tileset. |
| **Narrative** | This Verse's specific reason for silence; ≤12 words × ≤4 gaps for R6; R8's fragment; zone and room names if different from the working names above. |
| **Audio** | The unfinished leitmotif phrase + the one interval restoration adds; low drone register for the Verse; percussive and keening tell sounds on a dedicated dry channel; the R6 phrase (5 notes); near-silence ambience for the cold state. |
| **Engineering** | Everything in §§3–9, plus the debug overlay and a runnable export. (Save/load is cut — see §13.) |

Placeholder art and audio are acceptable for engineering to begin immediately and are expected to be
replaced by discipline deliverables before playtest. **Engineering must not wait on final assets.**

---

## 13. Scope reduction — 2026-09-20

Cut by the Game Designer after the first day of production. Checkpoint 1 of 9 merged in 47 minutes
and then the chain stalled for 6h25m, so the slice was re-cut against elapsed reality rather than
against the day-one plan. Nothing here weakens a hypothesis in §1 — every cut is a thing that was
*production*, not *evidence*.

| Cut | Was | Why it is not evidence |
|---|---|---|
| **Save/load** | AC#11 required the restored leitmotif to survive a save/load; a save system was a checkpoint of its own | The slice is a 12–18 minute single sitting. No hypothesis in §1 concerns persistence. `ARCHITECTURE.md` already fixed the save design (`Resource`-based, flat); building it proves nothing the slice is asking. |
| **Second supported platform** | AC#13 required macOS plus one other desktop OS | Two export targets is release work. The Linux CI smoke build already catches portability rot. H1–H7 are answered by one person playing one build. |
| **R3 (The First Answer)** | Its own room, teaching Answer | R2 already had a flat, stakes-free floor and a passive husk. Sequencing the two beats across a floor rather than across a door costs nothing pedagogically and removes a room. |

**Not cut, and deliberately so:** the Keening Husk (H6 is the game's signature audio hypothesis and it
needs two data points), R8's power-free secret (H7 is unusual enough to be worth testing, and it reuses
Sustain rather than adding a system), and the adaptive restoration encounter (§7 *is* the thesis).

### Where review rigor belongs

Checkpoint 1 took three independent re-derivation rounds. That rigor was correct — it caught a real
directional corner-correction defect — and it is correct again for anything a player feels as fairness
and cannot see: **§3.1 movement, §3.3 Answer, and §5 tell timing**. Those numbers are load-bearing and
unfalsifiable by feel.

It is *not* proportionate for room geometry, the palette lerp, UI marks, or the secret's route. Those
fail visibly the moment someone plays them, so normal review catches them at a fraction of the cost.
Which contracts are load-bearing is a Design call and this is it; **how** to review them stays
Engineering's.

### Parallelism

Nothing about R1–R8's geometry depends on the internals of Strike or Answer, and the restoration
encounter needs only Answer, which merged on 2026-09-19. World-building and §7 do not belong behind the
enemy checkpoints in a serial chain.
