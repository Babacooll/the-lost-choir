# Vertical Slice Narrative — the low drone

Owner: Narrative Designer. Status: **slice-scoped production content**, written inside the approved
creative direction (`docs/creative-direction.md`) against the playable contract
(`docs/design/vertical-slice.md`). It establishes no new creative pillar.

This is not the narrative bible. It is the minimum narrative the first slice makes audible, written
so it composes into a bible later rather than pre-empting one. Everything here serves a row of §1 of
the design spec; nothing here exists because the world "needs lore".

Two standing limits, from the approved direction, are respected throughout and are restated here so
nobody has to re-derive them:

- **The Listener is not written.** No dialogue, no asserted backstory, no relationship to the choir,
  nothing that implies a face, species, origin or history. Protagonist identity is an open creative
  gate. Nothing below works *because* of who the Listener is — the bearer addresses the pitch that
  answered it, not a person it recognises. See §7.
- **The slice seeds doubt; it does not reveal.** "The choir silenced itself" is earned across
  regions. This zone ships exactly one voice's private reason, and that reason stays ambiguous on
  the one question that matters (§2.2).

---

## 1. Why this Verse went quiet

**One instance. Not a taxonomy.** The "why this Verse went quiet" category system stays deferred per
§10 of the design spec; this document must not be read as the first row of a table.

### 1.1 The canonical fact

The low drone was the **ground note**. Its entire function was not to stop: the other Verses did not
carry their own pitch, they took it from the drone and sang against it. Being the reference was the
whole of the job.

Over a very long time, the drone went **flat**. Not suddenly, not catastrophically — it drifted, by
an amount too small to hear in any one year. Everything tuned to it drifted with it. The piece stayed
internally consistent the entire time it was going wrong, which is exactly why nobody caught it.

When the drone finally heard what it had become, the damage was already structural: not one wrong
note it could correct, but decades of a whole work built on a wrong foundation. It stopped.

Canonically, **it stopped itself** — believing that continuing was worse than silence, that the
kindest thing a ruined reference can do is stop being the reference. It has been sitting in the
amphitheater's focus since, not singing, holding the pitch it has and not trusting it.

### 1.2 Why this reason, specifically

- It is personal, not cosmological. Nothing about it explains the world; it explains **one voice**.
- It implies a system without describing one: if the others tuned to it, there were others, and they
  were load-bearing to each other. The player can feel a structure they are never shown.
- It is inseparable from the register. Only the *low drone* can have this reason — a keening voice or
  a percussive voice could not be the thing everything else was measured against. That is the test a
  second Verse's reason must also pass: **if the reason could be swapped onto a different register
  without loss, it is a lore-dump wearing a costume.**
- It is legible in the verb. `Sustain` is holding a low note until your breath runs out and the world
  goes slack. The bearer's failure was a holding problem. The player performs the bearer's job every
  time they cross a membrane, and pays for it in breath.

### 1.3 What it must never become in this slice

No villain. No cataclysm. No date, no war, no name for the piece, no count of how many Verses there
are, no map of who the others were. The bearer does not know what happened to anybody else, and the
slice never implies it does.

---

## 2. Narrative architecture

### 2.1 The four layers

| Layer | Content |
|---|---|
| **Canonical fact** | The drone drifted flat over a long time, took the others down with it, heard it too late, and chose silence as the lesser harm. |
| **What the player initially believes** | Something came and silenced this place. The bearer is a victim of it, and restoring it is undoing that damage. |
| **Evidence encounterable in the slice** | The four gap lines in R6 (§3); the cracked tuning bell in R8 (§4); the zone's architecture, which is built for a piece that is no longer being performed (§5). |
| **When it can become knowable** | The gap lines are unavoidable — every player gets them, interleaved with learning the phrase. R8 is optional and only reachable on the return leg. Nothing in the critical path requires R8 to make sense. |
| **Intentionally ambiguous** | **Whether it stopped or was stopped.** No line in the slice asserts agency. |

### 2.2 The ambiguity is the whole seed

The bearer never says "I stopped." It says what went wrong, and that it could not take the note back.
A player finishing the slice can hold either reading:

- *it was silenced, and it blames itself the way survivors do* — the belief they arrived with; or
- *it let go on purpose* — the first hairline crack in that belief.

Both readings are supported by the same four lines. Neither is confirmed. That is the slice's entire
contribution to the long revision, and it is **one data point about one voice** — a voice that stops
itself is not a choir that agrees to. Do not let a later pass "clarify" this; the ambiguity is the
deliverable.

