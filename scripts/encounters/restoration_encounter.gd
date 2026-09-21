class_name RestorationEncounter
extends Node2D
## §7: the restoration encounter (R6) — the slice's thesis. It is **not** a
## boss fight: no HP, no damage, no fail state, no timer that can end badly
## (§11 AC#5). The Verse-bearer offers a phrase of notes — each note a tell
## against the same Answer verb combat uses, reusing the tell/window
## machinery from checkpoints 2-3 rather than a new input path.
##
## Design contracts (§7). Changing a number needs a Design sign-off.

const TellEmitterScript = preload("res://scripts/combat/tell_emitter.gd")

const NOTE_LEAD_MS: float = 700.0
const NOTE_SPACING_MS: float = 1100.0  # onset-to-onset; load-bearing, does not move (§7 narrative delivery)
const MISS_SILENCE_MS: float = 1400.0

const BASE_PHRASE_LENGTH: int = 3
const MAX_PHRASE_LENGTH: int = 5
const SHORTEN_TO_2_AFTER_FAILURES: int = 2
const SHORTEN_TO_1_AFTER_FAILURES: int = 4

## Minimum time a line stays fully legible, measured from the end of its
## 200 ms fade-in (§3.2 rule 4) — not from the line's onset. A line's
## earliest possible release-gate opening is therefore fade-in + this, i.e.
## LINE_RELEASE_GATE_MS below.
const LINE_MIN_HOLD_MS: float = 1800.0
const LINE_FADE_IN_MS: float = 200.0
const LINE_FADE_MS: float = 300.0
## Elapsed time since a line's onset at which its own 1800 ms floor of full
## legibility is reached. Two things happen at this mark: it becomes the
## earliest a successor may show (§3.2 rule 4's "whichever is later"), AND
## the line begins clearing itself over its own 300 ms fade-out regardless of
## whether a successor has actually shown yet — Scope 3's fix for two lines
## never being simultaneously legible (see _slot_visible's comment).
const LINE_RELEASE_GATE_MS: float = LINE_FADE_IN_MS + LINE_MIN_HOLD_MS
const MAX_NARRATIVE_LINES: int = 4

## §3.2 rule 4's mutual-exclusion threshold: a label at or above this alpha
## counts as "meaningfully legible." Engineering Lead's ruling (this issue,
## Scope 3 remediation) enforces "only one line legible at a time" directly
## against this threshold rather than deriving it from the two labels'
## independent fade timings — see _tick_narrative.
const LEGIBILITY_THRESHOLD: float = 0.30

const REGISTER_NAME := "verse_bearer"

## The approved restoration-encounter narrative (docs/narrative/vertical-slice-narrative.md
## §3.1), each within the ≤12 word / 4-line budget §7 sets.
const NARRATIVE_LINES: PackedStringArray = [
	"I was the ground note. Everything above was tuned to me.",
	"I drifted. Slowly. For years. And they followed me down.",
	"When I finally heard myself, I could not take it back.",
	"This is the pitch I have left. Answer it anyway.",
]

enum State { OFFERING, SILENCE, RESTORED }

signal restored()
signal line_shown(index: int, text: String)
signal line_hidden(index: int)

var state: int = State.OFFERING

var player: CharacterBody2D

var _emitter: TellEmitterScript

var _phrase_length: int = BASE_PHRASE_LENGTH
var _note_index: int = 0
var _consecutive_failures: int = 0

var _note_elapsed_ms: float = 0.0
var _silence_elapsed_ms: float = 0.0

var _narrative_index: int = 0
var _line_visible: bool = false
var _current_line_text: String = ""

## Which of the two labels (0 = _label, 1 = _label_b) most recently received
## a line — the two ping-pong on every show, one slot ahead. _line_visible /
## current_line_text() report on this slot, since it's always the most
## recent line, but every slot ticks its own clear independently (see
## _slot_visible etc. below) regardless of which one is "active."
var _active_label_index: int = 0

## Per-label narrative state, indexed the same way as _active_label_index.
## Each slot fades in over its own 200 ms, holds at full opacity until its
## own 1800 ms-of-legibility floor (2000 ms elapsed), then clears itself
## over 300 ms — unconditionally, whether or not a successor has shown yet.
##
## §3.2 rule 4 sanctions text overlapping a *note*, not text overlapping
## text ("a line is never interrupted by the next one") — Game Designer's
## ruling on the R6 playtest render (this issue) found the original
## implementation's overlap violated that: the outgoing line only started
## clearing once the incoming one released, so for ~200 ms both labels sat
## between roughly alpha 0.3-0.8 at once, superimposing two readable-ish
## sentences with no aligned words. Starting each line's own clear at its
## own floor — decoupled from when (or whether) a successor actually
## releases — is necessary but was found NOT sufficient on its own: Engineering
## Reviewer measured that the margin this creates is only ~3 frames on the
## nominal path and is consumed 1:1 by ordinary answer-timing jitter,
## reproducing the same superimposition under ~125-215 ms of reaction delay
## on the first note of a run. _tick_narrative therefore enforces the
## mutual-exclusion contract directly — see LEGIBILITY_THRESHOLD and the
## incoming/outgoing clamp below — rather than relying on this timing gap.
## If a release is delayed by real jitter past a line's own floor+300ms,
## that line finishes clearing before its successor shows — a brief blank
## screen, which the ruling accepts as the lesser defect versus ever
## showing two lines at once.
var _slot_visible: Array = [false, false]
var _slot_elapsed_ms: Array = [0.0, 0.0]
var _slot_index: Array = [-1, -1]