---

## 3. R6 — the restoration encounter text

Budget honoured: **4 lines, ≤12 words each, delivered strictly in the gaps between the bearer's
notes.** No cutscene, no log, no wall.

### 3.1 The lines

| # | Line | Words |
|---|---|---|
| 1 | *I was the ground note. Everything above was tuned to me.* | 11 |
| 2 | *I drifted. Slowly. For years. And they followed me down.* | 10 |
| 3 | *When I finally heard myself, I could not take it back.* | 11 |
| 4 | *This is the pitch I have left. Answer it anyway.* | 10 |

Line 4 is the encounter's thesis and the reason it lands on **agreement, not victory**: it is a
request, the player's reply to it is the Answer verb they already own, and nothing about the exchange
is a defeat. "Answer it anyway" is the playable form of *choosing to sing it again anyway*.

### 3.2 Delivery rules (contract for Engineering and Audio)

1. **The bearer does not speak.** Its only sound is sung — the phrase itself. The lines are
   **rendered text**, not voiced performance. This is deliberate: a spoken/whispered voice is a
   *different Verse's register* per the approved sonic identity, and giving it to the drone would
   spend a register the slice does not own.
2. **One line per gap, in order, index persists across attempts.** A failed phrase does not rewind
   the text. The player hears lines 1–4 exactly once each, in sequence, however many attempts it
   takes.
3. **Definition of a gap**: any silence between two of the bearer's notes — including the 1400 ms
   silence after a broken phrase, which is the gap between the last note sung and the first note of
   the re-offer. This keeps the text flowing for a player the adaptive shortening has dropped to a
   1-note phrase (design spec §7.4), who would otherwise have no gaps left to receive it in.
4. **Display timing**: a line fades in at gap onset and holds through the following note, clearing
   when the next line begins or 1800 ms after onset, whichever is later. Notes are 1100 ms apart, and
   ten words are not readable in 1100 ms. *This is the one place the text extends past the literal
   gap; flagged to Game Designer in §7 rather than assumed.*
5. **Once the lines are spent, the encounter is wordless.** On a clean run this is deliberate and
   load-bearing: attempt 1 (3 notes) carries lines 1–2, attempt 2 (4 notes) carries lines 3–4, and
   the final 5-note phrase — the one that actually restores the Verse — has **no text at all**. The
   beat lands on the music and the agreement, not on being told something.
6. **No text on the restoration itself.** No title card, no name, no "Verse restored" line. The seam,
   the interval and the room's temperature are the payoff. Nothing is captioned.

### 3.3 The bearer is unnamed

The slice gives the player no word for it. Not a proper name, not a title, not a species. A name here
would be a lore object the slice cannot spend, and it would start implying a roster. If a name is ever
needed, it is needed by a later region, not by this room.

---

## 4. R8 — the fragment

Optional. Pays out **meaning and nothing else**: no ability, no upgrade, no counter, no stat, no door.
H7 asks whether that motivates, so the fragment has to be worth a remembered ledge and a breath-tight
route on its own.

### 4.1 What is in the room

**The tuning bell.** A drone needs something to be right against. The bell hanging in R8 is what this
choir tuned to — and it is cracked, and it is flat.

Under it, worn into the stone, are the marks of someone who came back to this spot over and over to
check themselves against it.

### 4.2 How it pays out — wordless first

The payout is **an interval the player hears**, not a text they read:

- The player arrives carrying the restored drone. They `Sustain` in the room. **The bell answers —
  and it is flat against the note they are holding.** Roughly a quarter-tone; near enough to have been
  trusted, wrong enough to ruin a long work. Exact cents are Audio's call; the requirement is that it
  is *audibly wrong to a non-musician* while clearly being the same note.
- The bearer blamed itself for drifting. The thing it measured itself against was already broken.

The player has to do nothing but hold the note they were just given, in the room they remembered. The
detour's reward is that the thing they already did becomes worse to think about.

### 4.3 The one carved line

One inscription, ≤8 words, for players who will not parse the interval:

> *I asked it every year. It never wavered.*

A bell stuck flat never wavers. The line reads as devotion on the first pass and as the joke of the
whole zone on the second. Who carved it is not stated.

### 4.4 What R8 must not do

- It must not confirm agency. The bell explains **why the drone drifted**, not **why the singing
  stopped**, and it says nothing whatsoever about the other Verses.
- It must not date itself. Whether the crack predates the silence or happened after it is
  **intentionally ambiguous and must stay that way** — an authored answer here would decide, offscreen,
  whether this place was ruined or ruined itself.