@onready var _label: Label = get_node_or_null("NarrativeLayer/Label")
@onready var _label_b: Label = get_node_or_null("NarrativeLayer/LabelB")


func _ready() -> void:
	call_deferred("_find_player")
	_emitter = TellEmitterScript.new()
	add_child(_emitter)
	_emitter.tell_resolved.connect(_on_note_resolved)
	_emitter.tell_missed.connect(_on_note_missed)
	if _label != null:
		_label.hide()
	if _label_b != null:
		_label_b.hide()
	_open_note()


func _label_for(index: int) -> Label:
	return _label if index == 0 else _label_b


func _find_player() -> void:
	if player != null:
		return
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		set_player(players[0])


## Lets a test (or a future spawner) wire the player directly rather than
## relying on the deferred group lookup — same rationale as EnemyBase's.
func set_player(p: CharacterBody2D) -> void:
	player = p


func _physics_process(delta: float) -> void:
	var delta_ms := delta * 1000.0

	match state:
		State.OFFERING:
			_note_elapsed_ms += delta_ms
			if _note_elapsed_ms >= NOTE_SPACING_MS:
				_open_note()
		State.SILENCE:
			_silence_elapsed_ms += delta_ms
			if _silence_elapsed_ms >= MISS_SILENCE_MS:
				_restart_phrase()
		State.RESTORED:
			pass

	_tick_narrative(delta_ms)


func _open_note() -> void:
	_note_elapsed_ms = 0.0
	AudioDirector.set_encounter_phrase_length(_phrase_length)
	AudioDirector.set_encounter_note_index(_note_index)
	_emitter.open_tell(NOTE_LEAD_MS, REGISTER_NAME)


func _on_note_resolved() -> void:
	if state != State.OFFERING:
		return
	_note_index += 1
	# A resolved note opens a gap before the next note's onset (§7's literal
	# 400 ms gap, or the attempt-boundary gap on the phrase's last note) —
	# a candidate release point for the queued narrative line either way.
	_maybe_release_narrative_line()
	if _note_index >= _phrase_length:
		_complete_attempt()
	# else: the next note opens on schedule via _physics_process's
	# NOTE_SPACING_MS timer, anchored to this note's own onset — a note
	# answered early must not pull the next one's onset forward (§7's
	# "the 1100 ms spacing does not move").


func _on_note_missed() -> void:
	if state != State.OFFERING:
		return
	_consecutive_failures += 1
	_phrase_length = _shortened_phrase_length_after_failure()
	state = State.SILENCE
	_silence_elapsed_ms = 0.0
	_maybe_release_narrative_line()  # the post-miss silence counts as a gap (§7.4)


func _complete_attempt() -> void:
	_consecutive_failures = 0
	if _phrase_length >= MAX_PHRASE_LENGTH:
		_restore()
		return
	# Phrase length is a single ladder (1..5, §7.5 as amended by PR #15): a
	# completed attempt always climbs exactly one rung from wherever
	# shortening left the player — never a snap back to base, and never a
	# jump straight into the extension track either.
	_phrase_length += 1
	_note_index = 0
	# The next note's onset is still scheduled by the running NOTE_SPACING_MS
	# timer (started when this attempt's final note opened) — an attempt
	# boundary on success is not a special pause, just a longer phrase.


func _restart_phrase() -> void:
	state = State.OFFERING
	_note_index = 0
	_open_note()


## §7.4 as amended by PR #15: the thresholds are absolute floors reached
## from wherever the player currently is, not a fixed step relative to it —
## "a player at 4 notes who fails twice drops to 2," the same target a
## player at base (3) drops to. A failure that doesn't cross a threshold
## (1st, 3rd, ...) holds the current length; it does not shorten on its own.
func _shortened_phrase_length_after_failure() -> int:
	if _consecutive_failures >= SHORTEN_TO_1_AFTER_FAILURES:
		return mini(_phrase_length, 1)
	if _consecutive_failures >= SHORTEN_TO_2_AFTER_FAILURES:
		return mini(_phrase_length, 2)
	return _phrase_length


func _restore() -> void:
	state = State.RESTORED
	GameState.restoration_complete = true
	restored.emit()


# --- Narrative delivery (§7 narrative delivery section, §11 AC#14) ---------