- No pickup prompt, no fanfare, no entry added to anything. The player leaves with nothing in their
  hands.

---

## 5. Names

Four working names are kept, four are changed, and the zone is renamed. Each change fixes a specific
defect, not a taste preference.

| | Working name | Name | Why |
|---|---|---|---|
| **Zone** | The Cold Amphitheater | **The Undersong** | The zone and R6 currently share one name. An *undersong* is the sustaining strain beneath a melody — it names the low drone's domain as a place, spoils nothing, and frees the amphitheater name for the room that is one. |
| R1 | The Cold Step | **The Landing** | "Cold" goes stale: R1 is warm on the return leg. "Landing" reads as stone and as the room's job — it teaches jumps. |
| R2 | Reed Gallery | *Reed Gallery* | Kept. Diegetic, and the passive cracked husk is a reed husk. |
| R3 | The First Answer | **The Antechoir** | "The First Answer" is a design label, not a place. An *antechoir* is the space before the choir — exactly where the first voice speaks at you. |
| R4 | Membrane Hall | *Membrane Hall* | Kept. Names the affordance the player must read before they own the key. |
| R5 | The Colonnade | *The Colonnade* | Kept. (*The Organ Colonnade* available if Art wants the pipe read in the name.) |
| R6 | The Cold Amphitheater | **The Amphitheater** | Collision resolved, and "Cold" is one half of a room whose entire point is changing temperature. (*The Focus* — the amphitheater's acoustic centre, where the bearer sits — is the alternate.) |
| R7 | The Warm Return | **The Slack Run** | "Warm" labels the reveal, and "Return" collides with the combat tool. The membranes here hang slack until the player holds the note; *run* is both the passage and the musical figure. |
| R8 | The Cracked Bell | *The Cracked Bell* | Kept, and now load-bearing (§4). |

Names are team-facing in this slice — §9 of the design spec ships no minimap and no room labels.
Nothing above needs to appear on screen.

---

## 6. Environmental storytelling — the authored minimum

One authored reason per room, and **no more**. This is the cap, not the starting point: a prop that
does not appear below does not need a narrative justification invented for it, and should not get one.

| Room | The one thing the space says |
|---|---|
| The Landing (R1) | The architecture is built to be sung in — sightlines and surfaces aimed at a focus you cannot see yet. Nothing is broken here. It is just not being used. |
| Reed Gallery (R2) | The passive husk is *seated*, in a row of identical empty seats. It did not die fighting; it stayed. |
| The Antechoir (R3) | The first husk that moves is in the room where performers waited to go on. It is still waiting. |
| Membrane Hall (R4) | Slack membranes hang at the height of a note nobody is holding. The unreachable ledge is visibly a route — worn, used, ordinary — which is why not reaching it stings. |
| The Colonnade (R5) | Pipes running the full height, carved with weathered notation, all of it for the part beneath — this whole structure exists to amplify one voice. |
| The Amphitheater (R6) | Every surface aims at the focus. One occupant. It has been sat in long enough to have worn the stone. |
| The Slack Run (R7) | A service route — the way the choir got to its places. Ordinary, well-worn, unceremonious. The world was somebody's job. |
| The Cracked Bell (R8) | §4. The marks under the bell are the only handwriting in the zone. |

---

## 7. Open, and what I did not decide

- **No Creative Checkpoint is required for this content.** The beat does not depend on who the
  Listener is: the bearer addresses the pitch that answered it, and never the being carrying that
  pitch. Line 4 asks for agreement from a voice, not from a person with a history here. If a later
  pass finds itself wanting the bearer to *recognise* the Listener, stop — that is the gate, and it
  is not mine to open.
- **Flagged to Game Designer** (§3.2 rule 4): the display of a gap line extends past the literal gap
  into the following note, because ten words are not readable in 1100 ms. The text still *begins* in
  the gap and the encounter still ends wordless. If Design wants the text strictly bounded by the
  silence, the lines drop to ~5 words each and lose lines 1 and 3's specificity — say so and I will
  rewrite rather than re-time.
- **Deferred, unchanged**: the "why this Verse went quiet" taxonomy; any second Verse's reason; the
  bearer's name; the other Verses' identities; anything about the collective choice.
- **For the post-play question list**: does R8 land as meaning, or as an anticlimax (H7)? And do
  players read the bearer as silenced, or as having stopped — the split in §2.2 is the thing worth
  measuring, and it is a question to ask *after* play, never a thing to explain before it.