## The gate a line's own floor opens (§3.2 rule 4: 1800 ms of full legibility
## measured from the end of its 200 ms fade-in) still governs the earliest a
## successor may show — unchanged from Scope 1. What changed in Scope 3 is
## only when the OUTGOING line starts visually clearing: see _tick_narrative,
## which starts that the moment the outgoing's own floor is reached, not
## when this function next runs. Whether that head start is enough to keep
## both labels' rendered alpha from crossing LEGIBILITY_THRESHOLD at once is
## no longer left to the gap schedule's margin — _tick_narrative clamps the
## incoming's displayed alpha directly whenever the outgoing is still above
## threshold, so the mutual-exclusion contract holds regardless of jitter.
func _maybe_release_narrative_line() -> void:
	if _narrative_index >= MAX_NARRATIVE_LINES or _narrative_index >= NARRATIVE_LINES.size():
		return
	var active_slot_visible: bool = _slot_visible[_active_label_index]
	var active_slot_elapsed: float = _slot_elapsed_ms[_active_label_index]
	if active_slot_visible and active_slot_elapsed < LINE_RELEASE_GATE_MS:
		return  # the current line hasn't held its full 1800 ms of legibility yet
	if active_slot_visible:
		_active_label_index = 1 - _active_label_index
	_show_line(_narrative_index)
	_narrative_index += 1


func _show_line(index: int) -> void:
	var slot := _active_label_index
	_slot_visible[slot] = true
	_slot_elapsed_ms[slot] = 0.0
	_slot_index[slot] = index
	_line_visible = true
	_current_line_text = NARRATIVE_LINES[index]
	var label := _label_for(slot)
	if label != null:
		label.text = _current_line_text
		label.modulate.a = 0.0
		label.show()
	line_shown.emit(index, _current_line_text)


func _tick_narrative(delta_ms: float) -> void:
	# Pass 1: advance each visible slot's own elapsed-time timer and compute
	# its RAW alpha from that timer alone — fade-in, hold, self-clear — with
	# no awareness of the other slot yet. This is exactly Scope 3's original
	# per-slot logic, untouched: durations, the 1800 ms floor, and the
	# self-clear-at-floor behavior all still come from elapsed time only.
	var was_visible: Array = [_slot_visible[0], _slot_visible[1]]
	var raw_alpha: Array = [0.0, 0.0]
	var hidden_index: Array = [-1, -1]
	for slot in [0, 1]:
		if not was_visible[slot]:
			continue
		_slot_elapsed_ms[slot] += delta_ms
		var elapsed: float = _slot_elapsed_ms[slot]
		if elapsed < LINE_FADE_IN_MS:
			raw_alpha[slot] = clampf(elapsed / LINE_FADE_IN_MS, 0.0, 1.0)
		elif elapsed < LINE_RELEASE_GATE_MS:
			raw_alpha[slot] = 1.0
		else:
			# Past its own 1800 ms floor: this slot clears itself over 300 ms
			# regardless of whether a successor has shown yet (Scope 3 — see
			# the comment on _slot_visible for why the clear can't wait on
			# that release).
			var fade_elapsed: float = elapsed - LINE_RELEASE_GATE_MS
			if fade_elapsed >= LINE_FADE_MS:
				_slot_visible[slot] = false
				hidden_index[slot] = _slot_index[slot]
				if slot == _active_label_index:
					_line_visible = false
			else:
				raw_alpha[slot] = 1.0 - clampf(fade_elapsed / LINE_FADE_MS, 0.0, 1.0)

	# Pass 2: enforce "only one line meaningfully legible" as a direct clamp
	# on the RENDERED value, not as a consequence of the two timers' margin
	# (Engineering Lead's ruling, Scope 3 remediation — see LEGIBILITY_
	# THRESHOLD and the comment on _slot_visible for why the margin alone
	# wasn't robust to answer-timing jitter). The incoming (the most
	# recently shown slot) has its displayed alpha capped at the threshold
	# for as long as the outgoing (the other slot) is still above it. The
	# incoming's own _slot_elapsed_ms keeps accumulating throughout — only
	# the number written to modulate.a is held back — so once the cap lifts
	# the incoming may jump straight to wherever its real timer already is,
	# rather than restarting its fade-in.
	var incoming_slot := _active_label_index
	var outgoing_slot := 1 - _active_label_index
	var display_alpha: Array = raw_alpha.duplicate()
	if raw_alpha[outgoing_slot] > LEGIBILITY_THRESHOLD:
		display_alpha[incoming_slot] = minf(raw_alpha[incoming_slot], LEGIBILITY_THRESHOLD)

	for slot in [0, 1]:
		if not was_visible[slot]:
			continue
		var label := _label_for(slot)
		if hidden_index[slot] >= 0:
			if label != null:
				label.hide()
			line_hidden.emit(hidden_index[slot])
		elif label != null:
			label.modulate.a = display_alpha[slot]


func current_line_text() -> String:
	return _current_line_text if _line_visible else ""


func narrative_lines_delivered() -> int:
	return _narrative_index
